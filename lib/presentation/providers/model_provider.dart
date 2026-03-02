import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/model_state.dart';
import '../../domain/entities/app_settings.dart';
import '../../data/datasources/llama_service.dart';
import 'settings_provider.dart';
export '../../data/datasources/llama_service.dart' show TokenCount;

final llamaServiceProvider = Provider<LlamaService>((ref) {
  final service = LlamaService();
  
  ref.listen(settingsProvider, (previous, next) {
    final settings = next.valueOrNull;
    if (settings != null) {
      if (previous?.valueOrNull == null || previous?.valueOrNull?.systemPrompt != settings.systemPrompt) {
        service.setSystemPrompt(settings.systemPrompt);
      }
      if (previous?.valueOrNull == null || previous?.valueOrNull?.chatTemplate != settings.chatTemplate) {
        service.setChatTemplate(settings.chatTemplate);
      }
    }
  });
  
  ref.onDispose(() => service.dispose());
  return service;
});

final tokenStreamProvider = StreamProvider<TokenCount>((ref) {
  final service = ref.watch(llamaServiceProvider);
  return service.tokenStream;
});

final modelStateProvider = StateNotifierProvider<ModelStateNotifier, ModelState>((ref) {
  final service = ref.watch(llamaServiceProvider);
  return ModelStateNotifier(service);
});

class ModelStateNotifier extends StateNotifier<ModelState> {
  final LlamaService _service;
  StreamSubscription? _subscription;

  ModelStateNotifier(this._service) : super(const ModelState()) {
    _subscription = _service.stateStream.listen((newState) {
      state = newState;
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final initializeModelProvider = Provider<Future<void> Function()>((ref) {
  final service = ref.watch(llamaServiceProvider);
  final settings = ref.watch(settingsProvider);
  
  return () async {
    final s = settings.valueOrNull;
    debugPrint('Initializing model');
    if (s == null || s.modelPath.isEmpty) {
      debugPrint('No model path set');
      return;
    }
    
    await service.initialize(
      modelPath: s.modelPath,
      mmprojPath: s.mmprojPath.isNotEmpty ? s.mmprojPath : null,
      contextWindow: s.contextWindow,
      systemPrompt: s.systemPrompt,
    );
  };
});

final autoLoadModelProvider = StateNotifierProvider<AutoLoadModelNotifier, void>((ref) {
  return AutoLoadModelNotifier(ref);
});

class AutoLoadModelNotifier extends StateNotifier<void> {
  final Ref _ref;
  String? _lastModelPath;

  AutoLoadModelNotifier(this._ref) : super(null) {
    _ref.listen<AsyncValue<AppSettings>>(settingsProvider, (previous, next) {
      next.whenData((settings) {
        if (_lastModelPath != null && _lastModelPath != settings.modelPath) {
          Future.microtask(() {
            final init = _ref.read(initializeModelProvider);
            init();
          });
        }
        _lastModelPath = settings.modelPath;
      });
    });
  }
}
