import 'package:flutter/material.dart';

import '../theme/palette.dart';

/// Concept C "Keyhole Face": a watch whose centre is a keyhole.
/// Geometry is the same 108-unit adaptive-icon canvas used in Figma and in
/// the Android launcher vector (res/drawable/ic_launcher_foreground.xml).
class KeyholeGlyph extends StatelessWidget {
  const KeyholeGlyph({super.key, required this.size, this.color, this.tight = false});
  final double size;
  final Color? color;

  /// true = glyph fills the box (no launcher padding).
  final bool tight;

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size.square(size),
        painter: _KeyholePainter(color ?? SeasonColors.of(context).primary, tight),
      );
}

/// The app logo: season-coloured rounded tile with the keyhole glyph.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 112});
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = SeasonColors.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      width: size,
      height: size,
      decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(size * 0.32)),
      child: KeyholeGlyph(size: size, color: c.onPrimary),
    );
  }
}

class _KeyholePainter extends CustomPainter {
  _KeyholePainter(this.color, this.tight);
  final Color color;
  final bool tight;

  @override
  void paint(Canvas canvas, Size size) {
    // Visible region in glyph units: tight = 21..87 (+stroke), else the
    // launcher crop (72 units) with the glyph at 78 %.
    final view = tight ? 70.0 : 72 / 0.78;
    final s = size.width / view;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(s);
    canvas.translate(-54, -54);
    final fill = Paint()..color = color;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(45, 21, 18, 8), const Radius.circular(3)), fill);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(45, 79, 18, 8), const Radius.circular(3)), fill);
    canvas.drawCircle(const Offset(54, 54), 23, stroke);
    canvas.drawCircle(const Offset(54, 49), 7, fill);
    canvas.drawPath(
      Path()
        ..moveTo(50.5, 52)
        ..lineTo(47.5, 66)
        ..lineTo(60.5, 66)
        ..lineTo(57.5, 52)
        ..close(),
      fill,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_KeyholePainter old) => old.color != color || old.tight != tight;
}
