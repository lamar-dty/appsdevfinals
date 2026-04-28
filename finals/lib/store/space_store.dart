import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/space.dart';
import 'auth_store.dart';

// Per-user list of spaces this account has joined/created.
String get _kSpaces => AuthStore.instance.scopedKey('space_store_spaces');

// Global registry: inviteCode -> Space JSON (written only by creator).
// Non-user-scoped so any account on the device can look up a space by code.
const _kGlobalRegistry = 'space_global_registry';

// Shared patches: inviteCode -> Space JSON (writable by any member).
// Members write their full space state here so the creator and other members
// can pull the latest tasks, status, and progress on next sync.
const _kSharedPatches = 'space_shared_patches';

// Pending invites inbox: userId -> List<Space JSON>
// Written by the inviter when they add someone by user ID.
// Drained by the invitee on load/focus so the space appears automatically.
String _pendingInviteKey(String userId) => 'space_pending_invites_$userId';

class SpaceStore extends ChangeNotifier {
  SpaceStore._();
  static final SpaceStore instance = SpaceStore._();

  final List<Space> _spaces = [];

  List<Space> get spaces => _spaces;

  // ── Initialisation ────────────────────────────────────────

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kSpaces);
    if (raw != null) {
      final list = jsonDecode(raw) as List;
      _spaces.addAll(
        list.map((e) => Space.fromJson(Map<String, dynamic>.from(e as Map))),
      );
      notifyListeners();
    }
    // Auto-accept any spaces pushed to this user by direct invite.
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

  // ── Global registry (creator-authoritative) ───────────────

  /// Publish this space to the global registry so others can join by code.
  /// Only called for creator-owned spaces.
  Future<void> _registerGlobally(Space space) async {
    if (!space.isCreator) return; // only the creator owns the registry entry
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kGlobalRegistry);
    final Map<String, dynamic> registry =
        raw != null ? Map<String, dynamic>.from(jsonDecode(raw) as Map) : {};
    registry[space.inviteCode] = space.toJson();
    await prefs.setString(_kGlobalRegistry, jsonEncode(registry));
  }

  /// Remove a space from the global registry (called when creator deletes it).
  Future<void> _unregisterGlobally(String inviteCode) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kGlobalRegistry);
    if (raw == null) return;
    final Map<String, dynamic> registry =
        Map<String, dynamic>.from(jsonDecode(raw) as Map);
    registry.remove(inviteCode);
    // Also clean up any shared patches for this space.
    final patchRaw = prefs.getString(_kSharedPatches);
    if (patchRaw != null) {
      final patches = Map<String, dynamic>.from(jsonDecode(patchRaw) as Map);
      patches.remove(inviteCode);
      await prefs.setString(_kSharedPatches, jsonEncode(patches));
    }
    await prefs.setString(_kGlobalRegistry, jsonEncode(registry));
  }

  /// Look up a space by invite code from the global registry.
  Future<Space?> lookupByCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kGlobalRegistry);
    if (raw == null) return null;
    final Map<String, dynamic> registry =
        Map<String, dynamic>.from(jsonDecode(raw) as Map);
    final entry = registry[code];
    if (entry == null) return null;
    return Space.fromJson(Map<String, dynamic>.from(entry as Map));
  }

  // ── Shared patches (any member can write) ─────────────────

  /// Write the full current state of a space into the shared patches store.
  /// Called by both creators and members after any mutation so the other
  /// party sees tasks, status, and progress updates on next sync.
  /// Public entry point used when a member leaves — writes the cleaned space
  /// state (member + task assignments already stripped) to shared patches so
  /// remaining members pick up the change on their next sync.
  Future<void> writeSharedPatchForLeave(Space space) => _writeSharedPatch(space);

  Future<void> _writeSharedPatch(Space space) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kSharedPatches);
    final Map<String, dynamic> patches =
        raw != null ? Map<String, dynamic>.from(jsonDecode(raw) as Map) : {};
    patches[space.inviteCode] = space.toJson();
    await prefs.setString(_kSharedPatches, jsonEncode(patches));
  }

  /// Patch only the members list in the global registry when a new user joins,
  /// so the creator's registry entry reflects the new membership immediately.
  Future<void> patchMembersInRegistry(
      String inviteCode, List<String> members) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kGlobalRegistry);
    if (raw == null) return;
    final Map<String, dynamic> registry =
        Map<String, dynamic>.from(jsonDecode(raw) as Map);
    final entry = registry[inviteCode];
    if (entry == null) return;
    final Map<String, dynamic> updated =
        Map<String, dynamic>.from(entry as Map);
    updated['members'] = members;
    registry[inviteCode] = updated;
    await prefs.setString(_kGlobalRegistry, jsonEncode(registry));
  }

  /// Pull the latest state from shared patches into all in-memory spaces,
  /// then persist locally. Call whenever the Spaces screen becomes visible.
  Future<void> syncFromSharedPatches() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kSharedPatches);
    if (raw == null) return;
    final Map<String, dynamic> patches =
        Map<String, dynamic>.from(jsonDecode(raw) as Map);

    bool changed = false;
    for (int i = 0; i < _spaces.length; i++) {
      final space = _spaces[i];
      final patch = patches[space.inviteCode];
      if (patch == null) continue;
      final patched =
          Space.fromJson(Map<String, dynamic>.from(patch as Map));

      // Merge: take tasks/status/progress from patch, keep local isCreator flag.
      final needsUpdate =
          patched.tasks.length != space.tasks.length ||
          patched.status != space.status ||
          patched.progress != space.progress ||
          patched.members.length != space.members.length;

      if (needsUpdate) {
        // Rebuild the space with patched fields, preserving this user's
        // isCreator flag (the patch comes from whichever user last wrote it).
        final merged = Space(
          name: patched.name,
          description: patched.description,
          dateRange: patched.dateRange,
          dueDate: patched.dueDate,
          members: patched.members,
          isCreator: space.isCreator, // always keep local flag
          creatorName: patched.creatorName,
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

  // ── Pending invites (direct add by user ID) ──────────────

  /// Write [space] into [recipientUserId]'s pending invite inbox so it
  /// appears on their device automatically when they next open the app.
  Future<void> pushPendingInvite(String recipientUserId, Space space) async {
    if (recipientUserId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final key = _pendingInviteKey(recipientUserId);
    final raw = prefs.getString(key);
    final List<dynamic> list = raw != null ? (jsonDecode(raw) as List) : [];
    // Dedup by invite code.
    if (!list.any((e) => (e as Map)['inviteCode'] == space.inviteCode)) {
      list.add(space.toJson());
      await prefs.setString(key, jsonEncode(list));
    }
  }

  /// Drain any pending invites for the current user and add them as spaces.
  /// Call on load and whenever the Spaces screen gains focus.
  Future<void> drainPendingInvites() async {
    final uid = AuthStore.instance.userId;
    if (uid.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final key = _pendingInviteKey(uid);
    final raw = prefs.getString(key);
    if (raw == null) return;
    try {
      final list = jsonDecode(raw) as List;
      bool changed = false;
      for (final e in list) {
        final space = Space.fromJson(Map<String, dynamic>.from(e as Map));
        // Skip if already joined.
        if (_spaces.any((s) => s.inviteCode == space.inviteCode)) continue;
        // Add as a non-creator member using the latest state from the registry.
        final latest = await lookupByCode(space.inviteCode) ?? space;
        final joined = Space(
          name: latest.name,
          description: latest.description,
          dateRange: latest.dateRange,
          dueDate: latest.dueDate,
          members: List<String>.from(latest.members),
          isCreator: false,
          creatorName: latest.creatorName,
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
    await _registerGlobally(space);   // only writes if isCreator
    await _writeSharedPatch(space);   // always write so others can sync
  }

  Future<void> removeSpace(Space space) async {
    _spaces.remove(space);
    notifyListeners();
    await _save();
    if (space.isCreator) {
      await _unregisterGlobally(space.inviteCode);
    } else {
      // Non-creator leaving: remove their name from the members list in both
      // the global registry and shared patches so the creator and other members
      // see the updated membership on their next sync.
      final leavingName = AuthStore.instance.displayName;
      await _removeMemberFromRegistry(space.inviteCode, leavingName);
      await _removeMemberFromPatches(space.inviteCode, leavingName);
    }
  }

  /// Remove [memberName] from the members list stored in the global registry.
  Future<void> _removeMemberFromRegistry(
      String inviteCode, String memberName) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kGlobalRegistry);
    if (raw == null) return;
    final Map<String, dynamic> registry =
        Map<String, dynamic>.from(jsonDecode(raw) as Map);
    final entry = registry[inviteCode];
    if (entry == null) return;
    final Map<String, dynamic> updated =
        Map<String, dynamic>.from(entry as Map);
    final members = List<String>.from(updated['members'] as List)
      ..remove(memberName);
    updated['members'] = members;
    registry[inviteCode] = updated;
    await prefs.setString(_kGlobalRegistry, jsonEncode(registry));
  }

  /// Remove [memberName] from the members list stored in the shared patches.
  Future<void> _removeMemberFromPatches(
      String inviteCode, String memberName) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kSharedPatches);
    if (raw == null) return;
    final Map<String, dynamic> patches =
        Map<String, dynamic>.from(jsonDecode(raw) as Map);
    final entry = patches[inviteCode];
    if (entry == null) return;
    final Map<String, dynamic> updated =
        Map<String, dynamic>.from(entry as Map);
    final members = List<String>.from(updated['members'] as List)
      ..remove(memberName);
    updated['members'] = members;
    patches[inviteCode] = updated;
    await prefs.setString(_kSharedPatches, jsonEncode(patches));
  }

  /// Call after mutating a Space in-place (e.g. adding a task, updating
  /// member list, changing status) so changes are persisted and shared.
  void save() {
    notifyListeners();
    _save();
    for (final s in _spaces) {
      if (s.isCreator) _registerGlobally(s); // keep creator registry current
      _writeSharedPatch(s);                  // broadcast to all members
    }
  }
}