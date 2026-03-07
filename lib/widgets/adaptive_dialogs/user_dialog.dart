import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart';

import 'package:cynk/config/themes.dart';
import 'package:cynk/l10n/l10n.dart';
import 'package:cynk/utils/date_time_extension.dart';
import 'package:cynk/widgets/adaptive_dialogs/adaptive_dialog_action.dart';
import 'package:cynk/widgets/avatar.dart';
import 'package:cynk/widgets/presence_builder.dart';
import '../../utils/url_launcher.dart';
import '../future_loading_dialog.dart';
import '../hover_builder.dart';
import '../matrix.dart';
import '../mxc_image_viewer.dart';

// Модель для бейджа
class Badge {
  final String type;
  final String text;
  final String? description;

  Badge({required this.type, required this.text, this.description});

  factory Badge.fromJson(Map<String, dynamic> json) {
    return Badge(
      type: json['type'] as String,
      text: json['text'] as String,
      description: json['description'] as String?,
    );
  }
}

class UserDialog extends StatelessWidget {
  static Future<void> show({
    required BuildContext context,
    required Profile profile,
    bool noProfileWarning = false,
  }) => showAdaptiveDialog(
    context: context,
    barrierDismissible: true,
    builder: (context) =>
        UserDialog(profile, noProfileWarning: noProfileWarning),
  );

  final Profile profile;
  final bool noProfileWarning;

  const UserDialog(this.profile, {this.noProfileWarning = false, super.key});

  // Загрузка бейджей пользователя
  Future<Map<String, dynamic>> _loadUserBadges(BuildContext context) async {
    final client = Matrix.of(context).client;
    try {
      final response = await client.httpClient.get(
        '/_matrix/client/v3/profile/${profile.userId}',
      );
      
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return {
          'badges': data['badges'] ?? [],
          'selected_badge': data['selected_badge'],
        };
      }
    } catch (e) {
      debugPrint('Error loading badges for ${profile.userId}: $e');
    }
    
    return {'badges': [], 'selected_badge': null};
  }

  // Иконка бейджа
  Widget _buildBadgeIcon(String badgeType, {double size = 20}) {
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

  // Виджет для отображения бейджа с текстом
  Widget _buildBadgeChip(Badge badge, {bool isSelected = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected 
            ? Theme.of(Matrix.context).colorScheme.primaryContainer
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: isSelected
            ? Border.all(
                color: Theme.of(Matrix.context).colorScheme.primary,
                width: 1,
              )
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildBadgeIcon(badge.type, size: 16),
          const SizedBox(width: 4),
          Text(
            badge.text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final client = Matrix.of(context).client;
    final dmRoomId = client.getDirectChatFromUserId(profile.userId);
    final displayname =
        profile.displayName ??
        profile.userId.localpart ??
        L10n.of(context).user;
    var copied = false;
    final theme = Theme.of(context);
    final avatar = profile.avatarUrl;
    
    return FutureBuilder<Map<String, dynamic>>(
      future: _loadUserBadges(context),
      builder: (context, snapshot) {
        final badgesData = snapshot.data?['badges'] as List? ?? [];
        final selectedBadge = snapshot.data?['selected_badge'] as String?;
        
        // Преобразуем в список объектов Badge
        final badges = badgesData.map((b) => Badge.fromJson(b)).toList();

        return AlertDialog.adaptive(
          title: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 256),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      displayname,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (selectedBadge != null) ...[
                    const SizedBox(width: 8),
                    _buildBadgeIcon(selectedBadge, size: 20),
                  ] else if (badges.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      width: 20,
                      height: 20,
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
                    ),
                  ],
                ],
              ),
            ),
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 256, maxHeight: 400),
            child: PresenceBuilder(
              userId: profile.userId,
              client: Matrix.of(context).client,
              builder: (context, presence) {
                if (presence == null) return const SizedBox.shrink();
                final statusMsg = presence.statusMsg;
                final lastActiveTimestamp = presence.lastActiveTimestamp;
                final presenceText = presence.currentlyActive == true
                    ? L10n.of(context).currentlyActive
                    : lastActiveTimestamp != null
                    ? L10n.of(context).lastActiveAgo(
                        lastActiveTimestamp.localizedTimeShort(context),
                      )
                    : null;
                return SingleChildScrollView(
                  child: Column(
                    spacing: 8,
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Avatar(
                          mxContent: avatar,
                          name: displayname,
                          size: Avatar.defaultSize * 2,
                          onTap: avatar != null
                              ? () => showDialog(
                                  context: context,
                                  builder: (_) => MxcImageViewer(avatar),
                                )
                              : null,
                        ),
                      ),
                      
                      // Список всех бейджей
                      if (badges.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          alignment: WrapAlignment.center,
                          children: badges.map((badge) {
                            return _buildBadgeChip(
                              badge,
                              isSelected: badge.type == selectedBadge,
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 8),
                      ],
                      
                      HoverBuilder(
                        builder: (context, hovered) => StatefulBuilder(
                          builder: (context, setState) => MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              onTap: () {
                                Clipboard.setData(
                                  ClipboardData(text: profile.userId),
                                );
                                setState(() {
                                  copied = true;
                                });
                              },
                              child: RichText(
                                text: TextSpan(
                                  children: [
                                    WidgetSpan(
                                      child: Padding(
                                        padding: const EdgeInsets.only(right: 4.0),
                                        child: AnimatedScale(
                                          duration: FluffyThemes.animationDuration,
                                          curve: FluffyThemes.animationCurve,
                                          scale: hovered
                                              ? 1.33
                                              : copied
                                              ? 1.25
                                              : 1.0,
                                          child: Icon(
                                            copied
                                                ? Icons.check_circle
                                                : Icons.copy,
                                            size: 12,
                                            color: copied ? Colors.green : null,
                                          ),
                                        ),
                                      ),
                                    ),
                                    TextSpan(text: profile.userId),
                                  ],
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontSize: 10,
                                  ),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (presenceText != null)
                        Text(
                          presenceText,
                          style: const TextStyle(fontSize: 10),
                          textAlign: TextAlign.center,
                        ),
                      if (statusMsg != null)
                        SelectableLinkify(
                          text: statusMsg,
                          textScaleFactor: MediaQuery.textScalerOf(
                            context,
                          ).scale(1),
                          textAlign: TextAlign.center,
                          options: const LinkifyOptions(humanize: false),
                          linkStyle: TextStyle(
                            color: theme.colorScheme.primary,
                            decoration: TextDecoration.underline,
                            decorationColor: theme.colorScheme.primary,
                          ),
                          onOpen: (url) =>
                              UrlLauncher(context, url.url).launchUrl(),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          actions: [
            if (client.userID != profile.userId) ...[
              AdaptiveDialogAction(
                borderRadius: AdaptiveDialogAction.topRadius,
                bigButtons: true,
                onPressed: () async {
                  final router = GoRouter.of(context);
                  final roomIdResult = await showFutureLoadingDialog(
                    context: context,
                    future: () => client.startDirectChat(profile.userId),
                  );
                  final roomId = roomIdResult.result;
                  if (roomId == null) return;
                  if (context.mounted) Navigator.of(context).pop();
                  router.go('/rooms/$roomId');
                },
                child: Text(
                  dmRoomId == null
                      ? L10n.of(context).startConversation
                      : L10n.of(context).sendAMessage,
                ),
              ),
              AdaptiveDialogAction(
                bigButtons: true,
                borderRadius: AdaptiveDialogAction.centerRadius,
                onPressed: () {
                  final router = GoRouter.of(context);
                  Navigator.of(context).pop();
                  router.go(
                    '/rooms/settings/security/ignorelist',
                    extra: profile.userId,
                  );
                },
                child: Text(
                  L10n.of(context).ignoreUser,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            ],
            AdaptiveDialogAction(
              bigButtons: true,
              borderRadius: AdaptiveDialogAction.bottomRadius,
              onPressed: Navigator.of(context).pop,
              child: Text(L10n.of(context).close),
            ),
          ],
        );
      },
    );
  }
}