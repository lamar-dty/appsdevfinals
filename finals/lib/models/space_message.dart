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

  Map<String, dynamic> toJson() => {
        'id': id,
        'sender': sender,
        'text': text,
        'timestamp': timestamp.millisecondsSinceEpoch,
        'isSystemMessage': isSystemMessage,
      };

  factory SpaceMessage.fromJson(Map<String, dynamic> j) => SpaceMessage(
        id: j['id'] as String,
        sender: j['sender'] as String,
        text: j['text'] as String,
        timestamp:
            DateTime.fromMillisecondsSinceEpoch(j['timestamp'] as int),
        isSystemMessage: j['isSystemMessage'] as bool,
      );
}