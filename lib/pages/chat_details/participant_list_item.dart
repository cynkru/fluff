import 'package:flutter/material.dart';

import 'package:matrix/matrix.dart';

import 'package:cynk/config/app_config.dart';
import 'package:cynk/l10n/l10n.dart';
import 'package:cynk/widgets/member_actions_popup_menu_button.dart';
import '../../widgets/avatar.dart';
import 'package:cynk/widgets/matrix.dart';
import 'dart:convert';

class ParticipantListItem extends StatelessWidget {
  final User user;

  const ParticipantListItem(this.user, {super.key});

  // Загрузка бейджей пользователя
  Future<Map<String, dynamic>> _loadUserBadges(BuildContext context) async {
    final client = Matrix.of(context).client;
    try {
      final response = await client.httpClient.get(
        '/_matrix/client/v3/profile/${user.id}',
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>
        return {
          'badges': data['badges'] ?? [],
          'selected_badge': data['selected_badge'],
        };
      }
    } catch (e) {
      debugPrint('Error loading badges for ${user.id}: $e');
    }
    
    return {'badges': [], 'selected_badge': null};
  }

  // Иконка бейджа
  Widget _buildBadgeIcon(String badgeType, {double size = 16}) {
    return Image.asset(
      'assets/badges/$badgeType.png',
      width: size,
      height: size,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(
            Icons.star,
            size: size * 0.7,
            color: Colors.grey.shade600,
          ),
        );
      },
    );
  }

  // Пустой бейдж (перечеркнутый круг)
  Widget _buildEmptyBadgeIcon({double size = 16}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.grey.shade400, width: 1.5),
      ),
      child: Transform.rotate(
        angle: 0.2,
        child: const Icon(
          Icons.close,
          size: 12,
          color: Colors.grey,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final membershipBatch = switch (user.membership) {
      Membership.ban => L10n.of(context).banned,
      Membership.invite => L10n.of(context).invited,
      Membership.join => null,
      Membership.knock => L10n.of(context).knocking,
      Membership.leave => L10n.of(context).leftTheChat,
    };

    final permissionBatch = user.powerLevel >= 100
        ? L10n.of(context).admin
        : user.powerLevel >= 50
        ? L10n.of(context).moderator
        : '';

    return FutureBuilder<Map<String, dynamic>>(
      future: _loadUserBadges(context),
      builder: (context, snapshot) {
        final selectedBadge = snapshot.data?['selected_badge'] as String?;
        final badges = snapshot.data?['badges'] as List? ?? [];

        return ListTile(
          onTap: () => showMemberActionsPopupMenu(context: context, user: user),
          title: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  user.calcDisplayname(),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Бейдж рядом с именем
              if (selectedBadge != null)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: _buildBadgeIcon(selectedBadge, size: 16),
                )
              else if (badges.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: _buildEmptyBadgeIcon(size: 16),
                ),
              if (permissionBatch.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: user.powerLevel >= 100
                        ? theme.colorScheme.tertiary
                        : theme.colorScheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(AppConfig.borderRadius),
                  ),
                  child: Text(
                    permissionBatch,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: user.powerLevel >= 100
                          ? theme.colorScheme.onTertiary
                          : theme.colorScheme.onTertiaryContainer,
                    ),
                  ),
                ),
              if (membershipBatch != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 4,
                    horizontal: 8,
                  ),
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      membershipBatch,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          subtitle: Text(user.id, maxLines: 1, overflow: TextOverflow.ellipsis),
          leading: Opacity(
            opacity: user.membership == Membership.join ? 1 : 0.5,
            child: Avatar(
              mxContent: user.avatarUrl,
              name: user.calcDisplayname(),
              presenceUserId: user.stateKey,
            ),
          ),
        );
      },
    );
  }
}