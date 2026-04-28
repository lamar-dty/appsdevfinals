import 'package:flutter/material.dart';
import 'dart:math';

// ─────────────────────────────────────────────────────────────
// SpaceAttachment
// ─────────────────────────────────────────────────────────────
class SpaceAttachment {
  final String name;

  SpaceAttachment({required this.name});

  /// Infer a file-type category from the extension.
  String get type {
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'svg'].contains(ext)) return 'image';
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
  String description; // mutable so notes can be edited in TaskDetailSheet
  String status;
  Color statusColor;

  /// Names of assigned members. Empty list means unassigned.
  List<String> assignedTo;

  /// Simulated attachments — swap picker call here when file_picker is ready.
  final List<SpaceAttachment> attachments;

  SpaceTask({
    required this.title,
    required this.description,
    required this.status,
    required this.statusColor,
    List<String>? assignedTo,
    List<SpaceAttachment>? attachments,
  })  : assignedTo = assignedTo ?? <String>[],
        attachments = attachments ?? <SpaceAttachment>[];

  static const List<String> _order = ['Not Started', 'In Progress', 'Completed'];

  static Color colorFor(String status) {
    switch (status) {
      case 'In Progress': return const Color(0xFF4A90D9);
      case 'Completed':   return const Color(0xFF3BBFA3);
      default:            return const Color(0xFFB0BAD3);
    }
  }

  factory SpaceTask.blank(String title, {String description = ''}) => SpaceTask(
    title:       title,
    description: description,
    status:      'Not Started',
    statusColor: const Color(0xFFB0BAD3),
  );

  void cycleStatus() {
    final next = (_order.indexOf(status) + 1) % _order.length;
    status      = _order[next];
    statusColor = colorFor(status);
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

  /// All members except the creator. Mutable so members can be kicked.
  final List<String> members;

  /// True when the current user created this space.
  final bool isCreator;

  String status;
  Color statusColor;
  final Color accentColor;
  double progress;
  int completedTasks;
  final List<SpaceTask> tasks;

  /// Unique 8-character alphanumeric invite code for this space.
  final String inviteCode;

  Space({
    required this.name,
    required this.description,
    required this.dateRange,
    required this.dueDate,
    required this.members,
    required this.isCreator,
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
    final rng = Random.secure();
    return List.generate(8, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  /// Total headcount including the creator.
  int get memberCount => members.length + 1;

  int get totalTasks => tasks.length;

  bool get isCompleted => status == 'Completed';

  /// Recalculates [completedTasks], [progress], and [status] from the task list.
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
      final due = DateTime(
        int.parse(parts[2]),
        int.parse(parts[0]),
        int.parse(parts[1]),
      );
      return due.difference(DateTime.now()).inDays;
    } catch (_) {
      return 0;
    }
  }
}