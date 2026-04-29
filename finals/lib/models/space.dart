import 'package:flutter/material.dart';
import 'dart:math';

// ─────────────────────────────────────────────────────────────
// SpaceAttachment
// ─────────────────────────────────────────────────────────────
class SpaceAttachment {
  final String name;

  SpaceAttachment({required this.name});

  Map<String, dynamic> toJson() => {'name': name};

  factory SpaceAttachment.fromJson(Map<String, dynamic> j) =>
      SpaceAttachment(name: (j['name'] as String?) ?? '');

  String get type {
    final ext =
        name.contains('.') ? name.split('.').last.toLowerCase() : '';
    if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'svg'].contains(ext)) {
      return 'image';
    }
    if (['pdf'].contains(ext)) return 'pdf';
    if (['doc', 'docx'].contains(ext)) return 'doc';
    if (['xls', 'xlsx'].contains(ext)) return 'sheet';
    if (['ppt', 'pptx'].contains(ext)) return 'slides';
    if (['zip', 'rar', '7z'].contains(ext)) return 'archive';
    if (['mp4', 'mov', 'avi'].contains(ext)) return 'video';
    return 'file';
  }

  IconData get icon {
    switch (type) {
      case 'image':   return Icons.image_rounded;
      case 'pdf':     return Icons.picture_as_pdf_rounded;
      case 'doc':     return Icons.description_rounded;
      case 'sheet':   return Icons.table_chart_rounded;
      case 'slides':  return Icons.slideshow_rounded;
      case 'archive': return Icons.folder_zip_rounded;
      case 'video':   return Icons.videocam_rounded;
      default:        return Icons.insert_drive_file_rounded;
    }
  }

  Color get color {
    switch (type) {
      case 'image':   return const Color(0xFF9B88E8);
      case 'pdf':     return const Color(0xFFE87070);
      case 'doc':     return const Color(0xFF4A90D9);
      case 'sheet':   return const Color(0xFF3BBFA3);
      case 'slides':  return const Color(0xFFE8A070);
      case 'archive': return const Color(0xFFB0BAD3);
      case 'video':   return const Color(0xFF70B8E8);
      default:        return const Color(0xFFB0BAD3);
    }
  }
}

// ─────────────────────────────────────────────────────────────
// SpaceTask
// ─────────────────────────────────────────────────────────────
class SpaceTask {
  String title;
  String description;
  String status;
  Color statusColor;

  /// Names of assigned members. Empty list = unassigned.
  List<String> assignedTo;

  final List<SpaceAttachment> attachments;

  SpaceTask({
    required this.title,
    required this.description,
    required this.status,
    required this.statusColor,
    List<String>? assignedTo,
    List<SpaceAttachment>? attachments,
  })  : assignedTo  = assignedTo  ?? <String>[],
        attachments = attachments ?? <SpaceAttachment>[];

  static const List<String> _order = [
    'Not Started',
    'In Progress',
    'Completed'
  ];

  static Color colorFor(String status) {
    switch (status) {
      case 'In Progress': return const Color(0xFF4A90D9);
      case 'Completed':   return const Color(0xFF3BBFA3);
      default:            return const Color(0xFFB0BAD3);
    }
  }

  factory SpaceTask.blank(String title, {String description = ''}) =>
      SpaceTask(
        title:       title,
        description: description,
        status:      'Not Started',
        statusColor: const Color(0xFFB0BAD3),
      );

  void cycleStatus() {
    final next  = (_order.indexOf(status) + 1) % _order.length;
    status      = _order[next];
    statusColor = colorFor(status);
  }

  Map<String, dynamic> toJson() => {
        'title':       title,
        'description': description,
        'status':      status,
        'assignedTo':  assignedTo,
        'attachments': attachments.map((a) => a.toJson()).toList(),
      };

  factory SpaceTask.fromJson(Map<String, dynamic> j) {
    final status = (j['status'] as String?) ?? 'Not Started';
    return SpaceTask(
      title:       (j['title'] as String?)       ?? '',
      description: (j['description'] as String?) ?? '',
      status:      status,
      statusColor: colorFor(status),
      assignedTo:  List<String>.from(
          (j['assignedTo'] as List?)?.whereType<String>().toList() ?? []),
      attachments: ((j['attachments'] as List?) ?? [])
          .whereType<Map>()
          .map((e) => SpaceAttachment.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Space
// ─────────────────────────────────────────────────────────────
class Space {
  String name;
  String description;
  final String dateRange;
  final String dueDate;

  /// All members except the creator.
  final List<String> members;

  /// True when the current user created this space.
  final bool isCreator;

  /// Display name of whoever created the space.
  final String creatorName;

  String status;
  Color statusColor;
  final Color accentColor;
  double progress;
  int completedTasks;
  final List<SpaceTask> tasks;
  final String inviteCode;

  Space({
    required this.name,
    required this.description,
    required this.dateRange,
    required this.dueDate,
    required this.members,
    required this.isCreator,
    required this.creatorName,
    required this.status,
    required this.statusColor,
    required this.accentColor,
    required this.progress,
    required this.completedTasks,
    required this.tasks,
    String? inviteCode,
  }) : inviteCode = inviteCode ?? _generateCode();

  static String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng   = Random.secure();
    return List.generate(8, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  /// Total headcount including the creator.
  int get memberCount => members.length + 1;

  int get totalTasks => tasks.length;

  bool get isCompleted => status == 'Completed';

  // ── Member helpers ─────────────────────────────────────────

  /// True if [displayName] is the creator OR appears in the members list.
  /// Also accepts the sentinel strings used in the assignment picker UI.
  bool containsMember(String displayName) {
    if (displayName == creatorName) return true;
    if (displayName == 'You' || displayName == 'You (Creator)') return true;
    // Strip the " (Creator)" suffix that the picker sometimes appends.
    final cleaned = displayName.endsWith(' (Creator)')
        ? displayName.substring(0, displayName.length - ' (Creator)'.length)
        : displayName;
    return members.contains(cleaned) || cleaned == creatorName;
  }

  /// Remove stale assignee names that are no longer members of the space.
  /// Call after removing a member or syncing from shared patches.
  void pruneStaleAssignees() {
    final valid = <String>{creatorName, ...members};
    for (final task in tasks) {
      task.assignedTo.removeWhere((name) {
        if (name == 'You' || name == 'You (Creator)') return false;
        final cleaned = name.endsWith(' (Creator)')
            ? name.substring(0, name.length - ' (Creator)'.length)
            : name;
        return !valid.contains(cleaned);
      });
    }
  }

  // ── Recalculation ─────────────────────────────────────────

  void recalculate() {
    completedTasks = tasks.where((t) => t.status == 'Completed').length;
    progress       = tasks.isEmpty ? 0.0 : completedTasks / tasks.length;
    final hasInProgress = tasks.any((t) => t.status == 'In Progress');
    if (tasks.isNotEmpty && completedTasks == tasks.length) {
      status      = 'Completed';
      statusColor = const Color(0xFF3BBFA3);
    } else if (completedTasks > 0 || hasInProgress) {
      status      = 'In Progress';
      statusColor = const Color(0xFF4A90D9);
    } else {
      status      = 'Not Started';
      statusColor = const Color(0xFFB0BAD3);
    }
  }

  /// Days remaining until [dueDate] (negative = overdue).
  int get daysLeft {
    try {
      final parts = dueDate.split('/');
      if (parts.length < 3) return 0;
      final due = DateTime(
        int.parse(parts[2]),
        int.parse(parts[0]),
        int.parse(parts[1]),
      );
      return due.difference(DateTime.now()).inDays;
    } catch (_) {
      return 0; // malformed date — treat as today
    }
  }

  // ── Serialisation ─────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'name':           name,
        'description':    description,
        'dateRange':      dateRange,
        'dueDate':        dueDate,
        'members':        members,
        'isCreator':      isCreator,
        'creatorName':    creatorName,
        'status':         status,
        'accentColor':    accentColor.value,
        'progress':       progress,
        'completedTasks': completedTasks,
        'tasks':          tasks.map((t) => t.toJson()).toList(),
        'inviteCode':     inviteCode,
      };

  factory Space.fromJson(Map<String, dynamic> j) {
    final status = (j['status'] as String?) ?? 'Not Started';
    return Space(
      name:           (j['name']        as String?) ?? '',
      description:    (j['description'] as String?) ?? '',
      dateRange:      (j['dateRange']   as String?) ?? '',
      dueDate:        (j['dueDate']     as String?) ?? '',
      members:        List<String>.from(
          (j['members'] as List?)?.whereType<String>().toList() ?? []),
      isCreator:      (j['isCreator']   as bool?)   ?? false,
      creatorName:    (j['creatorName'] as String?) ?? 'Creator',
      status:         status,
      statusColor:    SpaceTask.colorFor(status),
      accentColor:    Color((j['accentColor'] as int?) ?? 0xFF9B88E8),
      progress:       ((j['progress']      as num?)  ?? 0.0).toDouble(),
      completedTasks: (j['completedTasks'] as int?)  ?? 0,
      tasks: ((j['tasks'] as List?) ?? [])
          .whereType<Map>()
          .map((e) => SpaceTask.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      inviteCode: (j['inviteCode'] as String?) ?? '',
    );
  }
}