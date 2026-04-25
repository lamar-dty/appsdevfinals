import 'package:flutter/material.dart';
import '../constants/colors.dart';

class DashboardAppBar extends StatelessWidget implements PreferredSizeWidget {
  const DashboardAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: kNavyDark,
      elevation: 0,
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      title: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // ── Hamburger (no IconButton, no clipping) ──
          GestureDetector(
            onTap: () {
              // TODO: open drawer
            },
            child: const _HamburgerIcon(),
          ),

          // ── Avatar ──────────────────────────────────
          GestureDetector(
            onTap: () {
              // TODO: open profile
            },
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kWhite,
                border: Border.all(color: kTeal, width: 2),
              ),
              child: ClipOval(
                child: Image.network(
                  'https://api.dicebear.com/7.x/bottts/png?seed=bunny',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.person,
                    color: kNavyDark,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }
}

class _HamburgerIcon extends StatelessWidget {
  const _HamburgerIcon();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 20,
      child: CustomPaint(
        painter: _HamburgerPainter(),
      ),
    );
  }
}

class _HamburgerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = kTeal
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    // Top line
    canvas.drawLine(Offset(0, 0), Offset(size.width, 0), paint);
    // Middle line
    canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), paint);
    // Bottom line
    canvas.drawLine(Offset(0, size.height), Offset(size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}