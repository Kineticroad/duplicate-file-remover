import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'app_settings.dart';
import 'disclaimer_page.dart';
import 'l10n/strings.dart';
import 'trash_page.dart';

/// 옵션 화면: 언어 설정, 버전 정보.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final Future<PackageInfo> _packageInfo = PackageInfo.fromPlatform();

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    final s = settings.strings;
    final theme = Theme.of(context);

    Widget header(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(s.settings)),
      body: ListView(
        children: [
          header(s.language),
          RadioGroup<AppLanguage>(
            groupValue: settings.language,
            onChanged: (lang) {
              if (lang != null) settings.setLanguage(lang);
            },
            child: Column(
              children: [
                for (final lang in AppLanguage.values)
                  RadioListTile<AppLanguage>(
                    value: lang,
                    title: Text(lang.nativeName),
                  ),
              ],
            ),
          ),
          const Divider(),
          header(s.deleteMethodSection),
          RadioGroup<DeleteMethod>(
            groupValue: settings.deleteMethod,
            onChanged: (m) {
              if (m != null) settings.setDeleteMethod(m);
            },
            child: Column(
              children: [
                for (final m in DeleteMethod.values)
                  RadioListTile<DeleteMethod>(
                    value: m,
                    title: Text(s.deleteMethodLabel(m)),
                    subtitle: Text(s.deleteMethodHint(m)),
                  ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: Text(s.openTrash),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TrashPage(store: settings.trashStore),
              ),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.gpp_maybe_outlined),
            title: Text(s.disclaimerTitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DisclaimerPage()),
            ),
          ),
          const Divider(),
          header(s.versionInfo),
          FutureBuilder<PackageInfo>(
            future: _packageInfo,
            builder: (context, snapshot) {
              final info = snapshot.data;
              return Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.apps),
                    title: Text(s.appName),
                    subtitle: Text(s.appTitle),
                  ),
                  ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: Text(s.version),
                    subtitle: Text(info?.version ?? '-'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.tag),
                    title: Text(s.buildNumber),
                    subtitle: Text(info?.buildNumber ?? '-'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: Text(s.licenses),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => showLicensePage(
                      context: context,
                      applicationName: s.appTitle,
                      applicationVersion: info?.version,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
