import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/history_provider.dart';
import '../providers/model_provider.dart';
import '../providers/settings_provider.dart';
import '../../domain/entities/model_state.dart';
import '../../data/datasources/llama_service.dart';
import '../../data/datasources/document_service.dart';
import '../../data/datasources/document_generator.dart';
import '../widgets/status_indicator.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _documentService = DocumentService();
  final _documentGenerator = DocumentGenerator();
  bool _isGenerating = false;
  bool _isLoadingDocument = false;
  String _currentResponse = '';
  String? _lastConversationId;

  @override
  void initState() {
    super.initState();
    _lastConversationId = ref.read(historyProvider).currentConversationId;
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _pickDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'docx', 'txt'],
      );
      
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.path != null && file.path!.isNotEmpty) {
          setState(() => _isLoadingDocument = true);
          
          final text = await _documentService.extractText(file.path!);
          
          setState(() => _isLoadingDocument = false);
          
          if (mounted) {
            if (text.startsWith('Error:')) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(text)),
              );
            } else {
              final preview = text.length > 200 ? '${text.substring(0, 200)}...' : text;
              _showDocumentPreviewDialog(file.name, text, preview);
            }
          }
        }
      }
    } catch (e) {
      setState(() => _isLoadingDocument = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking document: $e')),
        );
      }
    }
  }

  void _showDocumentPreviewDialog(String fileName, String fullText, String preview) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(fileName),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Preview:',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    preview,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
            ],
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

  Future<void> _exportAsDocx(String content, String title) async {
    try {
      final suggestedName = title.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
      final result = await _documentGenerator.saveDocx(content, suggestedName.isEmpty ? 'document' : suggestedName);
      
      if (mounted) {
        if (result == 'Cancelled') {
          return;
        } else if (result.startsWith('Error')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result)),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Saved: $result')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting: $e')),
        );
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final modelState = ref.read(modelStateProvider);
    
    if (modelState.status != ModelStatus.ready) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Model not loaded. Go to Settings.')),
        );
      }
      return;
    }

    final historyState = ref.read(historyProvider);
    final conversationId = historyState.currentConversationId;
    if (conversationId == null) return;

    _controller.clear();
    setState(() => _isGenerating = true);
    _currentResponse = '';

    ref.read(historyProvider.notifier).addMessageToConversation(conversationId, 'user', text);

    final llamaService = ref.read(llamaServiceProvider);
    final settings = ref.read(settingsProvider).valueOrNull;
    final conv = historyState.currentConversation;
    final history = conv?.messages
        .map((m) => {'role': m.role, 'content': m.content})
        .toList() ?? [];

    try {
      await for (final chunk in llamaService.generateStream(
        text, 
        history: history,
        temperature: settings?.temperature,
        maxTokens: settings?.maxTokens,
        topP: settings?.topP,
        topK: settings?.topK,
        repeatPenalty: settings?.repeatPenalty,
        repeatLastN: settings?.repeatLastN,
      )) {
        if (mounted) {
          setState(() {
            _currentResponse += chunk;
          });
          _scrollToBottom();
        }
      }
      
      if (_currentResponse.isNotEmpty) {
        ref.read(historyProvider.notifier).addMessageToConversation(conversationId, 'assistant', _currentResponse);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _currentResponse = '';
        });
      }
    }
  }

  Future<void> _stopGeneration() async {
    final llamaService = ref.read(llamaServiceProvider);
    await llamaService.stop();
    if (_currentResponse.isNotEmpty && mounted) {
      final historyState = ref.read(historyProvider);
      final conversationId = historyState.currentConversationId;
      if (conversationId != null) {
        ref.read(historyProvider.notifier).addMessageToConversation(conversationId, 'assistant', _currentResponse);
      }
    }
    if (mounted) {
      setState(() {
        _isGenerating = false;
        _currentResponse = '';
      });
    }
  }

  Future<void> _continueMessage() async {
    final modelState = ref.read(modelStateProvider);
    final historyState = ref.read(historyProvider);
    final conv = historyState.currentConversation;
    final conversationId = historyState.currentConversationId;
    
    if (modelState.status != ModelStatus.ready) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Model not loaded.')),
        );
      }
      return;
    }

    if (conv == null || conv.messages.isEmpty || conversationId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No messages to continue.')),
        );
      }
      return;
    }

    final lastMessage = conv.messages.last;
    if (lastMessage.role != 'assistant') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Last message must be from assistant.')),
        );
      }
      return;
    }

    setState(() => _isGenerating = true);
    _currentResponse = '';

    final llamaService = ref.read(llamaServiceProvider);
    final settings = ref.read(settingsProvider).valueOrNull;
    final history = conv.messages
        .map((m) => {'role': m.role, 'content': m.content})
        .toList();

    try {
      await for (final chunk in llamaService.continueGeneration(
        history,
        temperature: settings?.temperature,
        maxTokens: settings?.maxTokens,
        topP: settings?.topP,
        topK: settings?.topK,
        repeatPenalty: settings?.repeatPenalty,
        repeatLastN: settings?.repeatLastN,
      )) {
        if (mounted) {
          setState(() {
            _currentResponse += chunk;
          });
          _scrollToBottom();
        }
      }
      
      if (_currentResponse.isNotEmpty) {
        ref.read(historyProvider.notifier).appendToLastMessage(_currentResponse);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _currentResponse = '';
        });
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showConversationDrawer() {
    _scaffoldKey.currentState?.openDrawer();
  }

  @override
  Widget build(BuildContext context) {
    final historyState = ref.watch(historyProvider);
    final modelState = ref.watch(modelStateProvider);
    final tokenData = ref.watch(tokenStreamProvider);
    final settings = ref.watch(settingsProvider).valueOrNull;
    final theme = Theme.of(context);

    final currentConvId = historyState.currentConversationId;
    if (_lastConversationId != null && currentConvId != null && _lastConversationId != currentConvId && !_isGenerating) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final llamaService = ref.read(llamaServiceProvider);
        await llamaService.resetContext();
        _lastConversationId = currentConvId;
      });
    }
    _lastConversationId = currentConvId;

    final messages = historyState.currentConversation?.messages ?? [];
    final allMessages = [...messages];
    if (_currentResponse.isNotEmpty) {
      allMessages.add(Message(
        id: 'temp',
        role: 'assistant',
        content: _currentResponse,
        timestamp: DateTime.now(),
      ));
    }

    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildConversationDrawer(context, historyState),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded),
          onPressed: _showConversationDrawer,
        ),
        title: Column(
          children: [
            Text(
              historyState.currentConversation?.title ?? 'Sancho.AI',
              style: theme.textTheme.titleMedium,
            ),
            CompactStatusIndicator(modelState: modelState),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: historyState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : allMessages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble_outline_rounded, size: 64, color: theme.colorScheme.outline),
                            const SizedBox(height: 16),
                            Text(
                              'Start a conversation',
                              style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.outline),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Configure your model in Settings first',
                              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                            ),
                          ],
                        ),
                      )
                    : ScrollConfiguration(
                        behavior: _GlowScrollBehavior(),
                        child: ListView.builder(
                          controller: _scrollController,
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          itemCount: allMessages.length,
                          itemBuilder: (context, index) {
                            final msg = allMessages[index];
                            final isLastAssistant = index == allMessages.length - 1 && msg.role == 'assistant';
                            return _MessageBubble(
                              message: msg,
                              isUser: msg.role == 'user',
                              onDelete: () => _showDeleteMessageDialog(msg),
                              onDeleteSubsequent: msg.role == 'user' 
                                  ? () => _showDeleteSubsequentDialog(msg)
                                  : null,
                              onCopy: () => _copyMessage(msg.content),
                              onContinue: isLastAssistant && !_isGenerating && modelState.status == ModelStatus.ready
                                  ? _continueMessage
                                  : null,
                            );
                          },
                        ),
                      ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    maxLines: 4,
                    minLines: 1,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  onPressed: _isGenerating ? _stopGeneration : _sendMessage,
                  backgroundColor: _isGenerating 
                      ? Theme.of(context).colorScheme.error 
                      : Theme.of(context).colorScheme.primaryContainer,
                  child: _isGenerating
                      ? const Icon(Icons.stop_rounded, color: Colors.white)
                      : const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationDrawer(BuildContext context, HistoryState historyState) {
    final theme = Theme.of(context);
    
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    'Chats',
                    style: theme.textTheme.titleLarge,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.add_rounded),
                    onPressed: () {
                      ref.read(historyProvider.notifier).createNewConversation();
                      Navigator.pop(context);
                    },
                    tooltip: 'New Chat',
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: historyState.conversations.length,
                itemBuilder: (context, index) {
                  final conv = historyState.conversations[index];
                  final isSelected = conv.id == historyState.currentConversationId;
                  
                  return ListTile(
                    selected: isSelected,
                    leading: Icon(
                      isSelected ? Icons.chat_rounded : Icons.chat_outlined,
                    ),
                    title: Text(
                      conv.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      conv.preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.colorScheme.outline,
                        fontSize: 12,
                      ),
                    ),
                    onTap: () {
                      ref.read(historyProvider.notifier).selectConversation(conv.id);
                      Navigator.pop(context);
                    },
                    trailing: PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, size: 20),
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'rename',
                          child: Row(
                            children: [
                              Icon(Icons.edit_rounded, size: 20),
                              SizedBox(width: 8),
                              Text('Rename'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline_rounded, size: 20),
                              SizedBox(width: 8),
                              Text('Delete'),
                            ],
                          ),
                        ),
                      ],
                      onSelected: (value) {
                        if (value == 'rename') {
                          _showRenameConversationDialog(conv);
                        } else if (value == 'delete') {
                          _showDeleteConversationDialog(conv);
                        }
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameConversationDialog(Conversation conv) {
    final controller = TextEditingController(text: conv.title);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Chat'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Chat name',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              ref.read(historyProvider.notifier).renameConversation(conv.id, value.trim());
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final newTitle = controller.text.trim();
              if (newTitle.isNotEmpty) {
                ref.read(historyProvider.notifier).renameConversation(conv.id, newTitle);
                Navigator.pop(context);
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConversationDialog(Conversation conv) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Chat'),
        content: Text('Delete "${conv.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(historyProvider.notifier).deleteConversation(conv.id);
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showDeleteMessageDialog(Message msg) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: const Text('Delete Message'),
              onTap: () {
                ref.read(historyProvider.notifier).deleteMessage(msg.id);
                Navigator.pop(context);
              },
            ),
            if (msg.role == 'user')
              ListTile(
                leading: const Icon(Icons.delete_sweep_rounded),
                title: const Text('Delete This and Subsequent'),
                subtitle: const Text('Deletes this and all following messages'),
                onTap: () {
                  ref.read(historyProvider.notifier).deleteMessageAndSubsequent(msg.id);
                  Navigator.pop(context);
                },
              ),
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: const Text('Copy Message'),
              onTap: () {
                _copyMessage(msg.content);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteSubsequentDialog(Message msg) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Messages'),
        content: const Text('Delete this message and all subsequent messages?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(historyProvider.notifier).deleteMessageAndSubsequent(msg.id);
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _copyMessage(String content) {
    Clipboard.setData(ClipboardData(text: content));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard')),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Message message;
  final bool isUser;
  final VoidCallback onDelete;
  final VoidCallback? onDeleteSubsequent;
  final VoidCallback onCopy;
  final VoidCallback? onContinue;

  const _MessageBubble({
    required this.message,
    required this.isUser,
    required this.onDelete,
    this.onDeleteSubsequent,
    required this.onCopy,
    this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onLongPress: () => _showContextMenu(context),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Align(
            alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isUser
                    ? theme.colorScheme.primary
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: isUser
                  ? Text(message.content, style: TextStyle(color: theme.colorScheme.onPrimary))
                  : MarkdownBody(
                      data: message.content,
                      styleSheet: MarkdownStyleSheet(
                        p: theme.textTheme.bodyMedium,
                        code: theme.textTheme.bodySmall?.copyWith(
                          backgroundColor: theme.colorScheme.surfaceContainerHighest,
                        ),
                      ),
                    ),
            ),
          ),
            if (!isUser && onContinue != null)
            Padding(
              padding: const EdgeInsets.only(left: 12, top: 4),
              child: TextButton.icon(
                onPressed: onContinue,
                icon: const Icon(Icons.forward_rounded, size: 16),
                label: const Text('Continue'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showContextMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: Text(isUser ? 'Delete Message' : 'Delete & Regenerate'),
              onTap: () {
                Navigator.pop(context);
                onDelete();
              },
            ),
            if (isUser && onDeleteSubsequent != null)
              ListTile(
                leading: const Icon(Icons.delete_sweep_rounded),
                title: const Text('Delete This and Subsequent'),
                subtitle: const Text('Deletes all following messages'),
                onTap: () {
                  Navigator.pop(context);
                  onDeleteSubsequent!();
                },
              ),
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: const Text('Copy'),
              onTap: () {
                Navigator.pop(context);
                onCopy();
              },
            ),
          ],
        ),
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
