import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../constants/colors.dart';

// ─────────────────────────────────────────────────────────────
// Data models
// ─────────────────────────────────────────────────────────────
enum _ExpenseStatus { overdue, unpaid, paid, deducted }

class _Expense {
  final String name;
  final double amount;
  final String? savingNote;   // e.g. "Save ₱16.67 daily"
  final String dateRange;
  final _ExpenseStatus status;
  final IconData icon;
  final Color iconColor;

  const _Expense({
    required this.name,
    required this.amount,
    required this.dateRange,
    required this.status,
    required this.icon,
    required this.iconColor,
    this.savingNote,
  });
}

class _BudgetCategory {
  final String label;
  final double amount;
  final Color color;

  const _BudgetCategory({
    required this.label,
    required this.amount,
    required this.color,
  });
}

class _SavingsPoint {
  final String month;
  final double value;
  const _SavingsPoint(this.month, this.value);
}

class _HighPriorityBreakdown {
  final String label;
  final double amount;
  final Color color;
  const _HighPriorityBreakdown(this.label, this.amount, this.color);
}

// ─────────────────────────────────────────────────────────────
// Sample data (matching screenshot)
// ─────────────────────────────────────────────────────────────
const _kDailyAllowance = 0.0;
const _kSavings        = 0.0;
const _kMonthlyBudget  = 0.0;
const _kBudgetUsed     = 0.0;

const List<_BudgetCategory> _kBudgetCategories = [];

const List<_HighPriorityBreakdown> _kHighPriorityBreakdown = [];

final List<_SavingsPoint> _kSavingsHistory = [];

const List<_Expense> _kUpcoming   = [];
const List<_Expense> _kRecent     = [];
const List<_Expense> _kDeductions = [];

// ─────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  static const double _snapPeek = 0.20;
  static const double _snapHalf = 0.50;
  static const double _snapFull = 1.0;

  late DraggableScrollableController _sheetController;
  double _sheetSize = _snapPeek;

  @override
  void initState() {
    super.initState();
    _sheetController = DraggableScrollableController();
    _sheetController.addListener(() {
      if (mounted) setState(() => _sheetSize = _sheetController.size);
    });
  }

  @override
  void dispose() {
    _sheetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Stack(
      children: [
        // ── BACKGROUND ────────────────────────────────────────
        Positioned.fill(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Padding(
              padding: EdgeInsets.only(bottom: screenHeight * _sheetSize),
              child: const _WalletBackground(),
            ),
          ),
        ),

        // ── DRAGGABLE SHEET ───────────────────────────────────
        DraggableScrollableSheet(
          controller: _sheetController,
          initialChildSize: _snapPeek,
          minChildSize: _snapPeek,
          maxChildSize: _snapFull,
          snap: true,
          snapSizes: const [_snapPeek, _snapHalf, _snapFull],
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: kWhite,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 16,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                controller: scrollController,
                physics: const ClampingScrollPhysics(),
                child: const _WalletSheet(),
              ),
            );
          },
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Background: summary cards + bar chart + donut + savings graph
// ─────────────────────────────────────────────────────────────
class _WalletBackground extends StatelessWidget {
  const _WalletBackground();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Summary cards row ─────────────────────────────
          Row(
            children: [
              // Daily Allowance
              Expanded(
                child: _SummaryCard(
                  icon: Icons.credit_card_rounded,
                  iconColor: const Color(0xFF4A90D9),
                  title: 'Daily Allowance',
                  value: '₱${_kDailyAllowance.toStringAsFixed(2)}',
                  subtitle: 'Current Balance',
                ),
              ),
              const SizedBox(width: 8),
              // Savings
              Expanded(
                child: _SummaryCard(
                  icon: Icons.savings_rounded,
                  iconColor: const Color(0xFF3BBFA3),
                  title: 'Savings',
                  value: '₱${_kSavings.toStringAsFixed(2)}',
                  subtitle: 'Saved',
                ),
              ),
              const SizedBox(width: 8),
              // Monthly Budget
              Expanded(
                child: _SummaryCard(
                  icon: Icons.account_balance_wallet_rounded,
                  iconColor: const Color(0xFF9B88E8),
                  title: 'Monthly Budget',
                  value: '₱${_kMonthlyBudget.toStringAsFixed(2)}',
                  subtitle: null,
                  showProgress: true,
                  progressValue: _kBudgetUsed,
                  progressLabel: '${(_kBudgetUsed * 100).round()}% Used',
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── Budget Allocation bar chart ───────────────────
          _SectionCard(
            title: 'Budget Allocation',
            action: 'Edit',
            child: _kBudgetCategories.isEmpty
                ? _EmptyState(
                    icon: Icons.bar_chart_rounded,
                    message: 'No budget set yet',
                  )
                : _BarChart(categories: _kBudgetCategories),
          ),

          const SizedBox(height: 16),

          // ── High Priority breakdown donut ─────────────────
          _SectionCard(
            title: 'High Priority Expenses Breakdown',
            child: _HighPrioritySection(items: _kHighPriorityBreakdown),
          ),

          const SizedBox(height: 16),

          // ── Savings overview line graph ───────────────────
          _SectionCard(
            title: 'Savings Overview',
            child: _EmptyState(
              icon: Icons.show_chart_rounded,
              message: 'No savings recorded yet',
            ),
          ),

          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Sheet: Upcoming / Recent / Savings Deduction
// ─────────────────────────────────────────────────────────────
class _WalletSheet extends StatelessWidget {
  const _WalletSheet();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Drag handle
        Center(
          child: Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 20),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),

        // Upcoming Expenses
        _SheetSectionHeader(title: 'Upcoming Expenses', onSort: () {}),
        const SizedBox(height: 8),
        _kUpcoming.isEmpty
            ? _SheetEmptyState(
                icon: Icons.event_available_rounded,
                message: 'No upcoming expenses',
              )
            : Column(children: _kUpcoming.map((e) => _ExpenseItem(expense: e)).toList()),

        const SizedBox(height: 20),

        // Recent Expenses
        _SheetSectionHeader(title: 'Recent Expenses', onSort: () {}),
        const SizedBox(height: 8),
        _kRecent.isEmpty
            ? _SheetEmptyState(
                icon: Icons.receipt_long_rounded,
                message: 'No recent expenses',
              )
            : Column(children: _kRecent.map((e) => _ExpenseItem(expense: e)).toList()),

        const SizedBox(height: 20),

        // Savings Deduction
        _SheetSectionHeader(title: 'Savings Deduction', onSort: () {}),
        const SizedBox(height: 8),
        _kDeductions.isEmpty
            ? _SheetEmptyState(
                icon: Icons.savings_rounded,
                message: 'No deductions yet',
              )
            : Column(children: _kDeductions.map((e) => _ExpenseItem(expense: e)).toList()),

        const SizedBox(height: 80),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Summary card (top row)
// ─────────────────────────────────────────────────────────────
class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  final String? subtitle;
  final bool showProgress;
  final double progressValue;
  final String? progressLabel;

  const _SummaryCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    this.subtitle,
    this.showProgress = false,
    this.progressValue = 0,
    this.progressLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: kNavyMid,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kWhite.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 14),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: kWhite.withOpacity(0.7),
                    fontSize: 10,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: kWhite,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          if (showProgress) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progressValue,
                minHeight: 4,
                backgroundColor: kWhite.withOpacity(0.12),
                valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFFE87070)),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              progressLabel ?? '',
              style: TextStyle(
                color: kWhite.withOpacity(0.5),
                fontSize: 9,
              ),
            ),
          ] else
            Text(
              subtitle ?? '',
              style: TextStyle(
                color: kWhite.withOpacity(0.5),
                fontSize: 10,
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Section card wrapper (navy card with title + optional action)
// ─────────────────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final String title;
  final String? action;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.child,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kNavyMid,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kWhite.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: kWhite,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (action != null)
                Text(
                  action!,
                  style: const TextStyle(
                    color: kTeal,
                    fontSize: 12,
                    decoration: TextDecoration.underline,
                    decorationColor: kTeal,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Bar chart (Budget Allocation)
// ─────────────────────────────────────────────────────────────
class _BarChart extends StatelessWidget {
  final List<_BudgetCategory> categories;

  const _BarChart({required this.categories});

  @override
  Widget build(BuildContext context) {
    const maxVal = 60.0;
    const chartH = 120.0;
    const gridLines = [0.0, 15.0, 30.0, 45.0, 60.0];

    return SizedBox(
      height: 170,
      child: Column(
        children: [
          // Chart area
          SizedBox(
            height: chartH,
            child: Stack(
              children: [
                // Grid lines
                ...gridLines.map((v) {
                  final y = chartH - (v / maxVal) * chartH;
                  return Positioned(
                    top: y,
                    left: 0,
                    right: 0,
                    child: Row(
                      children: [
                        SizedBox(
                          width: 24,
                          child: Text(
                            '${v.toInt()}',
                            style: TextStyle(
                              color: kWhite.withOpacity(0.3),
                              fontSize: 8,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Container(
                            height: 1,
                            color: kWhite.withOpacity(0.08),
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                // Bars
                Positioned.fill(
                  left: 28,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: categories.map((cat) {
                      final barH = (cat.amount / maxVal) * chartH;
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            '₱${cat.amount.toStringAsFixed(0)}',
                            style: const TextStyle(
                              color: kWhite,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Container(
                            width: 36,
                            height: barH,
                            decoration: BoxDecoration(
                              color: cat.color,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(5),
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // X-axis labels
          Padding(
            padding: const EdgeInsets.only(left: 28),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: categories
                  .map((cat) => SizedBox(
                        width: 60,
                        child: Text(
                          cat.label,
                          style: TextStyle(
                            color: kWhite.withOpacity(0.55),
                            fontSize: 9,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// High Priority section: donut on left, balance cards on right
// ─────────────────────────────────────────────────────────────
class _HighPrioritySection extends StatelessWidget {
  final List<_HighPriorityBreakdown> items;

  const _HighPrioritySection({required this.items});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Donut (takes up left portion)
        Expanded(
          flex: 5,
          child: _HighPriorityDonut(items: items),
        ),

        const SizedBox(width: 12),

        // Balance cards stacked on the right
        Expanded(
          flex: 3,
          child: Column(
            children: const [
              _BalanceCard(label: 'Academics', balance: null),
              SizedBox(height: 10),
              _BalanceCard(label: 'Discretionary', balance: null),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Small rounded balance card (e.g. Academics / Discretionary)
// ─────────────────────────────────────────────────────────────
class _BalanceCard extends StatelessWidget {
  final String label;
  final double? balance; // null = empty state

  const _BalanceCard({required this.label, this.balance});

  @override
  Widget build(BuildContext context) {
    final isEmpty = balance == null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: kNavyDark.withOpacity(0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kWhite.withOpacity(0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: kWhite,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isEmpty ? '—' : '₱${balance!.toStringAsFixed(2)}',
            style: TextStyle(
              color: isEmpty ? kWhite.withOpacity(0.25) : kWhite,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Balance',
            style: TextStyle(
              color: kWhite.withOpacity(0.4),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// High Priority donut + legend
// ─────────────────────────────────────────────────────────────
class _HighPriorityDonut extends StatelessWidget {
  final List<_HighPriorityBreakdown> items;

  const _HighPriorityDonut({required this.items});

  @override
  Widget build(BuildContext context) {
    final isEmpty = items.isEmpty;
    final total = isEmpty ? 0.0 : items.fold(0.0, (s, i) => s + i.amount);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Donut — always shown
        SizedBox(
          width: 100,
          height: 100,
          child: CustomPaint(
            painter: _HighPriorityDonutPainter(items: items, total: total),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isEmpty ? '0%' : '${(items.reduce((a, b) => a.amount > b.amount ? a : b).amount / total * 100).round()}%',
                    style: const TextStyle(
                      color: kWhite,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    isEmpty ? 'No data' : items.reduce((a, b) => a.amount > b.amount ? a : b).label,
                    style: TextStyle(
                      color: kWhite.withOpacity(0.6),
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(width: 10),

        // Legend — empty state text when no items
        Flexible(
          child: isEmpty
            ? Text(
                'No expenses\nadded yet',
                style: TextStyle(
                  color: kWhite.withOpacity(0.3),
                  fontSize: 12,
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: items
                    .map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: item.color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.label,
                                    style: const TextStyle(
                                      color: kWhite,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    '₱${item.amount.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      color: kWhite.withOpacity(0.5),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ))
                    .toList(),
              ),
          ),
      ],
    );
  }
}

class _HighPriorityDonutPainter extends CustomPainter {
  final List<_HighPriorityBreakdown> items;
  final double total;

  const _HighPriorityDonutPainter({required this.items, required this.total});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    const stroke = 20.0;
    const pi = math.pi;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Unified grey track ring (always drawn)
    canvas.drawArc(rect, 0, 2 * pi, false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = kWhite.withOpacity(0.12));

    if (total == 0) return;

    double start = -pi / 2;
    for (final item in items) {
      final sweep = 2 * pi * (item.amount / total);
      if (sweep <= 0) continue;
      canvas.drawArc(rect, start, sweep, false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke
            ..strokeCap = StrokeCap.round
            ..color = item.color);
      start += sweep + 0.05;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

// ─────────────────────────────────────────────────────────────
// Savings line chart
// ─────────────────────────────────────────────────────────────
class _SavingsChart extends StatelessWidget {
  final List<_SavingsPoint> points;

  const _SavingsChart({required this.points});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 150,
      child: CustomPaint(
        painter: _SavingsLinePainter(points: points),
        child: Container(),
      ),
    );
  }
}

class _SavingsLinePainter extends CustomPainter {
  final List<_SavingsPoint> points;

  const _SavingsLinePainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final gridValues = [0.0, 10.0, 100.0, 1000.0, 10000.0];
    final maxVal = 10000.0;
    const leftPad = 36.0;
    const bottomPad = 20.0;
    final chartW = size.width - leftPad;
    final chartH = size.height - bottomPad;

    // Log scale helper
    double logY(double v) {
      if (v <= 0) return chartH;
      final logMax = math.log(maxVal + 1);
      final logV = math.log(v + 1);
      return chartH - (logV / logMax) * chartH;
    }

    final gridPaint = Paint()
      ..color = kWhite.withOpacity(0.08)
      ..strokeWidth = 1;

    final labelStyle = TextStyle(
      color: kWhite.withOpacity(0.35),
      fontSize: 8,
    );

    // Grid lines + Y labels
    for (final v in gridValues) {
      final y = logY(v);
      canvas.drawLine(Offset(leftPad, y), Offset(size.width, y), gridPaint);
      final tp = TextPainter(
        text: TextSpan(
            text: v >= 1000 ? '${(v / 1000).toStringAsFixed(0)}k' : v.toStringAsFixed(0),
            style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(0, y - 5));
    }

    // X labels
    for (int i = 0; i < points.length; i++) {
      final x = leftPad + (i / (points.length - 1)) * chartW;
      final tp = TextPainter(
        text: TextSpan(text: points[i].month, style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, size.height - 14));
    }

    // Build path
    final path = Path();
    final fillPath = Path();
    final pts = <Offset>[];

    for (int i = 0; i < points.length; i++) {
      final x = leftPad + (i / (points.length - 1)) * chartW;
      final y = logY(points[i].value);
      pts.add(Offset(x, y));
    }

    path.moveTo(pts[0].dx, pts[0].dy);
    fillPath.moveTo(pts[0].dx, chartH);
    fillPath.lineTo(pts[0].dx, pts[0].dy);

    for (int i = 1; i < pts.length; i++) {
      final cp1 = Offset((pts[i - 1].dx + pts[i].dx) / 2, pts[i - 1].dy);
      final cp2 = Offset((pts[i - 1].dx + pts[i].dx) / 2, pts[i].dy);
      path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, pts[i].dx, pts[i].dy);
      fillPath.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, pts[i].dx, pts[i].dy);
    }

    fillPath.lineTo(pts.last.dx, chartH);
    fillPath.close();

    // Fill
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            kTeal.withOpacity(0.35),
            kTeal.withOpacity(0.0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    // Line
    canvas.drawPath(
      path,
      Paint()
        ..color = kTeal
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Dots
    for (final pt in pts) {
      canvas.drawCircle(pt, 3, Paint()..color = kTeal);
      canvas.drawCircle(
          pt,
          3,
          Paint()
            ..color = kWhite
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

// ─────────────────────────────────────────────────────────────
// Sheet section header
// ─────────────────────────────────────────────────────────────
class _SheetSectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onSort;

  const _SheetSectionHeader({required this.title, this.onSort});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: kNavyDark,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          GestureDetector(
            onTap: onSort,
            child: Row(
              children: const [
                Text('Sorted by',
                    style:
                        TextStyle(color: Color(0xFF6B7A99), fontSize: 12)),
                SizedBox(width: 3),
                Icon(Icons.arrow_drop_down,
                    color: Color(0xFF6B7A99), size: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Empty state — inside navy section card (background)
// ─────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 40, color: kWhite.withOpacity(0.12)),
            const SizedBox(height: 10),
            Text(
              message,
              style: TextStyle(color: kWhite.withOpacity(0.3), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Empty state — inside white sheet
// ─────────────────────────────────────────────────────────────
class _SheetEmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _SheetEmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 36, color: kNavyDark.withOpacity(0.1)),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(color: kNavyDark.withOpacity(0.3), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Expense item row (with dashed connector)
// ─────────────────────────────────────────────────────────────
class _ExpenseItem extends StatelessWidget {
  final _Expense expense;

  const _ExpenseItem({required this.expense});

  Color get _badgeColor {
    switch (expense.status) {
      case _ExpenseStatus.overdue:
        return const Color(0xFFE87070);
      case _ExpenseStatus.unpaid:
        return const Color(0xFF4A90D9);
      case _ExpenseStatus.paid:
        return const Color(0xFF3BBFA3);
      case _ExpenseStatus.deducted:
        return const Color(0xFF9B88E8);
    }
  }

  String get _badgeLabel {
    switch (expense.status) {
      case _ExpenseStatus.overdue:
        return 'Overdue ⚠';
      case _ExpenseStatus.unpaid:
        return 'Unpaid';
      case _ExpenseStatus.paid:
        return 'Paid';
      case _ExpenseStatus.deducted:
        return 'Deducted';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon circle + dashed line
          SizedBox(
            width: 36,
            child: Column(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: expense.iconColor.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(expense.icon,
                      color: expense.iconColor, size: 17),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name + badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        expense.name,
                        style: const TextStyle(
                          color: kNavyDark,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _badgeColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: _badgeColor.withOpacity(0.3)),
                      ),
                      child: Text(
                        _badgeLabel,
                        style: TextStyle(
                          color: _badgeColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 3),

                // Amount + saving note
                Row(
                  children: [
                    Text(
                      '₱${expense.amount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: kNavyDark,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (expense.savingNote != null) ...[
                      const Text(' – ',
                          style: TextStyle(
                              color: Color(0xFF6B7A99), fontSize: 12)),
                      Text(
                        expense.savingNote!,
                        style: const TextStyle(
                          color: Color(0xFF6B7A99),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 2),

                // Date
                Row(
                  children: [
                    const Icon(Icons.access_time_rounded,
                        size: 11, color: Color(0xFF6B7A99)),
                    const SizedBox(width: 3),
                    Text(
                      expense.dateRange,
                      style: const TextStyle(
                          color: Color(0xFF6B7A99), fontSize: 11),
                    ),
                  ],
                ),

                const Divider(height: 16, color: Color(0xFFEEEEEE)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}