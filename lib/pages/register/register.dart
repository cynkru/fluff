import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

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
  final TextEditingController confirmPasswordController = TextEditingController(); 
  
  String? tokenError;
  String? usernameError;
  String? passwordError;
  String? termsError;
  
  bool loading = false;
  bool showPassword = false;
  bool showConfirmPassword = false;
  bool termsAccepted = false;
  
  String? confirmPassword;

  // URL политики конфиденциальности
  final String privacyPolicyUrl = 'https://matrix.cynk.ru/_matrix/consent';

  void toggleShowPassword() =>
      setState(() => showPassword = !loading && !showPassword);
      
  void toggleShowConfirmPassword() =>
      setState(() => showConfirmPassword = !loading && !showConfirmPassword);

  void toggleTermsAccepted(bool? value) {
    if (value != null) {
      setState(() => termsAccepted = value);
    }
  }

  void _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Не удалось открыть ссылку: $url'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

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
    final username = _extractLocalPart(usernameController.text);
    final password = passwordController.text;
    final confirmPassword = confirmPasswordController.text; 
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

    if (!termsAccepted) {
      setState(() => termsError = 'Необходимо принять условия использования');
      hasError = true;
    } else {
      setState(() => termsError = null);
    }

    if (hasError) return;

    setState(() => loading = true);

    try {
      final homeserver = widget.client.homeserver;
      
      String? session;
      
      var response = await http.post(
        Uri.parse('$homeserver/_matrix/client/v3/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
          'initial_device_display_name': PlatformInfos.clientName,
        }),
      );

      if (response.statusCode != 401) {
        setState(() => tokenError = 'Неожиданный ответ сервера: ${response.statusCode}');
        return;
      }

      final sessionData = jsonDecode(response.body);
      session = sessionData['session'];
      
      if (session == null) {
        setState(() => tokenError = 'Не удалось получить session');
        return;
      }

      response = await http.post(
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

      if (response.statusCode == 200) {
        // Успех! (если вдруг сразу зарегистрировало)
        final data = jsonDecode(response.body);
        final userId = data['user_id'];
        
        await widget.client.login(
          LoginType.mLoginPassword,
          user: userId,
          password: password,
          initialDeviceDisplayName: PlatformInfos.clientName,
        );

        if (mounted) {
          context.go('/backup');
        }
        return;
      }

      // Проверяем, что прошло
      final errorData = jsonDecode(response.body);
      final completed = errorData['completed'] as List? ?? [];
      
      if (completed.contains('m.login.registration_token')) {
        
        response = await http.post(
          Uri.parse('$homeserver/_matrix/client/v3/register'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'auth': {
              'type': 'm.login.terms',
              'session': session,
            },
            'username': username,
            'password': password,
            'initial_device_display_name': PlatformInfos.clientName,
          }),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final userId = data['user_id'];
          
          await widget.client.login(
            LoginType.mLoginPassword,
            user: userId,
            password: password,
            initialDeviceDisplayName: PlatformInfos.clientName,
          );

          if (mounted) {
            context.go('/backup');
          }
          return;
        }

        final termsData = jsonDecode(response.body);
        final termsCompleted = termsData['completed'] as List? ?? [];

        // ============================================================
        // ШАГ 4: Завершение регистрации (m.login.dummy)
        // ============================================================
        if (termsCompleted.contains('m.login.terms')) {
          
          final dummyResponse = await http.post(
            Uri.parse('$homeserver/_matrix/client/v3/register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'auth': {
                'type': 'm.login.dummy',
                'session': session,
              },
              'username': username,
              'password': password,
              'initial_device_display_name': PlatformInfos.clientName,
            }),
          );

          if (dummyResponse.statusCode == 200) {
            final data = jsonDecode(dummyResponse.body);
            final userId = data['user_id'];
            
            await widget.client.login(
              LoginType.mLoginPassword,
              user: userId,
              password: password,
              initialDeviceDisplayName: PlatformInfos.clientName,
            );

            if (mounted) {
              context.go('/backup');
            }
            return;
          } else {
            final data = jsonDecode(dummyResponse.body);
            setState(() => tokenError = data['error'] ?? 'Ошибка завершения регистрации');
            return;
          }
        } else {
          setState(() => tokenError = termsData['error'] ?? 'Ошибка согласия с политикой');
          return;
        }
      }

      // Если ничего не сработало
      setState(() => tokenError = errorData['error'] ?? 'Неизвестная ошибка регистрации');
      
    } catch (exception) {
      print('❌ Исключение: $exception');
      setState(() => tokenError = exception.toString());
    }

    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) => RegisterWithTokenView(this);
}