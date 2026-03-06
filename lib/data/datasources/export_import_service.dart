import 'dart:io';
import 'package:toon_formater/toon_formater.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../../domain/entities/app_settings.dart';

class ExportImportService {
  Future<String> exportSettings(AppSettings settings, {String? fileName}) async {
    try {
      final data = {
        'systemPrompt': settings.systemPrompt,
        'temperature': settings.temperature,
        'maxTokens': settings.maxTokens,
        'contextWindow': settings.contextWindow,
        'repeatPenalty': settings.repeatPenalty,
        'topP': settings.topP,
        'topK': settings.topK,
        'repeatLastN': settings.repeatLastN,
        'chatTemplate': settings.chatTemplate,
        'autoDetectTemplate': settings.autoDetectTemplate,
      };

      final toon = encode(data);

      Directory? downloadsDir;
      
      if (Platform.isAndroid) {
        downloadsDir = Directory('/storage/emulated/0/Download');
        if (!await downloadsDir.exists()) {
          downloadsDir = Directory('/storage/emulated/0/Documents');
        }
      } else {
        downloadsDir = await getDownloadsDirectory();
      }

      if (downloadsDir == null || !await downloadsDir.exists()) {
        final appDir = await getApplicationDocumentsDirectory();
        final name = fileName ?? 'sanchoai_settings_${DateTime.now().millisecondsSinceEpoch}';
        final filePath = '${appDir.path}/$name.toon';
        final file = File(filePath);
        await file.writeAsString(toon);
        return filePath;
      }

      final name = fileName ?? 'sanchoai_settings_${DateTime.now().millisecondsSinceEpoch}';
      final filePath = '${downloadsDir.path}/$name.toon';
      final file = File(filePath);
      await file.writeAsString(toon);
      return filePath;
    } catch (e) {
      return 'Error exporting settings: $e';
    }
  }

  Future<String> exportSettingsAndShare(AppSettings settings, {String? fileName}) async {
    try {
      final data = {
        'systemPrompt': settings.systemPrompt,
        'temperature': settings.temperature,
        'maxTokens': settings.maxTokens,
        'contextWindow': settings.contextWindow,
        'repeatPenalty': settings.repeatPenalty,
        'topP': settings.topP,
        'topK': settings.topK,
        'repeatLastN': settings.repeatLastN,
        'chatTemplate': settings.chatTemplate,
        'autoDetectTemplate': settings.autoDetectTemplate,
      };

      final toon = encode(data);

      final tempDir = await getTemporaryDirectory();
      final name = fileName ?? 'sanchoai_settings_${DateTime.now().millisecondsSinceEpoch}';
      final filePath = '${tempDir.path}/$name.toon';
      final file = File(filePath);
      await file.writeAsString(toon);

      await Share.shareXFiles(
        [XFile(filePath)],
        text: 'Sancho.AI Settings',
      );

      return filePath;
    } catch (e) {
      return 'Error sharing settings: $e';
    }
  }

  Future<String?> importSettings() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['toon', 'txt'],
      );

      if (result == null || result.files.isEmpty) {
        return null;
      }

      final file = result.files.first;
      if (file.path == null) {
        return 'Error: File path is null';
      }

      final toonContent = await File(file.path!).readAsString();
      
      try {
        final decoded = decode(toonContent);
        if (decoded is! Map<String, dynamic>) {
          return 'Error: Invalid TOON format - expected object';
        }
        return _validateAndMergeSettings(decoded);
      } catch (e) {
        return 'Error parsing TOON format: $e';
      }
    } catch (e) {
      return 'Error importing settings: $e';
    }
  }

  String? _validateAndMergeSettings(Map<String, dynamic> data) {
    final validKeys = [
      'systemPrompt',
      'temperature',
      'maxTokens',
      'contextWindow',
      'repeatPenalty',
      'topP',
      'topK',
      'repeatLastN',
      'chatTemplate',
      'autoDetectTemplate',
    ];

    final filteredData = <String, dynamic>{};
    for (final key in validKeys) {
      if (data.containsKey(key)) {
        filteredData[key] = data[key];
      }
    }

    if (filteredData.isEmpty) {
      return 'Error: No valid settings found in file';
    }

    return _encodeSettings(filteredData);
  }

  String _encodeSettings(Map<String, dynamic> data) {
    final buffer = StringBuffer();
    for (final entry in data.entries) {
      buffer.writeln('${entry.key}: ${entry.value}');
    }
    return buffer.toString();
  }

  Map<String, dynamic> parseSettings(String toonContent) {
    final decoded = decode(toonContent);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    return {};
  }
}
