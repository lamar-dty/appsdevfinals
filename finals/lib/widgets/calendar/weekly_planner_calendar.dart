import 'package:flutter/material.dart';
import '../../constants/colors.dart';

// ── Data models ──────────────────────────────────────
class _CategoryItem {
  final String name;
  final Color color;
  final bool isParent;
  bool enabled;
  _CategoryItem(this.name, this.color, {this.isParent = false, this.enabled = true});
}

class WeeklyPlannerCalendar extends StatefulWidget {
  const WeeklyPlannerCalendar({super.key});

  @override
  State<WeeklyPlannerCalendar> createState() => _WeeklyPlannerCalendarState();
}

class _WeeklyPlannerCalendarState extends State<WeeklyPlannerCalendar> {
  late DateTime _focusedMonth;
  late DateTime _selectedDay;

  // Hierarchical categories: parents + indented children
  final List<_CategoryItem> _categories = [
    _CategoryItem('Academic Task', const Color(0xFF4A90D9), isParent: true),
    _CategoryItem('Assignment',    const Color(0xFF9B88E8)),
    _CategoryItem('Project',       const Color(0xFFE8D870)),
    _CategoryItem('Assessment',    const Color(0xFF90D0CB)),
    _CategoryItem('Events',        const Color(0xFFE8A870), isParent: true),
    _CategoryItem('Academic',      const Color(0xFF4A90D9)),
    _CategoryItem('Personal',      const Color(0xFFE8A870)),
    _CategoryItem('Personal Task', const Color(0xFF9B88E8), isParent: true),
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month);
    _selectedDay = now;
  }

  List<DateTime> _daysInMonth(DateTime month) {
    final first = DateTime(month.year, month.month, 1);
    final last = DateTime(month.year, month.month + 1, 0);
    final startOffset = (first.weekday - 1) % 7;
    final List<DateTime> days = [];
    for (int i = startOffset; i > 0; i--) {
      days.add(first.subtract(Duration(days: i)));
    }
    for (int i = 0; i < last.day; i++) {
      days.add(DateTime(month.year, month.month, i + 1));
    }
    final remaining = 42 - days.length;
    for (int i = 1; i <= remaining; i++) {
      days.add(last.add(Duration(days: i)));
    }
    return days;
  }

  List<DateTime> _weekDays() {
    final monday = _selectedDay.subtract(Duration(days: _selectedDay.weekday - 1));
    return List.generate(7, (i) => monday.add(Duration(days: i)));
  }

  @override
  Widget build(BuildContext context) {
    final days = _daysInMonth(_focusedMonth);
    final now = DateTime.now();
    final monthLabel = '${_monthName(_focusedMonth.month)} ${_focusedMonth.year}';
    final weekDays = _weekDays();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── CALENDAR + CHECKLIST ROW ─────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Left: Calendar ─────────────────────
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    // Month nav
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: () => setState(() {
                            _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
                          }),
                          child: const Icon(Icons.chevron_left, color: kWhite, size: 22),
                        ),
                        Text(monthLabel,
                            style: const TextStyle(
                                color: kWhite, fontSize: 15, fontWeight: FontWeight.bold)),
                        GestureDetector(
                          onTap: () => setState(() {
                            _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
                          }),
                          child: const Icon(Icons.chevron_right, color: kWhite, size: 22),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Day headers
                    Row(
                      children: ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su']
                          .map((d) => Expanded(
                                child: Center(
                                  child: Text(d,
                                      style: TextStyle(
                                          color: kWhite.withOpacity(0.55),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600)),
                                ),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 4),
                    // Calendar grid
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7,
                        mainAxisSpacing: 2,
                        crossAxisSpacing: 2,
                        childAspectRatio: 1.1,
                      ),
                      itemCount: days.length,
                      itemBuilder: (context, index) {
                        final day = days[index];
                        final isCurrentMonth = day.month == _focusedMonth.month;
                        final isToday = day.year == now.year &&
                            day.month == now.month &&
                            day.day == now.day;
                        final isSelected = day.year == _selectedDay.year &&
                            day.month == _selectedDay.month &&
                            day.day == _selectedDay.day;

                        return GestureDetector(
                          onTap: () => setState(() => _selectedDay = day),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? kTeal
                                  : isToday
                                      ? kWhite.withOpacity(0.15)
                                      : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Center(
                              child: Text('${day.day}',
                                  style: TextStyle(
                                    color: isSelected
                                        ? kNavyDark
                                        : isCurrentMonth
                                            ? kWhite
                                            : kWhite.withOpacity(0.25),
                                    fontSize: 12,
                                    fontWeight: isToday || isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  )),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              // ── Right: Checklist with white background ──
              Container(
                width: 115,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: kWhite,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _categories.map((cat) {
                    final isIndented = !cat.isParent;
                    return GestureDetector(
                      onTap: () => setState(() => cat.enabled = !cat.enabled),
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: isIndented ? 10.0 : 0.0,
                          top: cat.isParent ? 4.0 : 2.0,
                          bottom: 2.0,
                        ),
                        child: Row(
                          children: [
                            // Checkbox
                            Container(
                              width: 13,
                              height: 13,
                              decoration: BoxDecoration(
                                color: cat.enabled ? cat.color : Colors.transparent,
                                border: Border.all(color: cat.color, width: 1.5),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: cat.enabled
                                  ? const Icon(Icons.check, size: 9, color: Colors.white)
                                  : null,
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                cat.name,
                                style: TextStyle(
                                  color: kNavyDark,
                                  fontSize: cat.isParent ? 10 : 9,
                                  fontWeight: cat.isParent
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // ── WEEKLY TIME GRID ─────────────────────────
        _WeeklyGrid(weekDays: weekDays, now: now),
        const SizedBox(height: 20),
      ],
    );
  }

  String _monthName(int m) => [
        '', 'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
      ][m];
}

// ── Weekly time grid ─────────────────────────────────
class _WeeklyGrid extends StatelessWidget {
  final List<DateTime> weekDays;
  final DateTime now;

  const _WeeklyGrid({required this.weekDays, required this.now});

  @override
  Widget build(BuildContext context) {
    final dayNames = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    final hours = List.generate(13, (i) => i + 7); // 7AM–7PM

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Day header row
          Row(
            children: [
              SizedBox(
                width: 36,
                child: Text('TIME',
                    style: TextStyle(
                        color: kWhite.withOpacity(0.5),
                        fontSize: 9,
                        fontWeight: FontWeight.w600)),
              ),
              ...List.generate(7, (i) {
                final d = weekDays[i];
                final isToday = d.year == now.year &&
                    d.month == now.month &&
                    d.day == now.day;
                return Expanded(
                  child: Column(
                    children: [
                      Text(dayNames[i],
                          style: TextStyle(
                              color: kWhite.withOpacity(0.55),
                              fontSize: 9,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text('${d.day}',
                          style: TextStyle(
                            color: isToday ? kTeal : kWhite,
                            fontSize: 12,
                            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                          )),
                    ],
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 6),
          // Time rows — empty
          ...hours.map((hour) {
            final label = hour < 12
                ? '${hour} AM'
                : hour == 12
                    ? '12 PM'
                    : '${hour - 12} PM';
            return SizedBox(
              height: 40,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 36,
                    child: Text(label,
                        style: TextStyle(
                            color: kWhite.withOpacity(0.4), fontSize: 9)),
                  ),
                  ...List.generate(
                    7,
                    (_) => Expanded(
                      child: Container(
                        margin: const EdgeInsets.only(right: 1),
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(
                                color: kWhite.withOpacity(0.1), width: 0.5),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}