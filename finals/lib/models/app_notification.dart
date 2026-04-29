import 'package:flutter/material.dart';
import 'task.dart';
import 'event.dart';

enum NotificationType {
  // ── Task ──────────────────────────────
  taskReminder,   // created / advance reminder
  taskOverdue,    // past due, not completed
  taskDueToday,   // due today
  taskCompleted,  // marked complete

  // ── Event ─────────────────────────────
  eventReminder,  // created / advance reminder
  eventToday,     // happening today

  // ── Space ─────────────────────────────
  spaceCreated,       // user created a new space
  spaceJoined,        // user joined a space
  spaceMemberRemoved, // a member was kicked
  spaceMemberJoined,  // a new member joined the space
  spaceChatMessage,   // new chat message from another member
  spaceTaskAdded,     // a new task was added to a space
  spaceTaskAssigned,  // current user was assigned to a task
  spaceTaskStatus,    // a task's status changed
  spaceTaskCompleted, // a task was marked completed
  spaceTaskDueSoon,   // a space task is due tomorrow
  spaceTaskOverdue,   // a space task is overdue
  spaceDeleted,       // the space was deleted by its creator
}

class AppNotification {
  final String id;
  final NotificationType type;

  /// Primary source ID:
  ///   - personal task/event → the task.id / event.id
  ///   - space notification  → the space.inviteCode
  final String sourceId;

  /// Secondary deep-link ID — optional, type-specific:
  ///   - spaceTaskAdded / spaceTaskAssigned / spaceTaskStatus /
  ///     spaceTaskCompleted / spaceTaskDueSoon / spaceTaskOverdue
  ///       → SpaceTask.title (used to locate the task inside the space)
  ///   - spaceChatMessage → message timestamp string (for scroll-to)
  ///   Future: commentId, mentionId, etc.
  ///
  /// When null the router falls back to opening the parent context
  /// (the space overview or personal task list) rather than crashing.
  final String? secondaryId;

  final String title;
  final String subtitle;
  final String detail;
  final DateTime createdAt;

  // Task-specific (null for event / space notifications)
  final TaskCategory? taskCategory;
  final TaskPriority? priority;

  // Event-specific (null for task / space notifications)
  final EventCategory? eventCategory;

  // Space-specific (null for task / event notifications)
  /// The invite code of the related space — used for routing / dedup.
  final String? spaceInviteCode;

  /// Accent colour of the space, used for icon tinting.
  final Color? spaceAccentColor;

  bool isRead;

  AppNotification({
    required this.id,
    required this.type,
    required this.sourceId,
    required this.title,
    required this.subtitle,
    required this.detail,
    this.secondaryId,
    this.taskCategory,
    this.priority,
    this.eventCategory,
    this.spaceInviteCode,
    this.spaceAccentColor,
    DateTime? createdAt,
    this.isRead = false,
  }) : createdAt = createdAt ?? DateTime.now();

  // ── Icon ──────────────────────────────────────────────────
  IconData get icon {
    switch (type) {
      // Task
      case NotificationType.taskReminder:  return Icons.assignment_outlined;
      case NotificationType.taskOverdue:   return Icons.warning_amber_rounded;
      case NotificationType.taskDueToday:  return Icons.today_rounded;
      case NotificationType.taskCompleted: return Icons.check_circle_rounded;
      // Event
      case NotificationType.eventReminder: return Icons.event_outlined;
      case NotificationType.eventToday:    return Icons.event_available_rounded;
      // Space
      case NotificationType.spaceCreated:       return Icons.rocket_launch_rounded;
      case NotificationType.spaceJoined:        return Icons.login_rounded;
      case NotificationType.spaceMemberRemoved: return Icons.person_remove_rounded;
      case NotificationType.spaceMemberJoined:  return Icons.person_add_rounded;
      case NotificationType.spaceChatMessage:   return Icons.chat_rounded;
      case NotificationType.spaceTaskAdded:     return Icons.playlist_add_rounded;
      case NotificationType.spaceTaskAssigned:  return Icons.person_pin_rounded;
      case NotificationType.spaceTaskStatus:    return Icons.sync_rounded;
      case NotificationType.spaceTaskCompleted: return Icons.task_alt_rounded;
      case NotificationType.spaceTaskDueSoon:   return Icons.schedule_rounded;
      case NotificationType.spaceTaskOverdue:   return Icons.warning_amber_rounded;
      case NotificationType.spaceDeleted:       return Icons.delete_forever_rounded;
    }
  }

  // ── Colour helpers ────────────────────────────────────────
  Color get iconColor {
    if (spaceAccentColor != null) return spaceAccentColor!;
    if (eventCategory != null) return eventCategory!.color;
    return taskCategory?.color ?? const Color(0xFF9B88E8);
  }

  Color get iconBgColor => iconColor.withOpacity(0.15);

  // ── Convenience ───────────────────────────────────────────
  bool get isSpaceNotification => spaceInviteCode != null;

  /// Returns true for notification types that should route to a specific
  /// space task rather than just the space overview.
  bool get isSpaceTaskNotification {
    switch (type) {
      case NotificationType.spaceTaskAdded:
      case NotificationType.spaceTaskAssigned:
      case NotificationType.spaceTaskStatus:
      case NotificationType.spaceTaskCompleted:
      case NotificationType.spaceTaskDueSoon:
      case NotificationType.spaceTaskOverdue:
        return true;
      default:
        return false;
    }
  }

  /// Returns true for types that should open the space chat directly.
  bool get isSpaceChatNotification =>
      type == NotificationType.spaceChatMessage;

  // ── Serialisation ─────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.index,
        'sourceId': sourceId,
        'secondaryId': secondaryId,
        'title': title,
        'subtitle': subtitle,
        'detail': detail,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'isRead': isRead,
        'taskCategory': taskCategory?.index,
        'priority': priority?.index,
        'eventCategory': eventCategory?.index,
        'spaceInviteCode': spaceInviteCode,
        'spaceAccentColor': spaceAccentColor?.value,
      };

  factory AppNotification.fromJson(Map<String, dynamic> j) =>
      AppNotification(
        id: j['id'] as String,
        type: NotificationType.values[j['type'] as int],
        sourceId: j['sourceId'] as String,
        // secondaryId is new — gracefully absent in old persisted data
        secondaryId: j['secondaryId'] as String?,
        title: j['title'] as String,
        subtitle: j['subtitle'] as String,
        detail: j['detail'] as String,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(j['createdAt'] as int),
        isRead: j['isRead'] as bool,
        taskCategory: j['taskCategory'] == null
            ? null
            : TaskCategory.values[j['taskCategory'] as int],
        priority: j['priority'] == null
            ? null
            : TaskPriority.values[j['priority'] as int],
        eventCategory: j['eventCategory'] == null
            ? null
            : EventCategory.values[j['eventCategory'] as int],
        spaceInviteCode: j['spaceInviteCode'] as String?,
        spaceAccentColor: j['spaceAccentColor'] == null
            ? null
            : Color(j['spaceAccentColor'] as int),
      );
}