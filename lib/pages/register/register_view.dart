import 'package:flutter/material.dart';

import 'package:cynk/l10n/l10n.dart';
import 'package:cynk/widgets/layouts/login_scaffold.dart';
import 'register.dart';

class RegisterWithTokenView extends StatelessWidget {
  final RegisterWithTokenController controller;

  const RegisterWithTokenView(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = "Регистрация по токену";

    return LoginScaffold(
      appBar: AppBar(
        leading: controller.loading ? null : const Center(child: BackButton()),
        automaticallyImplyLeading: !controller.loading,
        titleSpacing: !controller.loading ? 0 : null,
        title: Text(title),
      ),
      body: Builder(
        builder: (context) {
          return AutofillGroup(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: <Widget>[
                Hero(
                  tag: 'info-logo',
                  child: Image.asset('assets/banner_transparent.png'),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: TextField(
                    readOnly: controller.loading,
                    autocorrect: false,
                    autofocus: true,
                    controller: controller.tokenController,
                    textInputAction: TextInputAction.next,
                    keyboardType: TextInputType.text,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.vpn_key_outlined),
                      errorText: controller.tokenError,
                      errorStyle: const TextStyle(color: Colors.orange),
                      hintText: 'Токен регистрации',
                      labelText: 'Токен регистрации',
                      helperText: 'Введите токен регистрации',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: TextField(
                    readOnly: controller.loading,
                    autocorrect: false,
                    controller: controller.usernameController,
                    textInputAction: TextInputAction.next,
                    keyboardType: TextInputType.text,
                    autofillHints: controller.loading
                        ? null
                        : [AutofillHints.username],
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.account_box_outlined),
                      errorText: controller.usernameError,
                      errorStyle: const TextStyle(color: Colors.orange),
                      hintText: 'Имя пользователя',
                      labelText: 'Имя пользователя',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: TextField(
                    readOnly: controller.loading,
                    autocorrect: false,
                    autofillHints: controller.loading
                        ? null
                        : [AutofillHints.password],
                    controller: controller.passwordController,
                    textInputAction: TextInputAction.next,
                    obscureText: !controller.showPassword,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.lock_outlined),
                      errorText: controller.passwordError,
                      errorStyle: const TextStyle(color: Colors.orange),
                      suffixIcon: IconButton(
                        onPressed: controller.toggleShowPassword,
                        icon: Icon(
                          controller.showPassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: Colors.black,
                        ),
                      ),
                      hintText: '******',
                      labelText: 'Пароль',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: TextField(
                    readOnly: controller.loading,
                    autocorrect: false,
                    autofillHints: controller.loading
                        ? null
                        : [AutofillHints.password],
                    controller: TextEditingController()
                      ..text = controller.confirmPassword ?? '',
                    onChanged: (value) {
                      controller.confirmPassword = value;
                      if (controller.passwordController.text != value) {
                        controller.setState(() {
                          controller.passwordError = L10n.of(context).passwordsDoNotMatch;
                        });
                      } else {
                        controller.setState(() {
                          controller.passwordError = null;
                        });
                      }
                    },
                    textInputAction: TextInputAction.go,
                    obscureText: !controller.showConfirmPassword,
                    onSubmitted: (_) => controller.register(),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.lock_outline),
                      errorText: controller.passwordError,
                      errorStyle: const TextStyle(color: Colors.orange),
                      suffixIcon: IconButton(
                        onPressed: controller.toggleShowConfirmPassword,
                        icon: Icon(
                          controller.showConfirmPassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: Colors.black,
                        ),
                      ),
                      hintText: '******',
                      labelText: 'Подтверждение пароля',
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                    ),
                    onPressed: controller.loading ? null : controller.register,
                    child: controller.loading
                        ? const LinearProgressIndicator()
                        : Text('Зарегистрироваться'),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }
}