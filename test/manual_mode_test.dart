import 'dart:io';

import 'package:duplicate_file_remover/main.dart';
import 'package:duplicate_file_remover/src/app_settings.dart';
import 'package:duplicate_file_remover/src/duplicate_scanner.dart';
import 'package:duplicate_file_remover/src/review_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory root;
  setUp(() => root = Directory.systemTemp.createTempSync('manual_test_'));
  tearDown(() => root.deleteSync(recursive: true));

  File write(String rel, String content) =>
      File('${root.path}/$rel')
        ..createSync(recursive: true)
        ..writeAsStringSync(content);

  Future<List<ScanDuplicateGroup>> scanManual(MatchMode mode) async {
    final groups = <ScanDuplicateGroup>[];
    await DuplicateScanner(
      mode: mode,
      deleteDuplicates: false,
      onEvent: (e) {
        if (e is ScanDuplicateGroup) groups.add(e);
      },
    ).scan(root.path);
    return groups;
  }

  test('수동 모드: 아무것도 삭제하지 않고 중복 그룹만 보고', () async {
    final a = write('a/A.jpg', 'same');
    final b = write('b/A.jpg', 'same');
    final c = write('c/A.jpg', 'same');
    final groups = await scanManual(MatchMode.name);

    expect([a, b, c].every((f) => f.existsSync()), isTrue);
    expect(groups, hasLength(1)); // b, c 가 다시 대상이 되어 중복 그룹을 만들지 않음
    expect(groups.single.keep.path, a.path);
    expect(groups.single.duplicates.map((d) => d.path), [b.path, c.path]);
  });

  test('수동 모드(내용 기준): 이름이 달라도 그룹으로 보고', () async {
    write('a/1.txt', 'same');
    write('b/2.txt', 'same');
    write('c/3.txt', 'other');
    final groups = await scanManual(MatchMode.content);
    expect(groups, hasLength(1));
    expect(groups.single.duplicates, hasLength(1));
  });

  group('ReviewController', () {
    test('추천대로 선택, 그룹마다 최소 1개는 남김, 선택 파일만 삭제', () async {
      final a = write('a/A.jpg', 'same');
      final b = write('b/A.jpg', 'same');
      final c = write('c/A.jpg', 'same');
      final controller = ReviewController(await scanManual(MatchMode.name));
      final group = controller.groups.single;

      // 기본: 추천(a)을 제외한 b, c 선택
      expect(controller.selected, {b.path, c.path});

      // a 까지 선택하면 그룹 전체가 삭제되므로 거부
      expect(controller.setSelected(group, group.files[0], true), isFalse);

      // c 는 남기기로 변경 후 a 선택 가능
      controller.setSelected(group, group.files[2], false);
      expect(controller.setSelected(group, group.files[0], true), isTrue);

      final (ok, failed) = await controller.deleteSelected((_) {});
      expect((ok, failed), (2, 0));
      expect(a.existsSync() || b.existsSync(), isFalse);
      expect(c.existsSync(), isTrue);
      expect(controller.groups, isEmpty); // 1개만 남은 그룹은 목록에서 제거
    });
  });

  group('경고문 동의', () {
    testWidgets('동의 전에는 메인 화면에 들어갈 수 없음', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final settings = AppSettings(AppLanguage.ko);
      await tester.pumpWidget(
        SettingsScope(settings: settings, child: const DuplicateRemoverApp()),
      );
      await tester.pumpAndSettle();

      expect(find.text('주의사항 및 면책 조항'), findsOneWidget);
      final agree = find.widgetWithText(FilledButton, '동의하고 시작');
      expect(tester.widget<FilledButton>(agree).onPressed, isNull);

      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      expect(tester.widget<FilledButton>(agree).onPressed, isNotNull);

      await tester.tap(agree);
      await tester.pump();
      expect(settings.disclaimerAccepted, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getInt('disclaimerAcceptedVersion'),
        AppSettings.disclaimerVersion,
      );
    });
  });
}
