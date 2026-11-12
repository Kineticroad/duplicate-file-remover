import 'dart:io';

import 'package:flutter/material.dart';

import 'app_settings.dart';
import 'duplicate_scanner.dart' show formatBytes;
import 'l10n/strings.dart';
import 'media_scanner.dart';
import 'review_page.dart' show FileThumbnail;
import 'trash_store.dart';

/// 휴지통: 복원 / 영구 삭제 / 비우기.
class TrashPage extends StatefulWidget {
  const TrashPage({super.key, required this.store});
  final TrashStore store;

  @override
  State<TrashPage> createState() => _TrashPageState();
}

class _TrashPageState extends State<TrashPage> {
  List<TrashEntry> _entries = [];
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _entries = widget.store.list();
      _selected.removeWhere((id) => !_entries.any((e) => e.id == id));
    });
  }

  List<TrashEntry> get _selectedEntries =>
      _entries.where((e) => _selected.contains(e.id)).toList();

  int _bytes(Iterable<TrashEntry> list) =>
      list.fold(0, (sum, e) => sum + e.size);

  void _snack(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  Future<bool> _confirm(String title, String body, String action) async {
    final cs = Theme.of(context).colorScheme;
    final s = S.of(context);
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            icon: Icon(Icons.delete_forever, color: cs.error),
            title: Text(title),
            content: Text(body),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(s.cancel),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: cs.error),
                onPressed: () => Navigator.pop(context, true),
                child: Text(action),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _restore(Strings s) {
    final restored = <String>[];
    var failed = 0;
    for (final e in _selectedEntries) {
      try {
        restored.add(widget.store.restore(e));
      } on FileSystemException {
        failed++;
      }
    }
    MediaScanner.scan(restored);
    _selected.clear();
    _reload();
    _snack(
      failed == 0
          ? s.restored(restored.length)
          : '${s.restored(restored.length)} (${s.statErrors(failed)})',
    );
  }

  Future<void> _deleteForever(
    Strings s,
    List<TrashEntry> targets, {
    required bool all,
  }) async {
    if (targets.isEmpty) return;
    final size = formatBytes(_bytes(targets));
    final ok = await _confirm(
      all ? s.emptyTrash : s.deleteForever,
      all
          ? s.emptyTrashConfirm(targets.length, size)
          : s.deleteForeverConfirm(targets.length, size),
      s.deleteForever,
    );
    if (!ok) return;
    var deleted = 0, failed = 0;
    for (final e in targets) {
      try {
        widget.store.deletePermanently(e);
        deleted++;
      } on FileSystemException {
        failed++;
      }
    }
    _selected.clear();
    _reload();
    _snack(s.deleteResult(deleted, failed));
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final allSelected =
        _entries.isNotEmpty && _selected.length == _entries.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.trashTitle),
        actions: [
          if (_entries.isNotEmpty)
            IconButton(
              tooltip: s.selectAll,
              icon: Icon(allSelected ? Icons.deselect : Icons.select_all),
              onPressed: () => setState(() {
                allSelected
                    ? _selected.clear()
                    : _selected.addAll(_entries.map((e) => e.id));
              }),
            ),
          if (_entries.isNotEmpty)
            IconButton(
              tooltip: s.emptyTrash,
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () => _deleteForever(s, _entries, all: true),
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: cs.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                '${s.trashInfo}\n'
                '${s.trashSummary(_entries.length, formatBytes(_bytes(_entries)))}',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ),
          Expanded(
            child: _entries.isEmpty
                ? Center(child: Text(s.trashEmpty))
                : ListView.builder(
                    itemCount: _entries.length,
                    itemBuilder: (context, i) {
                      final e = _entries[i];
                      final selected = _selected.contains(e.id);
                      final sep = e.originalPath.lastIndexOf(
                        Platform.pathSeparator,
                      );
                      return ListTile(
                        selected: selected,
                        onTap: () => setState(() {
                          selected
                              ? _selected.remove(e.id)
                              : _selected.add(e.id);
                        }),
                        leading: FileThumbnail(path: e.filePath, size: 52),
                        title: Text(
                          e.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${s.originalLocation}: '
                          '${e.originalPath.substring(0, sep)}\n'
                          '${formatBytes(e.size)} · '
                          '${s.trashedAt(_date(e.trashedAt))} · '
                          '${s.daysLeft(TrashStore.daysLeft(e))}',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        isThreeLine: true,
                        trailing: Checkbox(
                          value: selected,
                          onChanged: (v) => setState(() {
                            v == true
                                ? _selected.add(e.id)
                                : _selected.remove(e.id);
                          }),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: _selected.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.restore),
                        label: Text('${s.restore} (${_selected.length})'),
                        onPressed: () => _restore(s),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: cs.error,
                        ),
                        icon: const Icon(Icons.delete_forever),
                        label: Text(s.deleteForever),
                        onPressed: () =>
                            _deleteForever(s, _selectedEntries, all: false),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  static String _date(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} '
        '${two(d.hour)}:${two(d.minute)}';
  }
}
