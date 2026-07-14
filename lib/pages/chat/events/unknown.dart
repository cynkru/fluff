import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

/// Виджет для отображения неизвестных типов сообщений
class UnknownEventWidget extends StatelessWidget {
  final Event event;

  const UnknownEventWidget({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = event.content['body'] as String? ?? '';
    final msgtype = event.type ?? 'unknown';
    final sender = event.senderId ?? 'Неизвестный пользователь';

    // Проверяем, является ли это системным событием (join/leave)
    if (event.type == EventTypes.Member) {
      return _buildMemberEvent(context);
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '⚠️ Неподдерживаемый тип: $msgtype',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          if (body.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.05),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                body,
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            'От: $sender',
            style: TextStyle(
              fontSize: 10,
              color: theme.colorScheme.onSurface.withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberEvent(BuildContext context) {
    final theme = Theme.of(context);
    final displayName = event.content['displayname'] as String?;
    final membership = event.content['membership'] as String?;
    final prevMembership = event.prevContent?['membership'] as String?;

    String text;
    IconData icon;
    Color color;

    if (membership == 'join') {
      text = '$displayName присоединился к чату';
      icon = Icons.login;
      color = Colors.green;
    } else if (membership == 'leave') {
      text = '$displayName покинул чат';
      icon = Icons.logout;
      color = Colors.red;
    } else {
      text = event.content['body'] as String? ?? 'Системное событие';
      icon = Icons.info_outline;
      color = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: .min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Проверяет, является ли событие известным типом сообщения
bool isKnownMessageType(Event event) {
  if (event.type != EventTypes.Message) {
    return false;
  }
  
  final msgtype = event.content['msgtype'] as String?;
  const knownTypes = [
    'm.text',
    'm.emote',
    'm.notice',
    'm.image',
    'm.video',
    'm.file',
    'm.audio',
    'm.location',
  ];
  return knownTypes.contains(msgtype);
}