import 'dart:io';
import 'dart:typed_data';

import 'package:duplicate_file_remover/src/duplicate_scanner.dart';
import 'package:duplicate_file_remover/src/jpeg_info.dart';
import 'package:flutter_test/flutter_test.dart';

/// 테스트용 JPEG 생성. 구조(마커/세그먼트)만 흉내 낸다.
Uint8List makeJpeg({
  List<int> pixels = const [1, 2, 3],
  bool gps = false,
  bool motion = false,
  String comment = '',
}) {
  final out = BytesBuilder();
  void segment(int marker, List<int> body) {
    final len = body.length + 2;
    out.add([0xFF, marker, len >> 8, len & 0xFF, ...body]);
  }

  out.add([0xFF, 0xD8]); // SOI

  // APP1 EXIF (little endian TIFF)
  final tiff = <int>[0x49, 0x49, 0x2A, 0x00, 8, 0, 0, 0];
  if (gps) {
    tiff.addAll([1, 0, 0x25, 0x88, 4, 0, 1, 0, 0, 0, 26, 0, 0, 0, 0, 0, 0, 0]);
    tiff.addAll([1, 0, 0x02, 0x00, 5, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]);
  } else {
    tiff.addAll([0, 0, 0, 0, 0, 0]);
  }
  segment(0xE1, [...'Exif'.codeUnits, 0, 0, ...tiff]);
  if (comment.isNotEmpty) segment(0xFE, comment.codeUnits); // COM
  segment(0xDB, [0, ...List.filled(8, 7)]); // DQT
  segment(0xDA, [1, 1, 0, 0, 63, 0]); // SOS header
  out.add([...pixels, 0xFF, 0x00, 9]); // 엔트로피 데이터 (FF00 stuffing 포함)
  out.add([0xFF, 0xD9]); // EOI
  if (motion) {
    out.add([...'MotionPhoto_Data'.codeUnits]);
    out.add([0, 0, 0, 0x18, ...'ftyp'.codeUnits, ...'mp42'.codeUnits]);
    out.add(List.filled(100, 5));
  }
  return out.toBytes();
}

void main() {
  group('analyzeJpeg', () {
    test('메타데이터·모션 동영상이 달라도 사진 해시는 같음', () {
      final plain = analyzeJpeg(makeJpeg())!;
      final full = analyzeJpeg(
        makeJpeg(gps: true, motion: true, comment: 'x'),
      )!;
      expect(full.imageHash, plain.imageHash);
      expect(plain.isMotionPhoto || plain.hasGps, isFalse);
      expect(full.isMotionPhoto && full.hasGps, isTrue);
      expect(full.priority, greaterThan(plain.priority));
    });

    test('사진 데이터가 다르면 해시가 다름', () {
      expect(
        analyzeJpeg(makeJpeg(pixels: [1]))!.imageHash,
        isNot(analyzeJpeg(makeJpeg(pixels: [2]))!.imageHash),
      );
    });

    test('JPEG 이 아니거나 잘린 파일은 null', () {
      expect(analyzeJpeg(Uint8List.fromList([1, 2, 3, 4])), isNull);
      final jpeg = makeJpeg();
      expect(
        analyzeJpeg(Uint8List.sublistView(jpeg, 0, jpeg.length - 2)),
        isNull,
      );
    });
  });

  group('사진 기준 스캔', () {
    late Directory root;
    setUp(() => root = Directory.systemTemp.createTempSync('img_test_'));
    tearDown(() => root.deleteSync(recursive: true));

    File write(String rel, Uint8List bytes) => File('${root.path}/$rel')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes);

    Future<ScanStats> scan() => DuplicateScanner(
      onEvent: (_) {},
      mode: MatchMode.image,
    ).scan(root.path);

    test('모션 포토 > GPS > 일반: 나중에 찾았어도 모션 포토를 남김', () async {
      final plain = write('a/IMG.jpg', makeJpeg());
      final gps = write('b/IMG_gps.jpg', makeJpeg(gps: true));
      final motion = write('c/MOTION.jpg', makeJpeg(motion: true));
      final stats = await scan();

      expect(motion.existsSync(), isTrue);
      expect(plain.existsSync() || gps.existsSync(), isFalse);
      expect(stats.deletedCount, 2);
    });

    test('일반 vs GPS: GPS 사진을 남김', () async {
      final plain = write('a/1.jpg', makeJpeg());
      final gps = write('b/2.JPEG', makeJpeg(gps: true));
      await scan();

      expect(gps.existsSync(), isTrue);
      expect(plain.existsSync(), isFalse);
    });

    test('우선순위가 같으면 대상(먼저 찾은) 파일을 남김', () async {
      final a = write('a/1.jpg', makeJpeg(comment: 'one'));
      final b = write('b/2.jpg', makeJpeg(comment: 'two'));
      await scan();

      expect(a.existsSync(), isTrue);
      expect(b.existsSync(), isFalse);
    });

    test('사진 데이터가 다르면 모두 유지, JPEG 이 아닌 파일은 무시', () async {
      final a = write('a/1.jpg', makeJpeg(pixels: [1]));
      final b = write('b/2.jpg', makeJpeg(pixels: [2]));
      final c = write('c/3.png', makeJpeg(pixels: [1]));
      final stats = await scan();

      expect([a, b, c].every((f) => f.existsSync()), isTrue);
      expect(stats.deletedCount, 0);
    });
  });
}
