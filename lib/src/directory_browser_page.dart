import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'app_settings.dart';
import 'l10n/strings.dart';
import 'scan_page.dart';
import 'settings_page.dart';
import 'storage_permission.dart';
import 'trash_page.dart';

/// 1. 디렉토리 목록을 표시하고 2. 디렉토리를 선택하여 중복 파일 제거를 시작한다.
class DirectoryBrowserPage extends StatefulWidget {
  const DirectoryBrowserPage({super.key});

  @override
  State<DirectoryBrowserPage> createState() => _DirectoryBrowserPageState();
}

class _DirectoryBrowserPageState extends State<DirectoryBrowserPage> {
  final String _rootPath = defaultRootPath();
  late String _currentPath = _rootPath;
  String? _selectedPath;
  MatchMode _mode = MatchMode.name;

  /// 기본은 안전한 수동 삭제.
  DeleteMode _deleteMode = DeleteMode.manual;
  List<Directory> _dirs = [];
  bool _permissionGranted = false;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final granted = await ensureStoragePermission();
    if (!mounted) return;
    setState(() {
      _permissionGranted = granted;
      _loading = false;
    });
    if (!granted) return;
    _load(_currentPath);
    _purgeTrash();
  }

  /// 보관 기간(30일)이 지난 휴지통 파일을 영구 삭제.
  void _purgeTrash() {
    try {
      final purged = SettingsScope.read(context).trashStore.purgeExpired();
      if (purged > 0) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(S.of(context).purged(purged))));
      }
    } on FileSystemException {
      // 휴지통 정리 실패는 다음 실행 때 다시 시도.
    }
  }

  void _openTrash() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            TrashPage(store: SettingsScope.read(context).trashStore),
      ),
    );
  }

  void _load(String path) {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dirs =
          Directory(path)
              .listSync(followLinks: false)
              .whereType<Directory>()
              .where((d) => !_nameOf(d.path).startsWith('.'))
              .toList()
            ..sort(
              (a, b) =>
                  _nameOf(a.path)
                      .toLowerCase()
                      .compareTo(_nameOf(b.path).toLowerCase()),
            );
      setState(() {
        _currentPath = path;
        _dirs = dirs;
        _loading = false;
      });
    } on FileSystemException catch (e) {
      setState(() {
        _currentPath = path;
        _dirs = [];
        _loading = false;
        _error = e.osError?.message ?? e.message;
      });
    }
  }

  static String _nameOf(String path) =>
      path.substring(path.lastIndexOf(Platform.pathSeparator) + 1);

  bool get _canGoUp => _currentPath != _rootPath && _currentPath.length > 1;

  void _goUp() {
    if (!_canGoUp) return;
    _load(Directory(_currentPath).parent.path);
  }

  Future<void> _startRemove() async {
    final target = _selectedPath;
    if (target == null) return;
    final s = S.of(context);
    final auto = _deleteMode == DeleteMode.auto;
    final toTrash =
        SettingsScope.read(context).deleteMethod == DeleteMethod.trash;
    var acknowledged = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final cs = Theme.of(context).colorScheme;
          return AlertDialog(
            title: Text(auto ? s.removeDuplicates : s.findDuplicates),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.confirmBody(_mode, _deleteMode, target, toTrash: toTrash),
                  ),
                  if (auto) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: cs.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        toTrash ? s.autoTrashWarning : s.autoDeleteWarning,
                        style: TextStyle(color: cs.onErrorContainer),
                      ),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: acknowledged,
                      onChanged: (v) =>
                          setDialogState(() => acknowledged = v ?? false),
                      title: Text(s.autoDeleteAck),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(s.cancel),
              ),
              FilledButton(
                style: auto
                    ? FilledButton.styleFrom(backgroundColor: cs.error)
                    : null,
                onPressed: !auto || acknowledged
                    ? () => Navigator.pop(context, true)
                    : null,
                child: Text(s.start),
              ),
            ],
          );
        },
      ),
    );
    if (ok != true || !mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ScanPage(rootPath: target, mode: _mode, deleteMode: _deleteMode),
      ),
    );
    if (mounted) _load(_currentPath);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = S.of(context);
    return PopScope(
      canPop: !_canGoUp,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goUp();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(s.appTitle),
          actions: [
            IconButton(
              tooltip: s.refresh,
              icon: const Icon(Icons.refresh),
              onPressed: _permissionGranted ? () => _load(_currentPath) : null,
            ),
            IconButton(
              tooltip: s.trashTitle,
              icon: const Icon(Icons.delete_outline),
              onPressed: _permissionGranted ? _openTrash : null,
            ),
            IconButton(
              tooltip: s.settings,
              icon: const Icon(Icons.settings),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsPage()),
              ),
            ),
          ],
        ),
        body: !_permissionGranted && !_loading
            ? _PermissionRequired(onRetry: _init)
            : Column(
                children: [
                  Material(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: s.goUp,
                          icon: const Icon(Icons.arrow_upward),
                          onPressed: _canGoUp ? _goUp : null,
                        ),
                        Expanded(
                          child: Text(
                            _currentPath,
                            style: theme.textTheme.bodySmall,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                    ),
                  ),
                  _DirTile(
                    icon: Icons.folder_special,
                    title: s.selectCurrentFolder,
                    subtitle: _currentPath,
                    selected: _selectedPath == _currentPath,
                    onTap: () => setState(() => _selectedPath = _currentPath),
                  ),
                  const Divider(height: 1),
                  Expanded(child: _buildList(s)),
                  _buildBottomBar(theme, s),
                ],
              ),
      ),
    );
  }

  Widget _buildList(Strings s) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(s.cannotReadFolder(_error!)));
    if (_dirs.isEmpty) return Center(child: Text(s.noSubfolders));
    return ListView.builder(
      itemCount: _dirs.length,
      itemBuilder: (context, i) {
        final dir = _dirs[i];
        return _DirTile(
          icon: Icons.folder,
          title: _nameOf(dir.path),
          selected: _selectedPath == dir.path,
          onTap: () => setState(() => _selectedPath = dir.path),
          onOpen: () => _load(dir.path),
          openTooltip: s.openFolder,
        );
      },
    );
  }

  Widget _buildBottomBar(ThemeData theme, Strings s) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _selectedPath == null
                  ? s.selectFolderPrompt
                  : s.selected(_selectedPath!),
              style: theme.textTheme.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            SegmentedButton<MatchMode>(
              showSelectedIcon: false,
              segments: [
                for (final m in MatchMode.values)
                  ButtonSegment(
                    value: m,
                    label: Text(s.modeLabel(m)),
                    icon: Icon(switch (m) {
                      MatchMode.name => Icons.text_fields,
                      MatchMode.content => Icons.fingerprint,
                      MatchMode.image => Icons.photo,
                    }),
                  ),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => setState(() => _mode = s.first),
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    s.modeScope(_mode),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SegmentedButton<DeleteMode>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: DeleteMode.manual,
                  label: Text(s.deleteModeLabel(DeleteMode.manual)),
                  icon: const Icon(Icons.checklist),
                ),
                ButtonSegment(
                  value: DeleteMode.auto,
                  label: Text(s.deleteModeLabel(DeleteMode.auto)),
                  icon: const Icon(Icons.auto_delete_outlined),
                ),
              ],
              selected: {_deleteMode},
              onSelectionChanged: (v) => setState(() => _deleteMode = v.first),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              style: _deleteMode == DeleteMode.auto
                  ? FilledButton.styleFrom(
                      backgroundColor: theme.colorScheme.error,
                    )
                  : null,
              icon: Icon(
                _deleteMode == DeleteMode.auto
                    ? Icons.cleaning_services
                    : Icons.search,
              ),
              label: Text(
                _deleteMode == DeleteMode.auto
                    ? s.removeDuplicates
                    : s.findDuplicates,
              ),
              onPressed: _selectedPath == null ? null : _startRemove,
            ),
          ],
        ),
      ),
    );
  }
}

class _DirTile extends StatelessWidget {
  const _DirTile({
    required this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.onOpen,
    this.openTooltip,
  });

  final String? openTooltip;

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(selected ? Icons.check_circle : icon),
      title: Text(title),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis),
      selected: selected,
      selectedTileColor: Theme.of(context).colorScheme.primaryContainer
          .withValues(alpha: 0.4),
      onTap: onTap,
      trailing: onOpen == null
          ? null
          : IconButton(
              tooltip: openTooltip,
              icon: const Icon(Icons.chevron_right),
              onPressed: onOpen,
            ),
    );
  }
}

class _PermissionRequired extends StatelessWidget {
  const _PermissionRequired({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 48),
            const SizedBox(height: 16),
            Text(s.permissionRequired, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: Text(s.requestPermission)),
            TextButton(
              onPressed: openAppSettings,
              child: Text(s.openAppSettings),
            ),
          ],
        ),
      ),
    );
  }
}
