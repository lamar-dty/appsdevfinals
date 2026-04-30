import 'package:flutter/material.dart';
import 'dart:math';
import '../store/auth_store.dart';

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
  final String id;
  String title;
  String description;
  String status;
  Color statusColor;

  /// User IDs of assigned members.
  /// Use [assignedNames] to obtain display names for the UI.
  List<String> assignedUserIds;

  final List<SpaceAttachment> attachments;

  SpaceTask({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.statusColor,
    List<String>? assignedUserIds,
    List<SpaceAttachment>? attachments,
  })  : assignedUserIds = _dedupeIds(assignedUserIds ?? <String>[]),
        attachments     = attachments ?? <SpaceAttachment>[];

  /// Resolved display names for all assigned user IDs.
  /// IDs that cannot be resolved are silently skipped.
  List<String> get assignedNames => assignedUserIds
      .map((id) => AuthStore.instance.nameForId(id) ?? '')
      .where((n) => n.isNotEmpty)
      .toList();

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

  static String _generateId() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex(int b) => b.toRadixString(16).padLeft(2, '0');
    return '${hex(bytes[0])}${hex(bytes[1])}${hex(bytes[2])}${hex(bytes[3])}'
        '-${hex(bytes[4])}${hex(bytes[5])}'
        '-${hex(bytes[6])}${hex(bytes[7])}'
        '-${hex(bytes[8])}${hex(bytes[9])}'
        '-${hex(bytes[10])}${hex(bytes[11])}${hex(bytes[12])}${hex(bytes[13])}${hex(bytes[14])}${hex(bytes[15])}';
  }

  factory SpaceTask.blank(String title, {String description = ''}) =>
      SpaceTask(
        id:          _generateId(),
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

  /// Deduplicates a list of user IDs, dropping empty strings.
  static List<String> _dedupeIds(List<String> raw) {
    final seen = <String>{};
    return raw.where((id) => id.isNotEmpty && seen.add(id)).toList();
  }

  /// Converts a list of legacy display names to user IDs for migration.
  static List<String> _taskNamesToIds(List<dynamic>? rawNames) {
    const drop = <String>{'You', 'You (Creator)', 'Creator'};
    final result = <String>[];
    for (final item in rawNames?.whereType<String>() ?? <String>[]) {
      if (item.isEmpty || drop.contains(item)) continue;
      final name = item.endsWith(' (Creator)')
          ? item.substring(0, item.length - ' (Creator)'.length).trim()
          : item;
      if (name.isEmpty) continue;
      final uid = AuthStore.instance.userIdForName(name);
      if (uid != null && uid.isNotEmpty) result.add(uid);
    }
    final seen = <String>{};
    return result.where(seen.add).toList();
  }

  Map<String, dynamic> toJson() => {
        'id':              id,
        'title':           title,
        'description':     description,
        'status':          status,
        'assignedUserIds': assignedUserIds,
        'attachments':     attachments.map((a) => a.toJson()).toList(),
      };

  factory SpaceTask.fromJson(Map<String, dynamic> j) {
    final status = (j['status'] as String?) ?? 'Not Started';
    final id = (j['id'] as String?)?.isNotEmpty == true
        ? j['id'] as String
        : _generateId();

    // ── Migration: prefer assignedUserIds; fall back to converting legacy names ──
    final List<String> resolvedIds;
    if (j.containsKey('assignedUserIds') && j['assignedUserIds'] is List) {
      resolvedIds = _dedupeIds(
          List<String>.from(
              (j['assignedUserIds'] as List).whereType<String>()));
    } else {
      resolvedIds = _taskNamesToIds(j['assignedTo'] as List?);
    }

    return SpaceTask(
      id:              id,
      title:           (j['title']       as String?) ?? '',
      description:     (j['description'] as String?) ?? '',
      status:          status,
      statusColor:     colorFor(status),
      assignedUserIds: resolvedIds,
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

  /// User IDs of all members except the creator.
  /// Use [memberNames] to obtain display names for the UI.
  final List<String> memberIds;

  /// True when the current user created this space.
  final bool isCreator;

  /// Canonical display name of whoever created the space.
  /// Must never be a sentinel string.
  final String creatorName;

  /// User ID of the creator. Empty for legacy spaces loaded before this
  /// field was introduced — use [creatorName] as fallback in that case.
  final String creatorId;

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
    required this.memberIds,
    required this.isCreator,
    required this.creatorName,
    this.creatorId = '',
    required this.status,
    required this.statusColor,
    required this.accentColor,
    required this.progress,
    required this.completedTasks,
    required this.tasks,
    String? inviteCode,
  })  : assert(
          creatorName.isNotEmpty,
          'Space.creatorName must not be empty. '
          'Pass AuthStore.instance.displayName when constructing a Space.',
        ),
        assert(
          !_isSentinel(creatorName),
          'Space.creatorName must be a real display name, not a sentinel '
          'string ("$creatorName").',
        ),
        inviteCode = inviteCode ?? _generateCode();

  // ── Member name resolution ─────────────────────────────────

  /// Resolved display names for all non-creator members.
  /// IDs that cannot be resolved are silently skipped.
  List<String> get memberNames => memberIds
      .map((id) => AuthStore.instance.nameForId(id) ?? '')
      .where((n) => n.isNotEmpty)
      .toList();

  /// Total headcount including the creator.
  int get memberCount => memberIds.length + 1;

  // ── Sentinel guard ─────────────────────────────────────────
  static bool _isSentinel(String name) {
    const sentinels = <String>{'You', 'You (Creator)', 'Creator'};
    if (sentinels.contains(name)) return true;
    if (name.endsWith(' (Creator)')) return true;
    return false;
  }

  static String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng   = Random.secure();
    return List.generate(8, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  int get totalTasks => tasks.length;

  bool get isCompleted => status == 'Completed';

  // ── Member helpers ─────────────────────────────────────────

  String canonicalNameFor(String currentUserDisplayName) {
    if (currentUserDisplayName.isEmpty) return creatorName;
    return _stripCreatorSuffix(currentUserDisplayName);
  }

  /// True if [userId] is the creator or a member (ID-based).
  bool containsMemberId(String userId) {
    if (userId.isEmpty) return false;
    if (creatorId.isNotEmpty && userId == creatorId) return true;
    return memberIds.contains(userId);
  }

  /// True if [displayName] resolves to the creator or a member.
  /// Kept for call sites that still work with display names.
  bool containsMember(String displayName) {
    if (displayName.isEmpty) return false;
    final cleaned = _stripCreatorSuffix(displayName);
    if (cleaned == creatorName) return true;
    return memberNames.contains(cleaned);
  }

  static String _stripCreatorSuffix(String name) {
    if (name.endsWith(' (Creator)')) {
      return name.substring(0, name.length - ' (Creator)'.length).trim();
    }
    return name;
  }

  /// Removes assignee IDs from all tasks whose users are no longer members.
  void pruneStaleAssignees() {
    final validIds = <String>{
      if (creatorId.isNotEmpty) creatorId,
      ...memberIds,
    };
    // Fallback: if creatorId is empty, resolve by name.
    if (creatorId.isEmpty && creatorName.isNotEmpty) {
      final cid = AuthStore.instance.userIdForName(creatorName);
      if (cid != null) validIds.add(cid);
    }
    for (final task in tasks) {
      task.assignedUserIds
          .removeWhere((id) => id.isEmpty || !validIds.contains(id));
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
      return 0;
    }
  }

  // ── Serialisation ─────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'name':           name,
        'description':    description,
        'dateRange':      dateRange,
        'dueDate':        dueDate,
        'memberIds':      memberIds,
        'isCreator':      isCreator,
        'creatorName':    creatorName,
        'creatorId':      creatorId,
        'status':         status,
        'accentColor':    accentColor.value,
        'progress':       progress,
        'completedTasks': completedTasks,
        'tasks':          tasks.map((t) => t.toJson()).toList(),
        'inviteCode':     inviteCode,
      };

  static String _normaliseDateRange(String raw) {
    if (raw.isEmpty) return raw;
    return raw.replaceAll(RegExp(r'\s*-\s*'), ' - ');
  }

  static String _sanitiseCreatorName(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    if (raw == 'Creator' || raw == 'You' || raw == 'You (Creator)') return '';
    if (raw.endsWith(' (Creator)')) {
      return raw.substring(0, raw.length - ' (Creator)'.length).trim();
    }
    return raw;
  }

  /// Converts a legacy display-name list to user IDs.
  /// Names that cannot be resolved are dropped.
  static List<String> _namesToIds(List<dynamic>? rawNames) {
    const drop = <String>{'You', 'You (Creator)', 'Creator'};
    final result = <String>[];
    for (final item in rawNames?.whereType<String>() ?? <String>[]) {
      if (item.isEmpty || drop.contains(item)) continue;
      final name = item.endsWith(' (Creator)')
          ? item.substring(0, item.length - ' (Creator)'.length).trim()
          : item;
      if (name.isEmpty) continue;
      final uid = AuthStore.instance.userIdForName(name);
      if (uid != null && uid.isNotEmpty) result.add(uid);
    }
    final seen = <String>{};
    return result.where(seen.add).toList();
  }

  static List<String> _sanitiseMemberIds(List<dynamic>? raw) {
    final result = <String>[];
    for (final item in raw?.whereType<String>() ?? <String>[]) {
      if (item.isNotEmpty) result.add(item);
    }
    final seen = <String>{};
    return result.where(seen.add).toList();
  }

  factory Space.fromJson(Map<String, dynamic> j) {
    final status      = (j['status'] as String?) ?? 'Not Started';
    final creatorName = _sanitiseCreatorName(j['creatorName'] as String?);
    final creatorId   = (j['creatorId'] as String?) ?? '';

    // ── Migration: prefer memberIds; fall back to converting legacy names ──
    final List<String> rawMemberIds;
    if (j.containsKey('memberIds') && j['memberIds'] is List) {
      rawMemberIds = _sanitiseMemberIds(j['memberIds'] as List?);
    } else {
      rawMemberIds = _namesToIds(j['members'] as List?);
    }

    // Resolve creator ID (may have been stored, or derive from name).
    final resolvedCreatorId = creatorId.isNotEmpty
        ? creatorId
        : (creatorName.isNotEmpty
            ? (AuthStore.instance.userIdForName(creatorName) ?? '')
            : '');

    // Remove creator's own ID from memberIds to avoid double-counting.
    final filteredMemberIds = resolvedCreatorId.isNotEmpty
        ? rawMemberIds.where((id) => id != resolvedCreatorId).toList()
        : rawMemberIds;

    return Space(
      name:           (j['name']        as String?) ?? '',
      description:    (j['description'] as String?) ?? '',
      dateRange:      _normaliseDateRange((j['dateRange'] as String?) ?? ''),
      dueDate:        (j['dueDate']     as String?) ?? '',
      memberIds:      filteredMemberIds,
      isCreator:      (j['isCreator']   as bool?)   ?? false,
      creatorName:    creatorName.isNotEmpty ? creatorName : 'Unknown',
      creatorId:      resolvedCreatorId,
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