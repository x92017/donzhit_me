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

  const DonzHitLogoHorizontal({super.key, this.height = 72}); // 20% bigger (60 * 1.2)

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.only(left: 0, right: 12, top: 6, bottom: 6),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end, // Align to bottom
        children: [
          // Walking person on left - 25% bigger, less padding
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Icon(
              Icons.hiking,
              color: Colors.white,
              size: height * 0.625, // 25% bigger (0.5 * 1.25)
            ),
          ),
          // DonzHit.me text with car positioned over "onz"
          Stack(
            clipBehavior: Clip.none,
            children: [
              // DonzHit.me text - 15% bigger than before
              Text(
                'DonzHit.me',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: height * 0.316, // 15% bigger (0.275 * 1.15)
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              // Car on top, positioned over "onz"
              Positioned(
                top: -(height * 0.32),
                left: 16,
                child: Transform(
                  transform: Matrix4.identity()
                    ..scale(1.15, 0.85), // 15% wider, 15% flatter
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.directions_car,
                    color: Colors.white,
                    size: height * 0.49,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
