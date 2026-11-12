import 'dart:io';

import 'package:crypto/crypto.dart';

import 'jpeg_info.dart';
import 'l10n/strings.dart';
import 'trash_store.dart';

export 'l10n/strings.dart' show MatchMode, AppLanguage;

/// 탐색 통계.
class ScanStats {
  int targetFiles = 0;
  int dirsScanned = 0;
  int filesScanned = 0;
  int comparisons = 0;
  int deletedCount = 0;
  int freedBytes = 0;
  int errorCount = 0;

  /// 찾은 중복 파일 수/용량 (수동 모드에서는 삭제 후보).
  int foundCount = 0;
  int foundBytes = 0;

  ScanStats copy() => ScanStats()
    ..targetFiles = targetFiles
    ..dirsScanned = dirsScanned
    ..filesScanned = filesScanned
    ..comparisons = comparisons
    ..deletedCount = deletedCount
    ..freedBytes = freedBytes
    ..errorCount = errorCount
    ..foundCount = foundCount
    ..foundBytes = foundBytes;
}

enum LogLevel { info, compare, same, different, deleted, error }

/// 스캐너가 UI 로 보내는 이벤트.
sealed class ScanEvent {
  const ScanEvent();
}

/// 현재 비교 중인 대상 파일.
class ScanTarget extends ScanEvent {
  const ScanTarget(this.directory, this.name, this.stats);
  final String directory;
  final String name;
  final ScanStats stats;
}

/// 현재 진행 중인 작업 (사용자에게 "지금 무엇을 하는지" 표시).
class ScanActivity extends ScanEvent {
  const ScanActivity({
    required this.phase,
    required this.detail,
    required this.done,
    required this.total,
    required this.stats,
  });

  /// 단계 이름 (예: "2/3 사진 분석 중").
  final String phase;

  /// 지금 하고 있는 일 (예: "사진 데이터 해시 계산: IMG_001.jpg (4.2 MB)").
  final String detail;

  /// 단계 진행 수 / 전체 수. 전체를 모르면 [total] 은 0.
  final int done;
  final int total;
  final ScanStats stats;
}

/// 화면에 텍스트로 표시할 로그.
class ScanLog extends ScanEvent {
  const ScanLog(this.message, this.level);
  final String message;
  final LogLevel level;
}

/// 검토 화면용 파일 정보.
class DuplicateFile {
  const DuplicateFile(this.path, this.size, {this.note});
  final String path;
  final int size;

  /// 부가 설명 (예: 사진 기준의 "모션 포토+GPS").
  final String? note;
}

/// 수동 삭제 모드에서 찾은 중복 그룹. [keep] 은 남기기를 추천하는 파일.
class ScanDuplicateGroup extends ScanEvent {
  const ScanDuplicateGroup(this.keep, this.duplicates);
  final DuplicateFile keep;
  final List<DuplicateFile> duplicates;
}

/// 파일을 삭제(또는 휴지통으로 이동)함. 갤러리 갱신용.
class ScanRemoved extends ScanEvent {
  const ScanRemoved(this.path);
  final String path;
}

/// 탐색 완료.
class ScanFinished extends ScanEvent {
  const ScanFinished(this.stats);
  final ScanStats stats;
}

class _FileInfo {
  _FileInfo(this.path, this.size);
  final String path;
  final int size;
}

/// 선택된 폴더 전체를 재귀 탐색하여 파일 목록을 만든 뒤, 탐색 순서대로 파일을 하나씩
/// 대상으로 잡고, 대상 파일을 제외한 선택 폴더 전체에서 동일한 파일을 찾아 삭제한다.
/// 대상 파일은 항상 남기고, 탐색된 파일을 삭제한다.
///
/// - [MatchMode.name]: 이름이 같은 파일 중 checksum 이 같은 파일.
/// - [MatchMode.content]: 크기가 같은 파일 중 앞부분 checksum → 전체 checksum 이
///   같은 파일 (이름 무관). 크기 0 인 파일은 제외.
class DuplicateScanner {
  DuplicateScanner({
    required this.onEvent,
    this.mode = MatchMode.name,
    this.deleteDuplicates = true,
    this.trash,
    Strings? strings,
  }) : s = strings ?? const KoStrings();

  /// 지정하면 삭제 대신 휴지통으로 옮긴다.
  final TrashStore? trash;

  /// 파일 삭제 또는 휴지통 이동.
  void _remove(String path) {
    _activity(
      trash != null ? s.activityTrashing(path) : s.activityDeleting(path),
    );
    if (trash != null) {
      trash!.moveToTrash(path);
    } else {
      File(path).deleteSync();
    }
    onEvent(ScanRemoved(path));
    _log(
      trash != null ? s.logTrashed(path) : s.logDeleted(path),
      LogLevel.deleted,
    );
  }

  /// 로그/진행 상황 문구.
  final Strings s;

  /// 앞부분 checksum 에 사용할 크기.
  static const partialBytes = 64 * 1024;

  final void Function(ScanEvent event) onEvent;
  final MatchMode mode;
  final bool deleteDuplicates;

  final ScanStats stats = ScanStats();

  /// 경로 -> 체크섬 캐시.
  final Map<String, String> _checksumCache = {};

  String _phase = '';
  int _done = 0;
  int _total = 0;

  /// 새 단계 시작.
  void _setPhase(String phase, {int total = 0}) {
    _phase = phase;
    _done = 0;
    _total = total;
  }

  /// 현재 하고 있는 일을 알린다. [done] 을 주면 진행 수도 갱신.
  void _activity(String detail, {int? done}) {
    if (done != null) _done = done;
    onEvent(
      ScanActivity(
        phase: _phase,
        detail: detail,
        done: _done,
        total: _total,
        stats: stats.copy(),
      ),
    );
  }

  int get _steps => mode == MatchMode.image ? 3 : 2;

  /// 경로 -> 앞부분 체크섬 캐시.
  final Map<String, String> _partialCache = {};

  /// 비교 그룹 키: 이름 기준이면 파일명, 내용 기준이면 파일 크기.
  Object _keyOf(_FileInfo f) =>
      mode == MatchMode.name ? _nameOf(f.path) : f.size;

  Future<ScanStats> scan(String rootPath) async {
    final root = Directory(rootPath);
    if (!root.existsSync()) {
      _log(s.folderNotExist(rootPath), LogLevel.error);
      return _finish();
    }

    // 1단계: 선택 폴더 전체를 재귀 탐색하여 파일 목록 생성 (탐색 순서 유지).
    _log(s.logStart(mode, rootPath), LogLevel.info);
    _log('   ${s.modeScope(mode)}', LogLevel.info);
    _setPhase(s.phaseCollect(_steps));
    final files = <_FileInfo>[];
    final groups = <Object, List<_FileInfo>>{};
    _walk(root, (file, size) {
      stats.filesScanned++;
      // 내용 기준에서 빈 파일은 모두 "동일"로 판정되므로 제외.
      if (mode == MatchMode.content && size == 0) return;
      // 사진 기준은 JPEG 만 대상.
      if (mode == MatchMode.image && !isJpegPath(file.path)) return;
      final info = _FileInfo(file.path, size);
      files.add(info);
      (groups[_keyOf(info)] ??= []).add(info);
    });
    _log(s.logCollected(files.length, stats.dirsScanned), LogLevel.info);

    if (mode == MatchMode.image) {
      await _scanImages(files);
      return _finish();
    }

    // 2단계: 파일을 순서대로 대상으로 잡고, 대상을 제외한 전체에서 동일 파일 탐색.
    _log(s.logStepCompare, LogLevel.info);
    _setPhase(s.phaseCompare, total: files.length);
    final deleted = <_FileInfo>{};
    for (var i = 0; i < files.length; i++) {
      final target = files[i];
      _done = i + 1;
      if (deleted.contains(target)) continue; // 이미 중복으로 삭제된 파일
      stats.targetFiles++;
      _activity(s.activityFindSame(_nameOf(target.path), mode));
      final others = groups[_keyOf(target)]!
          .where((f) => !identical(f, target) && !deleted.contains(f))
          .toList();
      await _compareTarget(target, others, deleted);
    }

    _log(
      s.logDone(
        stats.filesScanned,
        stats.deletedCount,
        formatBytes(stats.freedBytes),
      ),
      LogLevel.info,
    );
    return _finish();
  }

  /// 사진 기준: 사진 데이터 해시로 묶고, 우선순위가 가장 높은 파일 하나만 남긴다.
  Future<void> _scanImages(List<_FileInfo> files) async {
    _log(s.logImageAnalyze(files.length), LogLevel.info);
    final infos = <_FileInfo, JpegInfo>{};
    final byHash = <String, List<_FileInfo>>{};
    _setPhase(s.phaseAnalyze, total: files.length);
    for (var i = 0; i < files.length; i++) {
      final f = files[i];
      _activity(
        s.activityAnalyze(
          _nameOf(f.path),
          formatBytes(f.size),
          f.size > _bigFile,
        ),
        done: i + 1,
      );
      JpegInfo? info;
      try {
        info = analyzeJpeg(File(f.path).readAsBytesSync());
      } on FileSystemException catch (e) {
        stats.errorCount++;
        _log(s.readFailed(f.path, e.message), LogLevel.error);
        continue;
      }
      if (info == null) {
        _log(s.jpegSkipped(f.path), LogLevel.compare);
        continue;
      }
      infos[f] = info;
      (byHash[info.imageHash] ??= []).add(f);
      _log(
        s.logAnalyzed(i + 1, files.length, _nameOf(f.path), _label(info)),
        LogLevel.compare,
      );
    }

    _log(s.logStepImageCompare, LogLevel.info);
    _setPhase(s.phaseImageCompare, total: files.length);
    final done = <_FileInfo>{};
    for (var i = 0; i < files.length; i++) {
      final target = files[i];
      _done = i + 1;
      final info = infos[target];
      if (info == null || done.contains(target)) continue;
      stats.targetFiles++;
      _activity(s.activityImageTarget(_nameOf(target.path), _label(info)));
      final sep = target.path.lastIndexOf(Platform.pathSeparator);
      onEvent(
        ScanTarget(
          target.path.substring(0, sep),
          target.path.substring(sep + 1),
          stats.copy(),
        ),
      );

      final group = byHash[info.imageHash]!; // 탐색 순서, target 이 첫 번째
      done.addAll(group);
      if (group.length < 2) continue;

      _log('${s.logTarget(target.path)} (${_label(info)})', LogLevel.info);
      _log(s.logSameImagesFound(group.length - 1), LogLevel.info);
      for (final other in group.skip(1)) {
        stats.comparisons++;
        _log(s.logSameImage(other.path, _label(infos[other]!)), LogLevel.same);
      }

      // 우선순위가 가장 높은 파일. 같으면 먼저 찾은 파일(대상).
      var keeper = group.first;
      for (final f in group) {
        if (infos[f]!.priority > infos[keeper]!.priority) keeper = f;
      }
      _log(s.logKeep(keeper.path, _label(infos[keeper]!)), LogLevel.info);
      _activity(
        s.activityKeep(
          group.length,
          _nameOf(keeper.path),
          _label(infos[keeper]!),
        ),
      );
      if (!infos[keeper]!.hasGps && group.any((f) => infos[f]!.hasGps)) {
        _log(s.warnGpsLost, LogLevel.error);
      }

      for (final f in group) {
        if (identical(f, keeper)) continue;
        stats.foundCount++;
        stats.foundBytes += f.size;
      }
      if (!deleteDuplicates) {
        _log(s.logAddedToReview, LogLevel.info);
        onEvent(
          ScanDuplicateGroup(
            DuplicateFile(
              keeper.path,
              keeper.size,
              note: _label(infos[keeper]!),
            ),
            [
              for (final f in group)
                if (!identical(f, keeper))
                  DuplicateFile(f.path, f.size, note: _label(infos[f]!)),
            ],
          ),
        );
        continue;
      }
      for (final f in group) {
        if (identical(f, keeper)) continue;
        try {
          _remove(f.path);
          stats.deletedCount++;
          stats.freedBytes += f.size;
        } on FileSystemException catch (e) {
          stats.errorCount++;
          _log(
            s.logDeleteFailed(f.path, e.osError?.message ?? e.message),
            LogLevel.error,
          );
        }
      }
    }

    _log(
      s.logImageDone(
        files.length,
        stats.deletedCount,
        formatBytes(stats.freedBytes),
      ),
      LogLevel.info,
    );
  }

  String _sizeHint(String path) {
    try {
      final size = File(path).lengthSync();
      return s.sizeHint(formatBytes(size), size > _bigFile);
    } on FileSystemException {
      return '';
    }
  }

  ScanStats _finish() {
    onEvent(ScanFinished(stats.copy()));
    return stats;
  }

  /// 재귀 탐색: 현재 폴더의 파일을 먼저(이름순), 그 다음 하위 폴더.
  void _walk(Directory dir, void Function(File file, int size) onFile) {
    stats.dirsScanned++;
    _activity(
      s.activityReadDir(dir.path, stats.dirsScanned, stats.filesScanned),
      done: stats.filesScanned,
    );
    List<FileSystemEntity> entries;
    try {
      entries = dir.listSync(followLinks: false);
    } on FileSystemException catch (e) {
      stats.errorCount++;
      _log(
        s.dirReadFailed(dir.path, e.osError?.message ?? e.message),
        LogLevel.error,
      );
      return;
    }
    entries.sort((a, b) => a.path.compareTo(b.path));
    for (final f in entries.whereType<File>()) {
      try {
        onFile(f, f.lengthSync());
      } on FileSystemException catch (e) {
        stats.errorCount++;
        _log(s.fileInfoFailed(f.path, e.message), LogLevel.error);
      }
    }
    for (final d in entries.whereType<Directory>()) {
      // 앱 휴지통은 탐색하지 않는다.
      if (d.path.endsWith(
        '${Platform.pathSeparator}${TrashStore.folderName}',
      )) {
        continue;
      }
      _walk(d, onFile);
    }
  }

  Future<void> _compareTarget(
    _FileInfo target,
    List<_FileInfo> others,
    Set<_FileInfo> deleted,
  ) async {
    final path = target.path;
    final sep = path.lastIndexOf(Platform.pathSeparator);
    onEvent(
      ScanTarget(path.substring(0, sep), path.substring(sep + 1), stats.copy()),
    );
    if (others.isEmpty) return;

    _log(s.logTarget(path), LogLevel.info);
    _log(
      mode == MatchMode.name
          ? s.logSameNameFound(others.length)
          : s.logSameSizeFound(others.length, formatBytes(target.size)),
      LogLevel.info,
    );

    String? targetChecksum;
    final matches = <DuplicateFile>[];
    for (final other in others) {
      stats.comparisons++;
      _log(s.logCompare(other.path), LogLevel.compare);
      if (other.size != target.size) {
        _log(
          s.logSizeDiffers(
            formatExactBytes(other.size),
            formatExactBytes(target.size),
          ),
          LogLevel.different,
        );
        continue;
      }
      try {
        // 내용 기준: 큰 파일은 앞부분만 먼저 비교하여 빠르게 걸러낸다.
        if (mode == MatchMode.content && target.size > partialBytes) {
          final a = await _partialChecksum(path);
          final b = await _partialChecksum(other.path);
          if (a != b) {
            _log(s.logPartialDiffers, LogLevel.different);
            continue;
          }
          _log(s.logPartialSame, LogLevel.compare);
        }
        targetChecksum ??= await _checksum(path);
        final otherChecksum = await _checksum(other.path);
        _log(s.logChecksumTarget(targetChecksum), LogLevel.compare);
        _log(s.logChecksumOther(otherChecksum), LogLevel.compare);
        if (otherChecksum != targetChecksum) {
          _log(s.logChecksumDiffers, LogLevel.different);
          continue;
        }
      } on FileSystemException catch (e) {
        stats.errorCount++;
        _log(s.checksumFailed(e.message), LogLevel.error);
        continue;
      }

      _log(s.logIdentical, LogLevel.same);
      stats.foundCount++;
      stats.foundBytes += other.size;
      if (!deleteDuplicates) {
        // 수동 모드: 삭제하지 않고 검토 목록에 추가. 이후 대상에서 제외.
        _log(s.logAddedToReview, LogLevel.info);
        deleted.add(other);
        matches.add(DuplicateFile(other.path, other.size));
        continue;
      }
      try {
        _remove(other.path);
        deleted.add(other);
        _checksumCache.remove(other.path);
        _partialCache.remove(other.path);
        stats.deletedCount++;
        stats.freedBytes += other.size;
      } on FileSystemException catch (e) {
        stats.errorCount++;
        _log(
          s.logDeleteFailed(other.path, e.osError?.message ?? e.message),
          LogLevel.error,
        );
      }
    }
    if (matches.isNotEmpty) {
      onEvent(ScanDuplicateGroup(DuplicateFile(path, target.size), matches));
    }
  }

  Future<String> _checksum(String path) async {
    final cached = _checksumCache[path];
    if (cached != null) return cached;
    _activity(s.activityChecksum(_nameOf(path), _sizeHint(path)));
    final digest = await md5.bind(File(path).openRead()).first;
    final value = digest.toString();
    _checksumCache[path] = value;
    return value;
  }

  Future<String> _partialChecksum(String path) async {
    final cached = _partialCache[path];
    if (cached != null) return cached;
    _activity(s.activityPartial(_nameOf(path)));
    final digest = await md5.bind(File(path).openRead(0, partialBytes)).first;
    final value = digest.toString();
    _partialCache[path] = value;
    return value;
  }

  static const _bigFile = 20 * 1024 * 1024;

  String _label(JpegInfo info) =>
      s.jpegLabel(motion: info.isMotionPhoto, gps: info.hasGps);

  void _log(String message, LogLevel level) => onEvent(ScanLog(message, level));

  static String _nameOf(String path) =>
      path.substring(path.lastIndexOf(Platform.pathSeparator) + 1);
}

String formatBytes(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  double value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return unit == 0 ? '$bytes B' : '${value.toStringAsFixed(1)} ${units[unit]}';
}

/// Exact byte count with thousands separators, e.g. `1,153,024 B`.
/// Used where rounded sizes could look identical.
String formatExactBytes(int bytes) {
  final digits = bytes.abs().toString();
  final buf = StringBuffer(bytes < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }
  return '$buf B';
}
