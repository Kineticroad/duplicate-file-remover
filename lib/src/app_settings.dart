import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n/strings.dart';
import 'storage_permission.dart';
import 'trash_store.dart';

/// 앱 설정(언어). 변경 시 저장하고 화면을 다시 그린다.
class AppSettings extends ChangeNotifier {
  AppSettings(
    this._language, [
    this._disclaimerAccepted = false,
    this._deleteMethod = DeleteMethod.trash,
  ]);

  static const _languageKey = 'language';
  static const _disclaimerKey = 'disclaimerAcceptedVersion';
  static const _deleteMethodKey = 'deleteMethod';

  /// 경고문 내용이 바뀌면 올려서 사용자에게 다시 동의를 받는다.
  static const disclaimerVersion = 2; // 2: 휴지통 안내 추가

  bool _disclaimerAccepted;
  DeleteMethod _deleteMethod;

  /// 지운 파일 처리 방식 (기본: 휴지통).
  DeleteMethod get deleteMethod => _deleteMethod;

  /// 앱 휴지통.
  TrashStore get trashStore => TrashStore.inStorage(defaultRootPath());

  /// 휴지통 방식이면 휴지통 경로, 영구 삭제면 null.
  String? get trashDirOrNull =>
      _deleteMethod == DeleteMethod.trash ? trashStore.root : null;

  /// 주의사항·면책 조항에 동의했는지.
  bool get disclaimerAccepted => _disclaimerAccepted;

  AppLanguage _language;
  AppLanguage get language => _language;
  Strings get strings => Strings.of(_language);

  /// 저장된 언어를 불러온다. 없으면 기기 언어가 한국어일 때 한국어, 아니면 영어.
  static Future<AppSettings> load() async {
    AppLanguage? saved;
    var accepted = false;
    var method = DeleteMethod.trash;
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString(_languageKey);
      saved = AppLanguage.values.where((l) => l.name == name).firstOrNull;
      accepted = (prefs.getInt(_disclaimerKey) ?? 0) >= disclaimerVersion;
      final m = prefs.getString(_deleteMethodKey);
      method =
          DeleteMethod.values.where((v) => v.name == m).firstOrNull ?? method;
    } catch (_) {
      // 저장소를 읽지 못하면 기본값 사용.
    }
    final system = PlatformDispatcher.instance.locale.languageCode == 'ko'
        ? AppLanguage.ko
        : AppLanguage.en;
    return AppSettings(saved ?? system, accepted, method);
  }

  Future<void> setDeleteMethod(DeleteMethod method) async {
    if (method == _deleteMethod) return;
    _deleteMethod = method;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_deleteMethodKey, method.name);
  }

  Future<void> acceptDisclaimer() async {
    _disclaimerAccepted = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_disclaimerKey, disclaimerVersion);
  }

  Future<void> setLanguage(AppLanguage language) async {
    if (language == _language) return;
    _language = language;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, language.name);
  }
}

/// 위젯 트리에 [AppSettings] 를 제공한다.
class SettingsScope extends InheritedNotifier<AppSettings> {
  const SettingsScope({
    super.key,
    required AppSettings settings,
    required super.child,
  }) : super(notifier: settings);

  /// 변경 구독 없이 읽기 (initState 등에서 사용).
  static AppSettings read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<SettingsScope>()!.notifier!;

  static AppSettings of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SettingsScope>()!.notifier!;
}

/// 현재 언어의 문구: `S.of(context).appTitle`
abstract final class S {
  static Strings of(BuildContext context) => SettingsScope.of(context).strings;
}
