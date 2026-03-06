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
    debugPrint('System prompt set to: $_systemPrompt');
  }

  void setChatTemplate(String template) {
    _chatTemplate = template;
    debugPrint('Chat template set to: $_chatTemplate');
  }

  String get systemPrompt => _systemPrompt;
  String get chatTemplate => _chatTemplate;

  static String detectTemplateFromFilename(String modelPath) {
    final filename = modelPath.toLowerCase();
    
    if (filename.contains('llama-3') || filename.contains('llama3') || 
        filename.contains('llama2') || filename.contains('llama-2')) {
      return 'llama2';
    }
    if (filename.contains('mistral') || filename.contains('mixtral')) {
      return 'chatml';
    }
    if (filename.contains('qwen')) {
      return 'chatml';
    }
    if (filename.contains('phi')) {
      return 'phi';
    }
    if (filename.contains('gemma')) {
      return 'gemma';
    }
    if (filename.contains('zephyr')) {
      return 'zephyr';
    }
    if (filename.contains('vicuna')) {
      return 'vicuna';
    }
    if (filename.contains('alpaca')) {
      return 'alpaca';
    }
    if (filename.contains('chatml')) {
      return 'chatml';
    }
    
    return 'none';
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
    final template = _chatTemplate.toLowerCase();
    
    if (template == 'none' || template.isEmpty) {
      return _buildUniversalPrompt(message, history);
    }
    
    switch (template) {
      case 'chatml':
        return _buildChatMLPrompt(message, history);
      case 'llama2':
      case 'llama-2':
        return _buildLlama2Prompt(message, history);
      case 'alpaca':
        return _buildAlpacaPrompt(message, history);
      case 'vicuna':
        return _buildVicunaPrompt(message, history);
      case 'phi':
        return _buildPhiPrompt(message, history);
      case 'gemma':
        return _buildGemmaPrompt(message, history);
      case 'zephyr':
        return _buildZephyrPrompt(message, history);
      default:
        return _buildUniversalPrompt(message, history);
    }
  }

  String _buildChatMLPrompt(String message, List<Map<String, String>>? history) {
    final buffer = StringBuffer();
    
    buffer.writeln('<|im_start|>system');
    buffer.writeln(_systemPrompt.trim());
    buffer.writeln('<|im_end|>');
    
    if (history != null) {
      for (final msg in history) {
        final role = msg['role'] ?? 'user';
        final content = msg['content'] ?? '';
        if (content.isNotEmpty) {
          buffer.writeln('<|im_start|>$role');
          buffer.writeln(content.trim());
          buffer.writeln('<|im_end|>');
        }
      }
    }
    
    buffer.writeln('<|im_start|>user');
    buffer.writeln(message.trim());
    buffer.writeln('<|im_end|>');
    buffer.write('<|im_start|>assistant\n');
    
    return buffer.toString();
  }

  String _buildLlama2Prompt(String message, List<Map<String, String>>? history) {
    final buffer = StringBuffer();
    
    buffer.writeln('[INST] <<SYS>>\n${_systemPrompt.trim()}\n<</SYS>>\n\n');
    
    if (history != null) {
      for (int i = 0; i < history.length; i++) {
        final msg = history[i];
        final role = msg['role'] ?? 'user';
        final content = msg['content'] ?? '';
        if (content.isNotEmpty) {
          if (role == 'user') {
            buffer.writeln(content.trim());
          } else if (role == 'assistant') {
            buffer.writeln('[/INST] ${content.trim()}</s><s>[INST] ');
          }
        }
      }
    }
    
    buffer.write('${message.trim()}[/INST]');
    
    return buffer.toString();
  }

  String _buildAlpacaPrompt(String message, List<Map<String, String>>? history) {
    final buffer = StringBuffer();
    
    buffer.writeln('### Instruction:\n${_systemPrompt.trim()}\n\n');
    
    if (history != null) {
      for (final msg in history) {
        final role = msg['role'] ?? 'user';
        final content = msg['content'] ?? '';
        if (content.isNotEmpty) {
          if (role == 'user') {
            buffer.writeln('### Input:\n$content\n\n### Response:\n');
          } else if (role == 'assistant') {
            buffer.writeln('$content\n');
          }
        }
      }
    }
    
    buffer.write('### Input:\n$message\n\n### Response:\n');
    
    return buffer.toString();
  }

  String _buildVicunaPrompt(String message, List<Map<String, String>>? history) {
    final buffer = StringBuffer();
    
    buffer.writeln('SYSTEM: ${_systemPrompt.trim()}\n');
    
    if (history != null) {
      for (final msg in history) {
        final role = msg['role'] ?? 'user';
        final content = msg['content'] ?? '';
        if (content.isNotEmpty) {
          if (role == 'user') {
            buffer.writeln('USER: $content');
          } else if (role == 'assistant') {
            buffer.writeln('ASSISTANT: $content');
          }
        }
      }
    }
    
    buffer.write('USER: $message\nASSISTANT:');
    
    return buffer.toString();
  }

  String _buildPhiPrompt(String message, List<Map<String, String>>? history) {
    final buffer = StringBuffer();
    
    buffer.writeln('<|system|>\n${_systemPrompt.trim()}<|end|>\n');
    
    if (history != null) {
      for (final msg in history) {
        final role = msg['role'] ?? 'user';
        final content = msg['content'] ?? '';
        if (content.isNotEmpty) {
          if (role == 'user') {
            buffer.writeln('<|user|>\n$content<|end|>\n');
          } else if (role == 'assistant') {
            buffer.writeln('<|assistant|>\n$content<|end|>\n');
          }
        }
      }
    }
    
    buffer.write('<|user|>\n$message<|end|>\n<|assistant|>\n');
    
    return buffer.toString();
  }

  String _buildGemmaPrompt(String message, List<Map<String, String>>? history) {
    final buffer = StringBuffer();
    
    buffer.writeln('<start_of_turn>model\n${_systemPrompt.trim()}<end_of_turn>\n');
    
    if (history != null) {
      for (final msg in history) {
        final role = msg['role'] ?? 'user';
        final content = msg['content'] ?? '';
        if (content.isNotEmpty) {
          if (role == 'user') {
            buffer.writeln('<start_of_turn>user\n$content<end_of_turn>\n');
          } else if (role == 'assistant') {
            buffer.writeln('<start_of_turn>model\n$content<end_of_turn>\n');
          }
        }
      }
    }
    
    buffer.write('<start_of_turn>user\n$message<end_of_turn>\n<start_of_turn>model\n');
    
    return buffer.toString();
  }

  String _buildZephyrPrompt(String message, List<Map<String, String>>? history) {
    final buffer = StringBuffer();
    
    buffer.writeln('<|system|>\n${_systemPrompt.trim()}<|endoftext|>');
    
    if (history != null) {
      for (final msg in history) {
        final role = msg['role'] ?? 'user';
        final content = msg['content'] ?? '';
        if (content.isNotEmpty) {
          if (role == 'user') {
            buffer.writeln('<|user|>\n$content<|endoftext|>');
          } else if (role == 'assistant') {
            buffer.writeln('<|assistant|>\n$content<|endoftext|>');
          }
        }
      }
    }
    
    buffer.write('<|user|>\n$message<|endoftext|>\n<|assistant|>\n');
    
    return buffer.toString();
  }

  String _buildUniversalPrompt(String message, List<Map<String, String>>? history) {
    final buffer = StringBuffer();
    
    buffer.writeln('System: ${_systemPrompt.trim()}');
    buffer.writeln();
    
    if (history != null) {
      for (final msg in history) {
        final role = msg['role'] ?? 'user';
        final content = msg['content'] ?? '';
        if (content.isNotEmpty) {
          if (role == 'user') {
            buffer.writeln('User: ${content.trim()}');
          } else if (role == 'assistant') {
            buffer.writeln('Assistant: ${content.trim()}');
          }
        }
      }
    }
    
    buffer.write('User: ${message.trim()}\nAssistant:');
    
    return buffer.toString();
  }

  String buildContinuePrompt(List<Map<String, String>>? history) {
    if (history == null || history.isEmpty) {
      return '';
    }
    
    final template = _chatTemplate.toLowerCase();
    
    if (template == 'none' || template.isEmpty) {
      return _buildUniversalContinuePrompt(history);
    }
    
    switch (template) {
      case 'chatml':
        return _buildChatMLContinuePrompt(history);
      case 'llama2':
      case 'llama-2':
        return _buildLlama2ContinuePrompt(history);
      case 'alpaca':
        return _buildAlpacaContinuePrompt(history);
      case 'vicuna':
        return _buildVicunaContinuePrompt(history);
      case 'phi':
        return _buildPhiContinuePrompt(history);
      case 'gemma':
        return _buildGemmaContinuePrompt(history);
      case 'zephyr':
        return _buildZephyrContinuePrompt(history);
      default:
        return _buildUniversalContinuePrompt(history);
    }
  }

  String _buildChatMLContinuePrompt(List<Map<String, String>> history) {
    final buffer = StringBuffer();
    
    buffer.writeln('<|im_start|>system');
    buffer.writeln(_systemPrompt.trim());
    buffer.writeln('<|im_end|>');
    
    for (final msg in history) {
      final role = msg['role'] ?? 'user';
      final content = msg['content'] ?? '';
      if (content.isNotEmpty) {
        buffer.writeln('<|im_start|>$role');
        buffer.writeln(content.trim());
        buffer.writeln('<|im_end|>');
      }
    }
    
    buffer.write('<|im_start|>assistant\n');
    return buffer.toString();
  }

  String _buildLlama2ContinuePrompt(List<Map<String, String>> history) {
    final buffer = StringBuffer();
    
    buffer.writeln('[INST] <<SYS>>\n${_systemPrompt.trim()}\n<</SYS>>\n\n');
    
    for (int i = 0; i < history.length; i++) {
      final msg = history[i];
      final role = msg['role'] ?? 'user';
      final content = msg['content'] ?? '';
      if (content.isNotEmpty) {
        if (role == 'user') {
          buffer.writeln(content.trim());
        } else if (role == 'assistant') {
          buffer.writeln('[/INST] ${content.trim()}</s><s>[INST] ');
        }
      }
    }
    
    buffer.write('[/INST]');
    return buffer.toString();
  }

  String _buildAlpacaContinuePrompt(List<Map<String, String>> history) {
    final buffer = StringBuffer();
    
    buffer.writeln('### Instruction:\n${_systemPrompt.trim()}\n\n');
    
    for (final msg in history) {
      final role = msg['role'] ?? 'user';
      final content = msg['content'] ?? '';
      if (content.isNotEmpty) {
        if (role == 'user') {
          buffer.writeln('### Input:\n$content\n\n### Response:\n');
        } else if (role == 'assistant') {
          buffer.writeln('$content\n');
        }
      }
    }
    
    return buffer.toString();
  }

  String _buildVicunaContinuePrompt(List<Map<String, String>> history) {
    final buffer = StringBuffer();
    
    buffer.writeln('SYSTEM: ${_systemPrompt.trim()}\n');
    
    for (final msg in history) {
      final role = msg['role'] ?? 'user';
      final content = msg['content'] ?? '';
      if (content.isNotEmpty) {
        if (role == 'user') {
          buffer.writeln('USER: $content');
        } else if (role == 'assistant') {
          buffer.writeln('ASSISTANT: $content');
        }
      }
    }
    
    buffer.write('ASSISTANT:');
    return buffer.toString();
  }

  String _buildPhiContinuePrompt(List<Map<String, String>> history) {
    final buffer = StringBuffer();
    
    buffer.writeln('<|system|>\n${_systemPrompt.trim()}<|end|>\n');
    
    for (final msg in history) {
      final role = msg['role'] ?? 'user';
      final content = msg['content'] ?? '';
      if (content.isNotEmpty) {
        if (role == 'user') {
          buffer.writeln('<|user|>\n$content<|end|>\n');
        } else if (role == 'assistant') {
          buffer.writeln('<|assistant|>\n$content<|end|>\n');
        }
      }
    }
    
    buffer.write('<|assistant|>\n');
    return buffer.toString();
  }

  String _buildGemmaContinuePrompt(List<Map<String, String>> history) {
    final buffer = StringBuffer();
    
    buffer.writeln('<start_of_turn>model\n${_systemPrompt.trim()}<end_of_turn>\n');
    
    for (final msg in history) {
      final role = msg['role'] ?? 'user';
      final content = msg['content'] ?? '';
      if (content.isNotEmpty) {
        if (role == 'user') {
          buffer.writeln('<start_of_turn>user\n$content<end_of_turn>\n');
        } else if (role == 'assistant') {
          buffer.writeln('<start_of_turn>model\n$content<end_of_turn>\n');
        }
      }
    }
    
    buffer.write('<start_of_turn>model\n');
    return buffer.toString();
  }

  String _buildZephyrContinuePrompt(List<Map<String, String>> history) {
    final buffer = StringBuffer();
    
    buffer.writeln('<|system|>\n${_systemPrompt.trim()}<|endoftext|>');
    
    for (final msg in history) {
      final role = msg['role'] ?? 'user';
      final content = msg['content'] ?? '';
      if (content.isNotEmpty) {
        if (role == 'user') {
          buffer.writeln('<|user|>\n$content<|endoftext|>');
        } else if (role == 'assistant') {
          buffer.writeln('<|assistant|>\n$content<|endoftext|>');
        }
      }
    }
    
    buffer.write('<|assistant|>\n');
    return buffer.toString();
  }

  String _buildUniversalContinuePrompt(List<Map<String, String>> history) {
    final buffer = StringBuffer();
    
    buffer.writeln('System: ${_systemPrompt.trim()}');
    buffer.writeln();
    
    for (final msg in history) {
      final role = msg['role'] ?? 'user';
      final content = msg['content'] ?? '';
      if (content.isNotEmpty) {
        if (role == 'user') {
          buffer.writeln('User: ${content.trim()}');
        } else if (role == 'assistant') {
          buffer.writeln('Assistant: ${content.trim()}');
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
