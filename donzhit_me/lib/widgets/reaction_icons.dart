import 'package:flutter/material.dart';

/// Custom angry car icon - car front view with angry face
class AngryCarIcon extends StatelessWidget {
  final double size;
  final Color color;
  final bool filled;

  const AngryCarIcon({
    super.key,
    this.size = 24,
    this.color = Colors.grey,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _AngryCarPainter(color: color, filled: filled),
    );
  }
}

class _AngryCarPainter extends CustomPainter {
  final Color color;
  final bool filled;

  _AngryCarPainter({required this.color, required this.filled});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = filled ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = size.width * 0.08
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;

    // Car body (front view) - rounded rectangle
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.1, h * 0.35, w * 0.8, h * 0.5),
      Radius.circular(w * 0.1),
    );
    canvas.drawRRect(bodyRect, paint);

    // Car roof/top
    final roofRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.2, h * 0.15, w * 0.6, h * 0.25),
      Radius.circular(w * 0.08),
    );
    canvas.drawRRect(roofRect, paint);

    // Wheels
    final wheelPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(w * 0.2, h * 0.85), w * 0.1, wheelPaint);
    canvas.drawCircle(Offset(w * 0.8, h * 0.85), w * 0.1, wheelPaint);

    // Angry eyes (on windshield area)
    final eyePaint = Paint()
      ..color = filled ? Colors.white : color
      ..style = PaintingStyle.fill;

    // Left angry eye (slanted)
    final leftEyePath = Path()
      ..moveTo(w * 0.25, h * 0.45)
      ..lineTo(w * 0.4, h * 0.4)
      ..lineTo(w * 0.4, h * 0.5)
      ..lineTo(w * 0.25, h * 0.5)
      ..close();
    canvas.drawPath(leftEyePath, eyePaint);

    // Right angry eye (slanted opposite)
    final rightEyePath = Path()
      ..moveTo(w * 0.75, h * 0.45)
      ..lineTo(w * 0.6, h * 0.4)
      ..lineTo(w * 0.6, h * 0.5)
      ..lineTo(w * 0.75, h * 0.5)
      ..close();
    canvas.drawPath(rightEyePath, eyePaint);

    // Angry mouth (grille area) - frowning
    final mouthPaint = Paint()
      ..color = filled ? Colors.white : color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.06
      ..strokeCap = StrokeCap.round;

    final mouthPath = Path()
      ..moveTo(w * 0.3, h * 0.7)
      ..quadraticBezierTo(w * 0.5, h * 0.6, w * 0.7, h * 0.7);
    canvas.drawPath(mouthPath, mouthPaint);
  }

  @override
  bool shouldRepaint(covariant _AngryCarPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.filled != filled;
  }
}

/// Custom angry face icon - just an angry face (for pedestrian reaction)
class AngryPedestrianIcon extends StatelessWidget {
  final double size;
  final Color color;
  final bool filled;

  const AngryPedestrianIcon({
    super.key,
    this.size = 24,
    this.color = Colors.grey,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _AngryPedestrianPainter(color: color, filled: filled),
    );
  }
}

class _AngryPedestrianPainter extends CustomPainter {
  final Color color;
  final bool filled;

  _AngryPedestrianPainter({required this.color, required this.filled});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = filled ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = size.width * 0.08
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;

    // Large centered angry face circle
    final faceCenterX = w * 0.5;
    final faceCenterY = h * 0.5;
    final faceRadius = w * 0.4;

    canvas.drawCircle(Offset(faceCenterX, faceCenterY), faceRadius, paint);

    // Angry face details
    final facePaint = Paint()
      ..color = filled ? Colors.white : color
      ..style = PaintingStyle.fill;

    // Left angry eye (slanted)
    final leftEyePath = Path()
      ..moveTo(faceCenterX - w * 0.22, faceCenterY - h * 0.08)
      ..lineTo(faceCenterX - w * 0.06, faceCenterY - h * 0.16)
      ..lineTo(faceCenterX - w * 0.06, faceCenterY - h * 0.02)
      ..lineTo(faceCenterX - w * 0.22, faceCenterY - h * 0.02)
      ..close();
    canvas.drawPath(leftEyePath, facePaint);

    // Right angry eye (slanted opposite)
    final rightEyePath = Path()
      ..moveTo(faceCenterX + w * 0.22, faceCenterY - h * 0.08)
      ..lineTo(faceCenterX + w * 0.06, faceCenterY - h * 0.16)
      ..lineTo(faceCenterX + w * 0.06, faceCenterY - h * 0.02)
      ..lineTo(faceCenterX + w * 0.22, faceCenterY - h * 0.02)
      ..close();
    canvas.drawPath(rightEyePath, facePaint);

    // Angry frowning mouth
    final mouthPaint = Paint()
      ..color = filled ? Colors.white : color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.06
      ..strokeCap = StrokeCap.round;

    final mouthPath = Path()
      ..moveTo(faceCenterX - w * 0.18, faceCenterY + h * 0.2)
      ..quadraticBezierTo(faceCenterX, faceCenterY + h * 0.1, faceCenterX + w * 0.18, faceCenterY + h * 0.2);
    canvas.drawPath(mouthPath, mouthPaint);
  }

  @override
  bool shouldRepaint(covariant _AngryPedestrianPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.filled != filled;
  }
}

/// Custom angry bicycle icon - side view bike with angry face on frame
class AngryBicycleIcon extends StatelessWidget {
  final double size;
  final Color color;
  final bool filled;

  const AngryBicycleIcon({
    super.key,
    this.size = 24,
    this.color = Colors.grey,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _AngryBicyclePainter(color: color, filled: filled),
    );
  }
}

class _AngryBicyclePainter extends CustomPainter {
  final Color color;
  final bool filled;

  _AngryBicyclePainter({required this.color, required this.filled});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.06
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;

    // Back wheel
    canvas.drawCircle(Offset(w * 0.2, h * 0.72), w * 0.17, paint);

    // Front wheel
    canvas.drawCircle(Offset(w * 0.8, h * 0.72), w * 0.17, paint);

    // Frame - seat tube (from bottom bracket up)
    canvas.drawLine(Offset(w * 0.45, h * 0.72), Offset(w * 0.38, h * 0.38), paint);

    // Frame - top tube (seat to head tube)
    canvas.drawLine(Offset(w * 0.38, h * 0.38), Offset(w * 0.68, h * 0.35), paint);

    // Frame - down tube (bottom bracket to head tube)
    canvas.drawLine(Offset(w * 0.45, h * 0.72), Offset(w * 0.68, h * 0.45), paint);

    // Frame - chain stay (bottom bracket to rear wheel)
    canvas.drawLine(Offset(w * 0.45, h * 0.72), Offset(w * 0.2, h * 0.72), paint);

    // Frame - seat stay (seat tube to rear wheel)
    canvas.drawLine(Offset(w * 0.38, h * 0.45), Offset(w * 0.2, h * 0.72), paint);

    // Head tube area (where face will be) - make it a filled circle for face
    // Face is 3x larger and repositioned to be more prominent
    final faceCenterX = w * 0.5;
    final faceCenterY = h * 0.35;
    final faceRadius = w * 0.35;

    if (filled) {
      final faceFillPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(faceCenterX, faceCenterY), faceRadius, faceFillPaint);
    } else {
      canvas.drawCircle(Offset(faceCenterX, faceCenterY), faceRadius, paint);
    }

    // Fork (head tube to front wheel)
    canvas.drawLine(Offset(w * 0.72, h * 0.55), Offset(w * 0.8, h * 0.72), paint);

    // Handlebar
    canvas.drawLine(Offset(w * 0.65, h * 0.25), Offset(w * 0.8, h * 0.28), paint);

    // Stem
    canvas.drawLine(Offset(w * 0.72, h * 0.28), Offset(w * 0.72, h * 0.35), paint);

    // Angry face on the head tube circle - 3x larger features
    final facePaint = Paint()
      ..color = filled ? Colors.white : color
      ..style = PaintingStyle.fill;

    // Left angry eye (slanted) - 3x larger
    final leftEyePath = Path()
      ..moveTo(faceCenterX - w * 0.22, faceCenterY - h * 0.04)
      ..lineTo(faceCenterX - w * 0.06, faceCenterY - h * 0.12)
      ..lineTo(faceCenterX - w * 0.06, faceCenterY + h * 0.02)
      ..lineTo(faceCenterX - w * 0.22, faceCenterY + h * 0.02)
      ..close();
    canvas.drawPath(leftEyePath, facePaint);

    // Right angry eye (slanted opposite) - 3x larger
    final rightEyePath = Path()
      ..moveTo(faceCenterX + w * 0.22, faceCenterY - h * 0.04)
      ..lineTo(faceCenterX + w * 0.06, faceCenterY - h * 0.12)
      ..lineTo(faceCenterX + w * 0.06, faceCenterY + h * 0.02)
      ..lineTo(faceCenterX + w * 0.22, faceCenterY + h * 0.02)
      ..close();
    canvas.drawPath(rightEyePath, facePaint);

    // Angry frowning mouth - 3x larger
    final mouthPaint = Paint()
      ..color = filled ? Colors.white : color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.08
      ..strokeCap = StrokeCap.round;

    final mouthPath = Path()
      ..moveTo(faceCenterX - w * 0.18, faceCenterY + h * 0.18)
      ..quadraticBezierTo(faceCenterX, faceCenterY + h * 0.10, faceCenterX + w * 0.18, faceCenterY + h * 0.18);
    canvas.drawPath(mouthPath, mouthPaint);
  }

  @override
  bool shouldRepaint(covariant _AngryBicyclePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.filled != filled;
  }
}
