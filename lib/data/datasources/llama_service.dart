import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:llama_flutter_android/llama_flutter_android.dart';
import '../../domain/entities/model_state.dart';

class TokenCount {
  final int promptTokens;
  final int completionTokens;
  final int totalTokens;

  const TokenCount({
    this.promptTokens = 0,
    this.completionTokens = 0,
    this.totalTokens = 0,
  });
}

class LlamaService {
  LlamaController? _controller;
  String _systemPrompt = 'You are a helpful AI assistant.';
  String _chatTemplate = 'none';
  
  ModelState _state = const ModelState();
  final _stateController = StreamController<ModelState>.broadcast();
  final _tokenController = StreamController<TokenCount>.broadcast();
  
  Stream<ModelState> get stateStream => _stateController.stream;
  Stream<TokenCount> get tokenStream => _tokenController.stream;
  ModelState get currentState => _state;

  void setSystemPrompt(String prompt) {
    _systemPrompt = prompt;
  }

  void setChatTemplate(String template) {
    _chatTemplate = template;
  }

  void _updateState(ModelState newState) {
    _state = newState;
    _stateController.add(newState);
  }

  Future<void> initialize({
    required String modelPath,
    String? mmprojPath,
    int contextWindow = 2048,
    int nThreads = 4,
    String systemPrompt = 'You are a helpful AI assistant.',
  }) async {
    debugPrint('LlamaService: Starting initialization...');
    debugPrint('Model file selected');
    _systemPrompt = systemPrompt;
    _updateState(const ModelState(status: ModelStatus.loading));
    
    try {
      final modelFile = File(modelPath);
      if (!await modelFile.exists()) {
        debugPrint('Model file not found!');
        _updateState(ModelState(
          status: ModelStatus.error,
          errorMessage: 'Model file not found',
        ));
        return;
      }
      
      debugPrint('Model file exists, creating controller...');
      _controller = LlamaController();
      
      bool hasMmproj = mmprojPath != null && mmprojPath.isNotEmpty;
      
      if (hasMmproj) {
        final mmprojFile = File(mmprojPath);
        if (!await mmprojFile.exists()) {
          debugPrint('Warning: mmproj file not found, disabling multimodal');
          hasMmproj = false;
        }
      }
      
      debugPrint('Loading model with $nThreads threads, context: $contextWindow');
      await _controller!.loadModel(
        modelPath: modelPath,
        threads: nThreads,
        contextSize: contextWindow,
      );
      
      debugPrint('Model loaded successfully');
      _updateState(ModelState(
        status: ModelStatus.ready,
        hasMultimodal: hasMmproj,
      ));
    } catch (e) {
      debugPrint('Error loading model: $e');
      _updateState(ModelState(
        status: ModelStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  String _buildPrompt(String message, List<Map<String, String>>? history) {
    if (_chatTemplate == 'none') {
      return _buildUniversalPrompt(message, history);
    }
    
    final buffer = StringBuffer();
    
    buffer.writeln('<|im_start|>system');
    buffer.writeln(_systemPrompt);
    buffer.writeln('<|im_end|>');
    
    if (history != null) {
      for (final msg in history) {
        final role = msg['role'] ?? 'user';
        final content = msg['content'] ?? '';
        if (content.isNotEmpty) {
          if (role == 'user') {
            buffer.writeln('<|im_start|>user');
            buffer.writeln(content);
            buffer.writeln('<|im_end|>');
          } else if (role == 'assistant') {
            buffer.writeln('<|im_start|>assistant');
            buffer.writeln(content);
            buffer.writeln('<|im_end|>');
          }
        }
      }
    }
    
    buffer.writeln('<|im_start|>user');
    buffer.writeln(message);
    buffer.writeln('<|im_end|>');
    buffer.write('<|im_start|>assistant');
    
    return buffer.toString();
  }

  String _buildUniversalPrompt(String message, List<Map<String, String>>? history) {
    final buffer = StringBuffer();
    
    buffer.writeln('System: $_systemPrompt');
    buffer.writeln();
    
    if (history != null) {
      for (final msg in history) {
        final role = msg['role'] ?? 'user';
        final content = msg['content'] ?? '';
        if (content.isNotEmpty) {
          if (role == 'user') {
            buffer.writeln('User: $content');
          } else if (role == 'assistant') {
            buffer.writeln('Assistant: $content');
          }
        }
      }
    }
    
    buffer.write('User: $message\nAssistant:');
    
    return buffer.toString();
  }

  String buildContinuePrompt(List<Map<String, String>>? history) {
    if (history == null || history.isEmpty) {
      return '';
    }
    
    if (_chatTemplate == 'none') {
      return _buildUniversalContinuePrompt(history);
    }
    
    final buffer = StringBuffer();
    
    buffer.writeln('<|im_start|>system');
    buffer.writeln(_systemPrompt);
    buffer.writeln('<|im_end|>');
    
    for (final msg in history) {
      final role = msg['role'] ?? 'user';
      final content = msg['content'] ?? '';
      if (content.isNotEmpty) {
        if (role == 'user') {
          buffer.writeln('<|im_start|>user');
          buffer.writeln(content);
          buffer.writeln('<|im_end|>');
        } else if (role == 'assistant') {
          buffer.writeln('<|im_start|>assistant');
          buffer.writeln(content);
          buffer.writeln('<|im_end|>');
        }
      }
    }
    
    buffer.write('<|im_start|>assistant');
    return buffer.toString();
  }

  String _buildUniversalContinuePrompt(List<Map<String, String>> history) {
    final buffer = StringBuffer();
    
    buffer.writeln('System: $_systemPrompt');
    buffer.writeln();
    
    for (final msg in history) {
      final role = msg['role'] ?? 'user';
      final content = msg['content'] ?? '';
      if (content.isNotEmpty) {
        if (role == 'user') {
          buffer.writeln('User: $content');
        } else if (role == 'assistant') {
          buffer.writeln('Assistant: $content');
        }
      }
    }
    
    buffer.write('Assistant:');
    return buffer.toString();
  }

  Future<String> generate(String message, {List<Map<String, String>>? history, double? temperature, int? maxTokens, double? topP, int? topK, double? repeatPenalty, int? repeatLastN}) async {
    if (_controller == null) {
      return 'Error: Model not loaded';
    }
    
    _updateState(_state.copyWith(status: ModelStatus.generating));
    
    try {
      final prompt = _buildPrompt(message, history);
      
      String result = '';
      
      final promptTokens = _estimateTokens(prompt);
      _updateTokenCount(promptTokens: promptTokens, completionTokens: 0);
      
      String completion = '';
      await for (final token in _controller!.generate(
        prompt: prompt,
        temperature: temperature ?? 0.5,
        topP: topP ?? 0.8,
        topK: topK ?? 40,
        maxTokens: maxTokens ?? 256,
        repeatPenalty: repeatPenalty ?? 1.1,
        repeatLastN: repeatLastN ?? 64,
      )) {
        result += token;
        completion += token;
        final completionTokens = _estimateTokens(completion);
        _updateTokenCount(promptTokens: promptTokens, completionTokens: completionTokens);
      }
      
      _updateState(_state.copyWith(status: ModelStatus.ready));
      return result.trim();
    } catch (e) {
      _updateState(_state.copyWith(status: ModelStatus.ready));
      return 'Error: $e';
    }
  }

  Stream<String> generateStream(String message, {List<Map<String, String>>? history, double? temperature, int? maxTokens, double? topP, int? topK, double? repeatPenalty, int? repeatLastN}) async* {
    if (_controller == null) {
      yield 'Error: Model not loaded';
      return;
    }
    
    _updateState(_state.copyWith(status: ModelStatus.generating));
    
    try {
      final prompt = _buildPrompt(message, history);
      final promptTokens = _estimateTokens(prompt);
      _updateTokenCount(promptTokens: promptTokens, completionTokens: 0);
      
      String completion = '';
      await for (final token in _controller!.generate(
        prompt: prompt,
        temperature: temperature ?? 0.5,
        topP: topP ?? 0.8,
        topK: topK ?? 40,
        maxTokens: maxTokens ?? 256,
        repeatPenalty: repeatPenalty ?? 1.1,
        repeatLastN: repeatLastN ?? 64,
      )) {
        yield token;
        completion += token;
        final completionTokens = _estimateTokens(completion);
        _updateTokenCount(promptTokens: promptTokens, completionTokens: completionTokens);
      }
    } finally {
      _updateState(_state.copyWith(status: ModelStatus.ready));
    }
  }

  Stream<String> continueGeneration(List<Map<String, String>>? history, {double? temperature, int? maxTokens, double? topP, int? topK, double? repeatPenalty, int? repeatLastN}) async* {
    if (_controller == null) {
      yield 'Error: Model not loaded';
      return;
    }
    
    _updateState(_state.copyWith(status: ModelStatus.generating));
    
    try {
      final prompt = buildContinuePrompt(history);
      if (prompt.isEmpty) {
        yield 'No conversation history';
        return;
      }
      
      final promptTokens = _estimateTokens(prompt);
      _updateTokenCount(promptTokens: promptTokens, completionTokens: 0);
      
      String completion = '';
      await for (final token in _controller!.generate(
        prompt: prompt,
        temperature: temperature ?? 0.5,
        topP: topP ?? 0.8,
        topK: topK ?? 40,
        maxTokens: maxTokens ?? 256,
        repeatPenalty: repeatPenalty ?? 1.1,
        repeatLastN: repeatLastN ?? 64,
      )) {
        yield token;
        completion += token;
        final completionTokens = _estimateTokens(completion);
        _updateTokenCount(promptTokens: promptTokens, completionTokens: completionTokens);
      }
    } finally {
      _updateState(_state.copyWith(status: ModelStatus.ready));
    }
  }

  Future<void> unload() async {
    try {
      await _controller?.dispose();
      _controller = null;
      _updateState(const ModelState(status: ModelStatus.idle));
    } catch (_) {}
  }

  Future<void> resetContext() async {
    await stop();
    _updateTokenCount(promptTokens: 0, completionTokens: 0);
  }

  Future<void> stop() async {
    try {
      await _controller?.stop();
      _updateState(_state.copyWith(status: ModelStatus.ready));
    } catch (_) {}
  }

  void dispose() {
    _stateController.close();
    _tokenController.close();
    _controller?.dispose();
  }

  int _estimateTokens(String text) {
    if (text.isEmpty) return 0;
    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    return (words / 0.75).ceil();
  }

  void _updateTokenCount({int promptTokens = 0, int completionTokens = 0}) {
    final total = promptTokens + completionTokens;
    _tokenController.add(TokenCount(
      promptTokens: promptTokens,
      completionTokens: completionTokens,
      totalTokens: total,
    ));
    _updateState(_state.copyWith(
      promptTokens: promptTokens,
      completionTokens: completionTokens,
      totalTokens: total,
    ));
  }
}
