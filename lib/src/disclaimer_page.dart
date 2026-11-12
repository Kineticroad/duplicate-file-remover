import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_settings.dart';

/// 주의사항 및 면책 조항.
///
/// [requireConsent] 가 true 면 첫 실행 동의 화면(동의해야 앱 사용 가능),
/// false 면 옵션 화면에서 다시 보기.
class DisclaimerPage extends StatefulWidget {
  const DisclaimerPage({super.key, this.requireConsent = false});
  final bool requireConsent;

  @override
  State<DisclaimerPage> createState() => _DisclaimerPageState();
}

class _DisclaimerPageState extends State<DisclaimerPage> {
  bool _checked = false;

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    final s = settings.strings;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.disclaimerTitle),
        automaticallyImplyLeading: !widget.requireConsent,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: cs.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          s.disclaimerIntro,
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  for (final (i, item) in s.disclaimerItems.indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 24,
                            child: Text(
                              '${i + 1}.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              item,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            if (widget.requireConsent) ...[
              const Divider(height: 1),
              CheckboxListTile(
                value: _checked,
                onChanged: (v) => setState(() => _checked = v ?? false),
                title: Text(s.disclaimerAgreeCheck),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => SystemNavigator.pop(),
                        child: Text(s.disclaimerDecline),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _checked ? settings.acceptDisclaimer : null,
                        child: Text(s.disclaimerAgree),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
