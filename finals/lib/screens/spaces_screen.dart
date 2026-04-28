import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../models/space.dart';
import '../models/space_message.dart';
import '../store/space_chat_store.dart';
import '../store/task_store.dart';                // ← Step 3: notification wiring
import '../widgets/create_space_sheet.dart';
import '../widgets/spaces/space_painters.dart';
import '../widgets/spaces/space_summary_background.dart';
import '../widgets/spaces/spaces_list_sheet.dart';
import '../widgets/spaces/space_detail_sheet.dart';
import '../widgets/spaces/space_dialogs.dart';
import '../widgets/spaces/space_chat_fab.dart';
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
      final space = _spaceFromResult(result);
      SpaceStore.instance.addSpace(space);

      // Notify: space created + schedule deadline alerts for any pre-loaded tasks.
      TaskStore.instance.notifySpaceCreated(space);
      TaskStore.instance.generateSpaceTaskDeadlineAlerts(space);
    });
  }

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
    final task = SpaceTask(
      title: title,
      description: note,
      status: 'Not Started',
      statusColor: const Color(0xFFB0BAD3),
    );
    setState(() {
      space.tasks.add(task);
      space.recalculate();
    });

    // Notify: task added + check deadline alerts for it.
    TaskStore.instance.notifySpaceTaskAdded(space, task);
    TaskStore.instance.refreshDeadlineAlertFor(space, task);
  }

  // ── Space mutations ────────────────────────────────────────
  void _removeSpace(Space space) {
    // Remove all notifications that belong to this space before removing the
    // space itself, so the notification centre doesn't show orphaned cards.
    TaskStore.instance.clearSpaceNotifications(space.inviteCode);
    setState(() {
      SpaceStore.instance.removeSpace(space);
      if (_selectedSpace == space) _selectedSpace = null;
    });
  }

  // ── Dialog bridges ─────────────────────────────────────────
  void _onTaskTapped(Space space, SpaceTask task) {
    // Snapshot the current user for this space.
    final currentUser = _resolvedCurrentUser(space);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (sheetCtx) => TaskDetailSheet(
        task: task,
        space: space,
        onCycleStatus: () {
          setState(() {
            task.cycleStatus();
            space.recalculate();
          });

          // Notify: status changed or completed.
          if (task.status == 'Completed') {
            TaskStore.instance.notifySpaceTaskCompleted(space, task);
          } else {
            TaskStore.instance.notifySpaceTaskStatusChanged(space, task);
          }
          // Refresh deadline alert in case it is now complete.
          TaskStore.instance.refreshDeadlineAlertFor(space, task);
        },
        onAssign: (members) {
          setState(() => task.assignedTo = members);
          // Notify: current user was assigned.
          TaskStore.instance.notifySpaceTaskAssigned(space, task, currentUser);
        },
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
      onConfirm: () {
        setState(() {
          space.members.remove(member);
          SpaceChatStore.instance.addSystemMessage(
            space.inviteCode,
            '$member was removed from the space.',
          );
          for (final task in space.tasks) {
            task.assignedTo.remove(member);
          }
        });

        // Notify: member removed.
        TaskStore.instance.notifyMemberRemoved(space, member);
      },
    );
  }

  void _onJoinSpace() {
    showJoinSpaceDialog(
      context,
      isAlreadyJoined: (code) => _spaces.any((s) => s.inviteCode == code),
      onJoin: (code) {
        if (code == '00000000') {
          final newSpace = Space(
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
            ],
            inviteCode: '00000000',
          );
          setState(() => SpaceStore.instance.addSpace(newSpace));

          // Notify: joined + schedule deadline alerts.
          TaskStore.instance.notifySpaceJoined(newSpace);
          TaskStore.instance.generateSpaceTaskDeadlineAlerts(newSpace);

          WidgetsBinding.instance.addPostFrameCallback((_) {
            // Seed history first so it sits below older timestamps,
            // then append the join message so it appears at the bottom.
            _seedFinalThesisChat(newSpace.inviteCode);
            SpaceChatStore.instance.addSystemMessage(
              newSpace.inviteCode,
              'You joined the space.',
            );
          });
        }
      },
    );
  }

  // ── Demo chat seed ─────────────────────────────────────────
  void _seedFinalThesisChat(String inviteCode) {
    final store = SpaceChatStore.instance;

    final existing = store.messagesFor(inviteCode);
    final hasRealMessages = existing.any((m) => !m.isSystemMessage);
    if (hasRealMessages) return;

    final now = DateTime.now();

    DateTime t(int daysAgo, int hour, int minute) => DateTime(
          now.year,
          now.month,
          now.day - daysAgo,
          hour,
          minute,
        );

    // ── Day –3 ──────────────────────────────────────────────
    store.addMessage(inviteCode, SpaceMessage(
      sender: 'Alex (Creator)',
      text: 'Hey team! I just set up the workspace. '
          'We have exactly a month before the defense — let\'s stay on top of this 💪',
      timestamp: t(3, 9, 5),
    ));
    store.addMessage(inviteCode, SpaceMessage(
      sender: 'John',
      text: 'Sounds good. What\'s the plan for dividing the chapters?',
      timestamp: t(3, 9, 18),
    ));
    store.addMessage(inviteCode, SpaceMessage(
      sender: 'Alex (Creator)',
      text: 'I\'ll handle Chapter 1 (intro + background) together with Mika. '
          'John, can you own the presentation slides once we have a draft?',
      timestamp: t(3, 9, 22),
    ));
    store.addMessage(inviteCode, SpaceMessage(
      sender: 'John',
      text: 'Sure, I\'m good at slides. Just send me the outline when it\'s ready.',
      timestamp: t(3, 9, 25),
    ));
    store.addMessage(inviteCode, SpaceMessage(
      sender: 'Mika',
      text: 'Hi everyone! Just accepted the invite. '
          'Alex I already started skimming the related literature, '
          'I\'ll share my notes later today.',
      timestamp: t(3, 10, 47),
    ));
    store.addMessage(inviteCode, SpaceMessage(
      sender: 'Alex (Creator)',
      text: 'Perfect Mika, that\'s exactly what we need first. Thank you!',
      timestamp: t(3, 10, 50),
    ));

    // ── Day –2 ──────────────────────────────────────────────
    store.addMessage(inviteCode, SpaceMessage(
      sender: 'Mika',
      text: 'Okay sharing my lit review notes now — '
          'found 3 really strong papers that back up our thesis statement.',
      timestamp: t(2, 11, 3),
    ));
    store.addMessage(inviteCode, SpaceMessage(
      sender: 'Alex (Creator)',
      text: 'These are great, Mika 🙌 I\'ll weave them into Chapter 1 tonight.',
      timestamp: t(2, 11, 15),
    ));
    store.addMessage(inviteCode, SpaceMessage(
      sender: 'John',
      text: 'Quick question — are we using APA or IEEE citation style?',
      timestamp: t(2, 13, 30),
    ));
    store.addMessage(inviteCode, SpaceMessage(
      sender: 'Alex (Creator)',
      text: 'APA 7th edition. Our adviser specified that in the guidelines doc.',
      timestamp: t(2, 13, 35),
    ));
    store.addMessage(inviteCode, SpaceMessage(
      sender: 'John',
      text: 'Got it, thanks. I\'ll make sure the references slide matches.',
      timestamp: t(2, 13, 36),
    ));
    store.addMessage(inviteCode, SpaceMessage(
      sender: 'Mika',
      text: 'Also — should the background section cover the local context '
          'or just global studies?',
      timestamp: t(2, 15, 12),
    ));
    store.addMessage(inviteCode, SpaceMessage(
      sender: 'Alex (Creator)',
      text: 'Both, but prioritise local. Our panel loves seeing '
          'Philippine-context research.',
      timestamp: t(2, 15, 20),
    ));

    // ── Day –1 ──────────────────────────────────────────────
    store.addMessage(inviteCode, SpaceMessage(
      sender: 'Alex (Creator)',
      text: 'Chapter 1 first draft is done ✅ '
          'Uploading to the shared drive now. Please review before tomorrow.',
      timestamp: t(1, 9, 0),
    ));
    store.addMessage(inviteCode, SpaceMessage(
      sender: 'Mika',
      text: 'Read it! Flow is solid. '
          'I left two comments on the problem statement — minor wording things.',
      timestamp: t(1, 11, 44),
    ));
    store.addMessage(inviteCode, SpaceMessage(
      sender: 'Alex (Creator)',
      text: 'Thanks Mika, fixing those now.',
      timestamp: t(1, 11, 50),
    ));
    store.addMessage(inviteCode, SpaceMessage(
      sender: 'John',
      text: 'Just finished the slide skeleton — title, agenda, problem statement, '
          'and a placeholder for the methodology. '
          'Will flesh out the rest once Ch.1 is finalised.',
      timestamp: t(1, 14, 22),
    ));
    store.addMessage(inviteCode, SpaceMessage(
      sender: 'Mika',
      text: 'Looking sharp John 👍 maybe add a timeline slide near the end?',
      timestamp: t(1, 14, 35),
    ));
    store.addMessage(inviteCode, SpaceMessage(
      sender: 'John',
      text: 'Good call, adding it now.',
      timestamp: t(1, 14, 38),
    ));
    store.addMessage(inviteCode, SpaceMessage(
      sender: 'Alex (Creator)',
      text: 'Great progress everyone. Let\'s sync tomorrow morning '
          'and do a full run-through. 10am work for both of you?',
      timestamp: t(1, 17, 5),
    ));
    store.addMessage(inviteCode, SpaceMessage(
      sender: 'John',
      text: '10am works for me ✅',
      timestamp: t(1, 17, 10),
    ));
    store.addMessage(inviteCode, SpaceMessage(
      sender: 'Mika',
      text: '10am works! See you both then 🙂',
      timestamp: t(1, 17, 14),
    ));
  }

  void _onAddSpace() {
    showCreateSpaceSheet(context, onSaved: (result) {
      final space = _spaceFromResult(result);
      setState(() {
        SpaceStore.instance.addSpace(space);
        SpaceChatStore.instance.addSystemMessage(
          space.inviteCode,
          '${space.members.isNotEmpty ? space.members.first : "You"} created the space.',
        );
      });

      // Notify: space created + schedule any pre-loaded task deadline alerts.
      TaskStore.instance.notifySpaceCreated(space);
      TaskStore.instance.generateSpaceTaskDeadlineAlerts(space);
    });
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

  // ── Helpers ────────────────────────────────────────────────

  /// Returns the display name that represents the current user in this space.
  ///
  /// This MUST match the label that TaskDetailSheet renders on the assign chip
  /// for the current user:
  ///   - creator → 'You (Creator)'
  ///   - member  → 'You'
  ///
  /// notifySpaceTaskAssigned checks task.assignedTo.contains(currentUser),
  /// so any mismatch here causes false "you were assigned" notifications.
  String _resolvedCurrentUser(Space space) =>
      space.isCreator ? 'You (Creator)' : 'You';

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
            child: SpaceChatFab(
              space: space,
              currentUser: _resolvedCurrentUser(space),
            ),
          ),
      ],
    );
  }
}