import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────
// SpaceMessage
// ─────────────────────────────────────────────────────────────
class SpaceMessage {
  final String id;
  final String sender;
  final String text;
  final DateTime timestamp;
  final bool isSystemMessage;

  SpaceMessage({
    required this.sender,
    required this.text,
    DateTime? timestamp,
    this.isSystemMessage = false,
    String? id,
  })  : timestamp = timestamp ?? DateTime.now(),
        id = id ?? '${DateTime.now().millisecondsSinceEpoch}_$sender';

  factory SpaceMessage.system(String text) => SpaceMessage(
        sender: 'system',
        text: text,
        isSystemMessage: true,
      );
}