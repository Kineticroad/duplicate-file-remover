import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

/// 외부 저장소 전체 접근 권한을 확보한다.
/// Android 11+ 는 "모든 파일 접근(MANAGE_EXTERNAL_STORAGE)", 그 이하는 저장소 권한.
Future<bool> ensureStoragePermission() async {
  if (!Platform.isAndroid) return true;

  if (await Permission.manageExternalStorage.isGranted) return true;
  if (await Permission.manageExternalStorage.request().isGranted) return true;

  // Android 10 이하 대응.
  if (await Permission.storage.isGranted) return true;
  return (await Permission.storage.request()).isGranted;
}

/// 기본으로 보여줄 루트 디렉토리.
String defaultRootPath() {
  if (Platform.isAndroid) return '/storage/emulated/0';
  return Platform.environment['HOME'] ?? Directory.current.path;
}
