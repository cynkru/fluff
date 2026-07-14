import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

/// Кеш для бейджей пользователей
class BadgeCache {
  static final BadgeCache _instance = BadgeCache._internal();
  factory BadgeCache() => _instance;
  BadgeCache._internal();

  // Кеш: userId -> {badges: [...], selected_badge: ...}
  final Map<String, Map<String, dynamic>> _cache = {};
  
  // Время жизни кеша (5 минут)
  final Duration _ttl = const Duration(minutes: 5);
  
  // Время последнего обновления
  final Map<String, DateTime> _lastUpdate = {};

  /// Получить бейджи пользователя из кеша или загрузить
  Future<Map<String, dynamic>> getBadges(
    BuildContext context,
    String userId,
  ) async {
    // Проверяем кеш
    final cached = _cache[userId];
    final lastUpdate = _lastUpdate[userId];
    
    if (cached != null && lastUpdate != null) {
      final age = DateTime.now().difference(lastUpdate);
      if (age < _ttl) {
        debugPrint('📦 Badge cache hit for $userId');
        return cached;
      }
    }
    
    // Загружаем свежие данные
    debugPrint('🌐 Loading badges for $userId');
    try {
      final client = Matrix.of(context).client;
      final response = await client.httpClient.get(
        Uri.parse('https://matrix.cynk.ru/_matrix/client/v3/profile/$userId'),
      );
      
      Map<String, dynamic> data;
      if (response.statusCode == 200) {
        data = jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        data = {'badges': [], 'selected_badge': null};
      }
      
      // Сохраняем в кеш
      _cache[userId] = data;
      _lastUpdate[userId] = DateTime.now();
      
      return data;
    } catch (e) {
      debugPrint('❌ Error loading badges for $userId: $e');
      return {'badges': [], 'selected_badge': null};
    }
  }

  /// Очистить кеш для конкретного пользователя
  void invalidate(String userId) {
    _cache.remove(userId);
    _lastUpdate.remove(userId);
  }

  /// Очистить весь кеш
  void clear() {
    _cache.clear();
    _lastUpdate.clear();
  }
}