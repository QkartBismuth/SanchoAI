import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:async';
import '../providers/settings_provider.dart';
import '../providers/model_provider.dart';
import '../../domain/entities/model_state.dart';
import '../../data/datasources/export_import_service.dart';
import '../../data/datasources/log_service.dart';
import '../../data/datasources/llama_service.dart';
import 'generation_params_info_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _promptController;
  Timer? _debounceTimer;
  final _exportImportService = ExportImportService();
  final _logService = LogService.instance;

  @override
  void initState() {
    super.initState();
    _promptController = TextEditingController();
    _logService.initialize();
    _logService.info('Settings screen opened');
  }

  @override
  void dispose() {
    _promptController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSystemPromptChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      ref.read(settingsProvider.notifier).setSystemPrompt(value);
      _logService.info('System prompt updated to: $value');
    });
  }

  Future<void> _showExportDialog() async {
    final settings = ref.read(settingsProvider).valueOrNull;
    if (settings == null) return;

    final controller = TextEditingController(
      text: 'sanchoai_settings_${DateTime.now().millisecondsSinceEpoch}',
    );

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter file name:'),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                suffix: Text('.toon'),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'save'),
            child: const Text('Save to Downloads'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'share'),
            child: const Text('Share'),
          ),
        ],
      ),
    );

    if (result == null) return;

    String fileName = controller.text.trim();
    if (fileName.isEmpty) {
      fileName = 'sanchoai_settings_${DateTime.now().millisecondsSinceEpoch}';
    }

    if (!fileName.endsWith('.toon')) {
      fileName = '$fileName.toon';
    }

    String exportResult;
    if (result == 'share') {
      exportResult = await _exportImportService.exportSettingsAndShare(settings, fileName: fileName.replaceAll('.toon', ''));
    } else {
      exportResult = await _exportImportService.exportSettings(settings, fileName: fileName.replaceAll('.toon', ''));
    }

    if (mounted) {
      if (exportResult.startsWith('Error')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(exportResult)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result == 'share' ? 'Settings ready to share' : 'Saved: $exportResult')),
        );
      }
    }
  }

  Future<void> _importSettings() async {
    final result = await _exportImportService.importSettings();
    
    if (result == null) return;

    if (result.startsWith('Error')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result)),
        );
      }
      return;
    }

    final settings = ref.read(settingsProvider).valueOrNull;
    if (settings == null) return;

    final imported = _exportImportService.parseSettings(result);
    final newSettings = settings.copyWith(
      systemPrompt: imported['systemPrompt'] ?? settings.systemPrompt,
      temperature: (imported['temperature'] ?? settings.temperature).toDouble(),
      maxTokens: imported['maxTokens'] ?? settings.maxTokens,
      contextWindow: imported['contextWindow'] ?? settings.contextWindow,
      repeatPenalty: (imported['repeatPenalty'] ?? settings.repeatPenalty).toDouble(),
      topP: (imported['topP'] ?? settings.topP).toDouble(),
      topK: imported['topK'] ?? settings.topK,
      repeatLastN: imported['repeatLastN'] ?? settings.repeatLastN,
      chatTemplate: imported['chatTemplate'] ?? settings.chatTemplate,
      autoDetectTemplate: imported['autoDetectTemplate'] ?? settings.autoDetectTemplate,
      enableThinking: imported['enableThinking'] ?? settings.enableThinking,
    );

    await ref.read(settingsProvider.notifier).updateSettings(newSettings);

    _logService.logGenerationSettings(
      temperature: newSettings.temperature,
      maxTokens: newSettings.maxTokens,
      repeatPenalty: newSettings.repeatPenalty,
      topP: newSettings.topP,
      topK: newSettings.topK,
      repeatLastN: newSettings.repeatLastN,
      systemPrompt: newSettings.systemPrompt,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings imported successfully')),
      );
    }
  }

  Future<void> _shareLogs() async {
    final logFile = await _logService.getLogFile();
    if (logFile == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No logs available')),
        );
      }
      return;
    }

    await Share.shareXFiles(
      [XFile(logFile.path)],
      text: 'Sancho.AI Logs',
    );
  }

  Future<void> _clearLogs() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Logs'),
        content: const Text('Are you sure you want to clear all logs?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _logService.clearLogs();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logs cleared')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final modelState = ref.watch(modelStateProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Settings'),
      ),
      body: settings.when(
        data: (s) {
          if (_promptController.text != s.systemPrompt) {
            _promptController.text = s.systemPrompt;
          }
          return ScrollConfiguration(
            behavior: _GlowScrollBehavior(),
            child: ListView(
              physics: const BouncingScrollPhysics(),
              children: [
                _SectionHeader(title: 'AI Model'),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.model_training_rounded),
                        title: const Text('Model File'),
                        subtitle: Text(s.modelPath.isEmpty ? 'Not selected' : s.modelPath.split('/').last),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Icon(
                              modelState.status == ModelStatus.ready
                                  ? Icons.check_circle_rounded
                                  : modelState.status == ModelStatus.error
                                      ? Icons.error_rounded
                                      : modelState.status == ModelStatus.generating
                                          ? Icons.auto_awesome_rounded
                                          : Icons.hourglass_empty_rounded,
                              size: 16,
                              color: _getStatusColor(modelState.status, theme.colorScheme),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _getStatusText(modelState.status),
                              style: TextStyle(
                                fontSize: 12,
                                color: _getStatusColor(modelState.status, theme.colorScheme),
                              ),
                            ),
                            const Spacer(),
                            if (modelState.status == ModelStatus.generating)
                              TextButton.icon(
                                onPressed: () => _cancelGeneration(ref),
                                icon: const Icon(Icons.stop_rounded, size: 16),
                                label: const Text('Stop'),
                              ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () async { 
                                  await _pickModelFile(context, ref); 
                                },
                                icon: const Icon(Icons.folder_open_rounded),
                                label: const Text('Select Model'),
                              ),
                            ),
                            if (s.modelPath.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: modelState.status == ModelStatus.loading || modelState.status == ModelStatus.generating
                                      ? null
                                      : () async {
                                          final init = ref.read(initializeModelProvider);
                                          await init();
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Model reloaded')),
                                            );
                                          }
                                        },
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: const Text('Reload Model'),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.image_rounded),
                        title: const Text('Multimodal Projector'),
                        subtitle: Text(s.mmprojPath.isEmpty ? 'Not selected (optional)' : s.mmprojPath.split('/').last),
                        trailing: s.mmprojPath.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () => ref.read(settingsProvider.notifier).setMmprojPath(''),
                              )
                            : null,
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _pickMmprojFile(context, ref),
                            icon: const Icon(Icons.folder_open_rounded),
                            label: Text(s.mmprojPath.isEmpty ? 'Select MMPRoJ' : 'Change MMPRoJ'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                _SectionHeader(title: 'AI Personality'),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _promptController,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  hintText: 'Enter system prompt...',
                                ),
                                maxLines: 4,
                                onChanged: _onSystemPromptChanged,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 32),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _importSettings,
                                icon: const Icon(Icons.file_upload_rounded),
                                label: const Text('Import'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _showExportDialog,
                                icon: const Icon(Icons.file_download_rounded),
                                label: const Text('Export'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                
                _SectionHeader(
                  title: 'Generation Settings',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.help_outline_rounded),
                        tooltip: 'Learn about generation parameters',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const GenerationParamsInfoScreen(),
                            ),
                          );
                        },
                      ),
                      TextButton.icon(
                        onPressed: () => ref.read(settingsProvider.notifier).resetGenerationSettings(),
                        icon: const Icon(Icons.restore_rounded, size: 18),
                        label: const Text('Reset'),
                      ),
                    ],
                  ),
                ),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Temperature'),
                            Text('${s.temperature.toStringAsFixed(1)}'),
                          ],
                        ),
                        Slider(
                          value: s.temperature,
                          min: 0.1,
                          max: 2.0,
                          divisions: 19,
                          onChanged: (v) => ref.read(settingsProvider.notifier).setTemperature(v),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Max Tokens'),
                            Text('${s.maxTokens}'),
                          ],
                        ),
                        Slider(
                          value: s.maxTokens.toDouble(),
                          min: 64,
                          max: 4096,
                          divisions: 63,
                          onChanged: (v) => ref.read(settingsProvider.notifier).setMaxTokens(v.toInt()),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Repeat Penalty'),
                            Text('${s.repeatPenalty.toStringAsFixed(2)}'),
                          ],
                        ),
                        Slider(
                          value: s.repeatPenalty,
                          min: 1.0,
                          max: 2.0,
                          divisions: 20,
                          onChanged: (v) => ref.read(settingsProvider.notifier).setRepeatPenalty(v),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Context Window'),
                            Text('${s.contextWindow}'),
                          ],
                        ),
                        Slider(
                          value: s.contextWindow.toDouble(),
                          min: 512,
                          max: 8192,
                          divisions: 15,
                          onChanged: (v) => ref.read(settingsProvider.notifier).setContextWindow(v.toInt()),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Top P'),
                            Text('${s.topP.toStringAsFixed(2)}'),
                          ],
                        ),
                        Slider(
                          value: s.topP,
                          min: 0.0,
                          max: 1.0,
                          divisions: 20,
                          onChanged: (v) => ref.read(settingsProvider.notifier).setTopP(v),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Top K'),
                            Text('${s.topK}'),
                          ],
                        ),
                        Slider(
                          value: s.topK.toDouble(),
                          min: 1,
                          max: 100,
                          divisions: 99,
                          onChanged: (v) => ref.read(settingsProvider.notifier).setTopK(v.toInt()),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Repeat Last N'),
                            Text('${s.repeatLastN}'),
                          ],
                        ),
                        Slider(
                          value: s.repeatLastN.toDouble(),
                          min: 0,
                          max: 128,
                          divisions: 128,
                          onChanged: (v) => ref.read(settingsProvider.notifier).setRepeatLastN(v.toInt()),
                        ),
                        const Divider(height: 32),
                        _SectionHeader(title: 'Chat Template', fontSize: 14),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButton<String>(
                                value: s.chatTemplate,
                                isExpanded: true,
                                items: const [
                                  DropdownMenuItem(value: 'none', child: Text('None (Universal)')),
                                  DropdownMenuItem(value: 'chatml', child: Text('ChatML')),
                                  DropdownMenuItem(value: 'llama2', child: Text('Llama-2')),
                                  DropdownMenuItem(value: 'alpaca', child: Text('Alpaca')),
                                  DropdownMenuItem(value: 'vicuna', child: Text('Vicuna')),
                                  DropdownMenuItem(value: 'phi', child: Text('Phi')),
                                  DropdownMenuItem(value: 'gemma', child: Text('Gemma')),
                                  DropdownMenuItem(value: 'zephyr', child: Text('Zephyr')),
                                ],
                                onChanged: (v) {
                                  if (v != null) ref.read(settingsProvider.notifier).setChatTemplate(v);
                                },
                              ),
                            ),
                          ],
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Auto-Detect Template'),
                          subtitle: const Text('Detect template from model filename'),
                          value: s.autoDetectTemplate,
                          onChanged: (v) => ref.read(settingsProvider.notifier).setAutoDetectTemplate(v),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Enable Thinking'),
                          subtitle: const Text('Show thinking in response for supported models'),
                          value: s.enableThinking,
                          onChanged: (v) => ref.read(settingsProvider.notifier).setEnableThinking(v),
                        ),
                      ],
                    ),
                  ),
                ),
                
                _SectionHeader(title: 'Appearance'),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    leading: const Icon(Icons.palette_rounded),
                    title: const Text('Theme'),
                    trailing: DropdownButton<String>(
                      value: s.theme,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: 'system', child: Text('System')),
                        DropdownMenuItem(value: 'light', child: Text('Light')),
                        DropdownMenuItem(value: 'dark', child: Text('Dark')),
                      ],
                      onChanged: (v) {
                        if (v != null) ref.read(settingsProvider.notifier).setTheme(v);
                      },
                    ),
                  ),
                ),

                _SectionHeader(title: 'Logs'),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.article_rounded),
                        title: const Text('View Logs'),
                        subtitle: const Text('View application logs'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => _showLogsDialog(),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.share_rounded),
                        title: const Text('Share Logs'),
                        subtitle: const Text('Share logs via other apps'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: _shareLogs,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: Icon(Icons.delete_outline_rounded, color: theme.colorScheme.error),
                        title: Text('Clear Logs', style: TextStyle(color: theme.colorScheme.error)),
                        subtitle: const Text('Clear all application logs'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: _clearLogs,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  void _showLogsDialog() async {
    final logs = await _logService.getLogs();
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Application Logs'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: SingleChildScrollView(
            child: SelectableText(
              logs.isEmpty ? 'No logs available' : logs,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _getStatusText(ModelStatus status) {
    switch (status) {
      case ModelStatus.idle:
        return 'Not loaded';
      case ModelStatus.loading:
        return 'Loading model...';
      case ModelStatus.ready:
        return 'Ready';
      case ModelStatus.generating:
        return 'Generating...';
      case ModelStatus.error:
        return 'Error';
    }
  }

  Color _getStatusColor(ModelStatus status, ColorScheme colorScheme) {
    switch (status) {
      case ModelStatus.idle:
        return colorScheme.outline;
      case ModelStatus.loading:
        return colorScheme.tertiary;
      case ModelStatus.ready:
        return colorScheme.primary;
      case ModelStatus.generating:
        return colorScheme.secondary;
      case ModelStatus.error:
        return colorScheme.error;
    }
  }

  Future<void> _pickModelFile(BuildContext context, WidgetRef ref) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );
      
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.path != null && file.path!.isNotEmpty) {
          final settings = ref.read(settingsProvider).valueOrNull;
          final autoDetect = settings?.autoDetectTemplate ?? true;
          
          if (autoDetect) {
            final detectedTemplate = LlamaService.detectTemplateFromFilename(file.path!);
            await ref.read(settingsProvider.notifier).setChatTemplate(detectedTemplate);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Auto-detected template: $detectedTemplate')),
              );
            }
          }
          
          await ref.read(settingsProvider.notifier).setModelPath(file.path!);
          
          _logService.logModelSettings(
            modelPath: file.path!,
            contextWindow: ref.read(settingsProvider).valueOrNull?.contextWindow ?? 2048,
            chatTemplate: ref.read(settingsProvider).valueOrNull?.chatTemplate ?? 'none',
            autoDetect: autoDetect,
          );
          
          final init = ref.read(initializeModelProvider);
          await init();
          
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Model loaded: ${file.name}')),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error picking model file: $e');
    }
  }

  Future<void> _cancelGeneration(WidgetRef ref) async {
    final service = ref.read(llamaServiceProvider);
    await service.stop();
  }

  Future<void> _pickMmprojFile(BuildContext context, WidgetRef ref) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );
      
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.path != null) {
          await ref.read(settingsProvider.notifier).setMmprojPath(file.path!);
          
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('MMPRoJ selected: ${file.name}')),
            );
          }
          
          final init = ref.read(initializeModelProvider);
          await init();
          
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Model reloaded with multimodal projector')),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error picking mmproj file: $e');
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final double fontSize;

  const _SectionHeader({required this.title, this.trailing, this.fontSize = 12});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Text(
            title.toUpperCase(),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
              fontSize: fontSize,
              letterSpacing: 1.2,
            ),
          ),
          if (trailing != null) ...[
            const Spacer(),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class _GlowScrollBehavior extends ScrollBehavior {
  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) {
    return GlowingOverscrollIndicator(
      axisDirection: details.direction,
      color: Theme.of(context).colorScheme.primary,
      child: child,
    );
  }
}
