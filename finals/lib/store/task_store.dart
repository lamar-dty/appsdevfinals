import 'package:flutter/material.dart';
import '../models/task.dart';
import '../models/event.dart';
import '../models/app_notification.dart';

class TaskStore extends ChangeNotifier {
  TaskStore._();
  static final TaskStore instance = TaskStore._();

  final List<Task> _tasks = [];
  final List<Event> _events = [];
  final List<AppNotification> _notifications = [];

  List<Task> get tasks => List.unmodifiable(_tasks);
  List<Event> get events => List.unmodifiable(_events);
  List<AppNotification> get notifications => List.unmodifiable(_notifications);

  // ── Task Counts ──────────────────────────────────────────────────
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
        final aMin = a.startTime!.hour * 60 + a.startTime!.minute;
        final bMin = b.startTime!.hour * 60 + b.startTime!.minute;
        return aMin.compareTo(bMin);
      });
  }

  // ── Recent tasks (sorted by due date, closest first) ─────
  List<Task> get recentTasks {
    final sorted = List<Task>.from(_tasks);
    sorted.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return sorted;
  }

  // ── Upcoming events (sorted by start date, soonest first) ─
  List<Event> get upcomingEvents {
    final now = DateTime.now();
    final sorted = _events
        .where((e) => !e.endDate.isBefore(DateTime(now.year, now.month, now.day)))
        .toList();
    sorted.sort((a, b) => a.startDate.compareTo(b.startDate));
    return sorted;
  }

  // ── TASK CRUD ─────────────────────────────────────────────
  void addTask(Task task) {
    _tasks.add(task);
    _generateTaskNotifications(task);
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
    _notifications.removeWhere((n) => n.sourceId == id);
    notifyListeners();
  }

  // ── EVENT CRUD ────────────────────────────────────────────
  void addEvent(Event event) {
    _events.add(event);
    _generateEventNotifications(event);
    notifyListeners();
  }

  void updateEvent(Event updated) {
    final idx = _events.indexWhere((e) => e.id == updated.id);
    if (idx != -1) {
      _events[idx] = updated;
      // Refresh notifications for this event
      _notifications.removeWhere((n) => n.sourceId == updated.id);
      _generateEventNotifications(updated);
      notifyListeners();
    }
  }

  void deleteEvent(String id) {
    _events.removeWhere((e) => e.id == id);
    _notifications.removeWhere((n) => n.sourceId == id);
    notifyListeners();
  }

  // ── Notification helpers ──────────────────────────────────
  void clearNotifications() {
    _notifications.clear();
    notifyListeners();
  }

  void deleteNotification(String notifId) {
    _notifications.removeWhere((n) => n.id == notifId);
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

  // ── Task notification generation ──────────────────────────

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
        if (days == 7) {
          _addNotification(_buildAdvanceReminder(
            task: task, daysAhead: 7,
            subtitle: '📌 High Priority — Plan ahead',
            detail: 'Start planning now. Aim to begin at least a week before the deadline.',
          ));
        } else if (days == 3) {
          _addNotification(_buildAdvanceReminder(
            task: task, daysAhead: 3,
            subtitle: '⚡ High Priority — Act soon',
            detail: 'Only 3 days left. Break this into steps and start today.',
          ));
        } else if (days == 1) {
          _addNotification(_buildAdvanceReminder(
            task: task, daysAhead: 1,
            subtitle: '🔴 High Priority — Due tomorrow!',
            detail: 'Final push! Make sure this is your top focus today.',
          ));
        }
        break;

      case TaskPriority.medium:
        if (days == 3) {
          _addNotification(_buildAdvanceReminder(
            task: task, daysAhead: 3,
            subtitle: '🟡 Medium Priority — Don\'t delay',
            detail: 'You have 3 days. Schedule some time to work on this soon.',
          ));
        } else if (days == 1) {
          _addNotification(_buildAdvanceReminder(
            task: task, daysAhead: 1,
            subtitle: '🟡 Medium Priority — Due tomorrow',
            detail: 'Last chance to wrap this up before the deadline.',
          ));
        }
        break;

      case TaskPriority.low:
        if (days == 1) {
          _addNotification(_buildAdvanceReminder(
            task: task, daysAhead: 1,
            subtitle: '🟢 Low Priority — Due tomorrow',
            detail: 'A low-priority task is due soon. Knock it out if you have a free moment.',
          ));
        }
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

  // ── Event notification generation ─────────────────────────

  void _generateEventNotifications(Event event) {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(event.startDate.year, event.startDate.month, event.startDate.day);
    final days  = start.difference(today).inDays;

    // Event already ended — no notifications
    final end = DateTime(event.endDate.year, event.endDate.month, event.endDate.day);
    if (end.isBefore(today)) return;

    // Starting today
    if (start == today) {
      _addNotification(_buildEventToday(event));
      return;
    }

    // Reminder 1 day before
    if (days == 1) {
      _addNotification(_buildEventReminder(event, daysAhead: 1));
      return;
    }

    // Reminder 3 days before
    if (days == 3) {
      _addNotification(_buildEventReminder(event, daysAhead: 3));
      return;
    }

    // Reminder 7 days before
    if (days == 7) {
      _addNotification(_buildEventReminder(event, daysAhead: 7));
    }
  }

  // ── Notification inserter ─────────────────────────────────
  void _addNotification(AppNotification notif) {
    _notifications.insert(0, notif);
  }

  // ── Task builders ─────────────────────────────────────────

  String _fmtDate(DateTime d) {
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  String _categoryLabel(Task task) =>
      task.category.isAcademic ? 'Academic Task Reminder' : 'Personal Task Reminder';

  AppNotification _buildAdvanceReminder({
    required Task task,
    required int daysAhead,
    required String subtitle,
    required String detail,
  }) => AppNotification(
    id: '${task.id}_remind_${daysAhead}d',
    type: NotificationType.taskReminder,
    sourceId: task.id,
    taskCategory: task.category,
    priority: task.priority,
    title: task.name,
    subtitle: subtitle,
    detail: detail,
  );

  AppNotification _buildDueToday(Task task) => AppNotification(
    id: '${task.id}_today',
    type: NotificationType.taskDueToday,
    sourceId: task.id,
    taskCategory: task.category,
    priority: task.priority,
    subtitle: 'Due today!',
    title: task.name,
    detail: _priorityDueTodayDetail(task.priority),
  );

  String _priorityDueTodayDetail(TaskPriority p) {
    switch (p) {
      case TaskPriority.high:   return '🔴 High priority — this needs to be done today.';
      case TaskPriority.medium: return '🟡 Medium priority — finish this up today.';
      case TaskPriority.low:    return '🟢 Low priority — try to get this done today.';
    }
  }

  AppNotification _buildOverdue(Task task) => AppNotification(
    id: '${task.id}_overdue',
    type: NotificationType.taskOverdue,
    sourceId: task.id,
    taskCategory: task.category,
    priority: task.priority,
    subtitle: 'This task is overdue!',
    title: task.name,
    detail: _priorityOverdueDetail(task.priority, task.dueDate),
  );

  String _priorityOverdueDetail(TaskPriority p, DateTime due) {
    final label = _fmtDate(due);
    switch (p) {
      case TaskPriority.high:   return '🔴 High priority · Was due $label — address this immediately.';
      case TaskPriority.medium: return '🟡 Medium priority · Was due $label — try to complete this soon.';
      case TaskPriority.low:    return '🟢 Low priority · Was due $label — update or complete when possible.';
    }
  }

  AppNotification _buildCompleted(Task task) => AppNotification(
    id: '${task.id}_done',
    type: NotificationType.taskCompleted,
    sourceId: task.id,
    taskCategory: task.category,
    priority: task.priority,
    subtitle: 'Great job! Task completed. 🎉',
    title: task.name,
    detail: _categoryLabel(task),
  );

  // ── Event builders ────────────────────────────────────────

  AppNotification _buildEventToday(Event event) => AppNotification(
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