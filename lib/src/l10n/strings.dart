/// 앱 문구 (한국어/영어).
///
/// 스캐너가 별도 Isolate 에서 로그를 만들기 때문에 Flutter 에 의존하지 않는
/// 순수 Dart 클래스로 구현한다. UI 에서는 `S.of(context)` 로 사용한다.
library;

enum AppLanguage {
  ko('한국어'),
  en('English');

  const AppLanguage(this.nativeName);

  /// 해당 언어로 표기한 언어 이름.
  final String nativeName;
}

/// 판정 기준 (문구 함수에서 쓰기 위해 여기 둔다).
enum MatchMode { name, content, image }

/// 지운 파일을 어떻게 처리할지.
enum DeleteMethod {
  /// 앱 휴지통으로 이동 (30일 후 자동 영구 삭제).
  trash,

  /// 즉시 영구 삭제.
  permanent,
}

/// 삭제 방식.
enum DeleteMode {
  /// 탐색 후 검토 화면에서 사용자가 직접 선택한 파일만 삭제.
  manual,

  /// 찾는 즉시 확인 없이 삭제.
  auto,
}

abstract class Strings {
  const Strings();

  factory Strings.of(AppLanguage lang) =>
      lang == AppLanguage.ko ? const KoStrings() : const EnStrings();

  // ---------- 공통 / 브라우저 ----------
  String get appTitle;
  String get refresh;
  String get settings;
  String get goUp;
  String get openFolder;
  String get selectCurrentFolder;
  String get noSubfolders;
  String cannotReadFolder(String msg);
  String get selectFolderPrompt;
  String selected(String path);
  String get removeDuplicates;
  String confirmBody(
    MatchMode mode,
    DeleteMode deleteMode,
    String target, {
    bool toTrash = false,
  });
  String get cancel;
  String get start;
  String get permissionRequired;
  String get requestPermission;
  String get openAppSettings;

  // ---------- 판정 기준 ----------
  String modeLabel(MatchMode mode);
  String modeDescription(MatchMode mode);

  /// 판정 기준별 검사 대상 파일 안내.
  String modeScope(MatchMode mode);
  String jpegLabel({required bool motion, required bool gps});

  // ---------- 진행 화면 ----------
  String get scanTitle;
  String scanHeader(String root, MatchMode mode);
  String statFolders(int n);
  String statFiles(int n);
  String statChecked(int done, int total);
  String statCompared(int n);
  String statDeleted(int n);
  String statFreed(String size);
  String statErrors(int n);
  String get targetFile;
  String pathLabel(String dir);
  String fileNameLabel(String name);
  String get stop;
  String get restart;
  String get statusRunning;
  String get statusStopped;
  String get statusFinished;
  String get preparing;
  String get startingDetail;
  String get stoppedDetail;
  String finishedDetail(int deleted, String freed);
  String elapsed(String time);
  String progress(int done, int total, int percent);
  String counting(int found);
  String get userStopped;
  String errorLog(Object error);

  // ---------- 설정 화면 ----------
  String get language;
  String get versionInfo;
  String get appName;
  String get version;
  String get buildNumber;
  String get licenses;

  // ---------- 스캐너 로그 / 진행 상황 ----------
  String folderNotExist(String path);
  String logStart(MatchMode mode, String root);
  String phaseCollect(int steps);
  String logCollected(int files, int dirs);
  String get logStepCompare;
  String get phaseCompare;
  String activityFindSame(String name, MatchMode mode);
  String logDone(int files, int deleted, String freed);
  String logImageAnalyze(int jpegs);
  String get phaseAnalyze;
  String activityAnalyze(String name, String size, bool big);
  String readFailed(String path, String msg);
  String jpegSkipped(String path);
  String logAnalyzed(int i, int n, String name, String label);
  String get logStepImageCompare;
  String get phaseImageCompare;
  String activityImageTarget(String name, String label);
  String logTarget(String path);
  String logSameImagesFound(int n);
  String logSameImage(String path, String label);
  String logKeep(String path, String label);
  String activityKeep(int count, String name, String label);
  String get warnGpsLost;
  String activityDeleting(String path);
  String logDeleted(String path);
  String logDeleteFailed(String path, String msg);
  String logImageDone(int jpegs, int deleted, String freed);
  String sizeHint(String size, bool big);
  String activityReadDir(String path, int dirs, int files);
  String dirReadFailed(String path, String msg);
  String fileInfoFailed(String path, String msg);
  String logSameNameFound(int n);
  String logSameSizeFound(int n, String size);
  String logCompare(String path);
  String logSizeDiffers(String a, String b);
  String get logPartialDiffers;
  String get logPartialSame;
  String logChecksumTarget(String c);
  String logChecksumOther(String c);
  String get logChecksumDiffers;
  String checksumFailed(String msg);
  String get logIdentical;
  String activityChecksum(String name, String hint);
  String activityPartial(String name);

  // ---------- 삭제 모드 / 경고 ----------
  String deleteModeLabel(DeleteMode mode);
  String get findDuplicates;
  String get autoDeleteWarning;
  String get autoDeleteAck;
  String get disclaimerTitle;
  String get disclaimerIntro;
  List<String> get disclaimerItems;
  String get disclaimerAgreeCheck;
  String get disclaimerAgree;
  String get disclaimerDecline;
  String get logAddedToReview;

  // ---------- 진행 화면 (수동) ----------
  String statFound(int n);
  String reviewButton(int groups);
  String finishedManualDetail(int found, String size);
  String get noDuplicatesFound;

  // ---------- 검토 화면 ----------
  String get reviewTitle;
  String reviewSummary(int groups, int files, String size);
  String get selectRecommended;
  String get clearSelection;
  String get keepRecommended;
  String get willDelete;
  String get willKeep;
  String deleteSelected(int n, String size);
  String get mustKeepOne;
  String get deleteConfirmTitle;
  String deleteConfirmBody(int n, String size);
  String get delete;
  String deleting(int done, int total);
  String deleteResult(int ok, int failed);
  String groupTitle(int index, int count, String size);
  String get compareTitle;
  String get sameContentNote;
  String get folderLabel;
  String get fileNameField;
  String get sizeLabel;
  String get modifiedLabel;
  String get typeLabel;
  String get previewUnavailable;
  String get textPreviewTruncated;
  String get reviewEmpty;
  String get fileMissing;
  String get tapToEnlarge;

  // ---------- 휴지통 ----------
  String get deleteMethodSection;
  String deleteMethodLabel(DeleteMethod m);
  String deleteMethodHint(DeleteMethod m);
  String get trashTitle;
  String get openTrash;
  String get trashEmpty;
  String get trashInfo;
  String trashSummary(int n, String size);
  String get restore;
  String get deleteForever;
  String get emptyTrash;
  String get selectAll;
  String emptyTrashConfirm(int n, String size);
  String deleteForeverConfirm(int n, String size);
  String restored(int n);
  String trashedAt(String date);
  String daysLeft(int days);
  String get originalLocation;
  String purged(int n);
  String logTrashed(String path);
  String activityTrashing(String path);
  String statTrashed(int n);
  String finishedTrashDetail(int n, String size);
  String get autoTrashWarning;
  String moveToTrashSelected(int n, String size);
  String get trashConfirmTitle;
  String trashConfirmBody(int n, String size);
  String trashing(int done, int total);
  String trashResult(int ok, int failed);
}

class KoStrings extends Strings {
  const KoStrings();

  @override
  String get appTitle => '중복 파일 제거';
  @override
  String get refresh => '새로고침';
  @override
  String get settings => '옵션';
  @override
  String get goUp => '상위 폴더';
  @override
  String get openFolder => '폴더 열기';
  @override
  String get selectCurrentFolder => '현재 폴더 선택';
  @override
  String get noSubfolders => '하위 폴더가 없습니다.';
  @override
  String cannotReadFolder(String msg) => '폴더를 읽을 수 없습니다: $msg';
  @override
  String get selectFolderPrompt => '폴더를 선택하세요';
  @override
  String selected(String path) => '선택: $path';
  @override
  String get removeDuplicates => '중복 파일 제거';
  @override
  String confirmBody(
    MatchMode mode,
    DeleteMode deleteMode,
    String target, {
    bool toTrash = false,
  }) =>
      '[${modeLabel(mode)} · ${deleteModeLabel(deleteMode)}]\n'
      '아래 폴더와 모든 하위 폴더에서 ${modeDescription(mode)}\n'
      '${modeScope(mode)}\n\n$target\n\n'
      '${deleteMode == DeleteMode.manual
          ? '탐색이 끝나면 검토 화면에서 파일을 비교·확인한 뒤 삭제할 파일을 직접 선택합니다. 탐색 중에는 아무 파일도 삭제되지 않습니다.'
          : toTrash
          ? '찾은 중복 파일은 확인 없이 즉시 휴지통으로 이동합니다. 휴지통에서 30일 동안 복원할 수 있습니다.'
          : '찾은 중복 파일은 확인 없이 즉시 영구 삭제됩니다.'}';
  @override
  String get cancel => '취소';
  @override
  String get start => '시작';
  @override
  String get permissionRequired => '파일을 탐색하고 삭제하려면\n"모든 파일 접근" 권한이 필요합니다.';
  @override
  String get requestPermission => '권한 요청';
  @override
  String get openAppSettings => '앱 설정 열기';

  @override
  String modeLabel(MatchMode mode) => switch (mode) {
    MatchMode.name => '이름 기준',
    MatchMode.content => '내용 기준',
    MatchMode.image => '사진 기준',
  };
  @override
  String modeDescription(MatchMode mode) => switch (mode) {
    MatchMode.name =>
      '이름과 내용(checksum)이 같은 파일을 찾습니다. 대상 파일은 남기고 '
          '탐색된 파일을 삭제 대상으로 합니다.',
    MatchMode.content =>
      '이름과 상관없이 내용(checksum)이 같은 파일을 찾습니다. '
          '대상 파일은 남기고 탐색된 파일을 삭제 대상으로 합니다.',
    MatchMode.image =>
      'JPEG 사진에서 메타데이터(EXIF/GPS)와 모션 포토 동영상을 '
          '제외한 사진 데이터가 같은 파일을 찾습니다. 모션 포토 > GPS 있음 > 일반 사진 '
          '순서로 하나만 남기고 나머지를 삭제 대상으로 합니다. (우선순위가 같으면 대상 파일을 남김)',
  };
  @override
  String modeScope(MatchMode mode) => switch (mode) {
    MatchMode.name => '검사 범위: 모든 종류의 파일 (사진, 동영상, 음악, 문서, 앱 설치 파일 등)',
    MatchMode.content =>
      '검사 범위: 모든 종류의 파일 (사진, 동영상, 음악, 문서 등). 크기가 0인 빈 파일은 제외',
    MatchMode.image => '검사 범위: JPEG 사진(.jpg, .jpeg)만. 동영상(mp4, mov 등)과 PNG·HEIC 등 다른 형식은 검사하지 않습니다',
  };
  @override
  String jpegLabel({required bool motion, required bool gps}) {
    final parts = [if (motion) '모션 포토', if (gps) 'GPS'];
    return parts.isEmpty ? '일반 사진' : parts.join('+');
  }

  @override
  String get scanTitle => '중복 파일 탐색';
  @override
  String scanHeader(String root, MatchMode mode) =>
      '탐색 폴더: $root\n판정: ${modeLabel(mode)}';
  @override
  String statFolders(int n) => '폴더 $n';
  @override
  String statFiles(int n) => '파일 $n';
  @override
  String statChecked(int done, int total) => '검사 $done/$total';
  @override
  String statCompared(int n) => '비교 $n';
  @override
  String statDeleted(int n) => '삭제 $n';
  @override
  String statFreed(String size) => '확보 $size';
  @override
  String statErrors(int n) => '오류 $n';
  @override
  String get targetFile => '대상 파일';
  @override
  String pathLabel(String dir) => '경로: $dir';
  @override
  String fileNameLabel(String name) => '파일명: $name';
  @override
  String get stop => '정지';
  @override
  String get restart => '다시 시작';
  @override
  String get statusRunning => '탐색 중';
  @override
  String get statusStopped => '정지됨';
  @override
  String get statusFinished => '완료';
  @override
  String get preparing => '준비 중';
  @override
  String get startingDetail => '탐색 작업을 시작하는 중';
  @override
  String get stoppedDetail => '"다시 시작"을 누르면 처음부터 다시 탐색합니다.';
  @override
  String finishedDetail(int deleted, String freed) => '삭제 $deleted개, 확보 $freed';
  @override
  String elapsed(String time) => '경과 $time';
  @override
  String progress(int done, int total, int percent) =>
      '$done / $total ($percent%)';
  @override
  String counting(int found) => '전체 개수를 세는 중… ($found개 발견)';
  @override
  String get userStopped => '사용자가 탐색을 정지했습니다.';
  @override
  String errorLog(Object error) => '오류: $error';

  @override
  String get language => '언어';
  @override
  String get versionInfo => '버전 정보';
  @override
  String get appName => '앱 이름';
  @override
  String get version => '버전';
  @override
  String get buildNumber => '빌드 번호';
  @override
  String get licenses => '오픈소스 라이선스';

  @override
  String folderNotExist(String path) => '폴더가 존재하지 않습니다: $path';
  @override
  String logStart(MatchMode mode, String root) =>
      '[${modeLabel(mode)}] ① 파일 목록 수집: $root';
  @override
  String phaseCollect(int steps) => '1/$steps 파일 목록 수집 중';
  @override
  String logCollected(int files, int dirs) => '   파일 $files개 (폴더 $dirs개)';
  @override
  String get logStepCompare => '② 대상 파일별 동일 파일 탐색';
  @override
  String get phaseCompare => '2/2 동일 파일 탐색 중';
  @override
  String activityFindSame(String name, MatchMode mode) =>
      '대상: $name\n같은 ${mode == MatchMode.name ? '이름' : '크기'}의 파일 찾는 중';
  @override
  String logDone(int files, int deleted, String freed) =>
      '탐색 완료 — 파일 $files개, 삭제 $deleted개, 확보 $freed';
  @override
  String logImageAnalyze(int jpegs) => '② 사진 데이터 분석 (JPEG $jpegs개)';
  @override
  String get phaseAnalyze => '2/3 사진 분석 중';
  @override
  String activityAnalyze(String name, String size, bool big) =>
      '$name ($size) 읽는 중\n'
      '메타데이터·모션 동영상을 빼고 사진 데이터 해시 계산, 모션 포토/GPS 확인'
      '${big ? '\n큰 파일이라 시간이 걸릴 수 있습니다' : ''}';
  @override
  String readFailed(String path, String msg) => '파일 읽기 실패: $path ($msg)';
  @override
  String jpegSkipped(String path) => 'JPEG 분석 불가(건너뜀): $path';
  @override
  String logAnalyzed(int i, int n, String name, String label) =>
      '  [$i/$n] $name → $label';
  @override
  String get logStepImageCompare => '③ 대상 파일별 동일 사진 탐색';
  @override
  String get phaseImageCompare => '3/3 같은 사진 비교·정리 중';
  @override
  String activityImageTarget(String name, String label) =>
      '대상: $name ($label)\n사진 데이터가 같은 파일 찾는 중';
  @override
  String logTarget(String path) => '[대상] $path';
  @override
  String logSameImagesFound(int n) => '  사진 데이터가 같은 파일 $n개 발견';
  @override
  String logSameImage(String path, String label) => '  동일 사진: $path ($label)';
  @override
  String logKeep(String path, String label) => '  남길 파일: $path ($label)';
  @override
  String activityKeep(int count, String name, String label) =>
      '같은 사진 $count장 중 남길 파일 결정: $name ($label)';
  @override
  String get warnGpsLost => '  ⚠ 남길 파일에 GPS 가 없습니다. GPS 는 삭제되는 파일에만 있습니다.';
  @override
  String activityDeleting(String path) => '중복 파일 삭제 중: $path';
  @override
  String logDeleted(String path) => '    삭제 완료: $path';
  @override
  String logDeleteFailed(String path, String msg) => '    삭제 실패: $path ($msg)';
  @override
  String logImageDone(int jpegs, int deleted, String freed) =>
      '탐색 완료 — JPEG $jpegs개, 삭제 $deleted개, 확보 $freed';
  @override
  String sizeHint(String size, bool big) =>
      big ? ' ($size, 큰 파일이라 시간이 걸릴 수 있습니다)' : ' ($size)';
  @override
  String activityReadDir(String path, int dirs, int files) =>
      '폴더 읽는 중: $path\n지금까지 폴더 $dirs개, 파일 $files개 발견';
  @override
  String dirReadFailed(String path, String msg) => '폴더 읽기 실패: $path ($msg)';
  @override
  String fileInfoFailed(String path, String msg) => '파일 정보 읽기 실패: $path ($msg)';
  @override
  String logSameNameFound(int n) => '  이름이 같은 파일 $n개 발견 → 비교 시작';
  @override
  String logSameSizeFound(int n, String size) =>
      '  크기가 같은 파일 $n개 발견 ($size) → 비교 시작';
  @override
  String logCompare(String path) => '  비교: $path';
  @override
  String logSizeDiffers(String a, String b) => '    크기 다름 ($a ≠ $b) → 다른 파일';
  @override
  String get logPartialDiffers => '    앞부분 checksum 다름 → 다른 파일';
  @override
  String get logPartialSame => '    앞부분 checksum 같음 → 전체 비교';
  @override
  String logChecksumTarget(String c) => '    checksum 대상: $c';
  @override
  String logChecksumOther(String c) => '    checksum 비교: $c';
  @override
  String get logChecksumDiffers => '    checksum 다름 → 다른 파일';
  @override
  String checksumFailed(String msg) => '    checksum 계산 실패 ($msg)';
  @override
  String get logIdentical => '    동일한 파일입니다!';
  @override
  String activityChecksum(String name, String hint) =>
      'checksum 계산 중 (파일 전체 읽기): $name$hint';
  @override
  String activityPartial(String name) =>
      '앞부분 checksum 계산 중 (앞 64KB만 읽기): $name';

  @override
  String deleteModeLabel(DeleteMode mode) => switch (mode) {
    DeleteMode.manual => '수동 삭제',
    DeleteMode.auto => '자동 삭제',
  };
  @override
  String get findDuplicates => '중복 파일 찾기';
  @override
  String get autoDeleteWarning =>
      '⚠ 자동 삭제 모드는 찾은 중복 파일을 확인 없이 즉시 영구 삭제합니다. '
      '삭제된 파일은 휴지통으로 이동하지 않으며 복구할 수 없습니다. '
      '삭제로 인한 파일 유실의 책임은 사용자에게 있습니다.';
  @override
  String get autoDeleteAck => '위 내용을 이해했으며, 중요한 파일은 미리 백업했습니다.';
  @override
  String get disclaimerTitle => '주의사항 및 면책 조항';
  @override
  String get disclaimerIntro => '이 앱을 사용하기 전에 아래 내용을 반드시 읽어 주세요.';
  @override
  List<String> get disclaimerItems => const [
    '이 앱은 사용자가 선택한 폴더의 파일을 삭제합니다. 삭제 방식이 "휴지통으로 이동"이면 30일 동안 복원할 수 있지만, 보관 기간이 지났거나 휴지통을 비운 경우, 또는 "바로 영구 삭제" 방식인 경우에는 복구할 수 없습니다.',
    '휴지통의 파일은 기기 저장소의 ".DuplicateRemoverTrash" 폴더에 보관되며 저장 공간을 계속 차지합니다. 앱을 삭제해도 이 폴더는 기기에 남을 수 있습니다.',
    '중복 판정은 파일 이름, 크기, checksum(MD5), 사진 데이터 비교에 기반한 자동 판정이며, 오판정 가능성을 완전히 배제할 수 없습니다.',
    '사용 전에 중요한 파일(사진, 동영상, 문서 등)은 반드시 별도의 장소에 백업하십시오.',
    '삭제할 파일의 최종 선택과 삭제 실행에 대한 판단 및 책임은 사용자에게 있습니다. 자동 삭제 모드는 확인 절차 없이 즉시 삭제합니다.',
    '시스템 폴더나 다른 앱이 사용하는 폴더의 파일을 삭제하면 해당 앱이나 기기가 정상적으로 동작하지 않을 수 있습니다.',
    '개발자는 관련 법령이 허용하는 최대 범위 내에서, 이 앱의 사용 또는 사용 불능으로 인해 발생한 파일 유실, 데이터 손상 및 기타 직접적·간접적 손해에 대하여 책임을 지지 않습니다.',
    '이 앱은 파일을 탐색하고 삭제하기 위해 "모든 파일 접근" 권한을 사용합니다. 파일 정보는 기기 안에서만 처리되며 외부로 전송되지 않습니다.',
  ];
  @override
  String get disclaimerAgreeCheck => '위 내용을 모두 읽고 이해했으며, 이에 동의합니다.';
  @override
  String get disclaimerAgree => '동의하고 시작';
  @override
  String get disclaimerDecline => '동의하지 않음 (종료)';
  @override
  String get logAddedToReview => '    → 검토 목록에 추가 (삭제하지 않음)';

  @override
  String statFound(int n) => '중복 $n';
  @override
  String reviewButton(int groups) => '검토 및 삭제 ($groups개 그룹)';
  @override
  String finishedManualDetail(int found, String size) =>
      '중복 파일 $found개 ($size) 발견 — 검토 화면에서 삭제할 파일을 선택하세요.';
  @override
  String get noDuplicatesFound => '중복 파일이 없습니다.';

  @override
  String get reviewTitle => '중복 파일 검토';
  @override
  String reviewSummary(int groups, int files, String size) =>
      '$groups개 그룹 · 삭제 선택 $files개 ($size)';
  @override
  String get selectRecommended => '추천대로 선택';
  @override
  String get clearSelection => '선택 해제';
  @override
  String get keepRecommended => '남김 추천';
  @override
  String get willDelete => '삭제';
  @override
  String get willKeep => '남김';
  @override
  String deleteSelected(int n, String size) => '선택한 $n개 삭제 ($size)';
  @override
  String get mustKeepOne => '그룹마다 최소 1개의 파일은 남겨야 합니다.';
  @override
  String get deleteConfirmTitle => '파일 삭제';
  @override
  String deleteConfirmBody(int n, String size) =>
      '선택한 파일 $n개($size)를 영구 삭제합니다.\n삭제된 파일은 복구할 수 없습니다.';
  @override
  String get delete => '삭제';
  @override
  String deleting(int done, int total) => '삭제 중… $done / $total';
  @override
  String deleteResult(int ok, int failed) =>
      failed == 0 ? '$ok개 삭제했습니다.' : '$ok개 삭제, $failed개 실패했습니다.';
  @override
  String groupTitle(int index, int count, String size) =>
      '그룹 $index · $count개 · 합계 $size';
  @override
  String get compareTitle => '파일 비교';
  @override
  String get sameContentNote =>
      '이 그룹의 파일들은 판정 기준상 내용이 동일합니다. 위치·이름·수정일을 비교해 남길 파일을 고르세요.';
  @override
  String get folderLabel => '폴더';
  @override
  String get fileNameField => '파일명';
  @override
  String get sizeLabel => '크기';
  @override
  String get modifiedLabel => '수정일';
  @override
  String get typeLabel => '종류';
  @override
  String get previewUnavailable => '미리보기를 지원하지 않는 파일입니다.';
  @override
  String get textPreviewTruncated => '… (앞부분만 표시)';
  @override
  String get reviewEmpty => '검토할 중복 파일이 없습니다.';
  @override
  String get fileMissing => '파일이 존재하지 않습니다.';
  @override
  String get tapToEnlarge => '탭하여 크게 보기';

  @override
  String get deleteMethodSection => '삭제 방식';
  @override
  String deleteMethodLabel(DeleteMethod m) => switch (m) {
    DeleteMethod.trash => '휴지통으로 이동 (권장)',
    DeleteMethod.permanent => '바로 영구 삭제',
  };
  @override
  String deleteMethodHint(DeleteMethod m) => switch (m) {
    DeleteMethod.trash =>
      '지운 파일을 30일 동안 보관하며 복원할 수 있습니다. 저장 공간은 휴지통을 비우거나 30일이 지나야 확보됩니다.',
    DeleteMethod.permanent => '지운 파일을 즉시 영구 삭제합니다. 복구할 수 없습니다.',
  };
  @override
  String get trashTitle => '휴지통';
  @override
  String get openTrash => '휴지통 열기';
  @override
  String get trashEmpty => '휴지통이 비어 있습니다.';
  @override
  String get trashInfo => '휴지통의 파일은 30일이 지나면 자동으로 영구 삭제됩니다.';
  @override
  String trashSummary(int n, String size) => '$n개 · $size 사용 중';
  @override
  String get restore => '복원';
  @override
  String get deleteForever => '영구 삭제';
  @override
  String get emptyTrash => '휴지통 비우기';
  @override
  String get selectAll => '전체 선택';
  @override
  String emptyTrashConfirm(int n, String size) =>
      '휴지통의 파일 $n개($size)를 모두 영구 삭제합니다.\n삭제된 파일은 복구할 수 없습니다.';
  @override
  String deleteForeverConfirm(int n, String size) =>
      '선택한 파일 $n개($size)를 영구 삭제합니다.\n삭제된 파일은 복구할 수 없습니다.';
  @override
  String restored(int n) => '$n개를 원래 위치로 복원했습니다.';
  @override
  String trashedAt(String date) => '삭제일 $date';
  @override
  String daysLeft(int days) => days == 0 ? '곧 영구 삭제' : '$days일 후 영구 삭제';
  @override
  String get originalLocation => '원래 위치';
  @override
  String purged(int n) => '보관 기간(30일)이 지난 파일 $n개를 휴지통에서 영구 삭제했습니다.';
  @override
  String logTrashed(String path) => '    휴지통으로 이동: $path';
  @override
  String activityTrashing(String path) => '휴지통으로 이동 중: $path';
  @override
  String statTrashed(int n) => '휴지통 $n';
  @override
  String finishedTrashDetail(int n, String size) =>
      '휴지통으로 $n개 이동 ($size) — 휴지통에서 30일 동안 복원할 수 있습니다.';
  @override
  String get autoTrashWarning =>
      '⚠ 자동 삭제 모드는 찾은 중복 파일을 확인 없이 즉시 휴지통으로 옮깁니다. '
      '휴지통의 파일은 30일 후 자동으로 영구 삭제되며, 그 이후에는 복구할 수 없습니다.';
  @override
  String moveToTrashSelected(int n, String size) => '선택한 $n개 휴지통으로 ($size)';
  @override
  String get trashConfirmTitle => '휴지통으로 이동';
  @override
  String trashConfirmBody(int n, String size) =>
      '선택한 파일 $n개($size)를 휴지통으로 옮깁니다.\n30일 동안 휴지통에서 복원할 수 있습니다.';
  @override
  String trashing(int done, int total) => '휴지통으로 이동 중… $done / $total';
  @override
  String trashResult(int ok, int failed) =>
      failed == 0 ? '$ok개를 휴지통으로 옮겼습니다.' : '$ok개를 휴지통으로 옮겼고, $failed개는 실패했습니다.';
}

class EnStrings extends Strings {
  const EnStrings();

  @override
  String get appTitle => 'Duplicate Remover';
  @override
  String get refresh => 'Refresh';
  @override
  String get settings => 'Options';
  @override
  String get goUp => 'Parent folder';
  @override
  String get openFolder => 'Open folder';
  @override
  String get selectCurrentFolder => 'Select this folder';
  @override
  String get noSubfolders => 'No subfolders.';
  @override
  String cannotReadFolder(String msg) => 'Cannot read folder: $msg';
  @override
  String get selectFolderPrompt => 'Select a folder';
  @override
  String selected(String path) => 'Selected: $path';
  @override
  String get removeDuplicates => 'Remove duplicates';
  @override
  String confirmBody(
    MatchMode mode,
    DeleteMode deleteMode,
    String target, {
    bool toTrash = false,
  }) =>
      '[${modeLabel(mode)} · ${deleteModeLabel(deleteMode)}]\n'
      'In the folder below and all its subfolders, ${modeDescription(mode)}'
      '\n${modeScope(mode)}\n\n$target\n\n'
      '${deleteMode == DeleteMode.manual
          ? 'After the scan, you can compare and inspect the files on the review screen and choose which ones to delete. Nothing is deleted during the scan.'
          : toTrash
          ? 'Duplicates found will be moved to the trash immediately without confirmation. They can be restored from the trash for 30 days.'
          : 'Duplicates found will be permanently deleted immediately without confirmation.'}';
  @override
  String get cancel => 'Cancel';
  @override
  String get start => 'Start';
  @override
  String get permissionRequired =>
      'To scan and delete files,\n"All files access" permission is required.';
  @override
  String get requestPermission => 'Request permission';
  @override
  String get openAppSettings => 'Open app settings';

  @override
  String modeLabel(MatchMode mode) => switch (mode) {
    MatchMode.name => 'By name',
    MatchMode.content => 'By content',
    MatchMode.image => 'By photo',
  };
  @override
  String modeDescription(MatchMode mode) => switch (mode) {
    MatchMode.name =>
      'finds files with the same name and content (checksum). '
          'The target file is kept and the files found become deletion '
          'candidates.',
    MatchMode.content =>
      'finds files with the same content (checksum) regardless of name. '
          'The target file is kept and the files found become deletion '
          'candidates.',
    MatchMode.image =>
      'finds JPEG photos whose image data is identical, '
          'ignoring metadata (EXIF/GPS) and motion photo video. Only one is '
          'kept in the order: motion photo > has GPS > plain photo; the rest '
          'become deletion candidates. (On a tie, the target file is kept.)',
  };
  @override
  String modeScope(MatchMode mode) => switch (mode) {
    MatchMode.name =>
      'Scope: all file types (photos, videos, music, documents, APKs, etc.)',
    MatchMode.content => 'Scope: all file types (photos, videos, music, documents, etc.). Empty (0-byte) files are excluded',
    MatchMode.image => 'Scope: JPEG photos (.jpg, .jpeg) only. Videos (mp4, mov, etc.) and other formats such as PNG/HEIC are not checked',
  };
  @override
  String jpegLabel({required bool motion, required bool gps}) {
    final parts = [if (motion) 'Motion photo', if (gps) 'GPS'];
    return parts.isEmpty ? 'Plain photo' : parts.join('+');
  }

  @override
  String get scanTitle => 'Scanning duplicates';
  @override
  String scanHeader(String root, MatchMode mode) =>
      'Folder: $root\nMatch: ${modeLabel(mode)}';
  @override
  String statFolders(int n) => 'Folders $n';
  @override
  String statFiles(int n) => 'Files $n';
  @override
  String statChecked(int done, int total) => 'Checked $done/$total';
  @override
  String statCompared(int n) => 'Compared $n';
  @override
  String statDeleted(int n) => 'Deleted $n';
  @override
  String statFreed(String size) => 'Freed $size';
  @override
  String statErrors(int n) => 'Errors $n';
  @override
  String get targetFile => 'Target file';
  @override
  String pathLabel(String dir) => 'Path: $dir';
  @override
  String fileNameLabel(String name) => 'Name: $name';
  @override
  String get stop => 'Stop';
  @override
  String get restart => 'Restart';
  @override
  String get statusRunning => 'Scanning';
  @override
  String get statusStopped => 'Stopped';
  @override
  String get statusFinished => 'Done';
  @override
  String get preparing => 'Preparing';
  @override
  String get startingDetail => 'Starting the scan';
  @override
  String get stoppedDetail =>
      'Press "Restart" to scan again from the beginning.';
  @override
  String finishedDetail(int deleted, String freed) =>
      'Deleted $deleted, freed $freed';
  @override
  String elapsed(String time) => 'Elapsed $time';
  @override
  String progress(int done, int total, int percent) =>
      '$done / $total ($percent%)';
  @override
  String counting(int found) => 'Counting files… ($found found)';
  @override
  String get userStopped => 'Scan stopped by user.';
  @override
  String errorLog(Object error) => 'Error: $error';

  @override
  String get language => 'Language';
  @override
  String get versionInfo => 'Version info';
  @override
  String get appName => 'App name';
  @override
  String get version => 'Version';
  @override
  String get buildNumber => 'Build number';
  @override
  String get licenses => 'Open source licenses';

  @override
  String folderNotExist(String path) => 'Folder does not exist: $path';
  @override
  String logStart(MatchMode mode, String root) =>
      '[${modeLabel(mode)}] ① Collecting file list: $root';
  @override
  String phaseCollect(int steps) => '1/$steps Collecting file list';
  @override
  String logCollected(int files, int dirs) => '   $files files ($dirs folders)';
  @override
  String get logStepCompare => '② Searching duplicates for each target file';
  @override
  String get phaseCompare => '2/2 Searching duplicates';
  @override
  String activityFindSame(String name, MatchMode mode) =>
      'Target: $name\nLooking for files with the same '
      '${mode == MatchMode.name ? 'name' : 'size'}';
  @override
  String logDone(int files, int deleted, String freed) =>
      'Done — $files files, $deleted deleted, $freed freed';
  @override
  String logImageAnalyze(int jpegs) => '② Analyzing image data ($jpegs JPEGs)';
  @override
  String get phaseAnalyze => '2/3 Analyzing photos';
  @override
  String activityAnalyze(String name, String size, bool big) =>
      'Reading $name ($size)\n'
      'Hashing image data without metadata/motion video, checking motion '
      'photo/GPS'
      '${big ? '\nLarge file, this may take a while' : ''}';
  @override
  String readFailed(String path, String msg) => 'Failed to read: $path ($msg)';
  @override
  String jpegSkipped(String path) => 'Cannot parse JPEG (skipped): $path';
  @override
  String logAnalyzed(int i, int n, String name, String label) =>
      '  [$i/$n] $name → $label';
  @override
  String get logStepImageCompare => '③ Searching identical photos per target';
  @override
  String get phaseImageCompare => '3/3 Comparing and cleaning up photos';
  @override
  String activityImageTarget(String name, String label) =>
      'Target: $name ($label)\nLooking for files with identical image data';
  @override
  String logTarget(String path) => '[Target] $path';
  @override
  String logSameImagesFound(int n) => '  $n file(s) with identical image data';
  @override
  String logSameImage(String path, String label) =>
      '  Same photo: $path ($label)';
  @override
  String logKeep(String path, String label) => '  Keeping: $path ($label)';
  @override
  String activityKeep(int count, String name, String label) =>
      'Choosing which of $count identical photos to keep: $name ($label)';
  @override
  String get warnGpsLost =>
      '  ⚠ The kept file has no GPS. GPS exists only in files being deleted.';
  @override
  String activityDeleting(String path) => 'Deleting duplicate: $path';
  @override
  String logDeleted(String path) => '    Deleted: $path';
  @override
  String logDeleteFailed(String path, String msg) =>
      '    Delete failed: $path ($msg)';
  @override
  String logImageDone(int jpegs, int deleted, String freed) =>
      'Done — $jpegs JPEGs, $deleted deleted, $freed freed';
  @override
  String sizeHint(String size, bool big) =>
      big ? ' ($size, large file, this may take a while)' : ' ($size)';
  @override
  String activityReadDir(String path, int dirs, int files) =>
      'Reading folder: $path\nSo far $dirs folders, $files files found';
  @override
  String dirReadFailed(String path, String msg) =>
      'Failed to read folder: $path ($msg)';
  @override
  String fileInfoFailed(String path, String msg) =>
      'Failed to read file info: $path ($msg)';
  @override
  String logSameNameFound(int n) =>
      '  $n file(s) with the same name → comparing';
  @override
  String logSameSizeFound(int n, String size) =>
      '  $n file(s) with the same size ($size) → comparing';
  @override
  String logCompare(String path) => '  Compare: $path';
  @override
  String logSizeDiffers(String a, String b) =>
      '    Size differs ($a ≠ $b) → different file';
  @override
  String get logPartialDiffers =>
      '    Partial checksum differs → different file';
  @override
  String get logPartialSame => '    Partial checksum matches → full compare';
  @override
  String logChecksumTarget(String c) => '    checksum target: $c';
  @override
  String logChecksumOther(String c) => '    checksum other:  $c';
  @override
  String get logChecksumDiffers => '    checksum differs → different file';
  @override
  String checksumFailed(String msg) => '    checksum failed ($msg)';
  @override
  String get logIdentical => '    Identical file!';
  @override
  String activityChecksum(String name, String hint) =>
      'Calculating checksum (reading whole file): $name$hint';
  @override
  String activityPartial(String name) =>
      'Calculating partial checksum (first 64KB only): $name';

  @override
  String deleteModeLabel(DeleteMode mode) => switch (mode) {
    DeleteMode.manual => 'Manual delete',
    DeleteMode.auto => 'Auto delete',
  };
  @override
  String get findDuplicates => 'Find duplicates';
  @override
  String get autoDeleteWarning =>
      '⚠ Auto delete mode permanently deletes duplicates immediately without '
      'confirmation. Deleted files are not moved to a trash and cannot be '
      'recovered. You are responsible for any file loss caused by deletion.';
  @override
  String get autoDeleteAck =>
      'I understand the above and have backed up my important files.';
  @override
  String get disclaimerTitle => 'Warnings & Disclaimer';
  @override
  String get disclaimerIntro =>
      'Please read the following before using this app.';
  @override
  List<String> get disclaimerItems => const [
    'This app deletes files in the folders you select. With the "Move to trash" method, files can be restored for 30 days; after the retention period, after emptying the trash, or with the "Delete permanently" method, they cannot be recovered.',
    'Trashed files are kept in the ".DuplicateRemoverTrash" folder on your device storage and continue to use space. This folder may remain on the device even after the app is uninstalled.',
    'Duplicate detection is automatic and based on file name, size, checksum (MD5) and image data comparison. The possibility of misjudgment cannot be completely ruled out.',
    'Before use, always back up important files (photos, videos, documents, etc.) to a separate location.',
    'You are solely responsible for choosing which files to delete and for executing deletion. Auto delete mode deletes immediately without confirmation.',
    'Deleting files in system folders or folders used by other apps may cause those apps or the device to malfunction.',
    'To the maximum extent permitted by applicable law, the developer is not liable for any file loss, data corruption, or other direct or indirect damages arising from the use of, or inability to use, this app.',
    'This app uses the "All files access" permission to scan and delete files. File information is processed only on your device and is never transmitted.',
  ];
  @override
  String get disclaimerAgreeCheck =>
      'I have read and understood all of the above and agree to it.';
  @override
  String get disclaimerAgree => 'Agree and start';
  @override
  String get disclaimerDecline => 'Decline (exit)';
  @override
  String get logAddedToReview => '    → Added to review list (not deleted)';

  @override
  String statFound(int n) => 'Duplicates $n';
  @override
  String reviewButton(int groups) => 'Review & delete ($groups groups)';
  @override
  String finishedManualDetail(int found, String size) =>
      '$found duplicate files ($size) found — choose files to delete on the review screen.';
  @override
  String get noDuplicatesFound => 'No duplicate files found.';

  @override
  String get reviewTitle => 'Review duplicates';
  @override
  String reviewSummary(int groups, int files, String size) =>
      '$groups groups · $files selected for deletion ($size)';
  @override
  String get selectRecommended => 'Select recommended';
  @override
  String get clearSelection => 'Clear selection';
  @override
  String get keepRecommended => 'Keep (recommended)';
  @override
  String get willDelete => 'Delete';
  @override
  String get willKeep => 'Keep';
  @override
  String deleteSelected(int n, String size) => 'Delete $n selected ($size)';
  @override
  String get mustKeepOne => 'You must keep at least one file in each group.';
  @override
  String get deleteConfirmTitle => 'Delete files';
  @override
  String deleteConfirmBody(int n, String size) =>
      '$n selected files ($size) will be permanently deleted.\nDeleted files cannot be recovered.';
  @override
  String get delete => 'Delete';
  @override
  String deleting(int done, int total) => 'Deleting… $done / $total';
  @override
  String deleteResult(int ok, int failed) =>
      failed == 0 ? 'Deleted $ok files.' : 'Deleted $ok files, $failed failed.';
  @override
  String groupTitle(int index, int count, String size) =>
      'Group $index · $count files · $size total';
  @override
  String get compareTitle => 'Compare files';
  @override
  String get sameContentNote =>
      'Files in this group have identical content by the selected criteria. Compare location, name and modified date to choose which to keep.';
  @override
  String get folderLabel => 'Folder';
  @override
  String get fileNameField => 'Name';
  @override
  String get sizeLabel => 'Size';
  @override
  String get modifiedLabel => 'Modified';
  @override
  String get typeLabel => 'Type';
  @override
  String get previewUnavailable => 'Preview is not available for this file.';
  @override
  String get textPreviewTruncated => '… (showing beginning only)';
  @override
  String get reviewEmpty => 'No duplicates to review.';
  @override
  String get fileMissing => 'File does not exist.';
  @override
  String get tapToEnlarge => 'Tap to enlarge';

  @override
  String get deleteMethodSection => 'Deletion method';
  @override
  String deleteMethodLabel(DeleteMethod m) => switch (m) {
    DeleteMethod.trash => 'Move to trash (recommended)',
    DeleteMethod.permanent => 'Delete permanently',
  };
  @override
  String deleteMethodHint(DeleteMethod m) => switch (m) {
    DeleteMethod.trash => 'Deleted files are kept for 30 days and can be restored. Space is freed only after emptying the trash or after 30 days.',
    DeleteMethod.permanent =>
      'Deleted files are removed immediately and cannot be recovered.',
  };
  @override
  String get trashTitle => 'Trash';
  @override
  String get openTrash => 'Open trash';
  @override
  String get trashEmpty => 'Trash is empty.';
  @override
  String get trashInfo =>
      'Files in the trash are permanently deleted automatically after 30 days.';
  @override
  String trashSummary(int n, String size) => '$n files · $size used';
  @override
  String get restore => 'Restore';
  @override
  String get deleteForever => 'Delete forever';
  @override
  String get emptyTrash => 'Empty trash';
  @override
  String get selectAll => 'Select all';
  @override
  String emptyTrashConfirm(int n, String size) =>
      'All $n files ($size) in the trash will be permanently deleted.\nDeleted files cannot be recovered.';
  @override
  String deleteForeverConfirm(int n, String size) =>
      '$n selected files ($size) will be permanently deleted.\nDeleted files cannot be recovered.';
  @override
  String restored(int n) => 'Restored $n files to their original location.';
  @override
  String trashedAt(String date) => 'Deleted $date';
  @override
  String daysLeft(int days) =>
      days == 0 ? 'Deleting soon' : 'Deleted forever in $days days';
  @override
  String get originalLocation => 'Original location';
  @override
  String purged(int n) =>
      'Permanently deleted $n files older than 30 days from the trash.';
  @override
  String logTrashed(String path) => '    Moved to trash: $path';
  @override
  String activityTrashing(String path) => 'Moving to trash: $path';
  @override
  String statTrashed(int n) => 'Trashed $n';
  @override
  String finishedTrashDetail(int n, String size) =>
      'Moved $n files ($size) to the trash — they can be restored for 30 days.';
  @override
  String get autoTrashWarning =>
      '⚠ Auto delete mode moves duplicates to the trash immediately without '
      'confirmation. Files in the trash are permanently deleted after 30 days '
      'and cannot be recovered after that.';
  @override
  String moveToTrashSelected(int n, String size) =>
      'Move $n selected to trash ($size)';
  @override
  String get trashConfirmTitle => 'Move to trash';
  @override
  String trashConfirmBody(int n, String size) =>
      '$n selected files ($size) will be moved to the trash.\nThey can be restored from the trash for 30 days.';
  @override
  String trashing(int done, int total) => 'Moving to trash… $done / $total';
  @override
  String trashResult(int ok, int failed) => failed == 0
      ? 'Moved $ok files to the trash.'
      : 'Moved $ok files to the trash, $failed failed.';
}
