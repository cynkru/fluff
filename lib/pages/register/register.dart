import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart';

import 'package:cynk/l10n/l10n.dart';
import 'package:cynk/utils/localized_exception_extension.dart';
import 'package:cynk/widgets/future_loading_dialog.dart';
import 'package:cynk/widgets/matrix.dart';
import '../../utils/platform_infos.dart';
import 'register_view.dart';

class RegisterWithToken extends StatefulWidget {
  final Client client;
  const RegisterWithToken({required this.client, super.key});

  @override
  RegisterController createState() => RegisterController();
}

class RegisterController extends State<RegisterWithToken> {
  final TextEditingController tokenController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  
  String? tokenError;
  String? usernameError;
  String? passwordError;
  
  bool loading = false;
  bool showPassword = false;
  bool showConfirmPassword = false;
  
  String? confirmPassword;

  void toggleShowPassword() =>
      setState(() => showPassword = !loading && !showPassword);
      
  void toggleShowConfirmPassword() =>
      setState(() => showConfirmPassword = !loading && !showConfirmPassword);

  Future<void> register() async {
    // Автоматически добавляем домен к username
    String username = usernameController.text;
    if (username.isNotEmpty && !username.contains('@') && !username.contains(':')) {
      username = '@$username:matrix.cynk.ru';
      usernameController.text = username;
    }

    // Валидация
    bool hasError = false;

    if (tokenController.text.isEmpty) {
      setState(() => tokenError = L10n.of(context).pleaseEnterRegistrationToken);
      hasError = true;
    } else {
      setState(() => tokenError = null);
    }

    if (usernameController.text.isEmpty) {
      setState(() => usernameError = L10n.of(context).pleaseEnterYourUsername);
      hasError = true;
    } else {
      setState(() => usernameError = null);
    }

    if (passwordController.text.isEmpty) {
      setState(() => passwordError = L10n.of(context).pleaseEnterYourPassword);
      hasError = true;
    } else if (passwordController.text != confirmPassword) {
      setState(() => passwordError = L10n.of(context).passwordsDoNotMatch);
      hasError = true;
    } else {
      setState(() => passwordError = null);
    }

    if (hasError) return;

    setState(() => loading = true);

    try {
      final matrix = Matrix.of(context);
      final client = await matrix.getLoginClient();

      // Используем токен регистрации — просто Map
      final registrationResponse = await client.register(
        username: usernameController.text,
        password: passwordController.text,
        initialDeviceDisplayName: PlatformInfos.clientName,
        auth: {
          'type': 'm.login.token',
          'token': tokenController.text,
        },
      );

      if (mounted && registrationResponse != null) {
        // После успешной регистрации выполняем логин
        await client.login(
          LoginType.mLoginPassword,
          user: usernameController.text,
          password: passwordController.text,
          initialDeviceDisplayName: PlatformInfos.clientName,
        );

        if (mounted) {
          context.go('/backup');
        }
      }
    } on MatrixException catch (exception) {
      setState(() => tokenError = exception.errorMessage);
      return setState(() => loading = false);
    } catch (exception) {
      setState(() => tokenError = exception.toString());
      return setState(() => loading = false);
    }

    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) => RegisterWithTokenView(this);
}