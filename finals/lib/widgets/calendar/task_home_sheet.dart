import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../constants/colors.dart';

class TaskHomeSheet extends StatelessWidget {
  const TaskHomeSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Drag handle ─────────────────────────────
        Center(
          child: Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 20),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.35),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),

        // ── Donut chart + stat legend ────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              // Unified donut — empty state
              SizedBox(
                width: 130,
                height: 130,
                child: CustomPaint(
                  painter: _UnifiedDonutPainter(
                    inProgress: 0,
                    notStarted: 0,
                    completed: 0,
                    total: 0,
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '0%',
                          style: TextStyle(
                            color: kNavyDark,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'No Tasks',
                          style: TextStyle(
                            color: Color(0xFF6B7A99),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 20),

              // Stat legend
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    _StatLegend(
                      color: Color(0xFF4A90D9),
                      label: 'In Progress',
                      count: 0,
                      total: 0,
                    ),
                    SizedBox(height: 14),
                    _StatLegend(
                      color: Color(0xFFB0BAD3),
                      label: 'Not Started',
                      count: 0,
                      total: 0,
                    ),
                    SizedBox(height: 14),
                    _StatLegend(
                      color: Color(0xFF3BBFA3),
                      label: 'Completed',
                      count: 0,
                      total: 0,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // ── Recent Tasks header ──────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Tasks',
                style: TextStyle(
                  color: kNavyDark,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              GestureDetector(
                onTap: () {},
                child: Row(
                  children: const [
                    Text('Sorted by',
                        style: TextStyle(
                            color: Color(0xFF6B7A99), fontSize: 13)),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_drop_down,
                        color: Color(0xFF6B7A99), size: 20),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 40),

        // ── Empty state ──────────────────────────────
        Center(
          child: Column(
            children: [
              Icon(Icons.task_alt_rounded,
                  size: 64, color: kNavyDark.withOpacity(0.1)),
              const SizedBox(height: 12),
              Text(
                'No tasks yet',
                style: TextStyle(
                  color: kNavyDark.withOpacity(0.4),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Tap + to add your first task',
                style: TextStyle(
                  color: kNavyDark.withOpacity(0.28),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 80),
      ],
    );
  }
}

// ── Unified donut painter (matches spaces_screen design) ──────
class _UnifiedDonutPainter extends CustomPainter {
  final int inProgress;
  final int notStarted;
  final int completed;
  final int total;

  const _UnifiedDonutPainter({
    required this.inProgress,
    required this.notStarted,
    required this.completed,
    required this.total,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 14;
    const stroke = 20.0;
    const pi = math.pi;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Grey track ring
    canvas.drawArc(
      rect, 0, 2 * pi, false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = const Color(0xFFEEEEEE),
    );

    // If no tasks, just show the grey ring
    if (total == 0) return;

    void arc(double start, double sweep, Color color) {
      if (sweep <= 0) return;
      canvas.drawArc(
        rect, start, sweep, false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..color = color,
      );
    }

    double start = -pi / 2;
    final ipSweep = 2 * pi * (inProgress / total);
    final nsSweep = 2 * pi * (notStarted / total);
    final cSweep  = 2 * pi * (completed / total);

    arc(start, ipSweep, const Color(0xFF4A90D9));
    start += ipSweep + 0.05;
    arc(start, nsSweep, const Color(0xFFB0BAD3));
    start += nsSweep + 0.05;
    arc(start, cSweep, const Color(0xFF3BBFA3));
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

// ── Stat legend row with mini progress bar ────────────────────
class _StatLegend extends StatelessWidget {
  final Color color;
  final String label;
  final int count;
  final int total;

  const _StatLegend({
    required this.color,
    required this.label,
    required this.count,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(label,
                    style: const TextStyle(
                        color: Color(0xFF6B7A99), fontSize: 11)),
              ],
            ),
            Text('$count',
                style: const TextStyle(
                    color: kNavyDark,
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: total > 0 ? count / total : 0,
            minHeight: 4,
            backgroundColor: const Color(0xFFEEEEEE),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}