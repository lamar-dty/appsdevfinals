import 'package:flutter/material.dart';
import '../../constants/colors.dart';
import '../../models/space.dart';

// ─────────────────────────────────────────────────────────────
// Sheet A: spaces list
// ─────────────────────────────────────────────────────────────
class SpacesSheet extends StatefulWidget {
  final List<Space> spaces;
  final void Function(Space) onSpaceTap;
  final VoidCallback onAdd;
  final VoidCallback onJoin;
  final void Function(Space) onDelete;
  final int inProgress;
  final int completed;
  final int notStarted;

  const SpacesSheet({
    super.key,
    required this.spaces,
    required this.onSpaceTap,
    required this.onAdd,
    required this.onJoin,
    required this.onDelete,
    required this.inProgress,
    required this.completed,
    required this.notStarted,
  });

  @override
  State<SpacesSheet> createState() => _SpacesSheetState();
}

class _SpacesSheetState extends State<SpacesSheet> {
  String? _activeFilter;

  List<Space> get _filteredSpaces {
    if (_activeFilter == null) return widget.spaces;
    return widget.spaces.where((s) => s.status == _activeFilter).toList();
  }

  void _setFilter(String? filter) => setState(() => _activeFilter = filter);

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredSpaces;

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
              GestureDetector(
                onTap: widget.onJoin,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: const BoxDecoration(
                    color: kNavyDark,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add_rounded, color: kWhite, size: 18),
                ),
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
              SpaceFilterChip(
                label: 'All',
                count: widget.spaces.length,
                color: kNavyDark,
                isActive: _activeFilter == null,
                onTap: () => _setFilter(null),
              ),
              const SizedBox(width: 8),
              SpaceFilterChip(
                label: 'In Progress',
                count: widget.inProgress,
                color: const Color(0xFF4A90D9),
                isActive: _activeFilter == 'In Progress',
                onTap: () => _setFilter('In Progress'),
              ),
              const SizedBox(width: 8),
              SpaceFilterChip(
                label: 'Not Started',
                count: widget.notStarted,
                color: const Color(0xFFB0BAD3),
                isActive: _activeFilter == 'Not Started',
                onTap: () => _setFilter('Not Started'),
              ),
              const SizedBox(width: 8),
              SpaceFilterChip(
                label: 'Completed',
                count: widget.completed,
                color: const Color(0xFF3BBFA3),
                isActive: _activeFilter == 'Completed',
                onTap: () => _setFilter('Completed'),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Space cards or empty state
        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.group_work_outlined,
                      size: 60, color: kNavyDark.withOpacity(0.1)),
                  const SizedBox(height: 14),
                  Text(
                    _activeFilter == null
                        ? 'No spaces yet'
                        : 'No $_activeFilter spaces',
                    style: TextStyle(
                        color: kNavyDark.withOpacity(0.4),
                        fontSize: 15,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _activeFilter == null
                        ? 'Tap + to create your first space'
                        : 'Try a different filter',
                    style: TextStyle(
                        color: kNavyDark.withOpacity(0.25), fontSize: 13),
                  ),
                ],
              ),
            ),
          )
        else ...[
          ...filtered.map((s) => SpaceCard(
                space: s,
                onTap: () => widget.onSpaceTap(s),
                onDelete: s.isCreator ? () => widget.onDelete(s) : null,
              )),
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
// Space card
// ─────────────────────────────────────────────────────────────
class SpaceCard extends StatelessWidget {
  final Space space;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const SpaceCard({
    super.key,
    required this.space,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final daysLeft = space.daysLeft;
    final isUrgent = !space.isCompleted && daysLeft >= 0 && daysLeft <= 2;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onDelete,
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

                      // Meta row
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
                          if (isUrgent) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color:
                                    const Color(0xFFE87070).withOpacity(0.12),
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
// Filter chip
// ─────────────────────────────────────────────────────────────
class SpaceFilterChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final bool isActive;
  final VoidCallback onTap;

  const SpaceFilterChip({
    super.key,
    required this.label,
    required this.count,
    required this.color,
    required this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? color : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: TextStyle(
                    color: isActive ? kWhite : color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
            const SizedBox(width: 5),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
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
      ),
    );
  }
}