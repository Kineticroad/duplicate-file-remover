// 앱 아이콘/스플래시 원본 PNG 생성기.
//
// 실행: flutter test tool/render_icons_test.dart
// 결과: assets/icon/*.png, assets/splash/*.png
// 그 후: dart run flutter_launcher_icons && dart run flutter_native_splash:create
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const brandDark = Color(0xFF283593);
const brand = Color(0xFF3949AB);
const brandLight = Color(0xFF5C6BC0);
const photoBg = Color(0xFFC5CAE9);
const sun = Color(0xFFFFCA28);
const badge = Color(0xFFFF7043);

/// 겹친 사진 카드 2장 + 삭제(−) 배지.
/// [scale] 은 캔버스 대비 그림 크기 (적응형 아이콘 안전 영역을 맞추기 위함).
void paintLogo(Canvas canvas, double size, {double scale = 1}) {
  final s = size * scale;
  canvas.save();
  canvas.translate(size / 2, size / 2);

  final cardW = 0.34 * s, cardH = 0.40 * s, r = Radius.circular(0.045 * s);
  final shadow = Paint()
    ..color = Colors.black.withValues(alpha: 0.18)
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, 0.02 * s);

  // 뒤쪽 카드 (복제본)
  canvas.save();
  canvas.translate(-0.07 * s, -0.06 * s);
  canvas.rotate(-10 * math.pi / 180);
  final back = RRect.fromRectAndRadius(
    Rect.fromCenter(center: Offset.zero, width: cardW, height: cardH),
    r,
  );
  canvas.drawRRect(back.shift(Offset(0, 0.012 * s)), shadow);
  canvas.drawRRect(back, Paint()..color = Colors.white.withValues(alpha: 0.55));
  canvas.restore();

  // 앞쪽 카드 (원본)
  canvas.save();
  canvas.translate(0.05 * s, 0.04 * s);
  canvas.rotate(4 * math.pi / 180);
  final front = RRect.fromRectAndRadius(
    Rect.fromCenter(center: Offset.zero, width: cardW, height: cardH),
    r,
  );
  canvas.drawRRect(front.shift(Offset(0, 0.015 * s)), shadow);
  canvas.drawRRect(front, Paint()..color = Colors.white);

  // 사진 영역
  final inset = 0.028 * s;
  final photo = Rect.fromLTRB(
    -cardW / 2 + inset,
    -cardH / 2 + inset,
    cardW / 2 - inset,
    cardH / 2 - inset - 0.05 * s,
  );
  canvas.save();
  canvas.clipRRect(RRect.fromRectAndRadius(photo, Radius.circular(0.02 * s)));
  canvas.drawRect(photo, Paint()..color = photoBg);
  canvas.drawCircle(
    Offset(photo.right - 0.07 * s, photo.top + 0.07 * s),
    0.035 * s,
    Paint()..color = sun,
  );
  final m1 = Path()
    ..moveTo(photo.left - 0.02 * s, photo.bottom)
    ..lineTo(photo.left + 0.10 * s, photo.top + 0.11 * s)
    ..lineTo(photo.left + 0.22 * s, photo.bottom)
    ..close();
  final m2 = Path()
    ..moveTo(photo.left + 0.10 * s, photo.bottom)
    ..lineTo(photo.left + 0.21 * s, photo.top + 0.16 * s)
    ..lineTo(photo.right + 0.04 * s, photo.bottom)
    ..close();
  canvas.drawPath(m1, Paint()..color = brandLight);
  canvas.drawPath(m2, Paint()..color = brand);
  canvas.restore();

  // 배지 (−)
  final badgeCenter = Offset(cardW / 2 - 0.01 * s, cardH / 2 - 0.02 * s);
  final badgeR = 0.085 * s;
  canvas.drawCircle(badgeCenter.translate(0, 0.01 * s), badgeR, shadow);
  canvas.drawCircle(badgeCenter, badgeR, Paint()..color = badge);
  canvas.drawCircle(
    badgeCenter,
    badgeR,
    Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.014 * s,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: badgeCenter,
        width: badgeR * 1.0,
        height: badgeR * 0.26,
      ),
      Radius.circular(badgeR * 0.13),
    ),
    Paint()..color = Colors.white,
  );
  canvas.restore();

  canvas.restore();
}

void paintBackground(Canvas canvas, double size) {
  final rect = Rect.fromLTWH(0, 0, size, size);
  canvas.drawRect(
    rect,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [brandLight, brandDark],
      ).createShader(rect),
  );
}

Future<void> render(
  String path,
  int size,
  void Function(Canvas canvas, double size) paint,
) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  paint(canvas, size.toDouble());
  final image = await recorder.endRecording().toImage(size, size);
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(png!.buffer.asUint8List());
}

void main() {
  testWidgets('render icons', (tester) async {
    await tester.runAsync(() async {
      // 일반 아이콘 (구형 런처, 플레이 스토어 512px 원본 겸용)
      await render('assets/icon/icon.png', 1024, (c, s) {
        paintBackground(c, s);
        paintLogo(c, s, scale: 1.05);
      });
      // 적응형 아이콘 전경: flutter_launcher_icons 가 16% 여백(inset)을 추가하므로
      // 일반 아이콘과 같은 크기로 그린다. (결과적으로 안전 영역 지름 66/108 안)
      await render(
        'assets/icon/icon_foreground.png',
        1024,
        (c, s) => paintLogo(c, s, scale: 1.05),
      );
      // 플레이 스토어용 512px
      await render('assets/icon/play_store_512.png', 512, (c, s) {
        paintBackground(c, s);
        paintLogo(c, s, scale: 1.05);
      });
      // 스플래시 로고 (Android 12: 1152px, 지름 768 원 안)
      await render(
        'assets/splash/splash_logo.png',
        1152,
        (c, s) => paintLogo(c, s, scale: 0.78),
      );
    });
  });
}
