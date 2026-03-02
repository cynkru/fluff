import 'package:flutter/material.dart';

import 'package:fluffychat/config/app_config.dart';
import 'package:fluffychat/config/themes.dart';
import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/pages/sign_in/view_model/flows/connect_to_homeserver_flow.dart';
import 'package:fluffychat/pages/sign_in/view_model/sign_in_view_model.dart';
import 'package:fluffychat/widgets/layouts/login_scaffold.dart';
import 'package:fluffychat/widgets/matrix.dart';
import 'package:fluffychat/widgets/view_model_builder.dart';

class SignInPage extends StatelessWidget {
  final bool signUp;
  const SignInPage({required this.signUp, super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ViewModelBuilder(
      create: () => SignInViewModel(Matrix.of(context), signUp: signUp),
      builder: (context, viewModel, _) {
        final state = viewModel.value;
        
        // Сразу запускаем подключение к matrix.cynk.ru при загрузке страницы
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (state.loginLoading.connectionState != ConnectionState.waiting) {
            viewModel.setLoginLoading(ConnectionState.waiting);
            connectToHomeserverFlow(
              'matrix.cynk.ru',
              context,
              viewModel.setLoginLoading,
              signUp,
            );
          }
        });

        return LoginScaffold(
          appBar: AppBar(
            backgroundColor: theme.colorScheme.surface,
            surfaceTintColor: theme.colorScheme.surface,
            scrolledUnderElevation: 0,
            centerTitle: true,
            title: Text(
              signUp
                  ? L10n.of(context).createNewAccount
                  : L10n.of(context).login,
            ),
          ),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Connecting to matrix.cynk.ru...',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 24),
                const CircularProgressIndicator.adaptive(),
              ],
            ),
          ),
        );
      },
    );
  }
}