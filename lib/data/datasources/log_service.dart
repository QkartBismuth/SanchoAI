import 'dart:convert';
import 'dart:io';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

class LogService {
  static LogService? _instance;
  File? _logFile;
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

  LogService._();

  static LogService get instance {
    _instance ??= LogService._();
    return _instance!;
  }

  Future<void> initialize() async {
    if (_logFile != null) return;
    
    try {
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().toIso8601String().split('T')[0];
      _logFile = File('${directory.path}/sanchoai_$timestamp.log');
      
      if (!await _logFile!.exists()) {
        await _logFile!.create(recursive: true);
      }
      await _logFile!.writeAsString('=== Sancho.AI Log Started ${DateTime.now()} ===\n', mode: FileMode.append);
      debugPrint('LogService initialized: ${_logFile!.path}');
    } catch (e) {
      debugPrint('LogService init error: $e');
    }
  }

  Future<void> log(String level, String message) async {
    if (_logFile == null) {
      await initialize();
    }
    
    if (_logFile == null) return;
    
    final timestamp = _dateFormat.format(DateTime.now());
    final logLine = '[$timestamp] [$level] $message\n';
    
    debugPrint('LOG: $logLine');
    
    try {
      await _logFile!.writeAsString(logLine, mode: FileMode.append);
    } catch (e) {
      debugPrint('Log write error: $e');
    }
  }

  void info(String message) => log('INFO', message);
  void warning(String message) => log('WARN', message);
  void error(String message) => log('ERROR', message);
  void debug(String message) => log('DEBUG', message);

  void logModelSettings({
    required String modelPath,
    required int contextWindow,
    required String chatTemplate,
    required bool autoDetect,
  }) {
    info('=== MODEL SETTINGS ===');
    info('Model: $modelPath');
    info('Context Window: $contextWindow');
    info('Chat Template: $chatTemplate');
    info('Auto Detect: $autoDetect');
    info('========================');
  }

  void logGenerationSettings({
    required double temperature,
    required int maxTokens,
    required double repeatPenalty,
    required double topP,
    required int topK,
    required int repeatLastN,
    required String systemPrompt,
  }) {
    info('=== GENERATION SETTINGS ===');
    info('Temperature: $temperature');
    info('Max Tokens: $maxTokens');
    info('Repeat Penalty: $repeatPenalty');
    info('Top P: $topP');
    info('Top K: $topK');
    info('Repeat Last N: $repeatLastN');
    info('System Prompt: $systemPrompt');
    info('============================');
  }

  void logChatMessage(String role, String content) {
    final preview = content.length > 100 ? '${content.substring(0, 100)}...' : content;
    info('[$role] $preview');
  }

  void logGenerationStart(String messagePreview) {
    info('=== GENERATION START ===');
    info('User message: $messagePreview');
  }

  void logGenerationEnd(String responsePreview) {
    final preview = responsePreview.length > 100 ? '${responsePreview.substring(0, 100)}...' : responsePreview;
    info('Response: $preview');
    info('=== GENERATION END ===');
  }

  void logError(String context, String errorMessage) {
    final preview = errorMessage.length > 100 ? '${errorMessage.substring(0, 100)}...' : errorMessage;
    info('[$context] $preview');
  }

  Future<String> getLogs() async {
    await initialize();
    if (_logFile == null) return '';
    
    try {
      return await _logFile!.readAsString(encoding: const Utf8Codec(allowMalformed: true));
    } catch (e) {
      try {
        return await _logFile!.readAsString(encoding: const Latin1Codec());
      } catch (e2) {
        return 'Error reading logs: $e';
      }
    }
  }

  Future<void> clearLogs() async {
    await initialize();
    if (_logFile == null) return;
    
    try {
      await _logFile!.writeAsString('=== Logs cleared ${DateTime.now()} ===\n');
    } catch (e) {
      // Ignore
    }
  }

  Future<String?> getLogFilePath() async {
    await initialize();
    return _logFile?.path;
  }

  Future<File?> getLogFile() async {
    await initialize();
    return _logFile;
  }
}
