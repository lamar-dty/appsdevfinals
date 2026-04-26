import 'package:flutter/material.dart';
import '../../constants/colors.dart';

// ─────────────────────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────────────────────
class PlanCategory {
  final String id;
  final String name;
  final Color color;
  final String? parentId;
  bool visible;

  PlanCategory({
    required this.id,
    required this.name,
    required this.color,
    this.parentId,
    this.visible = true,
  });

  bool get isParent => parentId == null;
}

class PlanEvent {
  final String title;
  final String categoryId;
  final Color color;
  final int weekday;      // 1=Mon … 7=Sun
  final double startHour; // e.g. 9.0 = 9:00 AM
  final double endHour;   // e.g. 10.5 = 10:30 AM

  const PlanEvent({
    required this.title,
    required this.categoryId,
    required this.color,
    required this.weekday,
    required this.startHour,
    required this.endHour,
  });

  double get durationHours => endHour - startHour;
}

final List<PlanEvent> _kSampleEvents = [];

// ─────────────────────────────────────────────────────────────
// WeeklyPlannerCalendar
// ─────────────────────────────────────────────────────────────
class WeeklyPlannerCalendar extends StatefulWidget {
  final double peekHeight;
  final int startHour;
  final int endHour;
  final void Function(int start, int end) onRangeChanged;

  const WeeklyPlannerCalendar({
    super.key,
    this.peekHeight = 0,
    this.startHour = 6,
    this.endHour = 22,
    required this.onRangeChanged,
  });

  @override
  State<WeeklyPlannerCalendar> createState() => _WeeklyPlannerCalendarState();
}

class _WeeklyPlannerCalendarState extends State<WeeklyPlannerCalendar>
    with SingleTickerProviderStateMixin {
  late DateTime _focusedMonth;
  late DateTime _selectedDay;
  late AnimationController _fadeCtrl;


  final List<PlanCategory> _categories = [
    PlanCategory(id: 'academic',      name: 'Academic Task', color: const Color(0xFF4A90D9)),
    PlanCategory(id: 'assignment',    name: 'Assignment',    color: const Color(0xFF9B88E8), parentId: 'academic'),
    PlanCategory(id: 'project',       name: 'Project',       color: const Color(0xFFE8D870), parentId: 'academic'),
    PlanCategory(id: 'assessment',    name: 'Assessment',    color: const Color(0xFF90D0CB), parentId: 'academic'),
    PlanCategory(id: 'events',        name: 'Events',        color: const Color(0xFFE8A870)),
    PlanCategory(id: 'acad_event',    name: 'Academic',      color: const Color(0xFF4A90D9), parentId: 'events'),
    PlanCategory(id: 'personal_evt',  name: 'Personal',      color: const Color(0xFFE8A870), parentId: 'events'),
    PlanCategory(id: 'personal_task', name: 'Personal Task', color: const Color(0xFF9B88E8)),
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month);
    _selectedDay  = now;
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Category helpers ──────────────────────────────────────
  bool _isCategoryVisible(String catId) {
    final cat = _categories.firstWhere((c) => c.id == catId, orElse: () => _categories.first);
    if (!cat.visible) return false;
    if (cat.parentId != null) {
      final parent = _categories.firstWhere((c) => c.id == cat.parentId!, orElse: () => cat);
      return parent.visible;
    }
    return true;
  }

  void _toggleCategory(PlanCategory cat) {
    setState(() {
      cat.visible = !cat.visible;
      if (cat.isParent) {
        for (final child in _categories.where((c) => c.parentId == cat.id)) {
          child.visible = cat.visible;
        }
      }
    });
  }

  List<PlanEvent> get _visibleEvents =>
      _kSampleEvents.where((e) => _isCategoryVisible(e.categoryId)).toList();

  // ── Date helpers ──────────────────────────────────────────
  List<DateTime> _daysInMonth(DateTime month) {
    final first  = DateTime(month.year, month.month, 1);
    final last   = DateTime(month.year, month.month + 1, 0);
    final offset = (first.weekday - 1) % 7;
    final days   = <DateTime>[];
    for (int i = offset; i > 0; i--) days.add(first.subtract(Duration(days: i)));
    for (int i = 0; i < last.day; i++) days.add(DateTime(month.year, month.month, i + 1));
    final rem = 42 - days.length;
    for (int i = 1; i <= rem; i++) days.add(last.add(Duration(days: i)));
    return days;
  }

  List<DateTime> _weekDays() {
    final monday = _selectedDay.subtract(Duration(days: _selectedDay.weekday - 1));
    return List.generate(7, (i) => monday.add(Duration(days: i)));
  }

  String _fullMonth(int m) => const [
    '', 'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ][m];

  String _shortMonth(int m) => const [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ][m];

  // ── Calendar settings sheet ───────────────────────────────
  void _openCalendarSettings() {
    int tempStart = widget.startHour;
    int tempEnd   = widget.endHour;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            String _fmt(int h) {
              if (h == 0)  return '12 AM';
              if (h < 12)  return '$h AM';
              if (h == 12) return '12 PM';
              return '${h - 12} PM';
            }

            return Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
              decoration: BoxDecoration(
                color: const Color(0xFF1B2D5B),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: kWhite.withOpacity(0.08)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 36, height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: kWhite.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Title
                  Row(
                    children: [
                      const Icon(Icons.tune_rounded, color: kTeal, size: 18),
                      const SizedBox(width: 8),
                      const Text(
                        'Calendar Hours',
                        style: TextStyle(
                          color: kWhite,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Set the visible time range for your weekly planner.',
                    style: TextStyle(color: kWhite.withOpacity(0.45), fontSize: 12),
                  ),

                  const SizedBox(height: 28),

                  // Start hour
                  Text('Start time', style: TextStyle(color: kWhite.withOpacity(0.6), fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  _HourSlider(
                    value: tempStart,
                    min: 0,
                    max: tempEnd - 1,
                    formatter: _fmt,
                    onChanged: (v) => setModal(() => tempStart = v),
                  ),

                  const SizedBox(height: 24),

                  // End hour
                  Text('End time', style: TextStyle(color: kWhite.withOpacity(0.6), fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  _HourSlider(
                    value: tempEnd,
                    min: tempStart + 1,
                    max: 24,
                    formatter: _fmt,
                    onChanged: (v) => setModal(() => tempEnd = v),
                  ),

                  const SizedBox(height: 8),

                  // Range preview
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: kTeal.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: kTeal.withOpacity(0.25)),
                      ),
                      child: Text(
                        '${_fmt(tempStart)} → ${_fmt(tempEnd)}  ·  ${tempEnd - tempStart}h visible',
                        style: const TextStyle(color: kTeal, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Buttons
                  Row(
                    children: [
                      // Reset to default
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => setModal(() { tempStart = 6; tempEnd = 22; }),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: kWhite.withOpacity(0.2)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text('Reset', style: TextStyle(color: kWhite.withOpacity(0.6), fontSize: 14)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Apply
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () {
                            widget.onRangeChanged(tempStart, tempEnd);
                            Navigator.pop(ctx);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kTeal,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                          ),
                          child: const Text('Apply', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── Build ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final days     = _daysInMonth(_focusedMonth);
    final now      = DateTime.now();
    final weekDays = _weekDays();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Mini calendar + filter panel ──────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 55,
                child: _MiniCalendar(
                  days: days,
                  focusedMonth: _focusedMonth,
                  selectedDay: _selectedDay,
                  now: now,
                  monthLabel: '${_fullMonth(_focusedMonth.month)} ${_focusedMonth.year}',
                  visibleEvents: _visibleEvents,
                  onPrev: () => setState(() =>
                    _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1)),
                  onNext: () => setState(() =>
                    _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1)),
                  onDayTap: (d) {
                    _fadeCtrl.forward(from: 0);
                    setState(() => _selectedDay = d);
                  },
                ),
              ),
              const SizedBox(width: 10),
              _LegendPanel(categories: _categories, onToggle: _toggleCategory),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // ── Week header bar ───────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Container(
                width: 3, height: 14,
                decoration: BoxDecoration(
                  color: kTeal, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 8),
              Text(
                'Week of ${weekDays.first.day} ${_shortMonth(weekDays.first.month)}',
                style: TextStyle(
                  color: kWhite.withOpacity(0.75),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              // Events badge
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Container(
                  key: ValueKey(_visibleEvents.length),
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: kTeal.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: kTeal.withOpacity(0.3)),
                  ),
                  child: Text(
                    '${_visibleEvents.length} events',
                    style: const TextStyle(
                        color: kTeal, fontSize: 10, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Settings button
              GestureDetector(
                onTap: _openCalendarSettings,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: kWhite.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: kWhite.withOpacity(0.1)),
                  ),
                  child: Icon(Icons.access_time_rounded,
                      color: kWhite.withOpacity(0.55), size: 14),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // ── Weekly grid ───────────────────────────────────
        FadeTransition(
          opacity: CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn),
          child: _WeeklyGrid(
            weekDays: weekDays,
            now: now,
            visibleEvents: _visibleEvents,
            startHour: widget.startHour,
            endHour: widget.endHour,
            peekHeight: widget.peekHeight,
          ),
        ),

        const SizedBox(height: 20),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Hour slider row
// ─────────────────────────────────────────────────────────────
class _HourSlider extends StatelessWidget {
  final int value;
  final int min;
  final int max;
  final String Function(int) formatter;
  final ValueChanged<int> onChanged;

  const _HourSlider({
    required this.value,
    required this.min,
    required this.max,
    required this.formatter,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 52,
          child: Text(
            formatter(value),
            style: const TextStyle(
              color: kTeal,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: kTeal,
              inactiveTrackColor: kWhite.withOpacity(0.1),
              thumbColor: kTeal,
              overlayColor: kTeal.withOpacity(0.15),
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            ),
            child: Slider(
              value: value.toDouble(),
              min: min.toDouble(),
              max: max.toDouble(),
              divisions: max - min,
              onChanged: (v) => onChanged(v.round()),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Mini calendar
// ─────────────────────────────────────────────────────────────
class _MiniCalendar extends StatelessWidget {
  final List<DateTime> days;
  final DateTime focusedMonth, selectedDay, now;
  final String monthLabel;
  final List<PlanEvent> visibleEvents;
  final VoidCallback onPrev, onNext;
  final void Function(DateTime) onDayTap;

  const _MiniCalendar({
    required this.days,
    required this.focusedMonth,
    required this.selectedDay,
    required this.now,
    required this.monthLabel,
    required this.visibleEvents,
    required this.onPrev,
    required this.onNext,
    required this.onDayTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _IconBtn(icon: Icons.chevron_left_rounded, onTap: onPrev),
            Text(monthLabel,
              style: const TextStyle(
                color: kWhite, fontSize: 13,
                fontWeight: FontWeight.bold, letterSpacing: 0.1)),
            _IconBtn(icon: Icons.chevron_right_rounded, onTap: onNext),
          ],
        ),
        const SizedBox(height: 8),

        Row(
          children: ['M', 'T', 'W', 'T', 'F', 'S', 'S']
              .map((d) => Expanded(
                    child: Center(
                      child: Text(d,
                        style: TextStyle(
                          color: kTeal.withOpacity(0.6),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        )),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 4),

        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
            childAspectRatio: 1.08,
          ),
          itemCount: days.length,
          itemBuilder: (_, index) {
            final day    = days[index];
            final isCur  = day.month == focusedMonth.month;
            final isToday = day.year == now.year && day.month == now.month && day.day == now.day;
            final isSel  = day.year == selectedDay.year &&
                day.month == selectedDay.month && day.day == selectedDay.day;

            final dots = isCur
                ? visibleEvents
                    .where((e) => e.weekday == day.weekday)
                    .map((e) => e.color)
                    .take(3)
                    .toList()
                : <Color>[];

            return GestureDetector(
              onTap: () => onDayTap(day),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  color: isSel
                      ? kTeal
                      : isToday
                          ? kWhite.withOpacity(0.12)
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('${day.day}',
                      style: TextStyle(
                        color: isSel
                            ? kNavyDark
                            : isCur
                                ? kWhite
                                : kWhite.withOpacity(0.18),
                        fontSize: 11,
                        fontWeight: isToday || isSel
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    if (dots.isNotEmpty && !isSel) ...[
                      const SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: dots
                            .map((c) => Container(
                                  width: 3.5, height: 3.5,
                                  margin: const EdgeInsets.only(right: 1),
                                  decoration: BoxDecoration(
                                      color: c, shape: BoxShape.circle),
                                ))
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Icon button
// ─────────────────────────────────────────────────────────────
class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            color: kWhite.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: kWhite.withOpacity(0.7), size: 18),
        ),
      );
}

// ─────────────────────────────────────────────────────────────
// Legend / filter panel
// ─────────────────────────────────────────────────────────────
class _LegendPanel extends StatelessWidget {
  final List<PlanCategory> categories;
  final void Function(PlanCategory) onToggle;

  const _LegendPanel({required this.categories, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 116,
      padding: const EdgeInsets.fromLTRB(12, 12, 8, 57),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune_rounded, size: 10, color: kNavyDark.withOpacity(0.4)),
              const SizedBox(width: 4),
              Text('FILTER',
                style: TextStyle(
                  color: kNavyDark.withOpacity(0.38),
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          ...categories.map((cat) {
            final isChild  = cat.parentId != null;
            final parentOff = isChild &&
                !(categories.firstWhere((c) => c.id == cat.parentId!).visible);
            final effectiveOn = cat.visible && !parentOff;

            return GestureDetector(
              onTap: () => onToggle(cat),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: EdgeInsets.only(
                  left: isChild ? 11.0 : 0.0,
                  top:  cat.isParent ? 6.0 : 3.0,
                  bottom: 1.0,
                ),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      width: 13, height: 13,
                      decoration: BoxDecoration(
                        color: effectiveOn ? cat.color : Colors.transparent,
                        border: Border.all(
                          color: effectiveOn ? cat.color : cat.color.withOpacity(0.3),
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: effectiveOn
                          ? const Icon(Icons.check_rounded, size: 9, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 160),
                        style: TextStyle(
                          color: effectiveOn
                              ? kNavyDark
                              : kNavyDark.withOpacity(0.25),
                          fontSize: cat.isParent ? 9.5 : 8.5,
                          fontWeight:
                              cat.isParent ? FontWeight.w700 : FontWeight.w500,
                        ),
                        child: Text(cat.name,
                            overflow: TextOverflow.ellipsis, maxLines: 1),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Weekly time grid — auto-scrolls to current time on open
// ─────────────────────────────────────────────────────────────
class _WeeklyGrid extends StatefulWidget {
  final List<DateTime> weekDays;
  final DateTime now;
  final List<PlanEvent> visibleEvents;
  final int startHour;
  final int endHour;
  final double peekHeight;

  const _WeeklyGrid({
    required this.weekDays,
    required this.now,
    required this.visibleEvents,
    required this.startHour,
    required this.endHour,
    this.peekHeight = 0,
  });

  @override
  State<_WeeklyGrid> createState() => _WeeklyGridState();
}

class _WeeklyGridState extends State<_WeeklyGrid> {
  static const double _rowH  = 50.0;
  static const double _timeW = 36.0;
  static const double _gap   = 5.0;

  late ScrollController _scrollCtrl;

  int get _hours => widget.endHour - widget.startHour;

  @override
  void initState() {
    super.initState();
    _scrollCtrl = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToNow());
  }

  @override
  void didUpdateWidget(_WeeklyGrid old) {
    super.didUpdateWidget(old);
    // Re-scroll if the range changes
    if (old.startHour != widget.startHour || old.endHour != widget.endHour) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToNow());
    }
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToNow() {
    final now     = widget.now;
    final nowFrac = (now.hour + now.minute / 60.0) - widget.startHour;
    // Clamp so we don't scroll past the grid; offset slightly above "now"
    final target  = (nowFrac * _rowH - 80).clamp(0.0, _rowH * _hours);
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(
        target,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
    }
  }

  String _timeLabel(int hour) {
    if (hour < 12) return '${hour}am';
    if (hour == 12) return '12pm';
    return '${hour - 12}pm';
  }

  @override
  Widget build(BuildContext context) {
    const dayNames = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Day header ───────────────────────────────────
          Row(
            children: [
              SizedBox(width: _timeW + _gap),
              ...List.generate(7, (i) {
                final d = widget.weekDays[i];
                final isToday = d.year == widget.now.year &&
                    d.month == widget.now.month && d.day == widget.now.day;
                return Expanded(
                  child: Column(
                    children: [
                      Text(dayNames[i],
                        style: TextStyle(
                          color: isToday ? kTeal : kWhite.withOpacity(0.38),
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 3),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 22, height: 22,
                        decoration: BoxDecoration(
                          color: isToday ? kTeal : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text('${d.day}',
                            style: TextStyle(
                              color: isToday ? kNavyDark : kWhite,
                              fontSize: 11,
                              fontWeight: isToday
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),

          const SizedBox(height: 6),

          // ── Scrollable grid body ──────────────────────────
          // Viewport = screen height minus appbar, top UI, bottom nav,
          // and whatever the peeking sheet currently covers.
          SizedBox(
            height: (_rowH * 8 - widget.peekHeight).clamp(_rowH * 3, _rowH * 8),
            child: SingleChildScrollView(
              controller: _scrollCtrl,
              physics: const ClampingScrollPhysics(),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final gridW = constraints.maxWidth;
                  final colW  = (gridW - _timeW - _gap) / 7;

                  return SizedBox(
                    height: _rowH * (_hours + 1),
                    child: Stack(
                      clipBehavior: Clip.hardEdge,
                      children: [
                        ..._buildBackground(),
                        ..._buildTimeLine(colW),
                        ..._buildEvents(colW),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildBackground() {
    return List.generate(_hours + 1, (i) {
      final hour = widget.startHour + i;
      return Positioned(
        top: i * _rowH,
        left: 0,
        right: 0,
        height: _rowH,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: _timeW,
              child: Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(_timeLabel(hour),
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: kWhite.withOpacity(0.28),
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            SizedBox(width: _gap),
            ...List.generate(7, (col) {
              final isWknd = col >= 5;
              return Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: isWknd ? kWhite.withOpacity(0.025) : Colors.transparent,
                    border: Border(
                      top: BorderSide(
                        color: i == 0
                            ? kWhite.withOpacity(0.18)
                            : kWhite.withOpacity(0.06),
                        width: 0.5,
                      ),
                      left: BorderSide(
                        color: kWhite.withOpacity(0.05),
                        width: 0.5,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      );
    });
  }

  List<Widget> _buildTimeLine(double colW) {
    final todayIdx = widget.weekDays.indexWhere(
        (d) => d.day == widget.now.day &&
               d.month == widget.now.month &&
               d.year == widget.now.year);
    if (todayIdx < 0) return [];

    final fraction = (widget.now.hour + widget.now.minute / 60.0) - widget.startHour;
    if (fraction < 0 || fraction > _hours) return [];

    final top  = fraction * _rowH;
    final left = _timeW + _gap + todayIdx * colW;

    return [
      Positioned(
        top: top,
        left: left,
        width: colW,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 7, height: 7,
              decoration: const BoxDecoration(
                  color: kTeal, shape: BoxShape.circle),
            ),
            Expanded(child: Container(height: 1.5, color: kTeal)),
          ],
        ),
      ),
    ];
  }

  List<Widget> _buildEvents(double colW) {
    return widget.visibleEvents.map((event) {
      final col = event.weekday - 1;
      if (col < 0 || col > 6) return const SizedBox.shrink();

      final top    = (event.startHour - widget.startHour) * _rowH;
      final height = (event.durationHours * _rowH - 4).clamp(14.0, double.infinity);
      final left   = _timeW + _gap + col * colW + 1.5;

      if (top > _rowH * _hours || top + height < 0) return const SizedBox.shrink();

      return Positioned(
        top: top,
        left: left,
        width: colW - 3,
        height: height,
        child: _EventBlock(event: event),
      );
    }).toList();
  }
}

// ─────────────────────────────────────────────────────────────
// Event block
// ─────────────────────────────────────────────────────────────
class _EventBlock extends StatelessWidget {
  final PlanEvent event;
  const _EventBlock({required this.event});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: event.color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(6),
        border: Border(left: BorderSide(color: event.color, width: 3)),
      ),
      padding: const EdgeInsets.fromLTRB(5, 3, 3, 3),
      child: Text(
        event.title,
        style: TextStyle(
          color: event.color,
          fontSize: 8.5,
          fontWeight: FontWeight.w700,
          height: 1.3,
        ),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}