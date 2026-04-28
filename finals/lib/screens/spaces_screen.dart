import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../models/space.dart';
import '../widgets/create_space_sheet.dart';
import '../widgets/spaces/space_painters.dart';
import '../widgets/spaces/space_summary_background.dart';
import '../widgets/spaces/spaces_list_sheet.dart';
import '../widgets/spaces/space_detail_sheet.dart';
import '../widgets/spaces/space_dialogs.dart';
import '../store/space_store.dart';

// ─────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────
class SpacesScreen extends StatefulWidget {
  const SpacesScreen({super.key});

  @override
  State<SpacesScreen> createState() => SpacesScreenState();
}

class SpacesScreenState extends State<SpacesScreen>
    with SingleTickerProviderStateMixin {
  static const double _snapPeek = 0.20;
  static const double _snapHalf = 0.50;
  static const double _snapFull = 1.0;

  late DraggableScrollableController _sheetController;
  late AnimationController _switchAnim;
  double _sheetSize = _snapPeek;
  Space? _selectedSpace;

List<Space> get _spaces => SpaceStore.instance.spaces;

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
  }

  @override
  void dispose() {
    _sheetController.dispose();
    _switchAnim.dispose();
    super.dispose();
  }

  // ── Public entry point for create_space_sheet ──────────────
  void addSpace(SpaceResult result) {
setState(() {
  SpaceStore.instance.addSpace(
    _spaceFromResult(result),
  );
});  }

  // ── Navigation ─────────────────────────────────────────────
  void _selectSpace(Space space) {
    setState(() => _selectedSpace = space);
    _switchAnim.forward(from: 0);
    _sheetController.animateTo(
      _snapPeek,
      duration: const Duration(milliseconds: 400),
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

  // ── Task mutations ─────────────────────────────────────────
  void _deleteTask(Space space, SpaceTask task) {
    setState(() {
      space.tasks.remove(task);
      space.recalculate();
    });
  }

  void _reorderTask(Space space, int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final task = space.tasks.removeAt(oldIndex);
      space.tasks.insert(newIndex, task);
    });
  }

  void _addTaskToSpace(Space space, String title, String note) {
    setState(() {
      space.tasks.add(SpaceTask(
        title: title,
        description: note,
        status: 'Not Started',
        statusColor: const Color(0xFFB0BAD3),
      ));
      space.recalculate();
    });
  }

  // ── Space mutations ────────────────────────────────────────
  void _removeSpace(Space space) {
    setState(() {
SpaceStore.instance.removeSpace(space);      if (_selectedSpace == space) _selectedSpace = null;
    });
  }

  // ── Dialog bridges ─────────────────────────────────────────
  void _onTaskTapped(Space space, SpaceTask task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (sheetCtx) => TaskDetailSheet(
        task: task,
        space: space,
        onCycleStatus: () => setState(() {
          task.cycleStatus();
          space.recalculate();
        }),
        onAssign: (members) => setState(() => task.assignedTo = members),
        onUpdateNotes: (notes) => setState(() => task.description = notes),
        onUpdateTitle: (title) => setState(() => task.title = title),
        onAddAttachment: (name) =>
            setState(() => task.attachments.add(SpaceAttachment(name: name))),
        onRemoveAttachment: (a) =>
            setState(() => task.attachments.remove(a)),
        onDelete: () {
  showConfirmDeleteTask(
    context,
    task,
    onConfirm: () {
      Navigator.pop(sheetCtx);
      _deleteTask(space, task);
    },
  );
},
      ),
    );
  }

  void _onAddTask(Space space) {
    showAddTaskDialog(
      context,
      space,
      onAdd: (title, note) => _addTaskToSpace(space, title, note),
    );
  }

  void _onAddMember(Space space) {
    showAddMemberDialog(
      context,
      space,
      onMemberAdded: () => setState(() {}),
    );
  }

  void _onDeleteSpace(Space space) {
    showConfirmDeleteSpace(
      context,
      space,
      onConfirm: () => _removeSpace(space),
    );
  }

  void _onLeaveSpace(Space space) {
    showConfirmLeaveSpace(
      context,
      space,
      onConfirm: () => _removeSpace(space),
    );
  }

  void _onKickMember(Space space, String member) {
    showConfirmKickMember(
      context,
      space,
      member,
onConfirm: () => setState(() {
  space.members.remove(member);

  for (final task in space.tasks) {
    task.assignedTo.remove(member);
  }
}),    );
  }

  void _onJoinSpace() {
  showJoinSpaceDialog(
    context,
    isAlreadyJoined: (code) => _spaces.any((s) => s.inviteCode == code),
    onJoin: (code) {
      if (code == '00000000') {
        setState(() {
          SpaceStore.instance.addSpace(
            Space(
              name: 'Final Thesis',
              description: 'Shared workspace for the team.',
              dateRange: '04/29/2026 - 05/29/2026',
              dueDate: '05/29/2026',
              members: [
                'Alex (Creator)',
                'John',
                'Mika',
              ],
              isCreator: false,
              status: 'Not Started',
              statusColor: const Color(0xFFB0BAD3),
              accentColor: const Color(0xFF6C63FF),
              progress: 0,
              completedTasks: 0,
tasks: [
  SpaceTask(
    title: 'Research Chapter 1',
    description: 'Finish the introduction and background study.',
    status: 'In Progress',
    statusColor: const Color(0xFF4A90D9),
    assignedTo: ['Alex (Creator)', 'Mika'],
  ),
  SpaceTask(
    title: 'Prepare Presentation Slides',
    description: 'Create the defense presentation deck.',
    status: 'Not Started',
    statusColor: const Color(0xFFB0BAD3),
    assignedTo: ['John'],
  ),
],              inviteCode: '00000000',
            ),
          );
        });
      }
    },
  );
}

  void _onAddSpace() {
    showCreateSpaceSheet(context, onSaved: (result) {
setState(() {
  SpaceStore.instance.addSpace(
    _spaceFromResult(result),
  );
});    });
  }

  // ── Factory ────────────────────────────────────────────────
  Space _spaceFromResult(SpaceResult r) {
    String fmt(DateTime d) =>
        '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}/${d.year.toString().substring(2)}';

    return Space(
      name: r.name,
      description:
          r.description.isEmpty ? 'No description.' : r.description,
      dateRange: '${fmt(r.startDate)}- ${fmt(r.endDate)}',
      dueDate: '${r.endDate.month}/${r.endDate.day}/${r.endDate.year}',
      members: List<String>.from(r.members),
      isCreator: true,
      status: 'Not Started',
      statusColor: const Color(0xFFB0BAD3),
      accentColor: r.accentColor,
      progress: 0.0,
      completedTasks: 0,
      tasks: r.checklistTitles.asMap().entries.map((e) => SpaceTask(
            title: e.value,
            description: r.checklistNotes.length > e.key
                ? r.checklistNotes[e.key]
                : '',
            status: 'Not Started',
            statusColor: const Color(0xFFB0BAD3),
          )).toList(),
    );
  }

  // ── Computed stats ─────────────────────────────────────────
  int get _inProgressCount =>
      _spaces.where((s) => s.status == 'In Progress').length;
  int get _completedCount =>
      _spaces.where((s) => s.status == 'Completed').length;
  int get _notStartedCount =>
      _spaces.where((s) => s.status == 'Not Started').length;
  double get _overallProgress => _spaces.isEmpty
      ? 0.0
      : _spaces.fold(0.0, (sum, s) => sum + s.progress) / _spaces.length;

  // ── Build ──────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final space = _selectedSpace;

    return Stack(
      children: [
        // Background
        Positioned.fill(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Padding(
              padding: EdgeInsets.only(bottom: screenHeight * _sheetSize),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: space == null
                    ? SummaryBackground(
                        key: const ValueKey('summary'),
                        inProgress: _inProgressCount,
                        completed: _completedCount,
                        notStarted: _notStartedCount,
                        totalSpaces: _spaces.length,
                        overallProgress: _overallProgress,
                      )
                    : SelectedBackground(
                        key: ValueKey(space.name),
                        space: space,
                        onBack: _backToSpaces,
                        onTaskTap: (task) => _onTaskTapped(space, task),
                        onDeleteTask: (task) => _deleteTask(space, task),
                        onAddTask: () => _onAddTask(space),
                        onDelete: () => _onDeleteSpace(space),
                        onLeave: () => _onLeaveSpace(space),
                        onKickMember: (member) => _onKickMember(space, member),
                        onAddMember: () => _onAddMember(space),
                        onReorder: (oldIndex, newIndex) =>
                            _reorderTask(space, oldIndex, newIndex),
                      ),
              ),
            ),
          ),
        ),

        // Draggable sheet
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
                child: SpacesSheet(
                  key: const ValueKey('spacesSheet'),
                  spaces: _spaces,
                  onSpaceTap: _selectSpace,
                  onAdd: _onAddSpace,
                  onJoin: _onJoinSpace,
                  onDelete: _onDeleteSpace,
                  inProgress: _inProgressCount,
                  completed: _completedCount,
                  notStarted: _notStartedCount,
                ),
              ),
            );
          },
        ),

        // Chat FAB
        if (space != null)
          Positioned(
            right: 20,
            bottom: screenHeight * _sheetSize + 16,
            child: const SpaceChatFab(),
          ),
      ],
    );
  }
}