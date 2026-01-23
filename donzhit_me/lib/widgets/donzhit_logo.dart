import 'package:flutter/material.dart';

/// Custom logo widget for DonzHit.me
/// Black background with:
/// - Woman walking with backpack (white) on left
/// - "DonzHit.me" text (red) in middle
/// - Car front (white) on top
class DonzHitLogo extends StatelessWidget {
  final double size;

  const DonzHitLogo({super.key, this.size = 120});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
      ),
      child: CustomPaint(
        size: Size(size, size),
        painter: _LogoPainter(),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Car icon at top
              Icon(
                Icons.directions_car,
                color: Colors.white,
                size: size * 0.25,
              ),
              const SizedBox(height: 4),
              // DonzHit.me text in red
              Text(
                'DonzHit.me',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: size * 0.12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              // Walking person icon at bottom
              Icon(
                Icons.hiking,
                color: Colors.white,
                size: size * 0.25,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Additional custom painting if needed
    // The main elements are handled by the child widgets
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Horizontal logo for header display
class DonzHitLogoHorizontal extends StatelessWidget {
  final double height;

  const DonzHitLogoHorizontal({super.key, this.height = 60});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Walking person on left
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.hiking,
                color: Colors.white,
                size: height * 0.5,
              ),
            ],
          ),
          const SizedBox(width: 8),
          // DonzHit.me text and car in middle
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Car on top
              Icon(
                Icons.directions_car,
                color: Colors.white,
                size: height * 0.35,
              ),
              // DonzHit.me text
              Text(
                'DonzHit.me',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: height * 0.22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
