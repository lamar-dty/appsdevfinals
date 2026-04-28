import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task.dart';
import '../models/event.dart';
import '../models/app_notification.dart';
import '../models/space.dart';
import 'auth_store.dart';

// ─────────────────────────────────────────────────────────────
// Storage keys — scoped per user via AuthStore.scopedKey()
// ─────────────────────────────────────────────────────────────
String get _kTasks         => AuthStore.instance.scopedKey('task_store_tasks');
String get _kEvents        => AuthStore.instance.scopedKey('task_store_events');
String get _kNotifications => AuthStore.instance.scopedKey('task_store_notifications');

// Global shared inbox: userId -> List<AppNotification JSON>
// Any user can push a notification here addressed to another user's ID.
// Each user drains their own inbox on load/focus and moves it to their scoped store.
String _sharedInboxKey(String userId) => 'shared_notifs_$userId';

class TaskStore extends ChangeNotifier {
  TaskStore._();
  static final TaskStore instance = TaskStore._();

  final List<Task>            _tasks         = [];
  final List<Event>           _events        = [];
  final List<AppNotification> _notifications = [];

  List<Task>            get tasks         => List.unmodifiable(_tasks);
  List<Event>           get events        => List.unmodifiable(_events);
  List<AppNotification> get notifications => List.unmodifiable(_notifications);

  // ── Initialisation ────────────────────────────────────────

  /// Call once from main() after WidgetsFlutterBinding.ensureInitialized().
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    final rawTasks = prefs.getString(_kTasks);
    if (rawTasks != null) {
      final list = jsonDecode(rawTasks) as List;
      _tasks.addAll(
        list.map((e) => Task.fromJson(Map<String, dynamic>.from(e as Map))),
      );
    }

    final rawEvents = prefs.getString(_kEvents);
    if (rawEvents != null) {
      final list = jsonDecode(rawEvents) as List;
      _events.addAll(
        list.map((e) => Event.fromJson(Map<String, dynamic>.from(e as Map))),
      );
    }

    final rawNotifs = prefs.getString(_kNotifications);
    if (rawNotifs != null) {
      final list = jsonDecode(rawNotifs) as List;
      _notifications.addAll(
        list.map((e) =>
            AppNotification.fromJson(Map<String, dynamic>.from(e as Map))),
      );
    }

    // Pull any cross-user notifications that were written for this user.
    await _drainSharedInbox(prefs);

    notifyListeners();
  }

  /// Drain the shared inbox for the current user: any notifications pushed
  /// by other users (e.g. task assignments, join alerts) are moved into this
  /// user's local notification list so they appear in the UI.
  Future<void> _drainSharedInbox(SharedPreferences prefs) async {
    final uid = AuthStore.instance.userId;
    if (uid.isEmpty) return;
    final key = _sharedInboxKey(uid);
    final raw = prefs.getString(key);
    if (raw == null) return;
    try {
      final list = jsonDecode(raw) as List;
      bool changed = false;
      for (final e in list) {
        final notif = AppNotification.fromJson(Map<String, dynamic>.from(e as Map));
        // Upsert: remove any stale copy then insert fresh at top.
        // This makes drain idempotent — safe to call multiple times.
        final hadIt = _notifications.any((n) => n.id == notif.id);
        _notifications.removeWhere((n) => n.id == notif.id);
        _notifications.insert(0, notif);
        if (!hadIt) changed = true;
      }
      // Clear the inbox so we don't re-process next time.
      await prefs.remove(key);
      if (changed) await _saveNotifications();
    } catch (_) {
      await prefs.remove(key); // corrupt data — just clear it
    }
  }

  /// Public version so screens can call it on focus (e.g. didChangeDependencies).
  Future<void> drainSharedInbox() async {
    final prefs = await SharedPreferences.getInstance();
    await _drainSharedInbox(prefs);
    // Always notify so the UI reflects inbox items that arrived since last build.
    notifyListeners();
  }

  /// Public entry point for pushing an invite notification from a dialog
  /// that doesn't have access to _pushToUser directly.
  Future<void> pushInviteNotification(String recipientUserId, AppNotification notif) =>
      _pushToUser(recipientUserId, notif);

  /// Push a notification into another user's shared inbox.
  /// [recipientUserId] is the target user's stable ID from AuthStore.
  Future<void> _pushToUser(String recipientUserId, AppNotification notif) async {
    if (recipientUserId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final key = _sharedInboxKey(recipientUserId);
    final raw = prefs.getString(key);
    final List<dynamic> list =
        raw != null ? (jsonDecode(raw) as List) : [];
    // Dedup by id so duplicate pushes don't stack.
    if (!list.any((e) => (e as Map)['id'] == notif.id)) {
      list.add(notif.toJson());
      await prefs.setString(key, jsonEncode(list));
    }
  }

  /// Clear in-memory state and reload from storage for the current user.
  Future<void> reload() async {
    _tasks.clear();
    _events.clear();
    _notifications.clear();
    await load();
  }

  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _kTasks, jsonEncode(_tasks.map((t) => t.toJson()).toList()));
  }

  Future<void> _saveEvents() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _kEvents, jsonEncode(_events.map((e) => e.toJson()).toList()));
  }

  Future<void> _saveNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _kNotifications,
        jsonEncode(_notifications.map((n) => n.toJson()).toList()));
  }

  // ── Task Counts ──────────────────────────────────────────────────
  int get total      => _tasks.length;
  int get inProgress => _tasks.where((t) => t.status == TaskStatus.inProgress).length;
  int get notStarted => _tasks.where((t) => t.status == TaskStatus.notStarted).length;
  int get completed  => _tasks.where((t) => t.status == TaskStatus.completed).length;

  double get completionPercent => total == 0 ? 0 : (completed / total);

  // ── Tasks for a specific day ──────────────────────────────
  List<Task> tasksForDay(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    return _tasks.where((t) {
      final td = DateTime(t.dueDate.year, t.dueDate.month, t.dueDate.day);
      return td == d;
    }).toList()
      ..sort((a, b) {
        if (a.dueTime == null && b.dueTime == null) return 0;
        if (a.dueTime == null) return 1;
        if (b.dueTime == null) return -1;
        return (a.dueTime!.hour * 60 + a.dueTime!.minute)
            .compareTo(b.dueTime!.hour * 60 + b.dueTime!.minute);
      });
  }

  // ── Events for a specific day ─────────────────────────────
  List<Event> eventsForDay(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    return _events.where((e) {
      final start = DateTime(e.startDate.year, e.startDate.month, e.startDate.day);
      final end   = DateTime(e.endDate.year,   e.endDate.month,   e.endDate.day);
      return !d.isBefore(start) && !d.isAfter(end);
    }).toList()
      ..sort((a, b) {
        if (a.startTime == null && b.startTime == null) return 0;
        if (a.startTime == null) return 1;
        if (b.startTime == null) return -1;
        return (a.startTime!.hour * 60 + a.startTime!.minute)
            .compareTo(b.startTime!.hour * 60 + b.startTime!.minute);
      });
  }

  List<Task> get recentTasks {
    final sorted = List<Task>.from(_tasks);
    sorted.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return sorted;
  }

  List<Event> get upcomingEvents {
    final now = DateTime.now();
    final sorted = _events
        .where((e) =>
            !e.endDate.isBefore(DateTime(now.year, now.month, now.day)))
        .toList();
    sorted.sort((a, b) => a.startDate.compareTo(b.startDate));
    return sorted;
  }

  // ── TASK CRUD ─────────────────────────────────────────────
  void addTask(Task task) {
    _tasks.add(task);
    _generateTaskNotifications(task);
    notifyListeners();
    _saveTasks();
    _saveNotifications();
  }

  void updateStatus(String id, TaskStatus status) {
    final idx = _tasks.indexWhere((t) => t.id == id);
    if (idx != -1) {
      _tasks[idx].status = status;
      _onStatusChanged(_tasks[idx]);
      notifyListeners();
      _saveTasks();
      _saveNotifications();
    }
  }

  void deleteTask(String id) {
    _tasks.removeWhere((t) => t.id == id);
    _notifications.removeWhere((n) => n.sourceId == id);
    notifyListeners();
    _saveTasks();
    _saveNotifications();
  }

  // ── EVENT CRUD ────────────────────────────────────────────
  void addEvent(Event event) {
    _events.add(event);
    _generateEventNotifications(event);
    notifyListeners();
    _saveEvents();
    _saveNotifications();
  }

  void updateEvent(Event updated) {
    final idx = _events.indexWhere((e) => e.id == updated.id);
    if (idx != -1) {
      _events[idx] = updated;
      _notifications.removeWhere((n) => n.sourceId == updated.id);
      _generateEventNotifications(updated);
      notifyListeners();
      _saveEvents();
      _saveNotifications();
    }
  }

  void deleteEvent(String id) {
    _events.removeWhere((e) => e.id == id);
    _notifications.removeWhere((n) => n.sourceId == id);
    notifyListeners();
    _saveEvents();
    _saveNotifications();
  }

  // ── Notification helpers ──────────────────────────────────
  void clearNotifications() {
    _notifications.clear();
    notifyListeners();
    _saveNotifications();
  }

  void deleteNotification(String notifId) {
    _notifications.removeWhere((n) => n.id == notifId);
    notifyListeners();
    _saveNotifications();
  }

  bool get hasUnreadNotifications => _notifications.any((n) => !n.isRead);

  void markAllNotificationsRead() {
    for (final n in _notifications) n.isRead = true;
    notifyListeners();
    _saveNotifications();
  }

  void markNotificationRead(String notifId) {
    final idx = _notifications.indexWhere((n) => n.id == notifId);
    if (idx != -1) {
      _notifications[idx].isRead = true;
      notifyListeners();
      _saveNotifications();
    }
  }

  // ═════════════════════════════════════════════════════════
  // SPACE NOTIFICATIONS — public API
  // ═════════════════════════════════════════════════════════

  void notifySpaceCreated(Space space) =>
      _addSpaceNotif(_buildSpaceCreated(space));

  void notifySpaceJoined(Space space) =>
      _addSpaceNotif(_buildSpaceJoined(space));

  /// Called when a new member joins a space.
  /// Adds the "joined" notification for the joiner AND pushes an alert
  /// to the creator's shared inbox so they are notified immediately.
  Future<void> notifyMemberJoined(
      Space space, String joinerName, String creatorName) async {
    // The joiner already gets notifySpaceJoined() — just handle the creator side.
    final creatorId = AuthStore.instance.userIdForName(creatorName);
    if (creatorId == null || creatorId == AuthStore.instance.userId) return;
    final notif = AppNotification(
      id: 'space_member_joined_${space.inviteCode}_$joinerName',
      type: NotificationType.spaceMemberJoined,
      sourceId: space.inviteCode,
      spaceInviteCode: space.inviteCode,
      spaceAccentColor: space.accentColor,
      title: space.name,
      subtitle: '$joinerName joined your space 👋',
      detail: '$joinerName has joined "${space.name}". Your team now has ${space.memberCount} members.',
    );
    await _pushToUser(creatorId, notif);
  }

  Future<void> notifyMemberRemoved(Space space, String member) async {
    // Creator sees the removal locally.
    _addSpaceNotif(_buildMemberRemoved(space, member));
    // Also tell the kicked member they were removed.
    final kickedId = AuthStore.instance.userIdForName(member);
    if (kickedId != null && kickedId != AuthStore.instance.userId) {
      final kickedNotif = AppNotification(
        id: 'space_you_removed_${space.inviteCode}',
        type: NotificationType.spaceMemberRemoved,
        sourceId: space.inviteCode,
        spaceInviteCode: space.inviteCode,
        spaceAccentColor: space.accentColor,
        title: space.name,
        subtitle: 'You were removed from a space',
        detail: 'You were removed from "${space.name}".',
      );
      await _pushToUser(kickedId, kickedNotif);
    }
  }

  /// Called when the current user voluntarily leaves a space.
  /// Pushes a notification to the creator and all remaining members.
  Future<void> notifyMemberLeft(Space space, String leavingName) async {
    final myId = AuthStore.instance.userId;
    final notif = AppNotification(
      id: 'space_member_left_${space.inviteCode}_$leavingName',
      type: NotificationType.spaceMemberRemoved,
      sourceId: space.inviteCode,
      spaceInviteCode: space.inviteCode,
      spaceAccentColor: space.accentColor,
      title: space.name,
      subtitle: '$leavingName left the space',
      detail: '$leavingName has left "${space.name}".',
    );
    // Push to creator.
    final creatorId = AuthStore.instance.userIdForName(space.creatorName);
    if (creatorId != null && creatorId != myId) {
      await _pushToUser(creatorId, notif);
    }
    // Push to every other member.
    for (final member in space.members) {
      if (member == leavingName) continue;
      final uid = AuthStore.instance.userIdForName(member);
      if (uid == null || uid == myId || uid == creatorId) continue;
      await _pushToUser(uid, notif);
    }
  }

  void notifyNewChatMessage(Space space, String senderName, String preview) {
    final id = _chatNotifId(space.inviteCode);
    if (_notifications.any((n) => n.id == id)) return;
    _addSpaceNotif(_buildChatMessage(space, senderName, preview, id));
  }

  void clearChatNotificationsFor(String spaceInviteCode) {
    final id = _chatNotifId(spaceInviteCode);
    if (_notifications.any((n) => n.id == id)) {
      _notifications.removeWhere((n) => n.id == id);
      notifyListeners();
      _saveNotifications();
    }
  }

  Future<void> notifySpaceTaskAdded(Space space, SpaceTask task) async {
    final notif = _buildSpaceTaskAdded(space, task);
    _addSpaceNotif(notif);
    await _pushToOtherMembers(space, notif);
  }

  /// Notify all users assigned to [task].
  /// For the current user: adds directly to their local notification list.
  /// For other users: pushes into their shared inbox so they see it next time
  /// they open the app or navigate to the Spaces screen.
  Future<void> notifySpaceTaskAssigned(
      Space space, SpaceTask task, String currentUser) async {
    final notif = _buildSpaceTaskAssigned(space, task);
    for (final assignee in task.assignedTo) {
      if (assignee == currentUser || assignee == 'You' || assignee == 'You (Creator)') {
        // This is the acting user — add locally.
        _addSpaceNotif(notif);
      } else {
        // Another user — look up their ID and push to their inbox.
        final uid = AuthStore.instance.userIdForName(assignee);
        if (uid != null) await _pushToUser(uid, notif);
      }
    }
  }

  Future<void> notifySpaceTaskStatusChanged(Space space, SpaceTask task) async {
    if (task.status == 'Completed') return;
    final id = 'space_task_status_${space.inviteCode}_${task.title}';
    _notifications.removeWhere((n) => n.id == id);
    final notif = _buildSpaceTaskStatus(space, task);
    _addSpaceNotif(notif);
    await _pushToOtherMembers(space, notif);
  }

  Future<void> notifySpaceTaskCompleted(Space space, SpaceTask task) async {
    _notifications.removeWhere((n) =>
        n.spaceInviteCode == space.inviteCode &&
        n.title == task.title &&
        (n.type == NotificationType.spaceTaskStatus ||
            n.type == NotificationType.spaceTaskOverdue ||
            n.type == NotificationType.spaceTaskDueSoon ||
            n.type == NotificationType.spaceTaskCompleted));
    final notif = _buildSpaceTaskCompleted(space, task);
    _addSpaceNotif(notif);
    await _pushToOtherMembers(space, notif);
  }

  void clearSpaceNotifications(String spaceInviteCode) {
    if (_notifications.any((n) => n.spaceInviteCode == spaceInviteCode)) {
      _notifications.removeWhere((n) => n.spaceInviteCode == spaceInviteCode);
      notifyListeners();
      _saveNotifications();
    }
  }

  void generateSpaceTaskDeadlineAlerts(Space space) {
    for (final task in space.tasks) {
      if (task.status == 'Completed') continue;
      _maybeAddDeadlineAlert(space, task);
    }
  }

  void refreshDeadlineAlertFor(Space space, SpaceTask task) {
    _notifications.removeWhere((n) =>
        n.spaceInviteCode == space.inviteCode &&
        n.title == task.title &&
        (n.type == NotificationType.spaceTaskDueSoon ||
            n.type == NotificationType.spaceTaskOverdue));
    if (task.status != 'Completed') _maybeAddDeadlineAlert(space, task);
  }

  // ── Space notification internals ──────────────────────────

  /// Push [notif] to every member of [space] except the current user.
  Future<void> _pushToOtherMembers(Space space, AppNotification notif) async {
    final myId = AuthStore.instance.userId;
    for (final member in space.members) {
      final uid = AuthStore.instance.userIdForName(member);
      if (uid == null || uid == myId) continue;
      await _pushToUser(uid, notif);
    }
  }

  void _addSpaceNotif(AppNotification notif) {
    if (_notifications.any((n) => n.id == notif.id)) return;
    _notifications.insert(0, notif);
    notifyListeners();
    _saveNotifications();
  }

  String _chatNotifId(String inviteCode) => 'space_chat_$inviteCode';

  void _maybeAddDeadlineAlert(Space space, SpaceTask task) {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime? due;
    try {
      final parts = space.dueDate.split('/');
      due = DateTime(int.parse(parts[2]), int.parse(parts[0]), int.parse(parts[1]));
    } catch (_) {
      return;
    }
    final dueDay = DateTime(due.year, due.month, due.day);
    final days   = dueDay.difference(today).inDays;
    if (dueDay.isBefore(today)) {
      _addSpaceNotif(_buildSpaceTaskOverdue(space, task));
    } else if (days == 1) {
      _addSpaceNotif(_buildSpaceTaskDueSoon(space, task));
    }
  }

  // ── Space notification builders ───────────────────────────

  AppNotification _buildSpaceCreated(Space space) => AppNotification(
        id: 'space_created_${space.inviteCode}',
        type: NotificationType.spaceCreated,
        sourceId: space.inviteCode,
        spaceInviteCode: space.inviteCode,
        spaceAccentColor: space.accentColor,
        title: space.name,
        subtitle: 'Space created 🚀',
        detail: 'You created "${space.name}". Share the invite code ${space.inviteCode} with your team.',
      );

  AppNotification _buildSpaceJoined(Space space) => AppNotification(
        id: 'space_joined_${space.inviteCode}',
        type: NotificationType.spaceJoined,
        sourceId: space.inviteCode,
        spaceInviteCode: space.inviteCode,
        spaceAccentColor: space.accentColor,
        title: space.name,
        subtitle: 'You joined a space 👋',
        detail: 'Welcome to "${space.name}". You can see tasks, chat with members, and track progress here.',
      );

  AppNotification _buildMemberRemoved(Space space, String member) =>
      AppNotification(
        id: 'space_kick_${space.inviteCode}_$member',
        type: NotificationType.spaceMemberRemoved,
        sourceId: space.inviteCode,
        spaceInviteCode: space.inviteCode,
        spaceAccentColor: space.accentColor,
        title: space.name,
        subtitle: 'Member removed',
        detail: '$member was removed from "${space.name}".',
      );

  AppNotification _buildChatMessage(Space space, String sender, String preview, String id) =>
      AppNotification(
        id: id,
        type: NotificationType.spaceChatMessage,
        sourceId: space.inviteCode,
        spaceInviteCode: space.inviteCode,
        spaceAccentColor: space.accentColor,
        title: space.name,
        subtitle: '$sender sent a message 💬',
        detail: preview.length > 80 ? '${preview.substring(0, 80)}…' : preview,
      );

  AppNotification _buildSpaceTaskAdded(Space space, SpaceTask task) =>
      AppNotification(
        id: 'space_task_added_${space.inviteCode}_${task.title}',
        type: NotificationType.spaceTaskAdded,
        sourceId: space.inviteCode,
        spaceInviteCode: space.inviteCode,
        spaceAccentColor: space.accentColor,
        title: space.name,
        subtitle: 'New task added',
        detail: '"${task.title}" was added to "${space.name}".',
      );

  AppNotification _buildSpaceTaskAssigned(Space space, SpaceTask task) =>
      AppNotification(
        id: 'space_task_assigned_${space.inviteCode}_${task.title}',
        type: NotificationType.spaceTaskAssigned,
        sourceId: space.inviteCode,
        spaceInviteCode: space.inviteCode,
        spaceAccentColor: space.accentColor,
        title: task.title,
        subtitle: 'You were assigned a task 📌',
        detail: 'You\'ve been assigned "${task.title}" in "${space.name}".',
      );

  AppNotification _buildSpaceTaskStatus(Space space, SpaceTask task) =>
      AppNotification(
        id: 'space_task_status_${space.inviteCode}_${task.title}',
        type: NotificationType.spaceTaskStatus,
        sourceId: space.inviteCode,
        spaceInviteCode: space.inviteCode,
        spaceAccentColor: space.accentColor,
        title: task.title,
        subtitle: 'Task status updated',
        detail: '"${task.title}" is now ${task.status} in "${space.name}".',
      );

  AppNotification _buildSpaceTaskCompleted(Space space, SpaceTask task) =>
      AppNotification(
        id: 'space_task_done_${space.inviteCode}_${task.title}',
        type: NotificationType.spaceTaskCompleted,
        sourceId: space.inviteCode,
        spaceInviteCode: space.inviteCode,
        spaceAccentColor: space.accentColor,
        title: task.title,
        subtitle: 'Task completed 🎉',
        detail: '"${task.title}" was completed in "${space.name}". Great work!',
      );

  AppNotification _buildSpaceTaskDueSoon(Space space, SpaceTask task) =>
      AppNotification(
        id: 'space_task_due_soon_${space.inviteCode}_${task.title}',
        type: NotificationType.spaceTaskDueSoon,
        sourceId: space.inviteCode,
        spaceInviteCode: space.inviteCode,
        spaceAccentColor: space.accentColor,
        title: task.title,
        subtitle: '⏰ Due tomorrow — ${space.name}',
        detail: '"${task.title}" in "${space.name}" is due tomorrow. Make sure it\'s on track.',
      );

  AppNotification _buildSpaceTaskOverdue(Space space, SpaceTask task) =>
      AppNotification(
        id: 'space_task_overdue_${space.inviteCode}_${task.title}',
        type: NotificationType.spaceTaskOverdue,
        sourceId: space.inviteCode,
        spaceInviteCode: space.inviteCode,
        spaceAccentColor: space.accentColor,
        title: task.title,
        subtitle: '🔴 Overdue — ${space.name}',
        detail: '"${task.title}" in "${space.name}" is past its deadline.',
      );

  // ═════════════════════════════════════════════════════════
  // EXISTING task / event internals
  // ═════════════════════════════════════════════════════════

  void _generateTaskNotifications(Task task) {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due   = DateTime(task.dueDate.year, task.dueDate.month, task.dueDate.day);
    final days  = due.difference(today).inDays;

    if (task.status == TaskStatus.completed) return;

    if (due.isBefore(today)) {
      _addNotification(_buildOverdue(task));
      return;
    }
    if (due == today) {
      _addNotification(_buildDueToday(task));
      return;
    }

    switch (task.priority) {
      case TaskPriority.high:
        if (days == 7) _addNotification(_buildAdvanceReminder(task: task, daysAhead: 7, subtitle: '📌 High Priority — Plan ahead', detail: 'Start planning now. Aim to begin at least a week before the deadline.'));
        if (days == 3) _addNotification(_buildAdvanceReminder(task: task, daysAhead: 3, subtitle: '⚡ High Priority — Act soon', detail: 'Only 3 days left. Break this into steps and start today.'));
        if (days == 1) _addNotification(_buildAdvanceReminder(task: task, daysAhead: 1, subtitle: '🔴 High Priority — Due tomorrow!', detail: 'Final push! Make sure this is your top focus today.'));
        break;
      case TaskPriority.medium:
        if (days == 3) _addNotification(_buildAdvanceReminder(task: task, daysAhead: 3, subtitle: '🟡 Medium Priority — Don\'t delay', detail: 'You have 3 days. Schedule some time to work on this soon.'));
        if (days == 1) _addNotification(_buildAdvanceReminder(task: task, daysAhead: 1, subtitle: '🟡 Medium Priority — Due tomorrow', detail: 'Last chance to wrap this up before the deadline.'));
        break;
      case TaskPriority.low:
        if (days == 1) _addNotification(_buildAdvanceReminder(task: task, daysAhead: 1, subtitle: '🟢 Low Priority — Due tomorrow', detail: 'A low-priority task is due soon. Knock it out if you have a free moment.'));
        break;
    }
  }

  void _onStatusChanged(Task task) {
    _notifications.removeWhere((n) => n.sourceId == task.id);
    if (task.status == TaskStatus.completed) {
      _addNotification(_buildCompleted(task));
    } else if (task.status == TaskStatus.notStarted) {
      _generateTaskNotifications(task);
    }
  }

  void _generateEventNotifications(Event event) {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(event.startDate.year, event.startDate.month, event.startDate.day);
    final end   = DateTime(event.endDate.year,   event.endDate.month,   event.endDate.day);
    final days  = start.difference(today).inDays;

    if (end.isBefore(today)) return;
    if (start == today) { _addNotification(_buildEventToday(event)); return; }
    if (days == 1) { _addNotification(_buildEventReminder(event, daysAhead: 1)); return; }
    if (days == 3) { _addNotification(_buildEventReminder(event, daysAhead: 3)); return; }
    if (days == 7)   _addNotification(_buildEventReminder(event, daysAhead: 7));
  }

  void _addNotification(AppNotification notif) {
    _notifications.insert(0, notif);
  }

  String _fmtDate(DateTime d) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  String _categoryLabel(Task task) =>
      task.category.isAcademic ? 'Academic Task Reminder' : 'Personal Task Reminder';

  AppNotification _buildAdvanceReminder({required Task task, required int daysAhead, required String subtitle, required String detail}) =>
      AppNotification(id: '${task.id}_remind_${daysAhead}d', type: NotificationType.taskReminder, sourceId: task.id, taskCategory: task.category, priority: task.priority, title: task.name, subtitle: subtitle, detail: detail);

  AppNotification _buildDueToday(Task task) =>
      AppNotification(id: '${task.id}_today', type: NotificationType.taskDueToday, sourceId: task.id, taskCategory: task.category, priority: task.priority, subtitle: 'Due today!', title: task.name, detail: _priorityDueTodayDetail(task.priority));

  String _priorityDueTodayDetail(TaskPriority p) {
    switch (p) {
      case TaskPriority.high:   return '🔴 High priority — this needs to be done today.';
      case TaskPriority.medium: return '🟡 Medium priority — finish this up today.';
      case TaskPriority.low:    return '🟢 Low priority — try to get this done today.';
    }
  }

  AppNotification _buildOverdue(Task task) =>
      AppNotification(id: '${task.id}_overdue', type: NotificationType.taskOverdue, sourceId: task.id, taskCategory: task.category, priority: task.priority, subtitle: 'This task is overdue!', title: task.name, detail: _priorityOverdueDetail(task.priority, task.dueDate));

  String _priorityOverdueDetail(TaskPriority p, DateTime due) {
    final label = _fmtDate(due);
    switch (p) {
      case TaskPriority.high:   return '🔴 High priority · Was due $label — address this immediately.';
      case TaskPriority.medium: return '🟡 Medium priority · Was due $label — try to complete this soon.';
      case TaskPriority.low:    return '🟢 Low priority · Was due $label — update or complete when possible.';
    }
  }

  AppNotification _buildCompleted(Task task) =>
      AppNotification(id: '${task.id}_done', type: NotificationType.taskCompleted, sourceId: task.id, taskCategory: task.category, priority: task.priority, subtitle: 'Great job! Task completed. 🎉', title: task.name, detail: _categoryLabel(task));

  AppNotification _buildEventToday(Event event) =>
      AppNotification(
        id: '${event.id}_event_today',
        type: NotificationType.eventToday,
        sourceId: event.id,
        eventCategory: event.category,
        title: event.title,
        subtitle: '📅 Happening today!',
        detail: event.location != null
            ? 'Your event starts today${event.startTime != null ? ' at ${_fmtTime(event.startTime!)}' : ''}. Location: ${event.location}'
            : 'Your event starts today${event.startTime != null ? ' at ${_fmtTime(event.startTime!)}' : ''}.',
      );

  AppNotification _buildEventReminder(Event event, {required int daysAhead}) {
    final dayLabel = daysAhead == 1 ? 'tomorrow' : 'in $daysAhead days';
    return AppNotification(
      id: '${event.id}_event_remind_${daysAhead}d',
      type: NotificationType.eventReminder,
      sourceId: event.id,
      eventCategory: event.category,
      title: event.title,
      subtitle: '🗓 Coming up $dayLabel',
      detail: event.location != null
          ? 'Don\'t forget — "${event.title}" is $dayLabel. Location: ${event.location}'
          : 'Don\'t forget — "${event.title}" is $dayLabel.',
    );
  }

  String _fmtTime(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $period';
  }
}