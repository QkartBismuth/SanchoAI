import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Message {
  final String id;
  final String role;
  final String content;
  final DateTime timestamp;
  final String? imagePath;

  Message({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.imagePath,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'role': role,
    'content': content,
    'timestamp': timestamp.toIso8601String(),
    'imagePath': imagePath,
  };

  factory Message.fromJson(Map<String, dynamic> json) => Message(
    id: json['id'] ?? '',
    role: json['role'] ?? 'user',
    content: json['content'] ?? '',
    timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
    imagePath: json['imagePath'],
  );

  Message copyWith({
    String? id,
    String? role,
    String? content,
    DateTime? timestamp,
    String? imagePath,
  }) => Message(
    id: id ?? this.id,
    role: role ?? this.role,
    content: content ?? this.content,
    timestamp: timestamp ?? this.timestamp,
    imagePath: imagePath ?? this.imagePath,
  );
}

class Conversation {
  final String id;
  final String title;
  final List<Message> messages;
  final DateTime createdAt;
  final DateTime updatedAt;

  Conversation({
    required this.id,
    required this.title,
    required this.messages,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'messages': messages.map((m) => m.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
    id: json['id'] ?? '',
    title: json['title'] ?? 'New Chat',
    messages: (json['messages'] as List<dynamic>?)
        ?.map((m) => Message.fromJson(m))
        .toList() ?? [],
    createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
    updatedAt: DateTime.parse(json['updatedAt'] ?? DateTime.now().toIso8601String()),
  );

  Conversation copyWith({
    String? id,
    String? title,
    List<Message>? messages,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Conversation(
    id: id ?? this.id,
    title: title ?? this.title,
    messages: messages ?? this.messages,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  String get preview {
    if (messages.isEmpty) return 'Empty conversation';
    final lastMsg = messages.last;
    return lastMsg.content.length > 50 
        ? '${lastMsg.content.substring(0, 50)}...' 
        : lastMsg.content;
  }
}

abstract class HistoryStorage {
  Future<void> initialize();
  Future<List<Conversation>> loadConversations();
  Future<Conversation?> loadConversation(String id);
  Future<void> saveConversation(Conversation conversation);
  Future<void> deleteConversation(String id);
  Future<void> deleteAllConversations();
  Future<String?> getCurrentConversationId();
  Future<void> setCurrentConversationId(String id);
}

class SharedPrefsHistoryStorage implements HistoryStorage {
  static const String _conversationsKey = 'chat_history_conversations';
  static const String _currentConvKey = 'chat_history_current_id';
  static const String _storageVersionKey = 'chat_history_version';
  static const int _currentVersion = 2;

  final SharedPreferences _prefs;

  SharedPrefsHistoryStorage(this._prefs);

  @override
  Future<void> initialize() async {
    final version = _prefs.getInt(_storageVersionKey) ?? 1;
    if (version < _currentVersion) {
      await _migrateFromV1();
      await _prefs.setInt(_storageVersionKey, _currentVersion);
    }
  }

  Future<void> _migrateFromV1() async {
    final oldData = _prefs.getString('chat_conversations');
    if (oldData != null) {
      try {
        final List<dynamic> jsonList = jsonDecode(oldData);
        final conversations = jsonList.map((e) => _convertV1ToV2(e)).toList();
        await _prefs.setString(
          _conversationsKey,
          jsonEncode(conversations.map((c) => c.toJson()).toList()),
        );
      } catch (e) {
        // Migration failed, start fresh
      }
    }
  }

  Conversation _convertV1ToV2(Map<String, dynamic> json) {
    final messages = (json['messages'] as List<dynamic>?)
        ?.map((m) => Message(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          role: m['role'] ?? 'user',
          content: m['content'] ?? '',
          timestamp: DateTime.parse(m['timestamp'] ?? DateTime.now().toIso8601String()),
        ))
        .toList() ?? [];
    
    String title = 'Chat';
    if (messages.isNotEmpty) {
      final firstUserMsg = messages.firstWhere(
        (m) => m.role == 'user',
        orElse: () => messages.first,
      );
      title = firstUserMsg.content.length > 30
          ? '${firstUserMsg.content.substring(0, 30)}...'
          : firstUserMsg.content;
    }

    return Conversation(
      id: json['id'] ?? '',
      title: title,
      messages: messages,
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<List<Conversation>> loadConversations() async {
    final data = _prefs.getString(_conversationsKey);
    if (data == null) return [];

    try {
      final List<dynamic> jsonList = jsonDecode(data);
      final conversations = jsonList
          .map((e) => Conversation.fromJson(e))
          .toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return conversations;
    } catch (e) {
      return [];
    }
  }

  @override
  Future<Conversation?> loadConversation(String id) async {
    final conversations = await loadConversations();
    try {
      return conversations.firstWhere((c) => c.id == id);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> saveConversation(Conversation conversation) async {
    final conversations = await loadConversations();
    final index = conversations.indexWhere((c) => c.id == conversation.id);
    
    final updatedConv = conversation.copyWith(updatedAt: DateTime.now());
    
    if (index >= 0) {
      conversations[index] = updatedConv;
    } else {
      conversations.add(updatedConv);
    }

    await _prefs.setString(
      _conversationsKey,
      jsonEncode(conversations.map((c) => c.toJson()).toList()),
    );
  }

  @override
  Future<void> deleteConversation(String id) async {
    final conversations = await loadConversations();
    conversations.removeWhere((c) => c.id == id);
    
    await _prefs.setString(
      _conversationsKey,
      jsonEncode(conversations.map((c) => c.toJson()).toList()),
    );
  }

  @override
  Future<void> deleteAllConversations() async {
    await _prefs.remove(_conversationsKey);
    await _prefs.remove(_currentConvKey);
  }

  @override
  Future<String?> getCurrentConversationId() async {
    return _prefs.getString(_currentConvKey);
  }

  @override
  Future<void> setCurrentConversationId(String id) async {
    await _prefs.setString(_currentConvKey, id);
  }
}

final sharedPreferencesProvider = FutureProvider<SharedPreferences>((ref) {
  return SharedPreferences.getInstance();
});

final historyStorageProvider = FutureProvider<HistoryStorage>((ref) async {
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  final storage = SharedPrefsHistoryStorage(prefs);
  await storage.initialize();
  return storage;
});

class HistoryState {
  final List<Conversation> conversations;
  final String? currentConversationId;
  final bool isLoading;
  final String? error;

  const HistoryState({
    this.conversations = const [],
    this.currentConversationId,
    this.isLoading = false,
    this.error,
  });

  Conversation? get currentConversation {
    if (currentConversationId == null) return null;
    try {
      return conversations.firstWhere((c) => c.id == currentConversationId);
    } catch (e) {
      return null;
    }
  }

  HistoryState copyWith({
    List<Conversation>? conversations,
    String? currentConversationId,
    bool? isLoading,
    String? error,
    bool clearCurrentConversation = false,
  }) => HistoryState(
    conversations: conversations ?? this.conversations,
    currentConversationId: clearCurrentConversation ? null : (currentConversationId ?? this.currentConversationId),
    isLoading: isLoading ?? this.isLoading,
    error: error,
  );
}

final historyProvider = StateNotifierProvider<HistoryNotifier, HistoryState>((ref) {
  return HistoryNotifier(ref);
});

class HistoryNotifier extends StateNotifier<HistoryState> {
  final Ref _ref;
  HistoryStorage? _storage;

  HistoryNotifier(this._ref) : super(const HistoryState(isLoading: true)) {
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      _storage = await _ref.read(historyStorageProvider.future);
      await _loadConversations();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> _loadConversations() async {
    if (_storage == null) return;
    
    state = state.copyWith(isLoading: true);
    
    try {
      final convs = await _storage!.loadConversations();
      final currentId = await _storage!.getCurrentConversationId();
      
      if (convs.isEmpty) {
        final newConv = Conversation(
          id: _generateId(),
          title: 'New Chat',
          messages: [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await _storage!.saveConversation(newConv);
        await _storage!.setCurrentConversationId(newConv.id);
        
        state = HistoryState(
          conversations: [newConv],
          currentConversationId: newConv.id,
          isLoading: false,
        );
      } else {
        final validCurrentId = currentId ?? convs.first.id;
        if (convs.any((c) => c.id == validCurrentId)) {
          state = HistoryState(
            conversations: convs,
            currentConversationId: validCurrentId,
            isLoading: false,
          );
        } else {
          state = HistoryState(
            conversations: convs,
            currentConversationId: convs.first.id,
            isLoading: false,
          );
        }
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  String _generateId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';
  }

  Future<void> addMessage(String role, String content) async {
    final currentId = state.currentConversationId;
    if (_storage == null || currentId == null) return;
    await addMessageToConversation(currentId, role, content);
  }

  Future<void> addMessageToConversation(String conversationId, String role, String content, {String? imagePath}) async {
    if (_storage == null) return;

    final convIndex = state.conversations.indexWhere(
      (c) => c.id == conversationId,
    );
    if (convIndex < 0) return;

    final conv = state.conversations[convIndex];
    final newMessage = Message(
      id: _generateId(),
      role: role,
      content: content,
      timestamp: DateTime.now(),
      imagePath: imagePath,
    );

    String title = conv.title;
    if (conv.messages.isEmpty && role == 'user') {
      title = content.length > 30 ? '${content.substring(0, 30)}...' : content;
    }

    final updatedConv = conv.copyWith(
      title: title,
      messages: [...conv.messages, newMessage],
      updatedAt: DateTime.now(),
    );

    await _storage!.saveConversation(updatedConv);

    final updatedConvs = [...state.conversations];
    updatedConvs[convIndex] = updatedConv;
    updatedConvs.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    state = state.copyWith(conversations: updatedConvs);
  }

  Future<void> clearCurrentConversation() async {
    if (_storage == null || state.currentConversationId == null) return;

    final convIndex = state.conversations.indexWhere(
      (c) => c.id == state.currentConversationId,
    );
    if (convIndex < 0) return;

    final conv = state.conversations[convIndex];
    final updatedConv = conv.copyWith(
      title: 'New Chat',
      messages: [],
      updatedAt: DateTime.now(),
    );

    await _storage!.saveConversation(updatedConv);

    final updatedConvs = [...state.conversations];
    updatedConvs[convIndex] = updatedConv;

    state = state.copyWith(conversations: updatedConvs);
  }

  Future<void> createNewConversation() async {
    if (_storage == null) return;

    final newConv = Conversation(
      id: _generateId(),
      title: 'New Chat',
      messages: [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _storage!.saveConversation(newConv);
    await _storage!.setCurrentConversationId(newConv.id);

    state = state.copyWith(
      conversations: [newConv, ...state.conversations],
      currentConversationId: newConv.id,
    );
  }

  Future<void> selectConversation(String id) async {
    if (_storage == null) return;
    if (!state.conversations.any((c) => c.id == id)) return;

    await _storage!.setCurrentConversationId(id);
    state = state.copyWith(currentConversationId: id);
  }

  Future<void> deleteConversation(String id) async {
    if (_storage == null) return;

    await _storage!.deleteConversation(id);

    final updatedConvs = state.conversations.where((c) => c.id != id).toList();
    
    String? newCurrentId = state.currentConversationId;
    if (state.currentConversationId == id) {
      newCurrentId = updatedConvs.isNotEmpty ? updatedConvs.first.id : null;
      if (newCurrentId != null) {
        await _storage!.setCurrentConversationId(newCurrentId);
      }
    }

    if (updatedConvs.isEmpty) {
      final newConv = Conversation(
        id: _generateId(),
        title: 'New Chat',
        messages: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _storage!.saveConversation(newConv);
      await _storage!.setCurrentConversationId(newConv.id);
      
      state = HistoryState(
        conversations: [newConv],
        currentConversationId: newConv.id,
        isLoading: false,
      );
    } else {
      state = HistoryState(
        conversations: updatedConvs,
        currentConversationId: newCurrentId,
        isLoading: false,
      );
    }
  }

  Future<void> deleteAll() async {
    if (_storage == null) return;

    await _storage!.deleteAllConversations();

    final newConv = Conversation(
      id: _generateId(),
      title: 'New Chat',
      messages: [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _storage!.saveConversation(newConv);
    await _storage!.setCurrentConversationId(newConv.id);

    state = HistoryState(
      conversations: [newConv],
      currentConversationId: newConv.id,
      isLoading: false,
    );
  }

  Future<void> renameConversation(String id, String newTitle) async {
    if (_storage == null) return;

    final convIndex = state.conversations.indexWhere((c) => c.id == id);
    if (convIndex < 0) return;

    final conv = state.conversations[convIndex];
    final updatedConv = conv.copyWith(
      title: newTitle,
      updatedAt: DateTime.now(),
    );

    await _storage!.saveConversation(updatedConv);

    final updatedConvs = [...state.conversations];
    updatedConvs[convIndex] = updatedConv;

    state = state.copyWith(conversations: updatedConvs);
  }

  Future<void> deleteMessage(String messageId) async {
    if (_storage == null || state.currentConversationId == null) return;

    final convIndex = state.conversations.indexWhere(
      (c) => c.id == state.currentConversationId,
    );
    if (convIndex < 0) return;

    final conv = state.conversations[convIndex];
    final msgIndex = conv.messages.indexWhere((m) => m.id == messageId);
    if (msgIndex < 0) return;

    final updatedMessages = [...conv.messages];
    updatedMessages.removeAt(msgIndex);

    final updatedConv = conv.copyWith(
      messages: updatedMessages,
      updatedAt: DateTime.now(),
    );

    await _storage!.saveConversation(updatedConv);

    final updatedConvs = [...state.conversations];
    updatedConvs[convIndex] = updatedConv;

    state = state.copyWith(conversations: updatedConvs);
  }

  Future<void> deleteMessageAndSubsequent(String messageId) async {
    if (_storage == null || state.currentConversationId == null) return;

    final convIndex = state.conversations.indexWhere(
      (c) => c.id == state.currentConversationId,
    );
    if (convIndex < 0) return;

    final conv = state.conversations[convIndex];
    final msgIndex = conv.messages.indexWhere((m) => m.id == messageId);
    if (msgIndex < 0) return;

    final updatedMessages = conv.messages.sublist(0, msgIndex);

    final updatedConv = conv.copyWith(
      messages: updatedMessages,
      updatedAt: DateTime.now(),
    );

    await _storage!.saveConversation(updatedConv);

    final updatedConvs = [...state.conversations];
    updatedConvs[convIndex] = updatedConv;

    state = state.copyWith(conversations: updatedConvs);
  }

  Future<void> appendToLastMessage(String additionalContent) async {
    if (_storage == null || state.currentConversationId == null) return;
    if (additionalContent.isEmpty) return;

    final convIndex = state.conversations.indexWhere(
      (c) => c.id == state.currentConversationId,
    );
    if (convIndex < 0) return;

    final conv = state.conversations[convIndex];
    if (conv.messages.isEmpty) return;

    final lastMessage = conv.messages.last;
    final updatedMessage = lastMessage.copyWith(
      content: lastMessage.content + additionalContent,
    );

    final updatedMessages = [...conv.messages];
    updatedMessages[updatedMessages.length - 1] = updatedMessage;

    final updatedConv = conv.copyWith(
      messages: updatedMessages,
      updatedAt: DateTime.now(),
    );

    await _storage!.saveConversation(updatedConv);

    final updatedConvs = [...state.conversations];
    updatedConvs[convIndex] = updatedConv;

    state = state.copyWith(conversations: updatedConvs);
  }
}
