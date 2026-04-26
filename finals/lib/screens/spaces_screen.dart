import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../constants/colors.dart';

// ─────────────────────────────────────────────────────────────
// Data models
// ─────────────────────────────────────────────────────────────
class _SpaceTask {
  final String title;
  final String description;
  final String status;
  final Color statusColor;
  final bool hasAssignee;
  final bool hasAttachment;

  const _SpaceTask({
    required this.title,
    required this.description,
    required this.status,
    required this.statusColor,
    this.hasAssignee = false,
    this.hasAttachment = false,
  });
}

class _Space {
  final String name;
  final String description;
  final String dateRange;
  final String dueDate; // for countdown
  final int memberCount;
  final String status;
  final Color statusColor;
  final Color accentColor;
  final double progress;
  final bool isCompleted;
  final int completedTasks;
  final int totalTasks;
  final List<_SpaceTask> tasks;

  const _Space({
    required this.name,
    required this.description,
    required this.dateRange,
    required this.dueDate,
    required this.memberCount,
    required this.status,
    required this.statusColor,
    required this.accentColor,
    required this.progress,
    required this.completedTasks,
    required this.totalTasks,
    required this.tasks,
    this.isCompleted = false,
  });

  int get daysLeft {
    try {
      final parts = dueDate.split('/');
      final due = DateTime(int.parse(parts[2]), int.parse(parts[0]), int.parse(parts[1]));
      return due.difference(DateTime.now()).inDays;
    } catch (_) {
      return 0;
    }
  }
}

// ─────────────────────────────────────────────────────────────
// Sample data — empty (fresh app state)
// ─────────────────────────────────────────────────────────────
final List<_Space> _kSpaces = [];

// ─────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────
class SpacesScreen extends StatefulWidget {
  const SpacesScreen({super.key});

  @override
  State<SpacesScreen> createState() => _SpacesScreenState();
}

class _SpacesScreenState extends State<SpacesScreen>
    with SingleTickerProviderStateMixin {
  static const double _snapPeek = 0.20;
  static const double _snapHalf = 0.50;
  static const double _snapFull = 1.0;

  late DraggableScrollableController _sheetController;
  late AnimationController _switchAnim;
  double _sheetSize = _snapPeek;
  _Space? _selectedSpace;

  // Sort state
  String _sortBy = 'Status';
  List<_Space> _sorted = [];

  @override
  void initState() {
    super.initState();
    _sheetController = DraggableScrollableController();
    _sheetController.addListener(() {
      if (mounted) setState(() => _sheetSize = _sheetController.size);
    });
    _switchAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _applySort();
  }

  void _applySort() {
    final list = List<_Space>.from(_kSpaces);
    if (_sortBy == 'Status') {
      const order = {'In Progress': 0, 'Not Started': 1, 'Completed': 2};
      list.sort((a, b) => (order[a.status] ?? 3).compareTo(order[b.status] ?? 3));
    } else if (_sortBy == 'Due Date') {
      list.sort((a, b) => a.daysLeft.compareTo(b.daysLeft));
    } else if (_sortBy == 'Progress') {
      list.sort((a, b) => b.progress.compareTo(a.progress));
    }
    _sorted = list;
  }

  void _selectSpace(_Space space) {
    setState(() => _selectedSpace = space);
    _switchAnim.forward(from: 0);
    _sheetController.animateTo(
      _snapHalf,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  void _backToSpaces() {
    setState(() => _selectedSpace = null);
    _switchAnim.reverse();
    _sheetController.animateTo(
      _snapPeek,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  void _showSortSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: kWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SortSheet(
        current: _sortBy,
        onSelect: (val) {
          setState(() {
            _sortBy = val;
            _applySort();
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showAddSpaceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: kWhite,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _AddSpaceSheet(),
    );
  }

  // Summary counts
  int get _inProgressCount =>
      _kSpaces.where((s) => s.status == 'In Progress').length;
  int get _completedCount =>
      _kSpaces.where((s) => s.status == 'Completed').length;
  int get _notStartedCount =>
      _kSpaces.where((s) => s.status == 'Not Started').length;
  double get _overallProgress => _kSpaces.isEmpty
      ? 0.0
      : _kSpaces.fold(0.0, (sum, s) => sum + s.progress) / _kSpaces.length;

  @override
  void dispose() {
    _sheetController.dispose();
    _switchAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final space = _selectedSpace;

    return Stack(
      children: [
        // ── BACKGROUND ───────────────────────────────────────
        Positioned.fill(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Padding(
              padding: EdgeInsets.only(bottom: screenHeight * _sheetSize),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: space == null
                    ? _SummaryBackground(
                        key: const ValueKey('summary'),
                        inProgress: _inProgressCount,
                        completed: _completedCount,
                        notStarted: _notStartedCount,
                        totalSpaces: _kSpaces.length,
                        overallProgress: _overallProgress,
                      )
                    : _SelectedBackground(
                        key: ValueKey(space.name),
                        space: space,
                      ),
              ),
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
                      offset: Offset(0, -4)),
                ],
              ),
              child: SingleChildScrollView(
                controller: scrollController,
                physics: const ClampingScrollPhysics(),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: space == null
                      ? _SpacesSheet(
                          key: const ValueKey('spacesSheet'),
                          spaces: _sorted,
                          sortBy: _sortBy,
                          onSpaceTap: _selectSpace,
                          onSort: _showSortSheet,
                          onAdd: _showAddSpaceDialog,
                          inProgress: _inProgressCount,
                          completed: _completedCount,
                          notStarted: _notStartedCount,
                        )
                      : _TasksSheet(
                          key: ValueKey('tasks_${space.name}'),
                          space: space,
                          onBack: _backToSpaces,
                        ),
                ),
              ),
            );
          },
        ),

        // ── Chat FAB (selected space only) ────────────────────
        if (space != null)
          Positioned(
            right: 20,
            bottom: screenHeight * _sheetSize + 16,
            child: _ChatFab(),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Background A: summary donut + stats
// ─────────────────────────────────────────────────────────────
class _SummaryBackground extends StatelessWidget {
  final int inProgress;
  final int completed;
  final int notStarted;
  final int totalSpaces;
  final double overallProgress;

  const _SummaryBackground({
    super.key,
    required this.inProgress,
    required this.completed,
    required this.notStarted,
    required this.totalSpaces,
    required this.overallProgress,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          const Text('Your Spaces',
              style: TextStyle(
                  color: kWhite, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(
            totalSpaces == 0 ? 'No active projects' : '$totalSpaces active projects',
            style: const TextStyle(color: kSubtitle, fontSize: 13),
          ),

          const SizedBox(height: 20),

          // Donut + legend row
          Row(
            children: [
              // Donut
              SizedBox(
                width: 130,
                height: 130,
                child: CustomPaint(
                  painter: _DonutPainter(
                    inProgress: inProgress,
                    completed: completed,
                    notStarted: notStarted,
                    total: totalSpaces,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${(overallProgress * 100).round()}%',
                          style: const TextStyle(
                              color: kWhite,
                              fontSize: 22,
                              fontWeight: FontWeight.bold),
                        ),
                        const Text('overall',
                            style:
                                TextStyle(color: kSubtitle, fontSize: 10)),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 24),

              // Stats column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StatRow(
                      color: const Color(0xFF4A90D9),
                      label: 'In Progress',
                      count: inProgress,
                      total: totalSpaces,
                    ),
                    const SizedBox(height: 14),
                    _StatRow(
                      color: const Color(0xFFB0BAD3),
                      label: 'Not Started',
                      count: notStarted,
                      total: totalSpaces,
                    ),
                    const SizedBox(height: 14),
                    _StatRow(
                      color: const Color(0xFF3BBFA3),
                      label: 'Completed',
                      count: completed,
                      total: totalSpaces,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final Color color;
  final String label;
  final int count;
  final int total;

  const _StatRow({
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
                        BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text(label,
                    style:
                        const TextStyle(color: kSubtitle, fontSize: 11)),
              ],
            ),
            Text('$count/$total',
                style: const TextStyle(
                    color: kWhite,
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
            backgroundColor: kWhite.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Background B: selected space gauge + info
// ─────────────────────────────────────────────────────────────
class _SelectedBackground extends StatelessWidget {
  final _Space space;
  const _SelectedBackground({super.key, required this.space});

  @override
  Widget build(BuildContext context) {
    final daysLeft = space.daysLeft;
    final daysLabel = space.isCompleted
        ? 'Completed'
        : daysLeft < 0
            ? 'Overdue'
            : daysLeft == 0
                ? 'Due today'
                : '$daysLeft days left';
    final daysColor = space.isCompleted
        ? const Color(0xFF3BBFA3)
        : daysLeft <= 2
            ? const Color(0xFFE87070)
            : kSubtitle;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Gauge
          Center(
            child: SizedBox(
              width: 240,
              height: 135,
              child: CustomPaint(
                painter: _SemiGaugePainter(
                  completed: space.completedTasks,
                  total: space.totalTasks,
                  accentColor: space.accentColor,
                ),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(children: [
                            TextSpan(
                              text: '${space.completedTasks} ',
                              style: const TextStyle(
                                  color: kWhite,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold),
                            ),
                            const TextSpan(
                              text: 'out of ',
                              style: TextStyle(
                                  color: kSubtitle, fontSize: 14),
                            ),
                            TextSpan(
                              text: '${space.totalTasks}',
                              style: const TextStyle(
                                  color: kWhite,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold),
                            ),
                          ]),
                        ),
                        const Text('Tasks Completed',
                            style: TextStyle(
                                color: kSubtitle, fontSize: 11)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Space name + due date badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  space.name,
                  style: const TextStyle(
                      color: kWhite,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: daysColor.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: daysColor.withOpacity(0.4)),
                ),
                child: Text(daysLabel,
                    style: TextStyle(
                        color: daysColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),

          const SizedBox(height: 6),
          Text(space.description,
              style: const TextStyle(color: kSubtitle, fontSize: 12)),

          const SizedBox(height: 10),

          // Meta row
          Row(
            children: [
              const Icon(Icons.access_time_rounded,
                  color: kSubtitle, size: 13),
              const SizedBox(width: 4),
              Text(space.dateRange,
                  style:
                      const TextStyle(color: kSubtitle, fontSize: 12)),
              const SizedBox(width: 16),
              const Icon(Icons.group_rounded, color: kSubtitle, size: 13),
              const SizedBox(width: 4),
              Text('${space.memberCount} People',
                  style:
                      const TextStyle(color: kSubtitle, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Sheet A: Spaces list
// ─────────────────────────────────────────────────────────────
class _SpacesSheet extends StatelessWidget {
  final List<_Space> spaces;
  final String sortBy;
  final void Function(_Space) onSpaceTap;
  final VoidCallback onSort;
  final VoidCallback onAdd;
  final int inProgress;
  final int completed;
  final int notStarted;

  const _SpacesSheet({
    super.key,
    required this.spaces,
    required this.sortBy,
    required this.onSpaceTap,
    required this.onSort,
    required this.onAdd,
    required this.inProgress,
    required this.completed,
    required this.notStarted,
  });

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
            margin: const EdgeInsets.only(top: 12, bottom: 16),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),

        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Your Spaces',
                  style: TextStyle(
                      color: kNavyDark,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              Row(
                children: [
                  // Sort button
                  GestureDetector(
                    onTap: onSort,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F2F8),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.sort_rounded,
                              color: Color(0xFF6B7A99), size: 14),
                          const SizedBox(width: 4),
                          Text(sortBy,
                              style: const TextStyle(
                                  color: Color(0xFF6B7A99),
                                  fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Add button
                  GestureDetector(
                    onTap: onAdd,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: kNavyDark,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.add_rounded,
                          color: kWhite, size: 18),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Quick filter chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              _FilterChip(
                  label: 'All',
                  count: _kSpaces.length,
                  color: kNavyDark,
                  isActive: true),
              const SizedBox(width: 8),
              _FilterChip(
                  label: 'In Progress',
                  count: inProgress,
                  color: const Color(0xFF4A90D9)),
              const SizedBox(width: 8),
              _FilterChip(
                  label: 'Not Started',
                  count: notStarted,
                  color: const Color(0xFFB0BAD3)),
              const SizedBox(width: 8),
              _FilterChip(
                  label: 'Completed',
                  count: completed,
                  color: const Color(0xFF3BBFA3)),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Space cards or empty state
        if (spaces.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.group_work_outlined,
                      size: 60, color: kNavyDark.withOpacity(0.1)),
                  const SizedBox(height: 14),
                  Text('No spaces yet',
                      style: TextStyle(
                          color: kNavyDark.withOpacity(0.4),
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text('Tap + to create your first space',
                      style: TextStyle(
                          color: kNavyDark.withOpacity(0.25),
                          fontSize: 13)),
                ],
              ),
            ),
          )
        else ...[
          ...spaces.map((s) => _SpaceCard(space: s, onTap: () => onSpaceTap(s))),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text('No More Spaces',
                  style: TextStyle(color: Color(0xFFB0BAD3), fontSize: 13)),
            ),
          ),
        ],

        const SizedBox(height: 40),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Sheet B: Tasks for selected space
// ─────────────────────────────────────────────────────────────
class _TasksSheet extends StatelessWidget {
  final _Space space;
  final VoidCallback onBack;
  const _TasksSheet({super.key, required this.space, required this.onBack});

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
            margin: const EdgeInsets.only(top: 12, bottom: 16),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),

        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: onBack,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F2F8),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: kNavyDark, size: 14),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text("Team's Tasks",
                      style: TextStyle(
                          color: kNavyDark,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                ],
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

        const SizedBox(height: 14),

        // Summary strip
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F7FF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _SummaryChip(
                  label: 'Total',
                  value: '${space.totalTasks}',
                  color: kNavyDark,
                ),
                _Divider(),
                _SummaryChip(
                  label: 'Done',
                  value: '${space.completedTasks}',
                  color: const Color(0xFF3BBFA3),
                ),
                _Divider(),
                _SummaryChip(
                  label: 'Progress',
                  value: '${(space.progress * 100).round()}%',
                  color: space.accentColor,
                ),
                _Divider(),
                _SummaryChip(
                  label: 'Members',
                  value: '${space.memberCount}',
                  color: const Color(0xFF9B88E8),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Progress bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Overall Progress',
                      style: TextStyle(
                          color: Color(0xFF6B7A99), fontSize: 12)),
                  Text('${(space.progress * 100).round()}%',
                      style: TextStyle(
                          color: space.accentColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: space.progress,
                  minHeight: 8,
                  backgroundColor: const Color(0xFFEEEEEE),
                  valueColor:
                      AlwaysStoppedAnimation<Color>(space.accentColor),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Task list or empty state
        space.tasks.isEmpty
            ? _EmptyTasks()
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: List.generate(
                    space.tasks.length,
                    (i) => _TaskItem(
                      task: space.tasks[i],
                      isLast: i == space.tasks.length - 1,
                    ),
                  ),
                ),
              ),

        const SizedBox(height: 80),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Space card
// ─────────────────────────────────────────────────────────────
class _SpaceCard extends StatelessWidget {
  final _Space space;
  final VoidCallback onTap;
  const _SpaceCard({required this.space, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final daysLeft = space.daysLeft;
    final isUrgent = !space.isCompleted && daysLeft >= 0 && daysLeft <= 2;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        decoration: BoxDecoration(
          color: kWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isUrgent
                ? const Color(0xFFE87070).withOpacity(0.5)
                : const Color(0xFFEEEEEE),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Colored left border accent
              Container(
                width: 5,
                decoration: BoxDecoration(
                  color: space.accentColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                ),
              ),

              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name + status badge
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(space.name,
                                style: const TextStyle(
                                    color: kNavyDark,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: space.statusColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(space.status,
                                style: TextStyle(
                                    color: space.statusColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // Progress bar + task count
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: space.progress,
                                minHeight: 5,
                                backgroundColor: const Color(0xFFEEEEEE),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    space.accentColor),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '${space.completedTasks}/${space.totalTasks}',
                            style: TextStyle(
                                color: space.accentColor,
                                fontSize: 11,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // Meta
                      Row(
                        children: [
                          const Icon(Icons.access_time_rounded,
                              size: 11, color: Color(0xFF6B7A99)),
                          const SizedBox(width: 3),
                          Text(space.dateRange,
                              style: const TextStyle(
                                  color: Color(0xFF6B7A99), fontSize: 10)),
                          const Spacer(),
                          const Icon(Icons.group_rounded,
                              size: 11, color: Color(0xFF6B7A99)),
                          const SizedBox(width: 3),
                          Text('${space.memberCount}',
                              style: const TextStyle(
                                  color: Color(0xFF6B7A99), fontSize: 10)),
                          // Urgent badge
                          if (isUrgent) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE87070)
                                    .withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                daysLeft == 0
                                    ? 'Due today!'
                                    : '$daysLeft days left!',
                                style: const TextStyle(
                                    color: Color(0xFFE87070),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Arrow
              const Padding(
                padding: EdgeInsets.only(right: 12),
                child: Icon(Icons.arrow_forward_ios_rounded,
                    size: 14, color: Color(0xFFB0BAD3)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Task item with dashed connector
// ─────────────────────────────────────────────────────────────
class _TaskItem extends StatelessWidget {
  final _SpaceTask task;
  final bool isLast;
  const _TaskItem({required this.task, required this.isLast});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 36,
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: task.statusColor.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    task.status == 'Completed'
                        ? Icons.check_circle_rounded
                        : task.status == 'In Progress'
                            ? Icons.access_time_rounded
                            : Icons.radio_button_unchecked_rounded,
                    color: task.statusColor,
                    size: 18,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: CustomPaint(
                      painter:
                          _DashedLinePainter(color: task.statusColor),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(task.title,
                          style: const TextStyle(
                              color: kNavyDark,
                              fontSize: 15,
                              fontWeight: FontWeight.bold)),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: task.statusColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(task.status,
                            style: TextStyle(
                                color: task.statusColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(task.description,
                      style: const TextStyle(
                          color: Color(0xFF6B7A99), fontSize: 12)),
                  if (task.hasAssignee || task.hasAttachment) ...[
                    const SizedBox(height: 8),
                    Row(children: [
                      if (task.hasAssignee) ...[
                        const Icon(Icons.person_outline_rounded,
                            size: 16, color: Color(0xFF6B7A99)),
                        const SizedBox(width: 8),
                      ],
                      if (task.hasAttachment)
                        const Icon(Icons.attach_file_rounded,
                            size: 16, color: Color(0xFF6B7A99)),
                    ]),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Small widgets
// ─────────────────────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final bool isActive;

  const _FilterChip({
    required this.label,
    required this.count,
    required this.color,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isActive ? color : color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Text(label,
              style: TextStyle(
                  color: isActive ? kWhite : color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          const SizedBox(width: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: isActive
                  ? kWhite.withOpacity(0.25)
                  : color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('$count',
                style: TextStyle(
                    color: isActive ? kWhite : color,
                    fontSize: 10,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _SummaryChip(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                color: color, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(color: Color(0xFF6B7A99), fontSize: 10)),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
        width: 1, height: 28, color: const Color(0xFFEEEEEE));
  }
}

class _EmptyTasks extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.task_alt_rounded,
                size: 52, color: kNavyDark.withOpacity(0.12)),
            const SizedBox(height: 12),
            Text('No tasks yet',
                style: TextStyle(
                    color: kNavyDark.withOpacity(0.4),
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('Add the first task for this space',
                style: TextStyle(
                    color: kNavyDark.withOpacity(0.25), fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _ChatFab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: kTeal,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
              color: kTeal.withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child:
          const Icon(Icons.chat_bubble_rounded, color: kWhite, size: 22),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Sort sheet
// ─────────────────────────────────────────────────────────────
class _SortSheet extends StatelessWidget {
  final String current;
  final void Function(String) onSelect;
  const _SortSheet({required this.current, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final options = ['Status', 'Due Date', 'Progress'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Sort by',
              style: TextStyle(
                  color: kNavyDark,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ...options.map((o) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(o,
                    style: const TextStyle(color: kNavyDark, fontSize: 15)),
                trailing: current == o
                    ? const Icon(Icons.check_rounded, color: kTeal)
                    : null,
                onTap: () => onSelect(o),
              )),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Add Space sheet (placeholder UI)
// ─────────────────────────────────────────────────────────────
class _AddSpaceSheet extends StatelessWidget {
  const _AddSpaceSheet();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('New Space',
              style: TextStyle(
                  color: kNavyDark,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          _Field(hint: 'Space name'),
          const SizedBox(height: 12),
          _Field(hint: 'Description', maxLines: 2),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _Field(hint: 'Start date')),
            const SizedBox(width: 12),
            Expanded(child: _Field(hint: 'End date')),
          ]),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: kNavyDark,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Create Space',
                  style: TextStyle(color: kWhite, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String hint;
  final int maxLines;
  const _Field({required this.hint, this.maxLines = 1});

  @override
  Widget build(BuildContext context) {
    return TextField(
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFB0BAD3)),
        filled: true,
        fillColor: const Color(0xFFF5F7FF),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Painters
// ─────────────────────────────────────────────────────────────
class _DonutPainter extends CustomPainter {
  final int inProgress;
  final int completed;
  final int notStarted;
  final int total;

  const _DonutPainter({
    required this.inProgress,
    required this.completed,
    required this.notStarted,
    required this.total,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 14;
    const stroke = 20.0;
    const pi = math.pi;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Grey track ring (always drawn)
    canvas.drawArc(rect, 0, 2 * pi, false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = const Color(0xFFEEEEEE));

    if (total == 0) return;

    void arc(double start, double sweep, Color color) {
      if (sweep <= 0) return;
      canvas.drawArc(rect, start, sweep, false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke
            ..strokeCap = StrokeCap.round
            ..color = color);
    }

    double start = -pi / 2;
    final ipSweep = 2 * pi * (inProgress / total);
    final nsSweep = 2 * pi * (notStarted / total);
    final cSweep = 2 * pi * (completed / total);

    arc(start, ipSweep, const Color(0xFF4A90D9));
    start += ipSweep + 0.05;
    arc(start, nsSweep, const Color(0xFFB0BAD3));
    start += nsSweep + 0.05;
    arc(start, cSweep, const Color(0xFF3BBFA3));
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

class _SemiGaugePainter extends CustomPainter {
  final int completed;
  final int total;
  final Color accentColor;

  const _SemiGaugePainter({
    required this.completed,
    required this.total,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = size.width / 2 - 14;
    const stroke = 24.0;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawArc(rect, math.pi, math.pi, false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..color = kWhite.withOpacity(0.18));

    if (total > 0) {
      final done = math.pi * (completed / total);
      canvas.drawArc(rect, math.pi, done, false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke
            ..strokeCap = StrokeCap.round
            ..color = accentColor);

      canvas.drawArc(rect, math.pi + done, math.pi - done, false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke
            ..strokeCap = StrokeCap.round
            ..color = kTeal);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

class _DashedLinePainter extends CustomPainter {
  final Color color;
  const _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.35)
      ..strokeWidth = 2;
    const dash = 5.0, gap = 4.0;
    double y = 0;
    final x = size.width / 2;
    while (y < size.height) {
      canvas.drawLine(
          Offset(x, y), Offset(x, math.min(y + dash, size.height)), paint);
      y += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}