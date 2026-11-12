import 'dart:async';
import 'dart:isolate';

import 'duplicate_scanner.dart';
import 'l10n/strings.dart';
import 'trash_store.dart';

/// 스캐너를 별도 Isolate 에서 실행하여 UI 가 멈추지 않게 하고,
/// [stop] 호출 시 Isolate 를 즉시 종료한다.
class ScanRunner {
  Isolate? _isolate;
  ReceivePort? _port;

  bool get isRunning => _isolate != null;

  Future<void> start({
    required String rootPath,
    required MatchMode mode,
    required AppLanguage language,
    required DeleteMode deleteMode,
    String? trashDir,
    required void Function(ScanEvent event) onEvent,
    required void Function() onExit,
  }) async {
    stop();
    final port = ReceivePort();
    _port = port;

    port.listen((message) {
      if (message is ScanEvent) {
        onEvent(message);
      } else if (message is List) {
        // onError: [error, stackTrace]
        onEvent(
          ScanLog(Strings.of(language).errorLog(message.first), LogLevel.error),
        );
      } else if (message == null) {
        // onExit
        _cleanup();
        onExit();
      }
    });

    _isolate = await Isolate.spawn(
      _entry,
      _Args(rootPath, mode, language, deleteMode, trashDir, port.sendPort),
      onExit: port.sendPort,
      onError: port.sendPort,
    );
  }

  /// 탐색을 즉시 중단한다.
  void stop() {
    _isolate?.kill(priority: Isolate.immediate);
    _cleanup();
  }

  void _cleanup() {
    _isolate = null;
    _port?.close();
    _port = null;
  }

  static Future<void> _entry(_Args args) async {
    final scanner = DuplicateScanner(
      onEvent: args.sendPort.send,
      mode: args.mode,
      deleteDuplicates: args.deleteMode == DeleteMode.auto,
      trash: args.trashDir == null ? null : TrashStore(args.trashDir!),
      strings: Strings.of(args.language),
    );
    await scanner.scan(args.rootPath);
  }
}

class _Args {
  const _Args(
    this.rootPath,
    this.mode,
    this.language,
    this.deleteMode,
    this.trashDir,
    this.sendPort,
  );

  /// null 이면 영구 삭제.
  final String? trashDir;
  final DeleteMode deleteMode;
  final AppLanguage language;
  final String rootPath;
  final MatchMode mode;
  final SendPort sendPort;
}
