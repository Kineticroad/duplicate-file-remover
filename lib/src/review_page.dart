import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import 'app_settings.dart';
import 'duplicate_scanner.dart';
import 'l10n/strings.dart';
import 'media_scanner.dart';
import 'trash_store.dart';

/// 중복 그룹. [files] 의 첫 번째가 남기기를 추천하는 파일.
class ReviewGroup {
  ReviewGroup(this.files);
  final List<DuplicateFile> files;
  DuplicateFile get recommended => files.first;
  int get totalBytes => files.fold(0, (sum, f) => sum + f.size);
}

/// 검토 화면 상태: 그룹 목록과 삭제할 파일 선택.
class ReviewController extends ChangeNotifier {
  ReviewController(List<ScanDuplicateGroup> groups, {this.trash})
    : groups = [
        for (final g in groups) ReviewGroup([g.keep, ...g.duplicates]),
      ] {
    selectRecommended();
  }

  final List<ReviewGroup> groups;

  /// 지정하면 삭제 대신 휴지통으로 이동.
  final TrashStore? trash;
  bool get toTrash => trash != null;
  final Set<String> selected = {};

  int get selectedCount => selected.length;
  int get selectedBytes => groups
      .expand((g) => g.files)
      .where((f) => selected.contains(f.path))
      .fold(0, (sum, f) => sum + f.size);

  bool isSelected(DuplicateFile f) => selected.contains(f.path);

  /// 추천 파일을 제외한 모든 파일을 삭제 대상으로 선택.
  void selectRecommended() {
    selected
      ..clear()
      ..addAll(groups.expand((g) => g.files.skip(1).map((f) => f.path)));
    notifyListeners();
  }

  void clearSelection() {
    selected.clear();
    notifyListeners();
  }

  /// 삭제 선택을 바꾼다. 그룹의 모든 파일이 선택되는 경우는 막고 false 를 돌려준다.
  bool setSelected(ReviewGroup group, DuplicateFile file, bool value) {
    if (value) {
      final others = group.files.where((f) => f.path != file.path);
      if (others.every(isSelected)) return false;
      selected.add(file.path);
    } else {
      selected.remove(file.path);
    }
    notifyListeners();
    return true;
  }

  /// 선택된 파일을 삭제한다. 반환: (성공, 실패).
  Future<(int, int)> deleteSelected(void Function(int done) onProgress) async {
    final targets = groups
        .expand((g) => g.files)
        .where((f) => selected.contains(f.path))
        .toList();
    var ok = 0, failed = 0;
    final removed = <String>{};
    for (var i = 0; i < targets.length; i++) {
      final f = targets[i];
      try {
        final file = File(f.path);
        if (file.existsSync()) {
          if (trash != null) {
            trash!.moveToTrash(f.path);
          } else {
            file.deleteSync();
          }
        }
        removed.add(f.path);
        ok++;
      } on FileSystemException {
        failed++;
      }
      onProgress(i + 1);
      if (i % 10 == 9) await Future<void>.delayed(Duration.zero);
    }
    for (final g in groups) {
      g.files.removeWhere((f) => removed.contains(f.path));
    }
    groups.removeWhere((g) => g.files.length < 2);
    selected.removeAll(removed);
    MediaScanner.scan(removed);
    notifyListeners();
    return (ok, failed);
  }
}

/// 수동 삭제: 중복 그룹 목록을 보여주고, 선택한 파일만 삭제한다.
class ReviewPage extends StatefulWidget {
  const ReviewPage({super.key, required this.controller});
  final ReviewController controller;

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  ReviewController get c => widget.controller;

  Future<void> _delete(Strings s) async {
    if (c.selectedCount == 0) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          c.toTrash ? Icons.delete_outline : Icons.delete_forever,
          color: Theme.of(context).colorScheme.error,
        ),
        title: Text(c.toTrash ? s.trashConfirmTitle : s.deleteConfirmTitle),
        content: Text(
          c.toTrash
              ? s.trashConfirmBody(
                  c.selectedCount,
                  formatBytes(c.selectedBytes),
                )
              : s.deleteConfirmBody(
                  c.selectedCount,
                  formatBytes(c.selectedBytes),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(s.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(c.toTrash ? s.trashConfirmTitle : s.delete),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final total = c.selectedCount;
    final progress = ValueNotifier(0);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: ValueListenableBuilder(
            valueListenable: progress,
            builder: (context, done, _) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(
                  value: total == 0 ? null : done / total,
                ),
                const SizedBox(height: 12),
                Text(
                  c.toTrash ? s.trashing(done, total) : s.deleting(done, total),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final (deleted, failed) = await c.deleteSelected((d) => progress.value = d);
    if (!mounted) return;
    Navigator.of(context).pop(); // 진행 창 닫기
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          c.toTrash
              ? s.trashResult(deleted, failed)
              : s.deleteResult(deleted, failed),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return ListenableBuilder(
      listenable: c,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: Text(s.reviewTitle),
          actions: [
            PopupMenuButton<int>(
              onSelected: (v) =>
                  v == 0 ? c.selectRecommended() : c.clearSelection(),
              itemBuilder: (_) => [
                PopupMenuItem(value: 0, child: Text(s.selectRecommended)),
                PopupMenuItem(value: 1, child: Text(s.clearSelection)),
              ],
            ),
          ],
        ),
        body: c.groups.isEmpty
            ? Center(child: Text(s.reviewEmpty))
            : Column(
                children: [
                  Material(
                    color: cs.surfaceContainerHighest,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              s.reviewSummary(
                                c.groups.length,
                                c.selectedCount,
                                formatBytes(c.selectedBytes),
                              ),
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: c.groups.length,
                      itemBuilder: (context, i) =>
                          _GroupCard(controller: c, index: i),
                    ),
                  ),
                ],
              ),
        bottomNavigationBar: c.groups.isEmpty
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: cs.error),
                    icon: Icon(
                      c.toTrash ? Icons.delete_outline : Icons.delete_forever,
                    ),
                    label: Text(
                      c.toTrash
                          ? s.moveToTrashSelected(
                              c.selectedCount,
                              formatBytes(c.selectedBytes),
                            )
                          : s.deleteSelected(
                              c.selectedCount,
                              formatBytes(c.selectedBytes),
                            ),
                    ),
                    onPressed: c.selectedCount == 0 ? null : () => _delete(s),
                  ),
                ),
              ),
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.controller, required this.index});
  final ReviewController controller;
  final int index;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final group = controller.groups[index];
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => _openCompare(context, group, 0),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      s.groupTitle(
                        index + 1,
                        group.files.length,
                        formatBytes(group.totalBytes),
                      ),
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.compare, size: 18),
                    label: Text(s.compareTitle),
                    onPressed: () => _openCompare(context, group, 0),
                  ),
                ],
              ),
            ),
          ),
          for (final (i, f) in group.files.indexed)
            _FileRow(
              controller: controller,
              group: group,
              file: f,
              recommended: i == 0,
              onTap: () => _openCompare(context, group, i),
            ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  void _openCompare(BuildContext context, ReviewGroup group, int initial) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GroupComparePage(
          controller: controller,
          group: group,
          initialIndex: initial,
        ),
      ),
    );
  }
}

class _FileRow extends StatelessWidget {
  const _FileRow({
    required this.controller,
    required this.group,
    required this.file,
    required this.recommended,
    required this.onTap,
  });

  final ReviewController controller;
  final ReviewGroup group;
  final DuplicateFile file;
  final bool recommended;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final cs = Theme.of(context).colorScheme;
    final selected = controller.isSelected(file);
    return ListTile(
      onTap: onTap,
      leading: FileThumbnail(path: file.path, size: 52),
      title: Text(
        _nameOf(file.path),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: selected
            ? TextStyle(color: cs.error, decoration: TextDecoration.lineThrough)
            : null,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_dirOf(file.path), maxLines: 1, overflow: TextOverflow.ellipsis),
          Wrap(
            spacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(formatBytes(file.size)),
              if (file.note != null) Text('· ${file.note}'),
              if (recommended) _Badge(text: s.keepRecommended),
            ],
          ),
        ],
      ),
      isThreeLine: true,
      trailing: _DeleteCheckbox(
        controller: controller,
        group: group,
        file: file,
      ),
    );
  }
}

class _DeleteCheckbox extends StatelessWidget {
  const _DeleteCheckbox({
    required this.controller,
    required this.group,
    required this.file,
  });

  final ReviewController controller;
  final ReviewGroup group;
  final DuplicateFile file;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final selected = controller.isSelected(file);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Checkbox(
          value: selected,
          activeColor: Theme.of(context).colorScheme.error,
          onChanged: (v) {
            if (!controller.setSelected(group, file, v ?? false)) {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(content: Text(s.mustKeepOne)));
            }
          },
        ),
        Text(
          selected ? s.willDelete : s.willKeep,
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, color: cs.onPrimaryContainer),
      ),
    );
  }
}

/// 그룹 내 파일들을 미리보기·정보와 함께 나란히(세로로) 비교하는 화면.
class GroupComparePage extends StatefulWidget {
  const GroupComparePage({
    super.key,
    required this.controller,
    required this.group,
    this.initialIndex = 0,
  });

  final ReviewController controller;
  final ReviewGroup group;
  final int initialIndex;

  @override
  State<GroupComparePage> createState() => _GroupComparePageState();
}

class _GroupComparePageState extends State<GroupComparePage> {
  late final _keys = [for (final _ in widget.group.files) GlobalKey()];

  @override
  void initState() {
    super.initState();
    if (widget.initialIndex > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _keys[widget.initialIndex].currentContext;
        if (ctx != null) Scrollable.ensureVisible(ctx);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final files = widget.group.files;
    final reference = files.first;

    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: Text(s.compareTitle)),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(s.sameContentNote, style: theme.textTheme.bodySmall),
              const SizedBox(height: 12),
              for (final (i, f) in files.indexed)
                Card(
                  key: _keys[i],
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Text(
                              '#${i + 1}',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(width: 8),
                            if (i == 0) _Badge(text: s.keepRecommended),
                            const Spacer(),
                            _DeleteCheckbox(
                              controller: widget.controller,
                              group: widget.group,
                              file: f,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        FilePreview(path: f.path),
                        const SizedBox(height: 8),
                        _FileInfoTable(file: f, reference: reference),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 파일 정보 표. [reference](추천 파일)와 값이 다른 항목은 강조한다.
class _FileInfoTable extends StatelessWidget {
  const _FileInfoTable({required this.file, required this.reference});
  final DuplicateFile file;
  final DuplicateFile reference;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final modified = _modifiedOf(file.path);
    final refModified = _modifiedOf(reference.path);

    TableRow row(String label, String value, {bool differs = false}) =>
        TableRow(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text(label, style: theme.textTheme.labelMedium),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: SelectableText(
                value,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: differs ? FontWeight.bold : null,
                  color: differs ? theme.colorScheme.tertiary : null,
                ),
              ),
            ),
          ],
        );

    final isRef = identical(file, reference);
    return Table(
      columnWidths: const {0: IntrinsicColumnWidth(), 1: FlexColumnWidth()},
      defaultVerticalAlignment: TableCellVerticalAlignment.top,
      children: [
        row(
          '${s.fileNameField}  ',
          _nameOf(file.path),
          differs: !isRef && _nameOf(file.path) != _nameOf(reference.path),
        ),
        row(
          '${s.folderLabel}  ',
          _dirOf(file.path),
          differs: !isRef && _dirOf(file.path) != _dirOf(reference.path),
        ),
        row(
          '${s.sizeLabel}  ',
          '${formatBytes(file.size)} (${file.size} B)',
          differs: !isRef && file.size != reference.size,
        ),
        row(
          '${s.modifiedLabel}  ',
          modified == null ? '-' : _formatDate(modified),
          differs: !isRef && modified != refModified,
        ),
        if (file.note != null)
          row(
            '${s.typeLabel}  ',
            file.note!,
            differs: !isRef && file.note != reference.note,
          ),
      ],
    );
  }
}

// ---------------- 미리보기 ----------------

enum _Kind { image, video, audio, text, other }

const _imageExt = {'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic', 'heif'};
const _videoExt = {'mp4', 'mov', '3gp', 'mkv', 'avi', 'webm', 'm4v'};
const _audioExt = {'mp3', 'm4a', 'wav', 'aac', 'ogg', 'flac', 'amr'};
const _textExt = {
  'txt', 'md', 'json', 'xml', 'csv', 'log', 'html', 'htm', 'css', 'js', //
  'dart', 'java', 'kt', 'py', 'yaml', 'yml', 'ini', 'conf', 'srt', 'vtt',
};

_Kind _kindOf(String path) {
  final dot = path.lastIndexOf('.');
  final ext = dot < 0 ? '' : path.substring(dot + 1).toLowerCase();
  if (_imageExt.contains(ext)) return _Kind.image;
  if (_videoExt.contains(ext)) return _Kind.video;
  if (_audioExt.contains(ext)) return _Kind.audio;
  if (_textExt.contains(ext)) return _Kind.text;
  return _Kind.other;
}

IconData _iconOf(_Kind kind) => switch (kind) {
  _Kind.image => Icons.image_outlined,
  _Kind.video => Icons.movie_outlined,
  _Kind.audio => Icons.audiotrack_outlined,
  _Kind.text => Icons.description_outlined,
  _Kind.other => Icons.insert_drive_file_outlined,
};

/// 목록용 작은 썸네일.
class FileThumbnail extends StatelessWidget {
  const FileThumbnail({super.key, required this.path, this.size = 48});
  final String path;
  final double size;

  @override
  Widget build(BuildContext context) {
    final kind = _kindOf(path);
    final cs = Theme.of(context).colorScheme;
    final fallback = Container(
      width: size,
      height: size,
      color: cs.surfaceContainerHighest,
      child: Icon(_iconOf(kind), color: cs.onSurfaceVariant),
    );
    if (kind != _Kind.image) {
      return ClipRRect(borderRadius: BorderRadius.circular(6), child: fallback);
    }
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.file(
        File(path),
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: (size * dpr).round(),
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}

/// 비교 화면용 큰 미리보기. 이미지는 탭하면 전체 화면 확대.
class FilePreview extends StatelessWidget {
  const FilePreview({super.key, required this.path});
  final String path;

  static const _height = 220.0;
  static const _textBytes = 4096;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final kind = _kindOf(path);

    Widget box(Widget child) => Container(
      height: _height,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );

    Widget message(IconData icon, String text) => box(
      Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: cs.onSurfaceVariant),
            const SizedBox(height: 8),
            Text(text, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );

    if (!File(path).existsSync()) {
      return message(Icons.error_outline, s.fileMissing);
    }

    switch (kind) {
      case _Kind.image:
        final dpr = MediaQuery.devicePixelRatioOf(context);
        return Stack(
          children: [
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => _FullScreenImage(path: path)),
              ),
              child: box(
                Image.file(
                  File(path),
                  fit: BoxFit.contain,
                  cacheHeight: (_height * dpr).round(),
                  errorBuilder: (_, _, _) => message(
                    Icons.broken_image_outlined,
                    s.previewUnavailable,
                  ),
                ),
              ),
            ),
            Positioned(
              right: 8,
              bottom: 8,
              child: Chip(
                visualDensity: VisualDensity.compact,
                avatar: const Icon(Icons.zoom_in, size: 16),
                label: Text(s.tapToEnlarge, style: theme.textTheme.labelSmall),
              ),
            ),
          ],
        );
      case _Kind.text:
        return FutureBuilder<(String, bool)>(
          future: _readText(),
          builder: (context, snap) {
            final data = snap.data;
            return box(
              data == null
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        data.$1 +
                            (data.$2 ? '\n${s.textPreviewTruncated}' : ''),
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                        ),
                      ),
                    ),
            );
          },
        );
      case _Kind.video || _Kind.audio || _Kind.other:
        return message(_iconOf(kind), s.previewUnavailable);
    }
  }

  /// 텍스트 앞부분 읽기. 반환: (내용, 잘렸는지).
  Future<(String, bool)> _readText() async {
    final file = File(path);
    final length = await file.length();
    final bytes = await file
        .openRead(0, _textBytes)
        .fold<List<int>>([], (acc, chunk) => acc..addAll(chunk));
    return (utf8.decode(bytes, allowMalformed: true), length > _textBytes);
  }
}

class _FullScreenImage extends StatelessWidget {
  const _FullScreenImage({required this.path});
  final String path;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(_nameOf(path), style: const TextStyle(fontSize: 14)),
      ),
      body: InteractiveViewer(
        maxScale: 8,
        child: Center(child: Image.file(File(path), fit: BoxFit.contain)),
      ),
    );
  }
}

// ---------------- 유틸 ----------------

String _nameOf(String path) =>
    path.substring(path.lastIndexOf(Platform.pathSeparator) + 1);

String _dirOf(String path) {
  final i = path.lastIndexOf(Platform.pathSeparator);
  return i <= 0 ? path : path.substring(0, i);
}

DateTime? _modifiedOf(String path) {
  try {
    return File(path).lastModifiedSync();
  } on FileSystemException {
    return null;
  }
}

String _formatDate(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)} '
      '${two(d.hour)}:${two(d.minute)}:${two(d.second)}';
}
