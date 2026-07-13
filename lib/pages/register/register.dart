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

  /// Извлекает локальную часть из полного username
  String _extractLocalPart(String input) {
    if (input.startsWith('@')) {
      final parts = input.split(':');
      if (parts.isNotEmpty) {
        return parts[0].replaceFirst('@', '');
      }
    }
    return input;
  }

  Future<void> register() async {
    // Извлекаем локальную часть username
    final username = _extractLocalPart(usernameController.text);
    final password = passwordController.text;
    final token = tokenController.text;

    // Валидация
    bool hasError = false;

    if (token.isEmpty) {
      setState(() => tokenError = L10n.of(context).pleaseEnterRegistrationToken);
      hasError = true;
    } else {
      setState(() => tokenError = null);
    }

    if (username.isEmpty) {
      setState(() => usernameError = L10n.of(context).pleaseEnterYourUsername);
      hasError = true;
    } else {
      setState(() => usernameError = null);
    }

    if (password.isEmpty) {
      setState(() => passwordError = L10n.of(context).pleaseEnterYourPassword);
      hasError = true;
    } else if (password != confirmPassword) {
      setState(() => passwordError = L10n.of(context).passwordsDoNotMatch);
      hasError = true;
    } else {
      setState(() => passwordError = null);
    }

    if (hasError) return;

    setState(() => loading = true);

    try {
      final homeserver = widget.client.homeserver;
      
      // ============================================================
      // ШАГ 1: Получаем UIA session
      // ============================================================
      print('📤 Шаг 1: Получение UIA session...');
      
      final sessionResponse = await http.post(
        Uri.parse('$homeserver/_matrix/client/v3/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
          'initial_device_display_name': PlatformInfos.clientName,
        }),
      );

      print('📥 Статус: ${sessionResponse.statusCode}');
      print('📥 Ответ: ${sessionResponse.body}');

      if (sessionResponse.statusCode != 401) {
        setState(() => tokenError = 'Неожиданный ответ сервера: ${sessionResponse.statusCode}');
        return;
      }

      final sessionData = jsonDecode(sessionResponse.body);
      final session = sessionData['session'];
      
      if (session == null) {
        setState(() => tokenError = 'Не удалось получить session для регистрации');
        return;
      }

      print('📋 Session получен: $session');

      // ============================================================
      // ШАГ 2: Завершаем регистрацию с токеном
      // ============================================================
      print('📤 Шаг 2: Завершение регистрации с токеном...');

      final response = await http.post(
        Uri.parse('$homeserver/_matrix/client/v3/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'auth': {
            'type': 'm.login.registration_token',
            'token': token,
            'session': session,
          },
          'username': username,
          'password': password,
          'initial_device_display_name': PlatformInfos.clientName,
        }),
      );

      print('📥 Финальный статус: ${response.statusCode}');
      print('📥 Финальный ответ: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final userId = data['user_id'];
        
        print('✅ Пользователь зарегистрирован: $userId');
        
        // Выполняем логин через библиотеку
        await widget.client.login(
          LoginType.mLoginPassword,
          user: userId,
          password: password,
          initialDeviceDisplayName: PlatformInfos.clientName,
        );

        if (mounted) {
          context.go('/backup');
        }
      } else {
        final data = jsonDecode(response.body);
        final error = data['error'] ?? 'Неизвестная ошибка регистрации';
        print('❌ Ошибка: $error');
        setState(() => tokenError = error);
      }
      
    } catch (exception) {
      print('❌ Исключение: $exception');
      setState(() => tokenError = exception.toString());
    }

    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) => RegisterWithTokenView(this);
}