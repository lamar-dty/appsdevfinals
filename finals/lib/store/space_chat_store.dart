import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/space.dart';
import '../models/space_message.dart';
import 'task_store.dart';
import 'auth_store.dart';

String get _kMessagesPrefix => AuthStore.instance.scopedKey('space_chat_msgs_');
String get _kCursorsKey     => AuthStore.instance.scopedKey('space_chat_cursors');

// ─────────────────────────────────────────────────────────────
// SpaceChatStore
// ─────────────────────────────────────────────────────────────
class SpaceChatStore extends ChangeNotifier {
  SpaceChatStore._();
  static final SpaceChatStore instance = SpaceChatStore._();

  final Map<String, List<SpaceMessage>> _messages    = {};
  final Map<String, int>                _readCursors = {};

  // ── Initialisation ────────────────────────────────────────

  Future<void> load(List<String> spaceCodes) async {
    final prefs = await SharedPreferences.getInstance();

    // Load messages for each known space
    for (final code in spaceCodes) {
      final raw = prefs.getString('${_kMessagesPrefix}$code');
      if (raw != null) {
        final list = jsonDecode(raw) as List;
        _messages[code] = list
            .map((e) =>
                SpaceMessage.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    }

    // Load read cursors
    final rawCursors = prefs.getString(_kCursorsKey);
    if (rawCursors != null) {
      final map = jsonDecode(rawCursors) as Map<String, dynamic>;
      map.forEach((k, v) => _readCursors[k] = v as int);
    }

    notifyListeners();
  }

  /// Clear in-memory state and reload for the current user.
  Future<void> reload(List<String> spaceCodes) async {
    _messages.clear();
    _readCursors.clear();
    await load(spaceCodes);
  }

  Future<void> _saveMessages(String spaceCode) async {
    final prefs = await SharedPreferences.getInstance();
    final msgs = _messages[spaceCode] ?? [];
    await prefs.setString(
      '${_kMessagesPrefix}$spaceCode',
      jsonEncode(msgs.map((m) => m.toJson()).toList()),
    );
  }

  Future<void> _saveCursors() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCursorsKey, jsonEncode(_readCursors));
  }

  Future<void> deleteMessagesFor(String spaceCode) async {
    _messages.remove(spaceCode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('${_kMessagesPrefix}$spaceCode');
    // Remove cursors for this space
    _readCursors.removeWhere((k, _) => k.startsWith('$spaceCode|'));
    await _saveCursors();
  }

  // ── Messages ────────────────────────────────────────────────

  List<SpaceMessage> messagesFor(String spaceCode) =>
      _messages.putIfAbsent(spaceCode, () => []);

  void addMessage(
    String spaceCode,
    SpaceMessage message, {
    Space? space,
    String? currentUser,
  }) {
    messagesFor(spaceCode).add(message);

    if (space != null &&
        currentUser != null &&
        !message.isSystemMessage &&
        message.sender != currentUser) {
      TaskStore.instance.notifyNewChatMessage(
        space,
        message.sender,
        message.text,
      );
    }

    notifyListeners();
    _saveMessages(spaceCode);
  }

  void addSystemMessage(String spaceCode, String text) {
    addMessage(spaceCode, SpaceMessage.system(text));
  }

  // ── Unread tracking ─────────────────────────────────────────

  String _cursorKey(String spaceCode, String currentUser) =>
      '$spaceCode|$currentUser';

  void markAsRead(String spaceCode, String currentUser) {
    final msgs     = messagesFor(spaceCode);
    final key      = _cursorKey(spaceCode, currentUser);
    final lastIndex = msgs.length - 1;
    if (lastIndex > (_readCursors[key] ?? -1)) {
      _readCursors[key] = lastIndex;
      notifyListeners();
      _saveCursors();
    }
  }

  int unreadCountFor(String spaceCode, String currentUser) {
    final msgs   = messagesFor(spaceCode);
    final cursor = _readCursors[_cursorKey(spaceCode, currentUser)] ?? -1;
    var count = 0;
    for (var i = cursor + 1; i < msgs.length; i++) {
      final m = msgs[i];
      if (!m.isSystemMessage && m.sender != currentUser) count++;
    }
    return count;
  }
}
