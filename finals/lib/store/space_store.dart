import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/space.dart';
import 'auth_store.dart';
import 'storage_keys.dart';

// ─────────────────────────────────────────────────────────────
// Key accessors — resolved via StorageKeys so no raw strings
// are scattered through this file.
// ─────────────────────────────────────────────────────────────
String get _kSpaces => AuthStore.instance.keySpaceList();

// ─────────────────────────────────────────────────────────────
// SpaceStore
// ─────────────────────────────────────────────────────────────
class SpaceStore extends ChangeNotifier {
  SpaceStore._();
  static final SpaceStore instance = SpaceStore._();

  final List<Space> _spaces = [];

  List<Space> get spaces => _spaces;

  // ── Initialisation ────────────────────────────────────────

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final raw = prefs.getString(_kSpaces);
      if (raw != null) {
        final list = jsonDecode(raw) as List;
        for (final e in list) {
          try {
            _spaces.add(Space.fromJson(Map<String, dynamic>.from(e as Map)));
          } catch (_) {
            // Corrupt single entry — skip it, keep the rest.
          }
        }
        notifyListeners();
      }
    } catch (_) {
      // Corrupt top-level data — wipe and start clean so the app doesn't crash.
      _spaces.clear();
      await prefs.remove(_kSpaces);
    }
    await drainPendingInvites();
  }

  /// Clear in-memory state and reload for the current user.
  Future<void> reload() async {
    _spaces.clear();
    await load();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _kSpaces, jsonEncode(_spaces.map((s) => s.toJson()).toList()));
  }

  // ── Global registry ───────────────────────────────────────

  Future<void> _registerGlobally(Space space) async {
    if (!space.isCreator) return;
    final prefs = await SharedPreferences.getInstance();
    try {
      final raw = prefs.getString(kSpaceGlobalRegistry);
      final Map<String, dynamic> registry =
          raw != null ? Map<String, dynamic>.from(jsonDecode(raw) as Map) : {};
      registry[space.inviteCode] = space.toJson();
      await prefs.setString(kSpaceGlobalRegistry, jsonEncode(registry));
    } catch (_) {
      try {
        await prefs.setString(
            kSpaceGlobalRegistry,
            jsonEncode({space.inviteCode: space.toJson()}));
      } catch (_) {}
    }
  }

  Future<void> _unregisterGlobally(String inviteCode) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final raw = prefs.getString(kSpaceGlobalRegistry);
      if (raw == null) return;
      final Map<String, dynamic> registry =
          Map<String, dynamic>.from(jsonDecode(raw) as Map);
      registry.remove(inviteCode);
      try {
        final patchRaw = prefs.getString(kSpaceSharedPatches);
        if (patchRaw != null) {
          final patches =
              Map<String, dynamic>.from(jsonDecode(patchRaw) as Map);
          patches.remove(inviteCode);
          await prefs.setString(kSpaceSharedPatches, jsonEncode(patches));
        }
      } catch (_) {}
      await prefs.setString(kSpaceGlobalRegistry, jsonEncode(registry));
    } catch (_) {}
  }

  /// Look up a space by invite code.
  /// Shared patches are checked first as they always carry the latest mutation;
  /// the global registry is used as a fallback for spaces not yet patched.
  Future<Space?> lookupByCode(String code) async {
    if (code.isEmpty) return null;
    final prefs = await SharedPreferences.getInstance();

    // Prefer the shared patches store — it is updated on every mutation.
    try {
      final patchRaw = prefs.getString(kSpaceSharedPatches);
      if (patchRaw != null) {
        final patches =
            Map<String, dynamic>.from(jsonDecode(patchRaw) as Map);
        final entry = patches[code];
        if (entry != null) {
          return Space.fromJson(Map<String, dynamic>.from(entry as Map));
        }
      }
    } catch (_) {}

    // Fall back to the global registry.
    try {
      final raw = prefs.getString(kSpaceGlobalRegistry);
      if (raw == null) return null;
      final Map<String, dynamic> registry =
          Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final entry = registry[code];
      if (entry == null) return null;
      return Space.fromJson(Map<String, dynamic>.from(entry as Map));
    } catch (_) {
      return null;
    }
  }

  // ── Shared patches ────────────────────────────────────────

  /// Broadcast the latest state of [space] to all other members via the
  /// shared patches store.  Call after every in-place mutation.
  /// Also refreshes the global registry when the acting user is the creator,
  /// so late-joining members always receive the latest task list.
  Future<void> writeSharedPatch(Space space) async {
    await _writeSharedPatch(space);
    if (space.isCreator) await _registerGlobally(space);
  }

  /// Push deletion notices for [space] into every member's deletion inbox.
  /// Call when the creator deletes a space so members remove it on next focus.
  Future<void> writeDeletionNotice(Space space) =>
      _pushDeletionNoticesToMembers(space);

  Future<void> _writeSharedPatch(Space space) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final raw = prefs.getString(kSpaceSharedPatches);
      final Map<String, dynamic> patches =
          raw != null ? Map<String, dynamic>.from(jsonDecode(raw) as Map) : {};
      patches[space.inviteCode] = space.toJson();
      await prefs.setString(kSpaceSharedPatches, jsonEncode(patches));
    } catch (_) {
      try {
        await prefs.setString(
            kSpaceSharedPatches,
            jsonEncode({space.inviteCode: space.toJson()}));
      } catch (_) {}
    }
  }

  /// Patches only the memberIds list in the shared patches store for
  /// [inviteCode], without overwriting the rest of the space snapshot.
  /// Use this when a member joins via invite code so their local (potentially
  /// stale) space copy does not clobber the creator's latest task/status data.
  Future<void> patchMembersInSharedPatch(
      String inviteCode, List<String> memberIds) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(kSpaceSharedPatches);
    if (raw == null) return;
    try {
      final Map<String, dynamic> patches =
          Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final entry = patches[inviteCode];
      if (entry == null) return;
      final Map<String, dynamic> updated =
          Map<String, dynamic>.from(entry as Map);
      updated['memberIds'] = memberIds;
      updated.remove('members'); // drop legacy key
      patches[inviteCode] = updated;
      await prefs.setString(kSpaceSharedPatches, jsonEncode(patches));
    } catch (_) {
      // Patch entry missing or corrupt — ignore; creator's next save will
      // write a fresh patch that includes the updated member list.
    }
  }

  /// Patches the memberIds list in the global registry for [inviteCode].
  Future<void> patchMembersInRegistry(
      String inviteCode, List<String> memberIds) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(kSpaceGlobalRegistry);
    if (raw == null) return;
    try {
      final Map<String, dynamic> registry =
          Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final entry = registry[inviteCode];
      if (entry == null) return;
      final Map<String, dynamic> updated =
          Map<String, dynamic>.from(entry as Map);
      updated['memberIds'] = memberIds;
      // Remove legacy 'members' key so readers always use 'memberIds'.
      updated.remove('members');
      registry[inviteCode] = updated;
      await prefs.setString(kSpaceGlobalRegistry, jsonEncode(registry));
    } catch (_) {
      // Registry corrupted — ignore; the creator will overwrite on next save.
    }
  }

  /// Pull the latest state from shared patches into all in-memory spaces.
  /// Also prunes members from task assignments who no longer exist in the
  /// patched member list, preventing ghost UI states.
  Future<void> syncFromSharedPatches() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(kSpaceSharedPatches);
    if (raw == null) return;
    Map<String, dynamic> patches;
    try {
      patches = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return;
    }

    bool changed = false;
    for (int i = 0; i < _spaces.length; i++) {
      final space = _spaces[i];
      final patch = patches[space.inviteCode];
      if (patch == null) continue;

      Space patched;
      try {
        patched = Space.fromJson(Map<String, dynamic>.from(patch as Map));
      } catch (_) {
        continue;
      }

      bool assignmentsChanged() {
        if (patched.tasks.length != space.tasks.length) return true;
        for (int t = 0; t < patched.tasks.length; t++) {
          final pIds = patched.tasks[t].assignedUserIds;
          final sIds = space.tasks[t].assignedUserIds;
          if (pIds.length != sIds.length) return true;
          for (int j = 0; j < pIds.length; j++) {
            if (pIds[j] != sIds[j]) return true;
          }
        }
        return false;
      }

      final needsUpdate = patched.tasks.length != space.tasks.length ||
          patched.status != space.status ||
          patched.progress != space.progress ||
          patched.memberIds.length != space.memberIds.length ||
          assignmentsChanged();

      if (needsUpdate) {
        // Prune assignedUserIds for members no longer in the space.
        final validIds = <String>{
          if (patched.creatorId.isNotEmpty) patched.creatorId,
          ...patched.memberIds,
        };
        for (final task in patched.tasks) {
          task.assignedUserIds
              .removeWhere((id) => id.isEmpty || !validIds.contains(id));
        }

        final merged = Space(
          name: patched.name,
          description: patched.description,
          dateRange: patched.dateRange,
          dueDate: patched.dueDate,
          memberIds: patched.memberIds,
          isCreator: space.isCreator, // always keep local flag
          creatorName: patched.creatorName,
          creatorId: patched.creatorId,
          status: patched.status,
          statusColor: patched.statusColor,
          accentColor: patched.accentColor,
          progress: patched.progress,
          completedTasks: patched.completedTasks,
          tasks: patched.tasks,
          inviteCode: space.inviteCode,
        );
        _spaces[i] = merged;
        changed = true;
      }
    }

    if (changed) {
      notifyListeners();
      await _save();
    }
  }

  // ── Pending invites ───────────────────────────────────────

  Future<void> pushPendingInvite(String recipientUserId, Space space) async {
    if (recipientUserId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final key = kInboxSpaceInvites(recipientUserId);
    List<dynamic> list;
    try {
      final raw = prefs.getString(key);
      list = raw != null ? (jsonDecode(raw) as List) : [];
    } catch (_) {
      list = [];
    }
    if (!list.any((e) => (e as Map)['inviteCode'] == space.inviteCode)) {
      list.add(space.toJson());
      await prefs.setString(key, jsonEncode(list));
    }
  }

  Future<void> drainPendingInvites() async {
    final uid = AuthStore.instance.userId;
    if (uid.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final key = kInboxSpaceInvites(uid);
    final raw = prefs.getString(key);
    if (raw == null) return;
    try {
      final list = jsonDecode(raw) as List;
      bool changed = false;
      for (final e in list) {
        Space incoming;
        try {
          incoming =
              Space.fromJson(Map<String, dynamic>.from(e as Map));
        } catch (_) {
          continue;
        }
        if (_spaces.any((s) => s.inviteCode == incoming.inviteCode)) {
          continue; // already joined
        }
        final latest = await lookupByCode(incoming.inviteCode) ?? incoming;
        final joined = Space(
          name: latest.name,
          description: latest.description,
          dateRange: latest.dateRange,
          dueDate: latest.dueDate,
          memberIds: List<String>.from(latest.memberIds),
          isCreator: false,
          creatorName: latest.creatorName,
          creatorId: latest.creatorId,
          status: latest.status,
          statusColor: latest.statusColor,
          accentColor: latest.accentColor,
          progress: latest.progress,
          completedTasks: latest.completedTasks,
          tasks: latest.tasks,
          inviteCode: latest.inviteCode,
        );
        _spaces.add(joined);
        changed = true;
      }
      await prefs.remove(key);
      if (changed) {
        notifyListeners();
        await _save();
      }
    } catch (_) {
      await prefs.remove(key);
    }
  }

  // ── CRUD ──────────────────────────────────────────────────

  Future<void> addSpace(Space space) async {
    _spaces.add(space);
    notifyListeners();
    await _save();
    if (space.isCreator) {
      await _registerGlobally(space);
      await _writeSharedPatch(space);
    }
  }

  Future<void> removeSpace(Space space) async {
    _spaces.remove(space);
    notifyListeners();
    await _save();
    if (space.isCreator) {
      await _unregisterGlobally(space.inviteCode);
    } else {
      final leavingId = AuthStore.instance.userId;
      await _removeMemberFromRegistry(space.inviteCode, leavingId);
      await _removeMemberFromPatches(space.inviteCode, leavingId);
    }
  }

  // ── Deletion broadcast ────────────────────────────────────

  /// Write [space.inviteCode] into each member's deletion inbox so they
  /// remove the space from their list the next time the screen focuses.
  Future<void> _pushDeletionNoticesToMembers(Space space) async {
    final myId = AuthStore.instance.userId;
    for (final memberId in space.memberIds) {
      if (memberId.isEmpty) continue;
      // Never send a deletion notice to the creator themselves.
      if (memberId == myId) continue;
      await _pushDeletionNotice(space.inviteCode, memberId);
    }
  }

  /// Write [inviteCode] into [recipientUserId]'s deletion inbox.
  Future<void> _pushDeletionNotice(
      String inviteCode, String recipientUserId) async {
    if (recipientUserId.isEmpty || inviteCode.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final key = kInboxSpaceDeletion(recipientUserId);
    List<dynamic> list;
    try {
      final raw = prefs.getString(key);
      list = raw != null ? (jsonDecode(raw) as List) : [];
    } catch (_) {
      list = [];
    }
    if (!list.contains(inviteCode)) {
      list.add(inviteCode);
      await prefs.setString(key, jsonEncode(list));
    }
  }

  /// Drain the deletion inbox for the current user.
  Future<Set<String>> drainDeletionNotices() async {
    final uid = AuthStore.instance.userId;
    if (uid.isEmpty) return {};
    final prefs = await SharedPreferences.getInstance();
    final key = kInboxSpaceDeletion(uid);
    final raw = prefs.getString(key);
    if (raw == null) return {};

    Set<String> removed = {};
    try {
      final List<dynamic> codes = jsonDecode(raw) as List;
      for (final entry in codes) {
        final code = entry is String ? entry : null;
        if (code == null || code.isEmpty) continue;
        final before = _spaces.length;
        _spaces.removeWhere((s) => s.inviteCode == code);
        if (_spaces.length < before) removed.add(code);
      }
    } catch (_) {}
    await prefs.remove(key);
    if (removed.isNotEmpty) {
      notifyListeners();
      await _save();
    }
    return removed;
  }

  /// Removes [memberId] from the memberIds list in the global registry.
  Future<void> _removeMemberFromRegistry(
      String inviteCode, String memberId) async {
    if (memberId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(kSpaceGlobalRegistry);
    if (raw == null) return;
    try {
      final Map<String, dynamic> registry =
          Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final entry = registry[inviteCode];
      if (entry == null) return;
      final Map<String, dynamic> updated =
          Map<String, dynamic>.from(entry as Map);
      final ids = List<String>.from(
          (updated['memberIds'] as List?) ?? [])
        ..remove(memberId);
      updated['memberIds'] = ids;
      updated.remove('members'); // drop legacy key
      registry[inviteCode] = updated;
      await prefs.setString(kSpaceGlobalRegistry, jsonEncode(registry));
    } catch (_) {}
  }

  /// Removes [memberId] from the memberIds list in the shared patches store.
  Future<void> _removeMemberFromPatches(
      String inviteCode, String memberId) async {
    if (memberId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(kSpaceSharedPatches);
    if (raw == null) return;
    try {
      final Map<String, dynamic> patches =
          Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final entry = patches[inviteCode];
      if (entry == null) return;
      final Map<String, dynamic> updated =
          Map<String, dynamic>.from(entry as Map);
      final ids = List<String>.from(
          (updated['memberIds'] as List?) ?? [])
        ..remove(memberId);
      updated['memberIds'] = ids;
      updated.remove('members'); // drop legacy key
      patches[inviteCode] = updated;
      await prefs.setString(kSpaceSharedPatches, jsonEncode(patches));
    } catch (_) {}
  }

  /// Persist in-memory state and notify listeners.
  /// Callers are responsible for calling [writeSharedPatch] on the mutated
  /// space to broadcast changes to other members.
  void save() {
    notifyListeners();
    _save();
  }

  /// Returns a set of all active invite codes for the current user's spaces.
  Set<String> get activeInviteCodes =>
      _spaces.map((s) => s.inviteCode).toSet();
}