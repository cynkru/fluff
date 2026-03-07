import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';

import 'package:fluffychat/widgets/lock_screen.dart';

class AppLockWidget extends StatefulWidget {
  const AppLockWidget({
    required this.child,
    required this.pincode,
    required this.clients,
    super.key,
  });

  final List<Client> clients;
  final String? pincode;
  final Widget child;

  @override
  State<AppLockWidget> createState() => AppLock();
}

class AppLock extends State<AppLockWidget> with WidgetsBindingObserver {
  String? _pincode;
  bool _isLocked = false;
  bool _paused = false;
  bool get isActive =>
      _pincode != null &&
      int.tryParse(_pincode!) != null &&
      _pincode!.length == 4 &&
      !_paused;

  @override
  void initState() {
    _pincode = widget.pincode;
    _isLocked = isActive;
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback(_checkLoggedIn);
  }

  void _checkLoggedIn(_) async {
    if (widget.clients.any((client) => client.isLogged())) return;

    await changePincode(null);
    setState(() {
      _isLocked = false;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (isActive &&
        state == AppLifecycleState.hidden &&
        !_isLocked &&
        isActive) {
      showLockScreen();
    }
  }

  bool get isLocked => _isLocked;

  Future<void> changePincode(String? pincode) async {
    await const FlutterSecureStorage().write(
      key: 'chat.fluffy.app_lock',
      value: pincode,
    );
    _pincode = pincode;
    return;
  }

  bool unlock(String pincode) {
    final isCorrect = pincode == _pincode;
    if (isCorrect) {
      setState(() {
        _isLocked = false;
      });
    }
    return isCorrect;
  }

  void showLockScreen() => setState(() {
    _isLocked = true;
  });

  Future<T> pauseWhile<T>(Future<T> future) async {
    _paused = true;
    try {
      return await future;
    } finally {
      _paused = false;
    }
  }

  static AppLock of(BuildContext context) =>
      Provider.of<AppLock>(context, listen: false);

  @override
  Widget build(BuildContext context) => Provider<AppLock>(
    create: (_) => this,
    child: Stack(
      fit: StackFit.expand,
      children: [widget.child, if (isLocked) const LockScreen()],
    ),
  );
}

// Новый LockScreen с красивым вводом пина
class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final List<int> _enteredPincode = [];
  String? _errorMessage;
  bool _shake = false;

  static const int pincodeLength = 4;

  void _onNumberPressed(int number) {
    if (_enteredPincode.length >= pincodeLength) return;
    
    setState(() {
      _enteredPincode.add(number);
      _errorMessage = null;
    });

    // Проверяем пин когда ввели все цифры
    if (_enteredPincode.length == pincodeLength) {
      _checkPincode();
    }
  }

  void _onDeletePressed() {
    if (_enteredPincode.isNotEmpty) {
      setState(() {
        _enteredPincode.removeLast();
        _errorMessage = null;
      });
    }
  }

  void _checkPincode() {
    final entered = _enteredPincode.join();
    final appLock = AppLock.of(context);
    
    if (appLock.unlock(entered)) {
      // Успешно - экран закроется сам (setState в unlock)
    } else {
      // Неправильный пин
      setState(() {
        _errorMessage = 'Неверный PIN';
        _shake = true;
        _enteredPincode.clear();
      });
      
      // Анимация тряски
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() => _shake = false);
        }
      });
    }
  }

  Widget _buildDot(int index) {
    return Container(
      width: 16,
      height: 16,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: index < _enteredPincode.length
            ? Theme.of(context).colorScheme.primary
            : Colors.grey.shade300,
        border: Border.all(
          color: index < _enteredPincode.length
              ? Colors.transparent
              : Colors.grey.shade400,
        ),
      ),
    );
  }

  Widget _buildNumberButton(int number) {
    return Expanded(
      child: AspectRatio(
        aspectRatio: 1,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => _onNumberPressed(number),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                child: Center(
                  child: Text(
                    number.toString(),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      color: theme.scaffoldBackgroundColor,
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Иконка замка
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.lock_outline,
                size: 40,
                color: theme.colorScheme.primary,
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Заголовок
            Text(
              'Введите PIN-код',
              style: theme.textTheme.titleLarge,
            ),
            
            const SizedBox(height: 8),
            
            // Подзаголовок
            Text(
              'для разблокировки приложения',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            
            const SizedBox(height: 48),
            
            // Точки ввода
            AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              transform: _shake
                  ? (Matrix4.identity()..translate(Offset(10, 0).dx))
                  : Matrix4.identity(),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  pincodeLength,
                  (index) => _buildDot(index),
                ),
              ),
            ),
            
            // Сообщение об ошибке
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: TextStyle(
                  color: theme.colorScheme.error,
                  fontSize: 14,
                ),
              ),
            ],
            
            const SizedBox(height: 48),
            
            // Цифровая клавиатура
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  // Первый ряд
                  Row(
                    children: [
                      _buildNumberButton(1),
                      _buildNumberButton(2),
                      _buildNumberButton(3),
                    ],
                  ),
                  // Второй ряд
                  Row(
                    children: [
                      _buildNumberButton(4),
                      _buildNumberButton(5),
                      _buildNumberButton(6),
                    ],
                  ),
                  // Третий ряд
                  Row(
                    children: [
                      _buildNumberButton(7),
                      _buildNumberButton(8),
                      _buildNumberButton(9),
                    ],
                  ),
                  // Четвертый ряд
                  Row(
                    children: [
                      const Spacer(),
                      Expanded(
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () => _onNumberPressed(0),
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: theme.colorScheme.surfaceContainerHighest,
                                  ),
                                  child: const Center(
                                    child: Text(
                                      '0',
                                      style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: _onDeletePressed,
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.transparent,
                                  ),
                                  child: Center(
                                    child: Icon(
                                      Icons.backspace_outlined,
                                      size: 28,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}