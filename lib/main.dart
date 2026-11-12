import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'src/app_settings.dart';
import 'src/directory_browser_page.dart';
import 'src/disclaimer_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await AppSettings.load();
  runApp(SettingsScope(settings: settings, child: const DuplicateRemoverApp()));
}

class DuplicateRemoverApp extends StatelessWidget {
  const DuplicateRemoverApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (_) => settings.strings.appTitle,
      locale: Locale(settings.language.name),
      supportedLocales: const [Locale('ko'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(colorSchemeSeed: Colors.indigo),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.dark,
      ),
      // 주의사항·면책 조항에 동의해야 앱을 사용할 수 있다.
      home: settings.disclaimerAccepted
          ? const DirectoryBrowserPage()
          : const DisclaimerPage(requireConsent: true),
    );
  }
}
