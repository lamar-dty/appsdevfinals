import 'package:flutter/material.dart';

enum TaskCategory {
  assignment,
  project,
  assessment,
  personalTask,
}

enum TaskPriority { low, medium, high }

enum TaskStatus { notStarted, inProgress, completed }

enum TaskRepeat { once, daily, weekly }

extension TaskCategoryExt on TaskCategory {
  String get label {
    switch (this) {
      case TaskCategory.assignment:   return 'Assignment';
      case TaskCategory.project:      return 'Project';
      case TaskCategory.assessment:   return 'Assessment';
      case TaskCategory.personalTask: return 'Personal Task';
    }
  }

  bool get isAcademic => this != TaskCategory.personalTask;

  Color get color {
    switch (this) {
      case TaskCategory.assignment:   return const Color(0xFF9B88E8);
      case TaskCategory.project:      return const Color(0xFFE8D870);
      case TaskCategory.assessment:   return const Color(0xFF90D0CB);
      case TaskCategory.personalTask: return const Color(0xFFE8A870);
    }
  }
}

extension TaskPriorityExt on TaskPriority {
  String get label {
    switch (this) {
      case TaskPriority.low:    return 'Low';
      case TaskPriority.medium: return 'Medium';
      case TaskPriority.high:   return 'High';
    }
  }

  Color get color {
    switch (this) {
      case TaskPriority.low:    return const Color(0xFF3BBFA3);
      case TaskPriority.medium: return const Color(0xFFE8D870);
      case TaskPriority.high:   return const Color(0xFFE87070);
    }
  }
}

extension TaskRepeatExt on TaskRepeat {
  String get label {
    switch (this) {
      case TaskRepeat.once:   return 'Once';
      case TaskRepeat.daily:  return 'Daily';
      case TaskRepeat.weekly: return 'Weekly';
    }
  }
}

class Task {
  final String id;
  String name;
  TaskCategory category;

  /// Start date (primary date)
  DateTime dueDate;

  /// Optional end date (for multi-day tasks)
  DateTime? endDate;

  /// Optional start time
  TimeOfDay? dueTime;

  /// Optional end time
  TimeOfDay? endTime;

  TaskPriority priority;
  String? spaceName;
  String? notes;
  TaskRepeat repeat;
  TaskStatus status;
  final DateTime createdAt;

  Task({
    required this.id,
    required this.name,
    required this.category,
    required this.dueDate,
    this.endDate,
    this.dueTime,
    this.endTime,
    this.priority = TaskPriority.medium,
    this.spaceName,
    this.notes,
    this.repeat = TaskRepeat.once,
    this.status = TaskStatus.notStarted,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isOverdue =>
      status != TaskStatus.completed &&
      dueDate.isBefore(DateTime.now().subtract(const Duration(days: 1)));

  bool get isMultiDay =>
      endDate != null &&
      !DateTime(endDate!.year, endDate!.month, endDate!.day)
          .isAtSameMomentAs(DateTime(dueDate.year, dueDate.month, dueDate.day));

  bool get hasTimeRange => dueTime != null && endTime != null;
}