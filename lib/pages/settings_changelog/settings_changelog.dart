import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher_string.dart';

import 'package:cynk/utils/platform_infos.dart';
import 'package:cynk/widgets/layouts/max_width_body.dart';

class SettingsChangelog extends StatefulWidget {
  const SettingsChangelog({super.key});

  @override
  State<SettingsChangelog> createState() => SettingsChangelogController();
}

class SettingsChangelogController extends State<SettingsChangelog> {
  late final Future<ReleaseInfo> _releaseFuture;

  @override
  void initState() {
    super.initState();
    _releaseFuture = _loadReleaseInfo();
  }

  Future<ReleaseInfo> _loadReleaseInfo() async {
    final tag = await PlatformInfos.getVersionTag();
    final uri = Uri.parse(
      'https://api.github.com/repos/cynkru/fluff/releases/tags/$tag',
    );

    final response = await http.get(
      uri,
      headers: {
        'Accept': 'application/vnd.github+json',
        'User-Agent': 'cynk-flutter',
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Не удалось получить changelog для тега $tag (${response.statusCode})',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    return ReleaseInfo(
      tag: (data['tag_name'] as String?) ?? tag,
      name: (data['name'] as String?)?.trim().isNotEmpty == true
          ? data['name'] as String
          : 'Release $tag',
      body: (data['body'] as String?)?.trim().isNotEmpty == true
          ? data['body'] as String
          : 'Описание релиза отсутствует.',
      htmlUrl: (data['html_url'] as String?) ??
          'https://github.com/cynkru/fluff/releases/tag/$tag',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Changelog')),
      body: MaxWidthBody(
        child: FutureBuilder<ReleaseInfo>(
          future: _releaseFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Не удалось загрузить changelog',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    SelectableText(snapshot.error.toString()),
                  ],
                ),
              );
            }

            final release = snapshot.data!;
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  release.name,
                                  style: theme.textTheme.titleLarge,
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () => launchUrlString(
                                  release.htmlUrl,
                                  mode: LaunchMode.externalApplication,
                                ),
                                icon: const Icon(Icons.open_in_new_outlined),
                                label: const Text('GitHub'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  MarkdownBody(
                    data: release.body.replaceAll('\r\n', '\n').trim(),
                    selectable: true,
                    styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                      p: theme.textTheme.bodyMedium,
                      h1: theme.textTheme.titleLarge,
                      h2: theme.textTheme.titleMedium,
                      h3: theme.textTheme.titleSmall,
                      listBullet: theme.textTheme.bodyMedium,
                      checkbox: theme.textTheme.bodyMedium,
                      code: theme.textTheme.bodyMedium?.copyWith(
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class ReleaseInfo {
  final String tag;
  final String name;
  final String body;
  final String htmlUrl;

  const ReleaseInfo({
    required this.tag,
    required this.name,
    required this.body,
    required this.htmlUrl,
  });
}
