import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher_string.dart';

import 'package:cynk/config/app_config.dart';
import 'package:cynk/utils/platform_infos.dart';

abstract class UpdateNotifier {
  static const String versionStoreKey = 'last_known_version';

  static Future<void> showUpdateSnackBar(BuildContext context) async {
    await showUpdateDialog(context);
  }

  static Future<void> showUpdateDialog(BuildContext context) async {
    if (!context.mounted) return;

    final currentVersion = await PlatformInfos.getVersion();
    final store = await SharedPreferences.getInstance();
    final storedVersion = store.getString(versionStoreKey);

    ReleaseInfo? release;
    try {
      release = await _fetchLatestRelease();
    } catch (_) {}

    final shouldShowReleaseNotes =
        storedVersion != null && storedVersion != currentVersion;
    final shouldShowUpdateAvailable = release != null &&
        _compareVersions(currentVersion, release.version) < 0;

    if (!shouldShowReleaseNotes && !shouldShowUpdateAvailable) {
      await store.setString(versionStoreKey, currentVersion);
      return;
    }

    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final title = shouldShowReleaseNotes
            ? 'Обновление установлено'
            : 'Доступна новая версия';
        final body = release?.body?.trim().isNotEmpty == true
            ? release!.body!
            : 'В этой версии внесены улучшения и исправления.';

        return AlertDialog(
          title: Text(title),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (shouldShowReleaseNotes)
                    Text(
                      'Версия $currentVersion установлена.',
                      style: Theme.of(dialogContext).textTheme.bodyMedium,
                    )
                  else if (release?.version != null)
                    Text(
                      'Доступна версия ${release!.version}.',
                      style: Theme.of(dialogContext).textTheme.bodyMedium,
                    ),
                  const SizedBox(height: 12),
                  MarkdownBody(
                    data: body,
                    selectable: true,
                    styleSheet: MarkdownStyleSheet.fromTheme(
                      Theme.of(dialogContext),
                    ).copyWith(
                      p: Theme.of(dialogContext).textTheme.bodyMedium,
                      h1: Theme.of(dialogContext).textTheme.titleLarge,
                      h2: Theme.of(dialogContext).textTheme.titleMedium,
                      h3: Theme.of(dialogContext).textTheme.titleSmall,
                      listBullet: Theme.of(dialogContext).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Закрыть'),
            ),
            if (release?.htmlUrl != null)
              TextButton.icon(
                onPressed: () => launchUrlString(release!.htmlUrl!),
                icon: const Icon(Icons.open_in_new_outlined),
                label: const Text('GitHub'),
              ),
          ],
        );
      },
    );

    await store.setString(versionStoreKey, currentVersion);
  }

  static Future<ReleaseInfo?> _fetchLatestRelease() async {
    final response = await http.get(
      Uri.parse(AppConfig.gitHubLatestReleaseUrl),
      headers: {
        'Accept': 'application/vnd.github+json',
        'User-Agent': 'cynk-flutter',
      },
    );

    if (response.statusCode != 200) {
      return null;
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final tag = (data['tag_name'] as String?)?.trim();
    final version = tag == null || tag.isEmpty
        ? null
        : tag.startsWith('v')
        ? tag.substring(1)
        : tag;

    return ReleaseInfo(
      version: version,
      body: data['body'] as String?,
      htmlUrl: data['html_url'] as String?,
    );
  }

  static int _compareVersions(String currentVersion, String? latestVersion) {
    if (latestVersion == null || latestVersion.isEmpty) {
      return 0;
    }

    final current = _normalizeVersion(currentVersion);
    final latest = _normalizeVersion(latestVersion);
    if (current == null || latest == null) {
      return 0;
    }

    for (var i = 0; i < 3; i++) {
      final currentPart = current.length > i ? current[i] : 0;
      final latestPart = latest.length > i ? latest[i] : 0;
      if (currentPart < latestPart) return -1;
      if (currentPart > latestPart) return 1;
    }
    return 0;
  }

  static List<int>? _normalizeVersion(String version) {
    var value = version.trim();
    if (value.startsWith('v')) {
      value = value.substring(1);
    }
    value = value.split('+').first;
    final parts = value.split('.');
    if (parts.length > 3) {
      return null;
    }

    final numbers = <int>[];
    for (final part in parts) {
      if (part.isEmpty) return null;
      final parsed = int.tryParse(part);
      if (parsed == null) return null;
      numbers.add(parsed);
    }
    while (numbers.length < 3) {
      numbers.add(0);
    }
    return numbers;
  }
}

class ReleaseInfo {
  final String? version;
  final String? body;
  final String? htmlUrl;

  const ReleaseInfo({this.version, this.body, this.htmlUrl});
}
