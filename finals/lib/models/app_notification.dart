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
}

class AppNotification {
  final String id;
  final NotificationType type;

  /// ID of the linked task OR event — used for grouping / deletion.
  final String sourceId;

  final String title;
  final String subtitle;
  final String detail;
  final DateTime createdAt;

  // Task-specific (null for event notifications)
  final TaskCategory? taskCategory;
  final TaskPriority? priority;

  // Event-specific (null for task notifications)
  final EventCategory? eventCategory;

  bool isRead;

  AppNotification({
    required this.id,
    required this.type,
    required this.sourceId,
    required this.title,
    required this.subtitle,
    required this.detail,
    this.taskCategory,
    this.priority,
    this.eventCategory,
    DateTime? createdAt,
    this.isRead = false,
  }) : createdAt = createdAt ?? DateTime.now();

  // ── Icon ──────────────────────────────────────────────────
  IconData get icon {
    switch (type) {
      case NotificationType.taskReminder:  return Icons.assignment_outlined;
      case NotificationType.taskOverdue:   return Icons.warning_amber_rounded;
      case NotificationType.taskDueToday:  return Icons.today_rounded;
      case NotificationType.taskCompleted: return Icons.check_circle_rounded;
      case NotificationType.eventReminder: return Icons.event_outlined;
      case NotificationType.eventToday:    return Icons.event_available_rounded;
    }
  }

  // ── Colour helpers ────────────────────────────────────────
  Color get iconColor {
    if (eventCategory != null) return eventCategory!.color;
    return taskCategory?.color ?? const Color(0xFF9B88E8);
  }

  Color get iconBgColor => iconColor.withOpacity(0.15);
}