import 'dart:io';
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
    
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().toIso8601String().split('T')[0];
    _logFile = File('${directory.path}/sanchoai_$timestamp.log');
    
    if (!await _logFile!.exists()) {
      await _logFile!.create(recursive: true);
      await _logFile!.writeAsString('=== Sancho.AI Log Started ${DateTime.now()} ===\n');
    }
  }

  Future<void> log(String level, String message) async {
    await initialize();
    if (_logFile == null) return;
    
    final timestamp = _dateFormat.format(DateTime.now());
    final logLine = '[$timestamp] [$level] $message\n';
    
    try {
      await _logFile!.writeAsString(logLine, mode: FileMode.append);
    } catch (e) {
      // Ignore write errors
    }
  }

  void info(String message) => log('INFO', message);
  void warning(String message) => log('WARN', message);
  void error(String message) => log('ERROR', message);
  void debug(String message) => log('DEBUG', message);

  Future<String> getLogs() async {
    await initialize();
    if (_logFile == null) return '';
    
    try {
      return await _logFile!.readAsString();
    } catch (e) {
      return 'Error reading logs: $e';
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
}
