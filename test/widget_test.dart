import 'dart:io';

import 'package:duplicate_file_remover/src/duplicate_scanner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;

  setUp(() => root = Directory.systemTemp.createTempSync('dup_test_'));
  tearDown(() => root.deleteSync(recursive: true));

  File write(String rel, String content) {
    final f = File('${root.path}/$rel')..createSync(recursive: true);
    f.writeAsStringSync(content);
    return f;
  }

  Future<ScanStats> scan() => DuplicateScanner(onEvent: (_) {}).scan(root.path);

  test('대상 파일을 기준으로 나중에 찾은 동일 파일 삭제', () async {
    final a = write('a/A.jpg', 'same');
    final b = write('b/A.jpg', 'same');
    final c = write('b/sub/A.jpg', 'same');
    final stats = await scan();

    expect(a.existsSync(), isTrue);
    expect(b.existsSync() || c.existsSync(), isFalse);
    expect(stats.deletedCount, 2);
  });

  test('이름이 같아도 내용이 다르면 유지', () async {
    final a = write('a/A.jpg', 'aaaa');
    final b = write('b/A.jpg', 'bbbb'); // 같은 크기, 다른 내용
    final c = write('c/A.jpg', 'longer'); // 다른 크기
    final stats = await scan();

    expect([a, b, c].every((f) => f.existsSync()), isTrue);
    expect(stats.deletedCount, 0);
  });

  test('대상과 다르지만 서로 같은 나중 파일들도 처리', () async {
    final a = write('a/A.jpg', 'xxxx');
    final b = write('b/A.jpg', 'yyyy');
    final c = write('c/A.jpg', 'yyyy');
    await scan();

    expect(a.existsSync() && b.existsSync(), isTrue);
    expect(c.existsSync(), isFalse);
  });

  test('내용이 같아도 이름이 다르면 유지', () async {
    final a = write('a/one.jpg', 'same');
    final b = write('b/two.jpg', 'same');
    await scan();

    expect(a.existsSync() && b.existsSync(), isTrue);
  });

  group('내용 기준', () {
    Future<ScanStats> scanContent() => DuplicateScanner(
      onEvent: (_) {},
      mode: MatchMode.content,
    ).scan(root.path);

    test('이름이 달라도 내용이 같으면 대상 파일을 남기고 탐색된 파일 삭제', () async {
      final a = write('a/IMG_001.jpg', 'same');
      final b = write('b/IMG_001 (1).jpg', 'same');
      final c = write('c/copy.jpg', 'same');
      final d = write('d/other.jpg', 'diff');
      final stats = await scanContent();

      expect(a.existsSync() && d.existsSync(), isTrue);
      expect(b.existsSync() || c.existsSync(), isFalse);
      expect(stats.deletedCount, 2);
    });

    test('큰 파일: 앞부분이 같고 뒷부분만 다르면 유지', () async {
      final head = 'x' * (DuplicateScanner.partialBytes + 10);
      final a = write('a/1.bin', '${head}A');
      final b = write('b/2.bin', '${head}B');
      final c = write('c/3.bin', '${head}A');
      await scanContent();

      expect(a.existsSync() && b.existsSync(), isTrue);
      expect(c.existsSync(), isFalse);
    });

    test('빈 파일은 삭제하지 않음', () async {
      final a = write('a/empty1', '');
      final b = write('b/empty2', '');
      await scanContent();

      expect(a.existsSync() && b.existsSync(), isTrue);
    });
  });
}
