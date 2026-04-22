import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class BackgroundService {
  static const _channel = MethodChannel('com.sanchoai/background_service');
  
  static BackgroundService? _instance;
  static BackgroundService get instance => _instance ??= BackgroundService._();
  BackgroundService._();
  
  bool _isActive = false;
  bool get isActive => _isActive;
  
  Future<void> start() async {
    if (_isActive) return;
    try {
      await _channel.invokeMethod('startService');
      _isActive = true;
    } catch (e) {
      debugPrint('BackgroundService start error: $e');
    }
  }
  
  Future<void> stop() async {
    if (!_isActive) return;
    try {
      await _channel.invokeMethod('stopService');
      _isActive = false;
    } catch (e) {
      debugPrint('BackgroundService stop error: $e');
    }
  }
}