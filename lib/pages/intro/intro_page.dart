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

class IntroPage extends StatefulWidget {
  const IntroPage({super.key});

  @override
  State<IntroPage> createState() => _IntroPageState();
}

class _IntroPageState extends State<IntroPage> {
  bool _useTestBackend = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final addMultiAccount = Matrix.of(
      context,
    ).widget.clients.any((client) => client.isLogged());

    return LoginScaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          addMultiAccount
              ? L10n.of(context).addAccount
              : "Cynk"
        ),
        actions: [
          /*PopupMenuButton(
            useRootNavigator: true,
            itemBuilder: (_) => [
              PopupMenuItem(
                onTap: () => restoreBackupFlow(context),
                child: Row(
                  mainAxisSize: .min,
                  children: [
                    const Icon(Icons.import_export_outlined),
                    const SizedBox(width: 12),
                    Text(L10n.of(context).hydrate),
                  ],
                ),
              ),
              PopupMenuItem(
                onTap: () => launchUrl(AppConfig.privacyUrl),
                child: Row(
                  mainAxisSize: .min,
                  children: [
                    const Icon(Icons.privacy_tip_outlined),
                    const SizedBox(width: 12),
                    Text(L10n.of(context).privacy),
                  ],
                ),
              ),
              PopupMenuItem(
                value: () => PlatformInfos.showDialog(context),
                child: Row(
                  mainAxisSize: .min,
                  children: [
                    const Icon(Icons.info_outlined),
                    const SizedBox(width: 12),
                    Text(L10n.of(context).about),
                  ],
                ),
              ),
            ],
          ),*/
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
                        text: _useTestBackend 
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
                    if (_useTestBackend) ...[
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
                    
                    // Переключатель "Тестировать бэкенд"
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Тестировать бэкенд',
                            style: TextStyle(
                              fontSize: 14,
                              color: _useTestBackend 
                                  ? theme.colorScheme.primary 
                                  : theme.colorScheme.onSurface.withOpacity(0.5),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Switch(
                            value: _useTestBackend,
                            onChanged: (value) {
                              setState(() {
                                _useTestBackend = value;
                                // Сохранение закомментировано
                                // AppSettings.useTestBackend.setItem(value);
                              });
                            },
                            activeColor: theme.colorScheme.primary,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Кнопка "Войти"
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32.0),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
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
                            
                            final homeserverUrl = _useTestBackend 
                                ? AppConfig.devServer
                                : AppConfig.mainServer;
                            
                            if (client.homeserver == null) {
                              client.homeserver = Uri.parse(homeserverUrl);
                            }
                            
                            if (context.mounted) {
                              // Убираем GoRouterState.of, используем прямой переход
                              context.go('/login', extra: client);
                            }
                          },
                          child: const Text("Войти"),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Кнопка "Зарегистрироваться"
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32.0),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
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
                            
                            final homeserverUrl = _useTestBackend 
                                ? AppConfig.devServer
                                : AppConfig.mainServer;
                            
                            if (client.homeserver == null) {
                              client.homeserver = Uri.parse(homeserverUrl);
                            }
                            
                            if (context.mounted) {
                              // Убираем GoRouterState.of, используем прямой переход
                              context.go('/register', extra: client);
                            }
                          },
                          child: const Text("Зарегистрироваться"),
                        ),
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