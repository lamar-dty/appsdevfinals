import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../widgets/calendar/weekly_planner_calendar.dart';
import '../widgets/calendar/task_home_sheet.dart';
import '../store/task_store.dart';

class CalendarScreen extends StatefulWidget {
  final int calStartHour;
  final int calEndHour;
  final void Function(int start, int end) onRangeChanged;
  final ValueNotifier<int> tabNotifier;

  const CalendarScreen({
    super.key,
    required this.calStartHour,
    required this.calEndHour,
    required this.onRangeChanged,
    required this.tabNotifier,
  });

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  static const double _snapPeek = 0.20;
  static const double _snapHalf = 0.50;
  static const double _snapFull = 1.0;

  late DraggableScrollableController _sheetController;

  double _sheetSize = _snapPeek;

  @override
  void initState() {
    super.initState();
    _sheetController = DraggableScrollableController();
    _sheetController.addListener(_onSheetSizeChanged);
    widget.tabNotifier.addListener(_onTabChanged);
    TaskStore.instance.addListener(_onStoreChanged);
  }

  void _onSheetSizeChanged() {
    if (!mounted) return;
    setState(() => _sheetSize = _sheetController.size);
  }

  // Collapse sheet when navigating away from Calendar tab (index 1).
  void _onTabChanged() {
    if (!mounted) return;
    if (widget.tabNotifier.value == 1) return; // staying on calendar — no-op
    if (!_sheetController.isAttached) return;
    _sheetController.animateTo(
      _snapPeek,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _onStoreChanged() {
    if (!mounted) return;
    // When a task open is requested, expand the sheet to half so the
    // TaskHomeSheet is visible before it opens the detail modal.
    if (TaskStore.instance.pendingOpenTaskId != null) {
      _sheetController.animateTo(
        _snapHalf,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _sheetController.removeListener(_onSheetSizeChanged);
    _sheetController.dispose();
    widget.tabNotifier.removeListener(_onTabChanged);
    TaskStore.instance.removeListener(_onStoreChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final sheetHeightPx = screenHeight * _sheetSize;

    return Stack(
      children: [
        // ── CALENDAR BACKGROUND ──────────────────────────────
        Positioned.fill(
          child: WeeklyPlannerCalendar(
            peekHeight: sheetHeightPx,
            startHour: widget.calStartHour,
            endHour: widget.calEndHour,
            onRangeChanged: widget.onRangeChanged,
          ),
        ),

        // ── DRAGGABLE TASK SHEET ─────────────────────────────
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
                child: const TaskHomeSheet(),
              ),
            );
          },
        ),
      ],
    );
  }
}