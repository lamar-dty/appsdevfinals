import 'package:flutter/material.dart';

enum EventCategory {
  academic,
  organization,
  social,
  health,
  other,
}

extension EventCategoryExt on EventCategory {
  String get label {
    switch (this) {
      case EventCategory.academic:     return 'Academic';
      case EventCategory.organization: return 'Organization';
      case EventCategory.social:       return 'Social';
      case EventCategory.health:       return 'Health & Wellness';
      case EventCategory.other:        return 'Other';
    }
  }

  String get description {
    switch (this) {
      case EventCategory.academic:     return 'Classes, exams, school events';
      case EventCategory.organization: return 'Org meetings, clubs, volunteer';
      case EventCategory.social:       return 'Parties, hangouts, gatherings';
      case EventCategory.health:       return 'Gym, appointments, rest days';
      case EventCategory.other:        return 'Anything else';
    }
  }

  Color get color {
    switch (this) {
      case EventCategory.academic:     return const Color(0xFF4A90D9);
      case EventCategory.organization: return const Color(0xFFE8A870);
      case EventCategory.social:       return const Color(0xFFD96B8A);
      case EventCategory.health:       return const Color(0xFF3BBFA3);
      case EventCategory.other:        return const Color(0xFFB0BAD3);
    }
  }

  IconData get icon {
    switch (this) {
      case EventCategory.academic:     return Icons.school_rounded;
      case EventCategory.organization: return Icons.groups_rounded;
      case EventCategory.social:       return Icons.people_rounded;
      case EventCategory.health:       return Icons.favorite_rounded;
      case EventCategory.other:        return Icons.circle_rounded;
    }
  }
}

class Event {
  final String id;
  String title;
  EventCategory category;
  String? location;
  String? notes;

  /// Start date of the event
  DateTime startDate;

  /// End date (defaults to same as startDate for single-day events)
  DateTime endDate;

  /// Optional start time
  TimeOfDay? startTime;

  /// Optional end time
  TimeOfDay? endTime;

  final DateTime createdAt;

  Event({
    required this.id,
    required this.title,
    required this.category,
    required this.startDate,
    DateTime? endDate,
    this.startTime,
    this.endTime,
    this.location,
    this.notes,
    DateTime? createdAt,
  })  : endDate = endDate ?? startDate,
        createdAt = createdAt ?? DateTime.now();

  bool get isMultiDay {
    final s = DateTime(startDate.year, startDate.month, startDate.day);
    final e = DateTime(endDate.year, endDate.month, endDate.day);
    return e.isAfter(s);
  }

  bool get hasTimeRange => startTime != null && endTime != null;
}