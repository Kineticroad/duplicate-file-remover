import 'dart:convert';
import 'dart:io';
import 'dart:math';

/// 휴지통에 들어간 파일 하나.
class TrashEntry {
  const TrashEntry({
    required this.id,
    required this.originalPath,
    required this.trashedAt,
    required this.size,
    required this.filePath,
  });

  final String id;
  final String originalPath;
  final DateTime trashedAt;
  final int size;

  /// 휴지통 안의 실제 파일 경로.
  final String filePath;

  String get name => originalPath.substring(
    originalPath.lastIndexOf(Platform.pathSeparator) + 1,
  );
}

/// 앱 전용 휴지통.
///
/// 구조: `<root>/<id>/meta.json` + `<root>/<id>/<원래 파일명>`.
/// 항목마다 폴더를 따로 두어 탐색 Isolate 와 UI 가 동시에 써도 충돌하지 않는다.
/// 순수 Dart 라서 탐색 Isolate 에서도 사용할 수 있다.
class TrashStore {
  TrashStore(this.root);

  /// 휴지통 보관 기간. 지나면 [purgeExpired] 에서 영구 삭제.
  static const retention = Duration(days: 30);

  static const folderName = '.DuplicateRemoverTrash';
  static const _meta = 'meta.json';

  final String root;

  /// [storageRoot] 아래의 기본 휴지통.
  factory TrashStore.inStorage(String storageRoot) =>
      TrashStore('$storageRoot${Platform.pathSeparator}$folderName');

  void _ensureRoot() {
    final dir = Directory(root);
    if (!dir.existsSync()) dir.createSync(recursive: true);
    // 갤러리 앱이 휴지통 사진을 다시 보여주지 않도록.
    final nomedia = File('$root${Platform.pathSeparator}.nomedia');
    if (!nomedia.existsSync()) nomedia.createSync();
  }

  static final _random = Random();
  String _newId() =>
      '${DateTime.now().microsecondsSinceEpoch}_${_random.nextInt(1 << 32)}';

  /// 파일을 휴지통으로 옮긴다. 같은 저장소면 이름 변경(즉시), 아니면 복사 후 삭제.
  TrashEntry moveToTrash(String path) {
    _ensureRoot();
    final source = File(path);
    final size = source.lengthSync();
    final id = _newId();
    final dir = Directory('$root${Platform.pathSeparator}$id')..createSync();
    final name = path.substring(path.lastIndexOf(Platform.pathSeparator) + 1);
    final dest = '${dir.path}${Platform.pathSeparator}$name';
    final entry = TrashEntry(
      id: id,
      originalPath: path,
      trashedAt: DateTime.now(),
      size: size,
      filePath: dest,
    );
    File('${dir.path}${Platform.pathSeparator}$_meta').writeAsStringSync(
      jsonEncode({
        'originalPath': entry.originalPath,
        'trashedAt': entry.trashedAt.toIso8601String(),
        'size': entry.size,
      }),
    );
    try {
      _move(source, dest);
    } catch (_) {
      dir.deleteSync(recursive: true); // 실패하면 흔적을 남기지 않는다.
      rethrow;
    }
    return entry;
  }

  /// 휴지통 목록 (최근 것부터).
  List<TrashEntry> list() {
    final dir = Directory(root);
    if (!dir.existsSync()) return [];
    final entries = <TrashEntry>[];
    for (final item in dir.listSync().whereType<Directory>()) {
      final entry = _read(item);
      if (entry != null) entries.add(entry);
    }
    entries.sort((a, b) => b.trashedAt.compareTo(a.trashedAt));
    return entries;
  }

  TrashEntry? _read(Directory item) {
    try {
      final meta = File('${item.path}${Platform.pathSeparator}$_meta');
      final json = jsonDecode(meta.readAsStringSync()) as Map<String, dynamic>;
      final original = json['originalPath'] as String;
      final name = original.substring(
        original.lastIndexOf(Platform.pathSeparator) + 1,
      );
      final file = '${item.path}${Platform.pathSeparator}$name';
      if (!File(file).existsSync()) return null;
      return TrashEntry(
        id: item.path.substring(
          item.path.lastIndexOf(Platform.pathSeparator) + 1,
        ),
        originalPath: original,
        trashedAt: DateTime.parse(json['trashedAt'] as String),
        size: json['size'] as int,
        filePath: file,
      );
    } catch (_) {
      return null; // 손상된 항목은 무시
    }
  }

  /// 원래 위치로 복원. 같은 이름의 파일이 이미 있으면 "이름 (1).확장자" 로 복원.
  /// 반환: 실제 복원된 경로.
  String restore(TrashEntry entry) {
    var target = entry.originalPath;
    Directory(File(target).parent.path).createSync(recursive: true);
    if (File(target).existsSync()) {
      final dot = target.lastIndexOf('.');
      final sep = target.lastIndexOf(Platform.pathSeparator);
      final hasExt = dot > sep + 1;
      final base = hasExt ? target.substring(0, dot) : target;
      final ext = hasExt ? target.substring(dot) : '';
      var n = 1;
      while (File('$base ($n)$ext').existsSync()) {
        n++;
      }
      target = '$base ($n)$ext';
    }
    _move(File(entry.filePath), target);
    _removeEntryDir(entry);
    return target;
  }

  void deletePermanently(TrashEntry entry) {
    final file = File(entry.filePath);
    if (file.existsSync()) file.deleteSync();
    _removeEntryDir(entry);
  }

  /// 보관 기간이 지난 항목을 영구 삭제. 반환: 삭제한 개수.
  int purgeExpired({DateTime? now}) {
    final limit = (now ?? DateTime.now()).subtract(retention);
    var count = 0;
    for (final e in list()) {
      if (e.trashedAt.isBefore(limit)) {
        try {
          deletePermanently(e);
          count++;
        } on FileSystemException {
          // 다음 실행 때 다시 시도
        }
      }
    }
    return count;
  }

  /// 남은 보관 일수 (0 이면 다음 정리 때 삭제).
  static int daysLeft(TrashEntry e, {DateTime? now}) {
    final expires = e.trashedAt.add(retention);
    final left = expires.difference(now ?? DateTime.now()).inHours / 24;
    return left <= 0 ? 0 : left.ceil();
  }

  void _removeEntryDir(TrashEntry entry) {
    final dir = Directory('$root${Platform.pathSeparator}${entry.id}');
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  }

  static void _move(File source, String dest) {
    try {
      source.renameSync(dest);
    } on FileSystemException {
      // 다른 저장소(SD 카드 등)로는 이름 변경이 안 되므로 복사 후 삭제.
      source.copySync(dest);
      source.deleteSync();
    }
  }
}
