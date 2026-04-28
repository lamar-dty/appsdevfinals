import 'package:flutter/material.dart';
import '../models/space.dart';
import '../models/space_message.dart';
import 'task_store.dart'; // ← Step 3: fire chat notification into TaskStore

// ─────────────────────────────────────────────────────────────
// SpaceChatStore
// Holds messages keyed by space inviteCode (unique per space).
// Tracks per-(space, user) read cursors for unread-dot logic.
// ─────────────────────────────────────────────────────────────
class SpaceChatStore extends ChangeNotifier {
  SpaceChatStore._();
  static final SpaceChatStore instance = SpaceChatStore._();

  final Map<String, List<SpaceMessage>> _messages = {};

  // Key: "$spaceCode|$currentUser"  →  index up-to-and-including which message
  // has been seen by that user. -1 means nothing has been read yet.
  final Map<String, int> _readCursors = {};

  // ── Messages ────────────────────────────────────────────────

  List<SpaceMessage> messagesFor(String spaceCode) =>
      _messages.putIfAbsent(spaceCode, () => []);

  /// Adds a message to the store.
  ///
  /// When [space] and [currentUser] are provided the store will automatically
  /// fire a [TaskStore] chat notification for messages sent by OTHER users
  /// (non-system, not the current user). This keeps the notification centre
  /// in sync without requiring call-sites to remember to do it manually.
  void addMessage(
    String spaceCode,
    SpaceMessage message, {
    Space? space,
    String? currentUser,
  }) {
    messagesFor(spaceCode).add(message);

    // Fire a chat notification when:
    //   • A Space context was supplied (so we have name, accent colour, etc.)
    //   • The message is not a system message
    //   • The sender is not the current user
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
  }

  /// Convenience wrapper for system messages (no notification generated).
  void addSystemMessage(String spaceCode, String text) {
    addMessage(spaceCode, SpaceMessage.system(text));
  }

  // ── Unread tracking ─────────────────────────────────────────

  String _cursorKey(String spaceCode, String currentUser) =>
      '$spaceCode|$currentUser';

  /// Call this when the chat sheet is opened (or a message is sent by the
  /// current user).  Advances the read cursor to the last message index so
  /// nothing is counted as unread any more.
  void markAsRead(String spaceCode, String currentUser) {
    final msgs = messagesFor(spaceCode);
    final key = _cursorKey(spaceCode, currentUser);
    final lastIndex = msgs.length - 1;
    // Only advance; never move the cursor backwards.
    if (lastIndex > (_readCursors[key] ?? -1)) {
      _readCursors[key] = lastIndex;
      notifyListeners();
    }
  }

  /// Returns the number of messages sent by OTHER users (non-system) that
  /// arrived after the current user's read cursor.
  int unreadCountFor(String spaceCode, String currentUser) {
    final msgs = messagesFor(spaceCode);
    final cursor = _readCursors[_cursorKey(spaceCode, currentUser)] ?? -1;
    var count = 0;
    for (var i = cursor + 1; i < msgs.length; i++) {
      final m = msgs[i];
      if (!m.isSystemMessage && m.sender != currentUser) count++;
    }
    return count;
  }
}