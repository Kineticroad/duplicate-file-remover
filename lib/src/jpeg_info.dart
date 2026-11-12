import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// JPEG 분석 결과.
class JpegInfo {
  const JpegInfo({
    required this.imageHash,
    required this.isMotionPhoto,
    required this.hasGps,
  });

  /// 메타데이터(APPn/COM 세그먼트)와 EOI 이후 데이터(모션 포토 동영상 등)를 제외한
  /// 순수 사진 데이터의 MD5.
  final String imageHash;

  /// EOI 뒤에 MP4 동영상이 붙어 있는 모션 포토인지.
  final bool isMotionPhoto;

  /// EXIF 에 GPS 위도 정보가 있는지.
  final bool hasGps;

  /// 남길 파일 우선순위 점수: 모션 포토(2) > GPS(1) > 일반(0).
  int get priority => (isMotionPhoto ? 2 : 0) + (hasGps ? 1 : 0);
}

bool isJpegPath(String path) {
  final lower = path.toLowerCase();
  return lower.endsWith('.jpg') || lower.endsWith('.jpeg');
}

/// JPEG 바이트를 분석한다. JPEG 이 아니거나 구조가 깨졌으면 null.
JpegInfo? analyzeJpeg(Uint8List b) {
  if (b.length < 4 || b[0] != 0xFF || b[1] != 0xD8) return null;

  Digest? digest;
  final sink = md5.startChunkedConversion(
    ChunkedConversionSink<Digest>.withCallback((d) => digest = d.single),
  );
  sink.add(const [0xFF, 0xD8]);

  var hasGps = false;
  int? eoiEnd;
  var pos = 2;

  while (pos + 1 < b.length) {
    if (b[pos] != 0xFF) return null;
    final marker = b[pos + 1];
    if (marker == 0xFF) {
      pos++; // fill byte
      continue;
    }
    if (marker == 0xD9) {
      // EOI: 사진 데이터 끝.
      sink.add(const [0xFF, 0xD9]);
      eoiEnd = pos + 2;
      break;
    }
    if ((marker >= 0xD0 && marker <= 0xD7) || marker == 0x01) {
      sink.add(Uint8List.sublistView(b, pos, pos + 2));
      pos += 2;
      continue;
    }
    if (pos + 3 >= b.length) return null;
    final len = (b[pos + 2] << 8) | b[pos + 3];
    final end = pos + 2 + len;
    if (len < 2 || end > b.length) return null;

    final isMetadata = (marker >= 0xE0 && marker <= 0xEF) || marker == 0xFE;
    if (isMetadata) {
      // APP1 EXIF 에서 GPS 여부만 확인하고 해시에서는 제외.
      if (marker == 0xE1 && _startsWith(b, pos + 4, _exifHeader)) {
        hasGps = hasGps || _exifHasGps(b, pos + 4 + _exifHeader.length, end);
      }
    } else {
      sink.add(Uint8List.sublistView(b, pos, end));
    }
    pos = end;

    if (marker == 0xDA) {
      // SOS 이후 엔트로피 코딩 데이터: 다음 마커(FF00, RSTn 제외)까지.
      var i = pos;
      while (i + 1 < b.length) {
        if (b[i] == 0xFF) {
          final n = b[i + 1];
          if (n != 0x00 && !(n >= 0xD0 && n <= 0xD7)) break;
        }
        i++;
      }
      sink.add(Uint8List.sublistView(b, pos, i));
      pos = i;
    }
  }

  if (eoiEnd == null) return null; // 잘린 파일
  sink.close();

  return JpegInfo(
    imageHash: digest.toString(),
    isMotionPhoto: _hasMp4After(b, eoiEnd),
    hasGps: hasGps,
  );
}

const _exifHeader = [0x45, 0x78, 0x69, 0x66, 0x00, 0x00]; // "Exif\0\0"
const _ftyp = [0x66, 0x74, 0x79, 0x70]; // "ftyp"

bool _startsWith(Uint8List b, int at, List<int> prefix) {
  if (at + prefix.length > b.length) return false;
  for (var i = 0; i < prefix.length; i++) {
    if (b[at + i] != prefix[i]) return false;
  }
  return true;
}

/// EOI 뒤에 MP4 박스("\0\0??ftyp")가 있으면 모션 포토로 판단.
/// (Google/삼성 모션 포토 모두 JPEG 뒤에 MP4 를 붙인다.)
bool _hasMp4After(Uint8List b, int from) {
  for (var i = from + 4; i + 4 <= b.length; i++) {
    if (b[i] == 0x66 &&
        _startsWith(b, i, _ftyp) &&
        b[i - 4] == 0 &&
        b[i - 3] == 0) {
      return true;
    }
  }
  return false;
}

/// EXIF(TIFF) 의 IFD0 → GPS IFD 에 GPSLatitude(0x0002) 태그가 있는지.
bool _exifHasGps(Uint8List b, int tiff, int end) {
  try {
    final le = b[tiff] == 0x49; // "II" little endian, "MM" big endian
    int u16(int o) {
      final p = tiff + o;
      if (p + 2 > end) throw RangeError('out of segment');
      return le ? b[p] | (b[p + 1] << 8) : (b[p] << 8) | b[p + 1];
    }

    int u32(int o) =>
        le ? u16(o) | (u16(o + 2) << 16) : (u16(o) << 16) | u16(o + 2);

    int? findTag(int ifd, int tag) {
      final count = u16(ifd);
      for (var i = 0; i < count; i++) {
        final entry = ifd + 2 + i * 12;
        if (u16(entry) == tag) return entry;
      }
      return null;
    }

    final gpsEntry = findTag(u32(4), 0x8825);
    if (gpsEntry == null) return false;
    return findTag(u32(gpsEntry + 8), 0x0002) != null;
  } catch (_) {
    return false;
  }
}
