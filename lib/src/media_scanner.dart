import 'dart:io';

import 'package:flutter/services.dart';

/// Android 미디어 스캐너 호출: 파일을 지우거나 옮긴 뒤 갤러리 목록을 갱신한다.
abstract final class MediaScanner {
  static const _channel = MethodChannel('duplicate_remover/media');

  static Future<void> scan(Iterable<String> paths) async {
    final list = paths.toList();
    if (!Platform.isAndroid || list.isEmpty) return;
    try {
      await _channel.invokeMethod<void>('scanFiles', list);
    } catch (_) {
      // 갤러리 갱신 실패는 치명적이지 않다.
    }
  }
}
