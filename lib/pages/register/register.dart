import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart';
import 'package:http/http.dart' as http;

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
      final homeserver = widget.client.homeserver;
      
      // 🔥 ПРЯМОЙ ЗАПРОС К /register
      final response = await http.post(
        Uri.parse('$homeserver/_matrix/client/v3/register'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'auth': {
            'type': 'm.login.token',
            'token': tokenController.text,
          },
          'username': usernameController.text.replaceFirst('@', '').replaceFirst(':matrix.cynk.ru', ''),
          'password': passwordController.text,
          'initial_device_display_name': PlatformInfos.clientName,
          'inhibit_login': true, // Не логинимся сразу, сделаем отдельно
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final userId = data['user_id'];
        
        // Теперь логинимся через библиотеку matrix
        await widget.client.login(
          LoginType.mLoginPassword,
          user: usernameController.text,
          password: passwordController.text,
          initialDeviceDisplayName: PlatformInfos.clientName,
        );

        if (mounted) {
          context.go('/backup');
        }
      } else if (response.statusCode == 401) {
        // Возможно, требуется завершить регистрацию (например, email)
        final data = jsonDecode(response.body);
        if (data['session'] != null) {
          // Здесь можно обработать многошаговую регистрацию
          setState(() => tokenError = 'Требуется дополнительная проверка');
        } else {
          setState(() => tokenError = 'Неверный токен регистрации');
        }
      } else {
        final data = jsonDecode(response.body);
        setState(() => tokenError = data['error'] ?? 'Ошибка регистрации');
      }
    } catch (exception) {
      setState(() => tokenError = exception.toString());
    }

    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) => RegisterWithTokenView(this);
}