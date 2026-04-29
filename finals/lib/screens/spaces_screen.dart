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
import '../store/auth_store.dart';

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
  void didChangeDependencies() {
    super.didChangeDependencies();

    // ── Step 1: Drain deletion notices FIRST.
    // If the creator deleted a space while this user was away, remove it
    // from the local list immediately and fire the in-app notification so
    // the user sees it in their notification panel.
    SpaceStore.instance.drainDeletionNotices().then((removedCodes) async {
      if (removedCodes.isEmpty) return;
      // ① Drain the shared inbox FIRST so the spaceDeleted notification is
      //    already in _notifications before clearSpaceNotifications runs.
      //    Reversing this order would wipe the notification before the user
      //    ever sees it (clearSpaceNotifications preserves spaceDeleted now,
      //    but draining first is still the safer, intention-revealing order).
      await TaskStore.instance.drainSharedInbox();
      for (final code in removedCodes) {
        // ② Clean up operational notifications (task alerts, chat, deadlines)
        //    for each removed space. spaceDeleted-type entries are preserved.
        SpaceChatStore.instance.deleteMessagesFor(code);
        TaskStore.instance.clearSpaceNotifications(code);
      }
      if (mounted) setState(() {});
    });

    // ── Step 2: Pull latest patches for spaces that still exist.
    SpaceStore.instance.syncFromSharedPatches().then((_) {
      if (mounted) setState(() {});
    });

    // ── Step 3: Accept any new space invites pushed to this user.
    SpaceStore.instance.drainPendingInvites().then((_) {
      if (mounted) setState(() {});
    });

    // ── Step 4: Drain remaining cross-user notifications (assignments etc).
    TaskStore.instance.drainSharedInbox();

    // ── Step 5: Prune stale notifications for any already-removed spaces.
    TaskStore.instance.pruneOrphanedSpaceNotifications(
      SpaceStore.instance.activeInviteCodes,
    );
  }

  @override
  void dispose() {
    _sheetController.dispose();
    _switchAnim.dispose();
    super.dispose();
  }

  // ── Public entry point for create_space_sheet ──────────────
  Future<void> addSpace(SpaceResult result) async {
    final space = _spaceFromResult(result);
    await SpaceStore.instance.addSpace(space);
    setState(() {});
    // Notify: space created + schedule deadline alerts for any pre-loaded tasks.
    TaskStore.instance.notifySpaceCreated(space);
    TaskStore.instance.generateSpaceTaskDeadlineAlerts(space);
    // Push a pending invite to every member added at creation time so their
    // device receives the space on next drainPendingInvites().
    await _pushInvitesToAddedMembers(space);
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
  void _saveSpaces() => SpaceStore.instance.save();

  void _deleteTask(Space space, SpaceTask task) {
    setState(() {
      space.tasks.remove(task);
      space.recalculate();
    });
    _saveSpaces();
  }

  void _reorderTask(Space space, int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final task = space.tasks.removeAt(oldIndex);
      space.tasks.insert(newIndex, task);
    });
    _saveSpaces();
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
    _saveSpaces();

    // Notify: task added + check deadline alerts for it.
    TaskStore.instance.notifySpaceTaskAdded(space, task);
    TaskStore.instance.refreshDeadlineAlertFor(space, task);
  }

  // ── Space mutations ────────────────────────────────────────
  Future<void> _removeSpace(Space space) async {
    if (!space.isCreator) {
      final leavingName = AuthStore.instance.displayName;
      // Strip the leaver from every task's assignedTo list and write the
      // cleaned state to shared patches so other members see it on next sync.
      for (final task in space.tasks) {
        task.assignedTo.remove(leavingName);
      }
      space.members.remove(leavingName);
      await SpaceStore.instance.writeSharedPatchForLeave(space);
      // Notify remaining members that someone left.
      await TaskStore.instance.notifyMemberLeft(space, leavingName);
    }
    TaskStore.instance.clearSpaceNotifications(space.inviteCode);
    SpaceChatStore.instance.deleteMessagesFor(space.inviteCode);

    if (space.isCreator) {
      // Push a deletion notification to every member BEFORE removeSpace()
      // wipes the member list from the registry, while we still have it.
      for (final memberName in space.members) {
        final cleaned = memberName
            .replaceAll(RegExp(r'\s*\(Creator\)\s*$'), '')
            .trim();
        if (cleaned.isEmpty) continue;
        final memberId = AuthStore.instance.userIdForName(cleaned);
        if (memberId == null || memberId.isEmpty) continue;
        await TaskStore.instance.notifySpaceDeletedForMember(
          spaceName:   space.name,
          creatorName: space.creatorName,
          accentColor: space.accentColor,
          inviteCode:  space.inviteCode,
          memberUserId: memberId,
        );
      }
    }

    await SpaceStore.instance.removeSpace(space);
    // Prune any inbox/deadline notifications that referenced this space
    // (or other already-deleted spaces) so ghost entries don't persist.
    TaskStore.instance.pruneOrphanedSpaceNotifications(
      SpaceStore.instance.activeInviteCodes,
    );
    setState(() {
      if (_selectedSpace == space) _selectedSpace = null;
    });
  }

  // ── Dialog bridges ─────────────────────────────────────────
  void _onTaskTapped(Space space, SpaceTask task) {
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
          _saveSpaces();

          if (task.status == 'Completed') {
            TaskStore.instance.notifySpaceTaskCompleted(space, task);
          } else {
            TaskStore.instance.notifySpaceTaskStatusChanged(space, task);
          }
          TaskStore.instance.refreshDeadlineAlertFor(space, task);
        },
        onAssign: (members) {
          setState(() => task.assignedTo = members);
          _saveSpaces();
          TaskStore.instance.notifySpaceTaskAssigned(space, task, currentUser); // async — fire and forget
        },
        onUpdateNotes: (notes) {
          setState(() => task.description = notes);
          _saveSpaces();
        },
        onUpdateTitle: (title) {
          setState(() => task.title = title);
          _saveSpaces();
        },
        onAddAttachment: (name) {
          setState(() => task.attachments.add(SpaceAttachment(name: name)));
          _saveSpaces();
        },
        onRemoveAttachment: (a) {
          setState(() => task.attachments.remove(a));
          _saveSpaces();
        },
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
        currentUser: currentUser,
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
          // Remove by raw display name AND the " (Creator)" sentinel variant
          // so that whichever label is stored in members / assignedTo is caught.
          final strippedMember =
              member.replaceAll(RegExp(r'\s*\(Creator\)\s*$'), '').trim();
          space.members.removeWhere((m) {
            final stripped = m.replaceAll(RegExp(r'\s*\(Creator\)\s*$'), '').trim();
            return stripped == strippedMember;
          });
          SpaceChatStore.instance.addSystemMessage(
            space.inviteCode,
            '$member was removed from the space.',
          );
          for (final task in space.tasks) {
            task.assignedTo.removeWhere((a) {
              final stripped = a.replaceAll(RegExp(r'\s*\(Creator\)\s*$'), '').trim();
              return stripped == strippedMember;
            });
          }
          // Prune any remaining stale assignee references from ALL tasks.
          space.pruneStaleAssignees();
          space.recalculate();
        });
        _saveSpaces();

        // Notify: member removed.
        TaskStore.instance.notifyMemberRemoved(space, member);
      },
    );
  }

  void _onJoinSpace() {
    showJoinSpaceDialog(
      context,
      isAlreadyJoined: (code) => _spaces.any((s) => s.inviteCode == code),
      onJoin: (code) async {
        if (code == '00000000') {
          // ── Demo space ──────────────────────────────────
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
            creatorName: 'Alex',
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
          await SpaceStore.instance.addSpace(newSpace);
          setState(() {});
          TaskStore.instance.notifySpaceJoined(newSpace);
          TaskStore.instance.generateSpaceTaskDeadlineAlerts(newSpace);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _seedFinalThesisChat(newSpace.inviteCode);
            SpaceChatStore.instance.addSystemMessage(
              newSpace.inviteCode,
              'You joined the space.',
            );
          });
          return;
        }

        // ── Real invite code — look up in global registry ──
        final found = await SpaceStore.instance.lookupByCode(code);
        if (found == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No space found with that invite code.')),
            );
          }
          return;
        }

        // Add to this user's space list as a non-creator member.
        final joined = Space(
          name: found.name,
          description: found.description,
          dateRange: found.dateRange,
          dueDate: found.dueDate,
          members: List<String>.from(found.members)
            ..add(AuthStore.instance.displayName),
          isCreator: false,
          creatorName: found.creatorName,
          status: found.status,
          statusColor: found.statusColor,
          accentColor: found.accentColor,
          progress: found.progress,
          completedTasks: found.completedTasks,
          tasks: found.tasks,
          inviteCode: found.inviteCode,
        );

        await SpaceStore.instance.addSpace(joined);
        // Patch the global registry member list so the creator sees the new joiner.
        await SpaceStore.instance.patchMembersInRegistry(
          joined.inviteCode,
          joined.members,
        );
        setState(() {});
        TaskStore.instance.notifySpaceJoined(joined);
        // Push a notification to the creator's inbox so they see the new member.
        await TaskStore.instance.notifyMemberJoined(
          joined,
          AuthStore.instance.displayName,
          joined.creatorName,
        );
        TaskStore.instance.generateSpaceTaskDeadlineAlerts(joined);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          SpaceChatStore.instance.addSystemMessage(
            joined.inviteCode,
            '${AuthStore.instance.displayName} joined the space.',
          );
        });
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
    showCreateSpaceSheet(context, onSaved: (result) async {
      final space = _spaceFromResult(result);
      await SpaceStore.instance.addSpace(space);
      setState(() {});
      SpaceChatStore.instance.addSystemMessage(
        space.inviteCode,
        '${space.members.isNotEmpty ? space.members.first : "You"} created the space.',
      );
      // Notify: space created + schedule any pre-loaded task deadline alerts.
      TaskStore.instance.notifySpaceCreated(space);
      TaskStore.instance.generateSpaceTaskDeadlineAlerts(space);
      // Push a pending invite to every member added at creation time so their
      // device receives the space on next drainPendingInvites().
      await _pushInvitesToAddedMembers(space);
    });
  }

  // ── Factory ────────────────────────────────────────────────
  /// Pushes a pending invite into the SharedPreferences inbox of every member
  /// that was added to [space] at creation time (i.e. everyone except the
  /// creator). Their device drains the inbox via drainPendingInvites() the
  /// next time SpacesScreen mounts or regains focus.
  Future<void> _pushInvitesToAddedMembers(Space space) async {
    final creatorName = AuthStore.instance.displayName;
    for (final memberName in space.members) {
      // Skip the creator's own entry and any sentinel strings.
      final cleaned = memberName
          .replaceAll(RegExp(r'\s*\(Creator\)\s*$'), '')
          .trim();
      if (cleaned == creatorName || cleaned == 'You' || cleaned.isEmpty) {
        continue;
      }
      // Resolve display name → userId so we know which inbox key to write to.
      final recipientId = AuthStore.instance.userIdForName(cleaned);
      if (recipientId == null || recipientId.isEmpty) continue;
      // 1. Push the space itself into their pending-invite inbox.
      await SpaceStore.instance.pushPendingInvite(recipientId, space);
      // 2. Push a notification so they see an alert in their inbox.
      await TaskStore.instance.notifyAddedToSpace(space, cleaned, recipientId);
    }
  }

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
      creatorName: AuthStore.instance.displayName,
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

  /// Returns the raw display name for the current user (never a sentinel).
  ///
  /// Always returns AuthStore.instance.displayName — the actual account name.
  /// Do NOT return sentinel strings like 'You' or 'You (Creator)' here.
  ///
  /// TaskStore._resolveAssigneeName() handles all sentinel translation
  /// internally when computing notification recipients, so the store always
  /// receives the raw name and performs its own normalisation. Passing a
  /// sentinel string here would bypass that logic and produce missed or
  /// duplicate notifications.
  String _resolvedCurrentUser(Space space) => AuthStore.instance.displayName;

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