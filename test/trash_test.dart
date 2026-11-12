import 'dart:io';

import 'package:duplicate_file_remover/src/duplicate_scanner.dart';
import 'package:duplicate_file_remover/src/review_page.dart';
import 'package:duplicate_file_remover/src/trash_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;
  late TrashStore trash;

  setUp(() {
    root = Directory.systemTemp.createTempSync('trash_test_');
    trash = TrashStore.inStorage(root.path);
  });
  tearDown(() => root.deleteSync(recursive: true));

  File write(String rel, String content) =>
      File('${root.path}/$rel')
        ..createSync(recursive: true)
        ..writeAsStringSync(content);

  group('TrashStore', () {
    test('이동 → 목록 → 복원', () {
      final f = write('DCIM/A.jpg', 'data');
      final entry = trash.moveToTrash(f.path);

      expect(f.existsSync(), isFalse);
      expect(File(entry.filePath).existsSync(), isTrue);
      expect(File('${trash.root}/.nomedia').existsSync(), isTrue);
      expect(trash.list().single.originalPath, f.path);

      final restored = trash.restore(trash.list().single);
      expect(restored, f.path);
      expect(f.readAsStringSync(), 'data');
      expect(trash.list(), isEmpty);
    });

    test('같은 이름이 이미 있으면 "이름 (1)" 로 복원, 폴더가 없으면 다시 만듦', () {
      final f = write('a/b/A.jpg', 'old');
      trash.moveToTrash(f.path);
      Directory('${root.path}/a').deleteSync(recursive: true);

      expect(trash.restore(trash.list().single), f.path);

      final g = write('x/B.jpg', 'trashed');
      trash.moveToTrash(g.path);
      write('x/B.jpg', 'new');
      expect(trash.restore(trash.list().single), '${root.path}/x/B (1).jpg');
      expect(File('${root.path}/x/B.jpg').readAsStringSync(), 'new');
    });

    test('30일 지난 항목만 자동 영구 삭제', () {
      trash.moveToTrash(write('old.jpg', '1').path);
      trash.moveToTrash(write('new.jpg', '2').path);
      final later = DateTime.now().add(const Duration(days: 31));
      // 두 항목 모두 31일 뒤 기준으로는 만료
      expect(trash.purgeExpired(now: later), 2);
      expect(trash.list(), isEmpty);

      trash.moveToTrash(write('keep.jpg', '3').path);
      expect(trash.purgeExpired(), 0);
      expect(trash.list(), hasLength(1));
    });

    test('남은 보관 일수', () {
      final e = trash.moveToTrash(write('a.jpg', '1').path);
      expect(TrashStore.daysLeft(e), 30);
      expect(
        TrashStore.daysLeft(e, now: e.trashedAt.add(const Duration(days: 31))),
        0,
      );
    });
  });

  test('자동 삭제 + 휴지통: 지우지 않고 휴지통으로 이동, 휴지통 폴더는 탐색 제외', () async {
    final a = write('a/A.jpg', 'same');
    final b = write('b/A.jpg', 'same');
    final stats = await DuplicateScanner(
      onEvent: (_) {},
      trash: trash,
    ).scan(root.path);

    expect(a.existsSync(), isTrue);
    expect(b.existsSync(), isFalse);
    expect(stats.deletedCount, 1);
    expect(trash.list().single.originalPath, b.path);

    // 다시 탐색해도 휴지통 안의 파일은 비교 대상이 아님
    final again = await DuplicateScanner(
      onEvent: (_) {},
      trash: trash,
    ).scan(root.path);
    expect(again.deletedCount, 0);
    expect(trash.list(), hasLength(1));
  });

  test('수동 삭제 + 휴지통: 검토 화면에서 선택한 파일이 휴지통으로 이동', () async {
    write('a/A.jpg', 'same');
    final b = write('b/A.jpg', 'same');
    final groups = <ScanDuplicateGroup>[];
    await DuplicateScanner(
      deleteDuplicates: false,
      onEvent: (e) {
        if (e is ScanDuplicateGroup) groups.add(e);
      },
    ).scan(root.path);

    final controller = ReviewController(groups, trash: trash);
    final (ok, failed) = await controller.deleteSelected((_) {});
    expect((ok, failed), (1, 0));
    expect(b.existsSync(), isFalse);
    expect(trash.list().single.originalPath, b.path);
  });
}
