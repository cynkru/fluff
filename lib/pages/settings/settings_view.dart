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
                final displayname =
                    profile?.displayName ?? mxid.localpart ?? mxid;
                
                // Загружаем бейджи пользователя
                return FutureBuilder<Map<String, dynamic>>(
                  future: _loadUserBadges(context),
                  builder: (context, badgesSnapshot) {
                    final badges = badgesSnapshot.data?['badges'] as List<dynamic>? 
                        ?? [];
                    final selectedBadge = badgesSnapshot.data?['selected_badge'] as String?;
                    
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
                                            builder: (_) => MxcImageViewer(avatar),
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
                                        child: const Icon(Icons.camera_alt_outlined),
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
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextButton.icon(
                                          onPressed: controller.setDisplaynameAction,
                                          icon: const Icon(Icons.edit_outlined, size: 16),
                                          style: TextButton.styleFrom(
                                            foregroundColor: theme.colorScheme.onSurface,
                                            iconColor: theme.colorScheme.onSurface,
                                          ),
                                          label: Text(
                                            displayname,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontSize: 18),
                                          ),
                                        ),
                                      ),
                                      // Отображаем выбранный бейдж рядом с именем
                                      if (selectedBadge != null)
                                        _buildBadgeIcon(selectedBadge, size: 24)
                                      else if (badges.isNotEmpty)
                                        // Если есть бейджи, но не выбран - показываем пустой (заблокированный)
                                        _buildEmptyBadgeIcon(size: 24),
                                    ],
                                  ),
                                  TextButton.icon(
                                    onPressed: () => FluffyShare.share(mxid, context),
                                    icon: const Icon(Icons.copy_outlined, size: 14),
                                    style: TextButton.styleFrom(
                                      foregroundColor: theme.colorScheme.secondary,
                                      iconColor: theme.colorScheme.secondary,
                                    ),
                                    label: Text(
                                      mxid.localpart.toString(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        
                        // Отображаем список бейджей
                        if (badges.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Divider(),
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: Text(
                                    'Бейджи',
                                    style: theme.textTheme.titleMedium,
                                  ),
                                ),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    // Пустой бейдж (сброс выбора)
                                    if (badges.isNotEmpty)
                                      _buildBadgeSelectorItem(
                                        context: context,
                                        badgeType: null,
                                        badgeText: 'Не выбран',
                                        isSelected: selectedBadge == null,
                                        onTap: () => _setSelectedBadge(context, null),
                                      ),
                                    // Все доступные бейджи
                                    ...badges.map((badge) {
                                      final badgeData = Badge.fromJson(badge);
                                      return _buildBadgeSelectorItem(
                                        context: context,
                                        badgeType: badgeData.type,
                                        badgeText: badgeData.text,
                                        isSelected: selectedBadge == badgeData.type,
                                        onTap: () => _setSelectedBadge(context, badgeData.type),
                                      );
                                    }),
                                  ],
                                ),
                              ],
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
              tileColor: activeRoute.startsWith('/rooms/settings/notifications')
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
            /*ListTile(
              leading: const Icon(Icons.dns_outlined),
              title: Text(
                L10n.of(context).aboutHomeserver(
                  Matrix.of(context).client.userID?.domain ?? 'homeserver',
                ),
              ),
              onTap: () => context.go('/rooms/settings/homeserver'),
              tileColor: activeRoute.startsWith('/rooms/settings/homeserver')
                  ? theme.colorScheme.surfaceContainerHigh
                  : null,
            ),*/
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
      // Получаем профиль с бейджами через новый API
      final response = await client.httpClient.get(
        Uri.parse('/_matrix/client/v3/profile/$userId'),
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

  // Установка выбранного бейджа
  Future<void> _setSelectedBadge(BuildContext context, String? badgeType) async {
    final client = Matrix.of(context).client;
    final userId = client.userID!;
    
    try {
      await client.httpClient.post(
        Uri.parse('/_matrix/client/v3/profile/$userId/selected_badge'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'selected_badge': badgeType}),
      );
      
      // Обновляем UI
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(badgeType == null 
                ? 'Бейдж сброшен' 
                : 'Выбран бейдж'),
            duration: const Duration(seconds: 2),
          ),
        );
        // Перезагружаем страницу
        (context as Element).markNeedsBuild();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Виджет для выбора бейджа
  Widget _buildBadgeSelectorItem({
    required BuildContext context,
    required String? badgeType,
    required String badgeText,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected 
                ? Theme.of(context).colorScheme.primary 
                : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: isSelected 
              ? Theme.of(context).colorScheme.primaryContainer 
              : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (badgeType == null)
              _buildEmptyBadgeIcon(size: 20)
            else
              _buildBadgeIcon(badgeType, size: 20),
            const SizedBox(width: 4),
            Text(badgeText),
          ],
        ),
      ),
    );
  }

  // Иконка бейджа
  Widget _buildBadgeIcon(String badgeType, {double size = 20}) {
    return Image.asset(
      'assets/badges/$badgeType.png',
      width: size,
      height: size,
      errorBuilder: (context, error, stackTrace) {
        // Если картинка не найдена - показываем заглушку
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
  Widget _buildEmptyBadgeIcon({double size = 20}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.grey.shade400, width: 1.5),
      ),
      child: Transform.rotate(
        angle: 0.2, // небольшой угол для крестика
        child: const Icon(
          Icons.close,
          size: 12,
          color: Colors.grey,
        ),
      ),
    );
  }
}