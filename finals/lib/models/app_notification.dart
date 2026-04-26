import 'package:flutter/material.dart';
import 'task.dart';

enum NotificationType {
  taskReminder,   // just created
  taskOverdue,    // past due, not completed
  taskDueToday,   // due today
  taskCompleted,  // marked complete
}

class AppNotification {
  final String id;
  final NotificationType type;
  final String taskId;
  final String title;
  final String subtitle;
  final String detail;
  final DateTime createdAt;
  final TaskCategory? category;
  final TaskPriority? priority;
  bool isRead;

  AppNotification({
    required this.id,
    required this.type,
    required this.taskId,
    required this.title,
    required this.subtitle,
    required this.detail,
    this.category,
    this.priority,
    DateTime? createdAt,
    this.isRead = false,
  }) : createdAt = createdAt ?? DateTime.now();

  IconData get icon {
    switch (type) {
      case NotificationType.taskReminder:  return Icons.assignment_outlined;
      case NotificationType.taskOverdue:   return Icons.warning_amber_rounded;
      case NotificationType.taskDueToday:  return Icons.today_rounded;
      case NotificationType.taskCompleted: return Icons.check_circle_rounded;
    }
  }

  Color get iconBgColor =>
      (category?.color ?? const Color(0xFF9B88E8)).withOpacity(0.15);

  Color get iconColor =>
      category?.color ?? const Color(0xFF9B88E8);
}