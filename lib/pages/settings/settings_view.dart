import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:cynk/config/app_config.dart';
import 'package:cynk/l10n/l10n.dart';
import 'package:cynk/utils/fluffy_share.dart';
import 'package:cynk/utils/platform_infos.dart';
import 'package:cynk/widgets/avatar.dart';
import 'package:cynk/widgets/matrix.dart';
import '../../widgets/mxc_image_viewer.dart';
import 'settings.dart';
import 'dart:convert';

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

class SettingsView extends StatelessWidget {
  final SettingsController controller;

  const SettingsView(this.controller, {super.key});

  String _formatUsername(String userId) {
    final localpart = userId.localpart;
    if (localpart != null && localpart.isNotEmpty) {
      return '@$localpart';
    }
    return userId;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeRoute = GoRouter.of(
      context,
    ).routeInformationProvider.value.uri.path;

    return Scaffold(
      appBar: AppBar(
        title: Text(L10n.of(context).settings),
        leading: Center(
          child: BackButton(onPressed: () => context.go('/rooms')),
        ),
      ),
      body: ListTileTheme(
        iconColor: theme.colorScheme.onSurface,
        child: ListView(
          key: const Key('SettingsListViewContent'),
          children: <Widget>[
            FutureBuilder<Profile>(
              future: controller.profileFuture,
              builder: (context, snapshot) {
                final profile = snapshot.data;
                final avatar = profile?.avatarUrl;
                final mxid =
                    Matrix.of(context).client.userID ?? L10n.of(context).user;
                final displayname = profile?.displayName ?? _formatUsername(mxid);

                // Загружаем бейджи пользователя
                return FutureBuilder<Map<String, dynamic>>(
                  future: _loadUserBadges(context),
                  builder: (context, badgesSnapshot) {
                    final badges = badgesSnapshot.data?['badges'] as List<
                        dynamic>? ?? [];

                    return Column(
                      children: [
                        Row(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: Stack(
                                children: [
                                  Avatar(
                                    mxContent: avatar,
                                    name: displayname,
                                    size: Avatar.defaultSize * 2.5,
                                    onTap: avatar != null
                                        ? () => showDialog(
                                          context: context,
                                          builder: (_) => MxcImageViewer(
                                            avatar,
                                          ),
                                        )
                                        : null,
                                  ),
                                  if (profile != null)
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: FloatingActionButton.small(
                                        elevation: 2,
                                        onPressed: controller.setAvatarAction,
                                        heroTag: null,
                                        child: const Icon(
                                          Icons.camera_alt_outlined,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  TextButton.icon(
                                    onPressed: controller.setDisplaynameAction,
                                    icon: const Icon(
                                      Icons.edit_outlined,
                                      size: 16,
                                    ),
                                    style: TextButton.styleFrom(
                                      foregroundColor: theme
                                          .colorScheme.onSurface,
                                      iconColor: theme.colorScheme.onSurface,
                                    ),
                                    label: Text(
                                      displayname,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 18),
                                    ),
                                  ),
                                  TextButton.icon(
                                    onPressed: () => FluffyShare.share(
                                      mxid,
                                      context,
                                    ),
                                    icon: const Icon(
                                      Icons.copy_outlined,
                                      size: 14,
                                    ),
                                    style: TextButton.styleFrom(
                                      foregroundColor: theme
                                          .colorScheme.secondary,
                                      iconColor: theme.colorScheme.secondary,
                                    ),
                                    label: Text(
                                      _formatUsername(mxid),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        // Отображаем бейджи как иконки под профилем
                        if (badges.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              children: badges.map((badge) {
                                final badgeData = Badge.fromJson(badge);
                                return _buildBadgeIconItem(
                                  context: context,
                                  badge: badgeData,
                                );
                              }).toList(),
                            ),
                          ),
                      ],
                    );
                  },
                );
              },
            ),
            FutureBuilder(
              future: Matrix.of(context).client.getAuthMetadata(),
              builder: (context, snapshot) {
                final accountManageUrl = snapshot.data?.issuer;
                if (accountManageUrl == null) {
                  return const SizedBox.shrink();
                }
                return ListTile(
                  leading: const Icon(Icons.account_circle_outlined),
                  title: Text(L10n.of(context).manageAccount),
                  trailing: const Icon(Icons.open_in_new_outlined),
                  onTap: () => launchUrl(
                    accountManageUrl,
                    mode: LaunchMode.inAppBrowserView,
                  ),
                );
              },
            ),
            Divider(color: theme.dividerColor),
            SwitchListTile.adaptive(
              controlAffinity: ListTileControlAffinity.trailing,
              value: controller.cryptoIdentityConnected == true,
              secondary: const Icon(Icons.backup_outlined),
              title: Text(L10n.of(context).chatBackup),
              onChanged: controller.firstRunBootstrapAction,
            ),
            Divider(color: theme.dividerColor),
            ListTile(
              leading: const Icon(Icons.format_paint_outlined),
              title: Text(L10n.of(context).changeTheme),
              tileColor: activeRoute.startsWith('/rooms/settings/style')
                  ? theme.colorScheme.surfaceContainerHigh
                  : null,
              onTap: () => context.go('/rooms/settings/style'),
            ),
            ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: Text(L10n.of(context).notifications),
              tileColor: activeRoute.startsWith(
                '/rooms/settings/notifications',
              )
                  ? theme.colorScheme.surfaceContainerHigh
                  : null,
              onTap: () => context.go('/rooms/settings/notifications'),
            ),
            ListTile(
              leading: const Icon(Icons.devices_outlined),
              title: Text(L10n.of(context).devices),
              onTap: () => context.go('/rooms/settings/devices'),
              tileColor: activeRoute.startsWith('/rooms/settings/devices')
                  ? theme.colorScheme.surfaceContainerHigh
                  : null,
            ),
            ListTile(
              leading: const Icon(Icons.forum_outlined),
              title: Text(L10n.of(context).chat),
              onTap: () => context.go('/rooms/settings/chat'),
              tileColor: activeRoute.startsWith('/rooms/settings/chat')
                  ? theme.colorScheme.surfaceContainerHigh
                  : null,
            ),
            ListTile(
              leading: const Icon(Icons.shield_outlined),
              title: Text(L10n.of(context).security),
              onTap: () => context.go('/rooms/settings/security'),
              tileColor: activeRoute.startsWith('/rooms/settings/security')
                  ? theme.colorScheme.surfaceContainerHigh
                  : null,
            ),
            Divider(color: theme.dividerColor),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: Text(L10n.of(context).privacy),
              onTap: () => launchUrl(AppConfig.privacyUrl),
            ),
            ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: Text(L10n.of(context).about),
              onTap: () => PlatformInfos.showDialog(context),
            ),
            ListTile(
              leading: const Icon(Icons.history_outlined),
              title: const Text('Changelog'),
              onTap: () => context.go('/rooms/settings/changelog'),
            ),
            Divider(color: theme.dividerColor),
            ListTile(
              leading: const Icon(Icons.logout_outlined),
              title: Text(L10n.of(context).logout),
              onTap: controller.logoutAction,
            ),
          ],
        ),
      ),
    );
  }

  // Загрузка бейджей пользователя
  Future<Map<String, dynamic>> _loadUserBadges(BuildContext context) async {
    final client = Matrix.of(context).client;
    final userId = client.userID!;

    try {
      final response = await client.httpClient.get(
        Uri.parse('https://matrix.cynk.ru/_matrix/client/v3/profile/$userId'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'badges': data['badges'] ?? [],
          'selected_badge': data['selected_badge'],
        };
      }
    } catch (e) {
      debugPrint('Error loading badges: $e');
    }

    return {'badges': [], 'selected_badge': null};
  }

  // Бейдж как иконка
  Widget _buildBadgeIconItem({
    required BuildContext context,
    required Badge badge,
  }) {
    final message = (badge.description ?? '').trim().isNotEmpty
        ? badge.description!.trim()
        : badge.text.trim();

    return Tooltip(
      message: badge.text,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (message.isNotEmpty) {
            ScaffoldMessenger.maybeOf(context)?.showSnackBar(
              SnackBar(
                content: Text(message),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        child: Image.asset(
          'assets/badges/${badge.type}.png',
          width: 28,
          height: 28,
          errorBuilder: (context, error, stackTrace) {
            // Если иконки нет — показываем заглушку
            return Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(
                Icons.star,
                size: 18,
                color: Colors.grey.shade600,
              ),
            );
          },
        ),
      ),
    );
  }
}