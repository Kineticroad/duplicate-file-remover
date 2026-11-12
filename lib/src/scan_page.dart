import 'dart:async';

import 'package:flutter/material.dart';

import 'app_settings.dart';
import 'duplicate_scanner.dart';
import 'l10n/strings.dart';
import 'media_scanner.dart';
import 'review_page.dart';
import 'scan_runner.dart';

enum _ScanState { running, stopped, finished }

/// 중복 파일 탐색/삭제 진행 화면.
/// 대상 파일 경로·파일명과 비교 과정을 텍스트로 보여주며, 정지/다시 시작을 지원한다.
class ScanPage extends StatefulWidget {
  const ScanPage({
    super.key,
    required this.rootPath,
    required this.mode,
    required this.deleteMode,
  });

  /// 삭제 방식 (수동이면 탐색 후 검토 화면에서 삭제).
  final DeleteMode deleteMode;

  /// 중복 판정 기준.
  final MatchMode mode;

  /// 선택된 폴더 — 이 폴더 전체(하위 포함)가 탐색 범위.
  final String rootPath;

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _LogLine {
  const _LogLine(this.text, this.level);
  final String text;
  final LogLevel level;
}

class _ScanPageState extends State<ScanPage> {
  static const _maxLogLines = 2000;

  final _runner = ScanRunner();
  final List<_LogLine> _logs = [];
  final List<ScanDuplicateGroup> _groups = [];
  _ScanState _state = _ScanState.stopped;
  ScanStats _stats = ScanStats();
  String _targetDir = '-';
  String _targetName = '-';
  String _phase = ''; // 비어 있으면 '준비 중' 표시
  String _detail = '';
  int _done = 0;
  int _total = 0;
  final _stopwatch = Stopwatch();

  // 이벤트가 매우 빠르게 들어오므로 화면 갱신은 일정 주기로 묶어서 처리한다.
  Timer? _refreshTimer;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _runner.stop();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _logs.clear();
      _groups.clear();
      _removed.clear();
      _usedTrash =
          SettingsScope.read(context).deleteMethod == DeleteMethod.trash;
      _stats = ScanStats();
      _targetDir = '-';
      _targetName = '-';
      _phase = '';
      _detail = '';
      _done = 0;
      _total = 0;
      _state = _ScanState.running;
    });
    _stopwatch
      ..reset()
      ..start();
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(milliseconds: 100), (t) {
      // 경과 시간 표시를 위해 1초마다 갱신.
      if (t.tick % 10 == 0) _dirty = true;
      if (_dirty && mounted) {
        _dirty = false;
        setState(() {});
      }
    });
    await _runner.start(
      rootPath: widget.rootPath,
      mode: widget.mode,
      language: SettingsScope.read(context).language,
      deleteMode: widget.deleteMode,
      trashDir: SettingsScope.read(context).trashDirOrNull,
      onEvent: _onEvent,
      onExit: () {
        _flushMediaScan();
        if (!mounted) return;
        _refreshTimer?.cancel();
        _stopwatch.stop();
        setState(() {
          if (_state == _ScanState.running) _state = _ScanState.finished;
        });
      },
    );
  }

  void _stop() {
    _runner.stop();
    _refreshTimer?.cancel();
    _stopwatch.stop();
    _flushMediaScan();
    setState(() {
      _state = _ScanState.stopped;
      _addLog(SettingsScope.read(context).strings.userStopped, LogLevel.info);
    });
  }

  bool get _manual => widget.deleteMode == DeleteMode.manual;

  /// 이번 탐색에서 휴지통 방식을 썼는지 (탐색 시작 시점 기준).
  bool _usedTrash = true;

  /// 자동 삭제로 지운 파일 (갤러리 갱신용).
  final List<String> _removed = [];

  void _flushMediaScan() {
    MediaScanner.scan(List.of(_removed));
    _removed.clear();
  }

  Future<void> _openReview() async {
    final settings = SettingsScope.read(context);
    final controller = ReviewController(
      List.of(_groups),
      trash: settings.deleteMethod == DeleteMethod.trash
          ? settings.trashStore
          : null,
    );
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ReviewPage(controller: controller)),
    );
    // 검토 화면에서 삭제한 결과를 반영.
    if (!mounted) return;
    setState(() {
      _groups
        ..clear()
        ..addAll([
          for (final g in controller.groups)
            ScanDuplicateGroup(g.files.first, g.files.skip(1).toList()),
        ]);
    });
  }

  void _onEvent(ScanEvent event) {
    switch (event) {
      case ScanTarget():
        _targetDir = event.directory;
        _targetName = event.name;
        _stats = event.stats;
      case ScanActivity():
        _phase = event.phase;
        _detail = event.detail;
        _done = event.done;
        _total = event.total;
        _stats = event.stats;
      case ScanLog():
        _addLog(event.message, event.level);
      case ScanRemoved():
        _removed.add(event.path);
      case ScanDuplicateGroup():
        _groups.add(event);
      case ScanFinished():
        _stats = event.stats;
        _state = _ScanState.finished;
    }
    _dirty = true;
  }

  void _addLog(String text, LogLevel level) {
    _logs.add(_LogLine(text, level));
    if (_logs.length > _maxLogLines) {
      _logs.removeRange(0, _logs.length - _maxLogLines);
    }
  }

  Color _colorFor(LogLevel level, ColorScheme cs) => switch (level) {
    LogLevel.info => cs.onSurface,
    LogLevel.compare => cs.onSurfaceVariant,
    LogLevel.same => Colors.orange.shade700,
    LogLevel.different => Colors.green.shade700,
    LogLevel.deleted => cs.error,
    LogLevel.error => cs.error,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = S.of(context);
    final running = _state == _ScanState.running;

    return Scaffold(
      appBar: AppBar(title: Text(s.scanTitle)),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${s.scanHeader(widget.rootPath, widget.mode)}'
                    ' · ${s.deleteModeLabel(widget.deleteMode)}',
                    style: theme.textTheme.bodySmall,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _StatusChip(state: _state),
              ],
            ),
            const SizedBox(height: 8),
            _buildActivityCard(theme, s),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                Text(s.statFolders(_stats.dirsScanned)),
                Text(s.statFiles(_stats.filesScanned)),
                Text(s.statChecked(_stats.targetFiles, _stats.filesScanned)),
                Text(s.statCompared(_stats.comparisons)),
                if (_manual) Text(s.statFound(_stats.foundCount)),
                if (!_manual)
                  Text(
                    _usedTrash
                        ? s.statTrashed(_stats.deletedCount)
                        : s.statDeleted(_stats.deletedCount),
                    style: TextStyle(color: cs.error),
                  ),
                if (!_manual && !_usedTrash)
                  Text(s.statFreed(formatBytes(_stats.freedBytes))),
                if (_stats.errorCount > 0)
                  Text(s.statErrors(_stats.errorCount)),
              ],
            ),
            const SizedBox(height: 8),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.targetFile, style: theme.textTheme.labelMedium),
                    const SizedBox(height: 4),
                    Text(
                      s.pathLabel(_targetDir),
                      style: theme.textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      s.fileNameLabel(_targetName),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: cs.outlineVariant),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  reverse: true, // 최신 로그가 항상 아래에 보이도록
                  padding: const EdgeInsets.all(8),
                  itemCount: _logs.length,
                  itemBuilder: (context, i) {
                    final line = _logs[_logs.length - 1 - i];
                    return Text(
                      line.text,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: _colorFor(line.level, cs),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            SafeArea(
              top: false,
              child: running
                  ? FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: cs.error),
                      icon: const Icon(Icons.stop),
                      label: Text(s.stop),
                      onPressed: _stop,
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_manual && _groups.isNotEmpty) ...[
                          FilledButton.icon(
                            icon: const Icon(Icons.fact_check),
                            label: Text(s.reviewButton(_groups.length)),
                            onPressed: _openReview,
                          ),
                          const SizedBox(height: 8),
                        ],
                        OutlinedButton.icon(
                          icon: const Icon(Icons.restart_alt),
                          label: Text(s.restart),
                          onPressed: _start,
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

extension on _ScanPageState {
  String _elapsed() {
    final d = _stopwatch.elapsed;
    String two(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    return h > 0
        ? '$h:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}'
        : '${two(d.inMinutes)}:${two(d.inSeconds % 60)}';
  }

  /// "지금 무엇을 하는지" 보여주는 카드: 단계, 진행률, 현재 작업, 경과 시간.
  Widget _buildActivityCard(ThemeData theme, Strings s) {
    final cs = theme.colorScheme;
    final (String phase, String detail) = switch (_state) {
      _ScanState.running => (
        _phase.isEmpty ? s.preparing : _phase,
        _detail.isEmpty ? s.startingDetail : _detail,
      ),
      _ScanState.stopped => (s.statusStopped, s.stoppedDetail),
      _ScanState.finished => (
        s.statusFinished,
        !_manual && _usedTrash
            ? s.finishedTrashDetail(
                _stats.deletedCount,
                formatBytes(_stats.freedBytes),
              )
            : !_manual
            ? s.finishedDetail(
                _stats.deletedCount,
                formatBytes(_stats.freedBytes),
              )
            : _stats.foundCount == 0
            ? s.noDuplicatesFound
            : s.finishedManualDetail(
                _stats.foundCount,
                formatBytes(_stats.foundBytes),
              ),
      ),
    };
    final hasTotal = _total > 0;
    final percent = hasTotal ? (_done * 100 / _total).floor() : 0;
    return Card(
      margin: EdgeInsets.zero,
      color: cs.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    phase,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: cs.onSecondaryContainer,
                    ),
                  ),
                ),
                Text(
                  s.elapsed(_elapsed()),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSecondaryContainer,
                  ),
                ),
              ],
            ),
            if (_state == _ScanState.running) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(value: hasTotal ? _done / _total : null),
              const SizedBox(height: 4),
              Text(
                hasTotal
                    ? s.progress(_done, _total, percent)
                    : s.counting(_done),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSecondaryContainer,
                ),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              detail,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSecondaryContainer,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.state});
  final _ScanState state;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final (label, icon) = switch (state) {
      _ScanState.running => (s.statusRunning, Icons.search),
      _ScanState.stopped => (s.statusStopped, Icons.pause_circle),
      _ScanState.finished => (s.statusFinished, Icons.check_circle),
    };
    return Chip(avatar: Icon(icon, size: 18), label: Text(label));
  }
}
