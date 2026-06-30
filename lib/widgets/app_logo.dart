import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  final double size;
  final bool showGlow;
  final double glowValue;

  const AppLogo({
    super.key,
    required this.size,
    this.showGlow = false,
    this.glowValue = 20.0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Resolve colors dynamically based on active theme
    final logoBg = isDark ? const Color(0xFF101424) : const Color(0xFFFFFFFF);
    final borderColor = const Color(0xFF1BDCA0).withAlpha(isDark ? 100 : 75);
    final glowColor = const Color(0xFF1BDCA0).withAlpha(isDark ? 60 : 25);
    final outerGlowColor = const Color(0xFF1BDCA0).withAlpha(isDark ? 40 : 15);
    
    final innerPadding = size * (showGlow ? 0.20 : 0.18);

    final logoContent = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: logoBg,
        shape: BoxShape.circle,
        border: Border.all(
          color: borderColor,
          width: size * 0.02,
        ),
        boxShadow: showGlow
            ? [
                BoxShadow(
                  color: glowColor,
                  blurRadius: glowValue,
                ),
              ]
            : null,
      ),
      child: ClipOval(
        child: Padding(
          padding: EdgeInsets.all(innerPadding),
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFF1BDCA0),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: CustomPaint(
                size: Size(
                  (size - 2 * innerPadding) * 0.8,
                  (size - 2 * innerPadding) * 0.8,
                ),
                painter: BoltPainter(color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );

    if (showGlow) {
      final outerSize = size + (size * 0.27);
      return Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: outerSize,
            height: outerSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: outerGlowColor,
                  blurRadius: glowValue + 15,
                  spreadRadius: glowValue / 2,
                ),
              ],
            ),
          ),
          logoContent,
        ],
      );
    }

    return logoContent;
  }
}

class BoltPainter extends CustomPainter {
  final Color color;

  BoltPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    // Coordinates are on a 1024x1024 viewBox.
    // M 560 180 L 360 580 L 480 580 L 460 844 L 700 460 L 560 460 Z
    final double scaleX = size.width / 1024.0;
    final double scaleY = size.height / 1024.0;

    // Shift coordinates slightly to center the bolt path inside the local 1024x1024 bounding box.
    // The original path bounding box:
    // Left: 360, Right: 700 -> width = 340 (center is 530)
    // Top: 180, Bottom: 844 -> height = 664 (center is 512)
    // The center is perfectly aligned at 530, 512, which is very close to 512, 512.
    // Let's just scale directly.
    path.moveTo(560 * scaleX, 180 * scaleY);
    path.lineTo(360 * scaleX, 580 * scaleY);
    path.lineTo(480 * scaleX, 580 * scaleY);
    path.lineTo(460 * scaleX, 844 * scaleY);
    path.lineTo(700 * scaleX, 460 * scaleY);
    path.lineTo(560 * scaleX, 460 * scaleY);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
