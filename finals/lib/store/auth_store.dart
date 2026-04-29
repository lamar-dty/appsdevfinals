import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'storage_keys.dart';

// ─────────────────────────────────────────────────────────────
// User model
// ─────────────────────────────────────────────────────────────
class UserRecord {
  final String id;           // stable UUID assigned at signup
  final String name;
  final String email;
  final String passwordHash;

  UserRecord({
    required this.id,
    required this.name,
    required this.email,
    required this.passwordHash,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'passwordHash': passwordHash,
      };

  factory UserRecord.fromJson(Map<String, dynamic> json) => UserRecord(
        // Old records without a stable id get one derived from their email so
        // they don't lose their stored data when upgrading.
        id: (json['id'] as String?) ??
            _hashPassword(json['email'] as String).substring(0, 12),
        name: json['name'] as String,
        email: json['email'] as String,
        passwordHash: json['passwordHash'] as String,
      );
}

// ── Lightweight deterministic hash (avoids storing plaintext) ─
String _hashPassword(String pass) {
  var h = 5381;
  for (final c in pass.codeUnits) {
    h = ((h << 5) + h + c) & 0xFFFFFFFF;
  }
  return h.toRadixString(16);
}

// ── UUID v4 generator (no external package) ───────────────────
String _generateUuid() {
  final rng = Random.secure();
  final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant
  String hex(int b) => b.toRadixString(16).padLeft(2, '0');
  return '${bytes.sublist(0, 4).map(hex).join()}'
      '-${bytes.sublist(4, 6).map(hex).join()}'
      '-${bytes.sublist(6, 8).map(hex).join()}'
      '-${bytes.sublist(8, 10).map(hex).join()}'
      '-${bytes.sublist(10, 16).map(hex).join()}';
}

// ─────────────────────────────────────────────────────────────
// AuthStore
// ─────────────────────────────────────────────────────────────
class AuthStore extends ChangeNotifier {
  AuthStore._();
  static final AuthStore instance = AuthStore._();

  final List<UserRecord> _users = [];
  UserRecord? _currentUser;

  bool get isLoggedIn     => _currentUser != null;
  String get userId       => _currentUser?.id    ?? '';
  String get displayName  => _currentUser?.name  ?? 'User';
  String get displayEmail => _currentUser?.email ?? '';

  /// Stripped UUID (no dashes), 32 hex chars — used as storage namespace.
  String get _storagePrefix =>
      _currentUser?.id.replaceAll('-', '') ?? '';

  /// Short tag shown in the drawer — first 8 chars of the stripped UUID.
  String get userTag => _currentUser != null
      ? '#${_storagePrefix.substring(0, 8)}'
      : '#--------';

  /// All registered accounts: displayName → userId.
  /// Used by TaskStore to address cross-user notifications.
  Map<String, String> get allUserIds =>
      {for (final u in _users) u.name: u.id};

  /// Look up a userId by display name. Returns null if not found.
  String? userIdForName(String name) {
    try {
      return _users.firstWhere((u) => u.name == name).id;
    } catch (_) {
      return null;
    }
  }

  /// Look up a display name by userId or the short 8-char userTag prefix.
  /// Returns null if not found.
  String? nameForId(String id) {
    final cleaned = id.startsWith('#') ? id.substring(1) : id;
    try {
      return _users
          .firstWhere((u) =>
              u.id == cleaned ||
              u.id.replaceAll('-', '').substring(0, 8) == cleaned)
          .name;
    } catch (_) {
      return null;
    }
  }

  // ── Initialisation ────────────────────────────────────────

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    // Restore registered accounts.  A schema mismatch must never prevent
    // the app from launching — wipe corrupted data cleanly.
    try {
      final rawUsers = prefs.getString(kAuthUsers);
      if (rawUsers != null) {
        final list = jsonDecode(rawUsers) as List;
        _users.addAll(
          list.map((e) =>
              UserRecord.fromJson(Map<String, dynamic>.from(e as Map))),
        );
      }
    } catch (_) {
      _users.clear();
      await prefs.remove(kAuthUsers);
      await prefs.remove(kAuthSessionUser);
      notifyListeners();
      return;
    }

    // Restore session.
    final sessionEmail = prefs.getString(kAuthSessionUser);
    if (sessionEmail != null) {
      _currentUser =
          _users.where((u) => u.email == sessionEmail).firstOrNull;
    }

    notifyListeners();
  }

  Future<void> _saveUsers() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        kAuthUsers, jsonEncode(_users.map((u) => u.toJson()).toList()));
  }

  Future<void> _saveSession() async {
    final prefs = await SharedPreferences.getInstance();
    if (_currentUser != null) {
      await prefs.setString(kAuthSessionUser, _currentUser!.email);
    } else {
      await prefs.remove(kAuthSessionUser);
    }
  }

  // ── Sign up ───────────────────────────────────────────────

  /// Returns null on success, or an error message string.
  Future<String?> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    final trimmedEmail = email.trim().toLowerCase();
    if (_users.any((u) => u.email == trimmedEmail)) {
      return 'An account with that email already exists.';
    }
    final record = UserRecord(
      id: _generateUuid(),
      name: name.trim(),
      email: trimmedEmail,
      passwordHash: _hashPassword(password),
    );
    _users.add(record);
    await _saveUsers();
    _currentUser = record;
    await _saveSession();
    await _reloadStores();
    notifyListeners();
    return null;
  }

  // ── Log in ────────────────────────────────────────────────

  /// Returns null on success, or an error message string.
  Future<String?> login({
    required String email,
    required String password,
  }) async {
    final trimmedEmail = email.trim().toLowerCase();
    final user =
        _users.where((u) => u.email == trimmedEmail).firstOrNull;

    if (user == null || user.passwordHash != _hashPassword(password)) {
      return 'Invalid email or password.';
    }
    _currentUser = user;
    await _saveSession();
    await _reloadStores();
    notifyListeners();
    return null;
  }

  // ── Log out ───────────────────────────────────────────────

  Future<void> logout() async {
    _currentUser = null;
    await _saveSession();
    await _clearStores();
    notifyListeners();
  }

  // ── Store lifecycle helpers ───────────────────────────────

  Future<void> _reloadStores() async {
    if (_onLogin != null) await _onLogin!();
  }

  Future<void> _clearStores() async {
    if (_onLogout != null) await _onLogout!();
  }

  Future<void> Function()? _onLogin;
  Future<void> Function()? _onLogout;

  /// Register lifecycle callbacks from main.dart to avoid circular imports.
  void registerStoreCallbacks({
    required Future<void> Function() onLogin,
    required Future<void> Function() onLogout,
  }) {
    _onLogin  = onLogin;
    _onLogout = onLogout;
  }

  // ── Storage key helpers ───────────────────────────────────
  // These delegate to the StorageKeys file so AuthStore remains
  // the single point-of-entry for callers who don't import StorageKeys.

  String keyTasks()         => kTaskTasks(_storagePrefix);
  String keyEvents()        => kTaskEvents(_storagePrefix);
  String keyNotifications() => kTaskNotifications(_storagePrefix);
  String keySpaceList()     => kSpaceList(_storagePrefix);
  String keyChatCursors()   => kSpaceChatCursors(_storagePrefix);

  /// Generic user-scoped key for one-off preferences.
  /// Prefer the typed helpers above for structured stores.
  String scopedKey(String base) {
    if (_currentUser == null) return 'guest_$base';
    return '${_storagePrefix}_$base';
  }
}