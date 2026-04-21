import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/app_settings.dart';
import '../../data/datasources/settings_service.dart';

final settingsServiceProvider = Provider<SettingsService>((ref) {
  return SettingsService();
});

final settingsProvider = StateNotifierProvider<SettingsNotifier, AsyncValue<AppSettings>>((ref) {
  return SettingsNotifier(ref.watch(settingsServiceProvider));
});

class SettingsNotifier extends StateNotifier<AsyncValue<AppSettings>> {
  final SettingsService _service;

  SettingsNotifier(this._service) : super(const AsyncValue.loading()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await _service.loadSettings();
      state = AsyncValue.data(settings);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateSettings(AppSettings settings) async {
    await _service.saveSettings(settings);
    state = AsyncValue.data(settings);
  }

  Future<void> setModelPath(String path) async {
    final current = state.valueOrNull ?? AppSettings();
    await updateSettings(current.copyWith(modelPath: path));
  }

  Future<void> setMmprojPath(String path) async {
    final current = state.valueOrNull ?? AppSettings();
    await updateSettings(current.copyWith(mmprojPath: path));
  }

  Future<void> setSystemPrompt(String prompt) async {
    final current = state.valueOrNull ?? AppSettings();
    await updateSettings(current.copyWith(systemPrompt: prompt));
  }

  Future<void> setTemperature(double temp) async {
    final current = state.valueOrNull ?? AppSettings();
    final clampedTemp = temp.clamp(0.1, 2.0);
    await updateSettings(current.copyWith(temperature: clampedTemp));
  }

  Future<void> setMaxTokens(int tokens) async {
    final current = state.valueOrNull ?? AppSettings();
    await updateSettings(current.copyWith(maxTokens: tokens));
  }

  Future<void> setContextWindow(int ctx) async {
    final current = state.valueOrNull ?? AppSettings();
    await updateSettings(current.copyWith(contextWindow: ctx));
  }

  Future<void> setRepeatPenalty(double penalty) async {
    final current = state.valueOrNull ?? AppSettings();
    final clampedPenalty = penalty.clamp(1.0, 2.0);
    await updateSettings(current.copyWith(repeatPenalty: clampedPenalty));
  }

  Future<void> setTheme(String theme) async {
    final current = state.valueOrNull ?? AppSettings();
    await updateSettings(current.copyWith(theme: theme));
  }

  Future<void> setLanguage(String lang) async {
    final current = state.valueOrNull ?? AppSettings();
    await updateSettings(current.copyWith(language: lang));
  }

  Future<void> setTopP(double topP) async {
    final current = state.valueOrNull ?? AppSettings();
    final clamped = topP.clamp(0.0, 1.0);
    await updateSettings(current.copyWith(topP: clamped));
  }

  Future<void> setTopK(int topK) async {
    final current = state.valueOrNull ?? AppSettings();
    await updateSettings(current.copyWith(topK: topK));
  }

  Future<void> setRepeatLastN(int repeatLastN) async {
    final current = state.valueOrNull ?? AppSettings();
    await updateSettings(current.copyWith(repeatLastN: repeatLastN));
  }

  Future<void> setChatTemplate(String template) async {
    final current = state.valueOrNull ?? AppSettings();
    await updateSettings(current.copyWith(chatTemplate: template));
  }

  Future<void> setAutoDetectTemplate(bool autoDetect) async {
    final current = state.valueOrNull ?? AppSettings();
    await updateSettings(current.copyWith(autoDetectTemplate: autoDetect));
  }

  Future<void> setEnableThinking(bool enable) async {
    final current = state.valueOrNull ?? AppSettings();
    await updateSettings(current.copyWith(enableThinking: enable));
  }

  Future<void> resetGenerationSettings() async {
    final current = state.valueOrNull ?? AppSettings();
    await updateSettings(current.copyWith(
      temperature: 0.5,
      maxTokens: 256,
      contextWindow: 2048,
      repeatPenalty: 1.15,
      topP: 0.8,
      topK: 30,
      repeatLastN: 64,
    ));
  }
}
