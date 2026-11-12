import 'package:duplicate_file_remover/src/app_settings.dart';
import 'package:duplicate_file_remover/src/l10n/strings.dart';
import 'package:duplicate_file_remover/src/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'dup',
      packageName: 'dev.thereis.duplicate_file_remover',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  testWidgets('옵션 화면: 버전 표시 및 언어 전환 후 저장', (tester) async {
    final settings = AppSettings(AppLanguage.ko);
    await tester.pumpWidget(SettingsScope(
      settings: settings,
      child: const MaterialApp(home: SettingsPage()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('옵션'), findsOneWidget);
    // 화면 아래쪽 버전 정보까지 스크롤
    await tester.scrollUntilVisible(find.text('1.0.0'), 200);
    expect(find.text('버전 정보'), findsOneWidget);
    expect(find.text('1.0.0'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('English'), -200);
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    expect(find.text('Options'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Version info'), 200);
    expect(find.text('Version info'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('language'), 'en');

    final loaded = await AppSettings.load();
    expect(loaded.language, AppLanguage.en);
  });
}
