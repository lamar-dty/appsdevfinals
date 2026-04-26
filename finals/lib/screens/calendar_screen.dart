import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../widgets/calendar/weekly_planner_calendar.dart';
import '../widgets/calendar/task_home_sheet.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  static const double _snapPeek = 0.20;
  static const double _snapHalf = 0.50;
  static const double _snapFull = 1.0;

  late DraggableScrollableController _sheetController;
  final ScrollController _calendarScrollController = ScrollController();

  // Tracks the sheet's current fractional size so we can
  // pad the background scroll area to always show all content.
  double _sheetSize = _snapPeek;

  @override
  void initState() {
    super.initState();
    _sheetController = DraggableScrollableController();
    _sheetController.addListener(_onSheetSizeChanged);
  }

  void _onSheetSizeChanged() {
    if (!mounted) return;
    setState(() => _sheetSize = _sheetController.size);
  }

  @override
  void dispose() {
    _sheetController.removeListener(_onSheetSizeChanged);
    _sheetController.dispose();
    _calendarScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    // Extra bottom padding = how much of the screen the sheet currently covers.
    // This lets the user always scroll the calendar fully into view.
    final sheetHeightPx = screenHeight * _sheetSize;

    return Stack(
      children: [
        // ── CALENDAR BACKGROUND ──────────────────────────────
        // Padded so content is never permanently hidden behind the sheet.
        Positioned.fill(
          child: SingleChildScrollView(
            controller: _calendarScrollController,
            physics: const ClampingScrollPhysics(),
            child: Padding(
              // Add bottom padding equal to the current sheet height so the
              // user can always scroll every row of the weekly grid into view.
              padding: EdgeInsets.only(bottom: sheetHeightPx),
              child: const WeeklyPlannerCalendar(),
            ),
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
              // Only the sheet's own scroll controller is attached here.
              // Touches above the sheet naturally fall through to the
              // background SingleChildScrollView.
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