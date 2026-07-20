import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';

import 'package:cynk/config/app_config.dart';
import 'package:cynk/l10n/l10n.dart';
import 'package:cynk/pages/intro/flows/restore_backup_flow.dart';
import 'package:cynk/utils/platform_infos.dart';
import 'package:cynk/widgets/layouts/login_scaffold.dart';
import 'package:cynk/widgets/matrix.dart';
import 'package:cynk/config/setting_keys.dart'; // Правильный путь

class IntroPage extends StatelessWidget {
  const IntroPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final addMultiAccount = Matrix.of(
      context,
    ).widget.clients.any((client) => client.isLogged());

    final useTestBackend = AppSettings.useTestBackend.value;

    return LoginScaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          addMultiAccount
              ? L10n.of(context).addAccount
              : "Cynk"
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Test',
                  style: TextStyle(
                    fontSize: 12,
                    color: useTestBackend 
                        ? theme.colorScheme.primary 
                        : theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
                Switch(
                  value: useTestBackend,
                  onChanged: (value) async {
                    await AppSettings.useTestBackend.setItem(value);
                    if (context.mounted) {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const IntroPage()),
                      );
                    }
                  },
                  activeColor: theme.colorScheme.primary,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                     Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Hero(
                        tag: 'info-logo',
                        child: Image.asset(
                          './assets/banner_transparent.png',
                          fit: BoxFit.fitWidth,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32.0),
                      child: SelectableLinkify(
                        text: useTestBackend 
                            ? "🧪 Тестовый сервер Cynk (dev.cynk.ru)"
                            : "👋 Привет! Это защищённый мессенджер на базе Matrix",
                        textScaleFactor: MediaQuery.textScalerOf(
                          context,
                        ).scale(1),
                        textAlign: TextAlign.center,
                        linkStyle: TextStyle(
                          color: theme.colorScheme.secondary,
                          decorationColor: theme.colorScheme.secondary,
                        ),
                        onOpen: (link) => launchUrlString(link.url),
                      ),
                    ),
                    if (useTestBackend) ...[
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32.0),
                        child: Container(
                          padding: const EdgeInsets.all(8.0),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          child: Text(
                            '⚠️ Тестовый режим: данные могут быть удалены',
                            style: TextStyle(
                              color: theme.colorScheme.onErrorContainer,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ElevatedButton(
                            onPressed: () async {
                              final matrix = Matrix.of(context);
                              final client = await matrix.getLoginClient();
                              
                              if (client == null) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Ошибка подключения к серверу'),
                                    ),
                                  );
                                }
                                return;
                              }
                              
                              final homeserverUrl = useTestBackend 
                                  ? AppConfig.devServer
                                  : AppConfig.mainServer;
                              
                              if (client.homeserver == null) {
                                client.homeserver = Uri.parse(homeserverUrl);
                              }
                              
                              if (context.mounted) {
                                context.go(
                                  '${GoRouterState.of(context).uri.path}/login',
                                  extra: client,
                                );
                              }
                            },
                            child: Text("Войти"),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ElevatedButton(
                            onPressed: () async {
                              final matrix = Matrix.of(context);
                              final client = await matrix.getLoginClient();
                              
                              if (client == null) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Ошибка подключения к серверу'),
                                    ),
                                  );
                                }
                                return;
                              }
                              
                              final homeserverUrl = useTestBackend 
                                  ? AppConfig.devServer
                                  : AppConfig.mainServer;
                              
                              if (client.homeserver == null) {
                                client.homeserver = Uri.parse(homeserverUrl);
                              }
                              
                              if (context.mounted) {
                                context.go(
                                  '${GoRouterState.of(context).uri.path}/register',
                                  extra: client,
                                );
                              }
                            },
                            child: Text("Зарегистрироваться"),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}