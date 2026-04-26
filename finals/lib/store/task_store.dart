import 'package:flutter/material.dart';
import '../models/task.dart';
import '../models/app_notification.dart';

class TaskStore extends ChangeNotifier {
  TaskStore._();
  static final TaskStore instance = TaskStore._();

  final List<Task> _tasks = [];
  final List<AppNotification> _notifications = [];

  List<Task> get tasks => List.unmodifiable(_tasks);
  List<AppNotification> get notifications => List.unmodifiable(_notifications);

  // ── Counts ──────────────────────────────────────────────────
  int get total      => _tasks.length;
  int get inProgress => _tasks.where((t) => t.status == TaskStatus.inProgress).length;
  int get notStarted => _tasks.where((t) => t.status == TaskStatus.notStarted).length;
  int get completed  => _tasks.where((t) => t.status == TaskStatus.completed).length;

  double get completionPercent =>
      total == 0 ? 0 : (completed / total);

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
        final aMin = a.dueTime!.hour * 60 + a.dueTime!.minute;
        final bMin = b.dueTime!.hour * 60 + b.dueTime!.minute;
        return aMin.compareTo(bMin);
      });
  }

  // ── Recent tasks (sorted by due date, closest first) ─────
  List<Task> get recentTasks {
    final sorted = List<Task>.from(_tasks);
    sorted.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return sorted;
  }

  // ── CRUD ─────────────────────────────────────────────────
  void addTask(Task task) {
    _tasks.add(task);
    _generateNotificationsFor(task);
    notifyListeners();
  }

  void updateStatus(String id, TaskStatus status) {
    final idx = _tasks.indexWhere((t) => t.id == id);
    if (idx != -1) {
      _tasks[idx].status = status;
      _onStatusChanged(_tasks[idx]);
      notifyListeners();
    }
  }

  void deleteTask(String id) {
    _tasks.removeWhere((t) => t.id == id);
    _notifications.removeWhere((n) => n.taskId == id);
    notifyListeners();
  }

  void clearNotifications() {
    _notifications.clear();
    notifyListeners();
  }

  bool get hasUnreadNotifications =>
      _notifications.any((n) => !n.isRead);

  void markAllNotificationsRead() {
    for (final n in _notifications) {
      n.isRead = true;
    }
    notifyListeners();
  }

  void markNotificationRead(String notifId) {
    final idx = _notifications.indexWhere((n) => n.id == notifId);
    if (idx != -1) {
      _notifications[idx].isRead = true;
      notifyListeners();
    }
  }

  // ── Notification generation ──────────────────────────────

  void _generateNotificationsFor(Task task) {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due   = DateTime(task.dueDate.year, task.dueDate.month, task.dueDate.day);

    if (task.status == TaskStatus.completed) return;

    if (due.isBefore(today)) {
      _addNotification(_buildOverdue(task));
    } else if (due == today) {
      _addNotification(_buildDueToday(task));
    } else {
      _addNotification(_buildReminder(task));
    }
  }

  void _onStatusChanged(Task task) {
    _notifications.removeWhere(
      (n) => n.taskId == task.id &&
             (n.type == NotificationType.taskReminder ||
              n.type == NotificationType.taskDueToday ||
              n.type == NotificationType.taskOverdue),
    );

    if (task.status == TaskStatus.completed) {
      _addNotification(_buildCompleted(task));
    } else {
      _generateNotificationsFor(task);
    }
  }

  void _addNotification(AppNotification notif) {
    _notifications.insert(0, notif);
  }

  // ── Builders ─────────────────────────────────────────────

  String _fmtDate(DateTime d) {
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  String _categoryLabel(Task task) =>
      task.category.isAcademic ? 'Academic Task Reminder' : 'Personal Task Reminder';

  AppNotification _buildReminder(Task task) => AppNotification(
    id: '${task.id}_reminder',
    type: NotificationType.taskReminder,
    taskId: task.id,
    category: task.category,
    priority: task.priority,
    subtitle: _categoryLabel(task),
    title: task.name,
    detail: _fmtDate(task.dueDate),
  );

  AppNotification _buildDueToday(Task task) => AppNotification(
    id: '${task.id}_today',
    type: NotificationType.taskDueToday,
    taskId: task.id,
    category: task.category,
    priority: task.priority,
    subtitle: 'Due today!',
    title: task.name,
    detail: _categoryLabel(task),
  );

  AppNotification _buildOverdue(Task task) => AppNotification(
    id: '${task.id}_overdue',
    type: NotificationType.taskOverdue,
    taskId: task.id,
    category: task.category,
    priority: task.priority,
    subtitle: 'This task is overdue.',
    title: task.name,
    detail: '${_categoryLabel(task)} · ${_fmtDate(task.dueDate)}',
  );

  AppNotification _buildCompleted(Task task) => AppNotification(
    id: '${task.id}_done',
    type: NotificationType.taskCompleted,
    taskId: task.id,
    category: task.category,
    priority: task.priority,
    subtitle: 'Great job! Task completed.',
    title: task.name,
    detail: _categoryLabel(task),
  );
}