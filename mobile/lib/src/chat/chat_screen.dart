import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:scalex_chat/src/profile/summary_screen.dart';
import '../auth/auth_repo.dart';
import 'chat_repo.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:isolate';
import 'dart:typed_data';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _text = TextEditingController();
  final _repo = ChatRepo();
  final _msgs = <Map<String, String>>[]; // {role, content}
  List<String> _models = [];
  String? _currentModel;
  bool _busy = false;
  final ScrollController _scrollController = ScrollController();
  int? _conversationId;
  List<Map<String, dynamic>> _conversations = [];
  late stt.SpeechToText _stt;
  bool _sttReady = false; // never nullable
  bool _listening = false; // never nullable

  @override
  void initState() {
    super.initState();
    _loadModels();
    _loadConversations();
    _initSTT();
    _text.addListener(_onTextChanged);
  }

  Future<void> _exportToPdf() async {
    bool isGenerating = true;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Generating PDF...'),
          ],
        ),
      ),
    );

    try {
      // Small delay to show loading
      await Future.delayed(Duration(milliseconds: 100));

      final pdf = pw.Document();
      final title =
          _conversations.firstWhere(
                (c) => c['id'] == _conversationId,
                orElse: () => {'title': 'Chat'},
              )['title']
              as String? ??
          'Chat';

      // Simple PDF content
      pdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Padding(
              padding: const pw.EdgeInsets.all(20),
              child: pw.Column(
                children: [
                  pw.Text(
                    title,
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 20),
                  ..._msgs.map((msg) {
                    return pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 4),
                      child: pw.Text(
                        '${msg['role'] == 'user' ? 'You' : 'AI'}: ${msg['content']}',
                      ),
                    );
                  }).toList(),
                ],
              ),
            );
          },
        ),
      );

      // Close loading dialog
      Navigator.of(context).pop();

      // Share PDF
      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: 'chat-${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    } catch (e) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  Future<void> _initSTT() async {
    _stt = stt.SpeechToText();
    final available = await _stt.initialize(
      onStatus: (s) => setState(() => _listening = (s == 'listening')),
      onError: (e) {
        setState(() => _listening = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Speech error: ${e.errorMsg}')));
      },
    );
    if (!mounted) return;
    setState(() => _sttReady = available == true); // force non-null bool
  }

  Future<void> _toggleListening() async {
    if (!_sttReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Speech recognition not available')),
      );
      return;
    }

    if (_listening || _stt.isListening) {
      await _stt.stop();
      if (!mounted) return;
      setState(() => _listening = false);
      return;
    }

    final lang = context.locale.languageCode;
    final localeId = (lang == 'ar') ? 'ar' : 'en_US';

    final started = await _stt.listen(
      localeId: localeId,
      onResult: (res) {
        if (!mounted) return;
        _text.text = res.recognizedWords;
        _text.selection = TextSelection.fromPosition(
          TextPosition(offset: _text.text.length),
        );
        // if (res.finalResult) _send(); // optional auto-send
        setState(() {}); // reflect text change
      },
      listenMode: stt.ListenMode.confirmation,
      partialResults: true,
    );

    if (!mounted) return;
    setState(() => _listening = started == true); // guard null
  }

  @override
  void dispose() {
    _text.removeListener(_onTextChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {}); // Rebuild to update send button state
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _loadConversations() async {
    final items = await _repo.listConversations();
    setState(() => _conversations = items);
  }

  Future<void> _loadModels() async {
    try {
      final m = await _repo.models();
      setState(() {
        _models = m;
        _currentModel ??= m.isNotEmpty ? m.first : null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading models: $e'),
          backgroundColor: const Color(0xFFe74c3c),
        ),
      );
    }
  }

  Future<void> _send() async {
    final text = _text.text.trim();
    if (text.isEmpty || _currentModel == null) return;
    setState(() {
      _msgs.add({'role': 'user', 'content': text});
      _busy = true;
      _text.clear();
    });
    _scrollToBottom();
    try {
      final resp = await _repo.send(
        model: _currentModel!,
        message: text,
        lang: context.locale.languageCode,
        conversationId: _conversationId,
      );
      final reply = resp['reply'] as String? ?? '';
      final newConvId = resp['conversationId'] as int?;
      if (newConvId != null && _conversationId == null) {
        _conversationId = newConvId;
        // refresh sidebar titles order
        _loadConversations();
      }
      setState(() => _msgs.add({'role': 'assistant', 'content': reply}));
      _scrollToBottom();
    } catch (e) {
      setState(() => _msgs.add({'role': 'assistant', 'content': 'Error: $e'}));
      _scrollToBottom();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _logout() async {
    await AuthRepo().logout();
    if (!mounted) return;
    Navigator.of(context).pop(); // back to login
  }

  Widget _buildMessageBubble(Map<String, String> msg, bool isUser) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!isUser)
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF32a94d),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.smart_toy_outlined,
                color: Colors.white,
                size: 18,
              ),
            ),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isUser
                    ? const Color(0xFF32a94d)
                    : const Color(0xFFf8f9fa),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: isUser
                      ? const Radius.circular(20)
                      : const Radius.circular(4),
                  bottomRight: isUser
                      ? const Radius.circular(4)
                      : const Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                msg['content'] ?? '',
                style: TextStyle(
                  color: isUser ? Colors.white : const Color(0xFF2c2c2c),
                  fontSize: 16,
                  height: 1.4,
                ),
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
          if (isUser)
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF2c2c2c),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.person, color: Colors.white, size: 18),
            ),
        ],
      ),
    );
  }

  bool get _canSend {
    return !_busy && _text.text.trim().isNotEmpty && _currentModel != null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              // Header with company branding
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color(0xFF32a94d),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.chat_bubble_outline,
                        color: Color(0xFF32a94d),
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Conversations',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_conversations.length} chats',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              // New Chat Button
              Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF32a94d),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF32a94d).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ListTile(
                  leading: const Icon(Icons.add, color: Colors.white),
                  title: Text(
                    'New Chat',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: () async {
                    final conv = await _repo.createConversation();
                    setState(() {
                      _conversationId = conv['id'] as int;
                      _msgs.clear();
                    });
                    _loadConversations();
                    Navigator.pop(context);
                  },
                ),
              ),

              const Divider(height: 1, color: Color(0xFFe0e0e0)),

              // Conversations List
              Expanded(
                child: _conversations.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: const Color(0xFFf8f9fa),
                                borderRadius: BorderRadius.circular(40),
                              ),
                              child: Icon(
                                Icons.forum_outlined,
                                color: const Color(0xFF32a94d),
                                size: 40,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No conversations yet',
                              style: TextStyle(
                                color: const Color(0xFF2c2c2c),
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Start a new chat to begin',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _conversations.length,
                        itemBuilder: (_, i) {
                          final c = _conversations[i];
                          final id = c['id'] as int;
                          final title = (c['title'] as String?) ?? 'New chat';
                          final selected = id == _conversationId;

                          return Container(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? const Color(0xFF32a94d).withOpacity(0.1)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ListTile(
                              selected: selected,
                              leading: Icon(
                                Icons.forum_outlined,
                                color: selected
                                    ? const Color(0xFF32a94d)
                                    : const Color(0xFF666666),
                              ),
                              title: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: selected
                                      ? const Color(0xFF32a94d)
                                      : const Color(0xFF2c2c2c),
                                  fontWeight: selected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                              onTap: () async {
                                final msgs = await _repo.loadMessages(id);
                                setState(() {
                                  _conversationId = id;
                                  _msgs
                                    ..clear()
                                    ..addAll(
                                      msgs.map(
                                        (m) => {
                                          'role':
                                              (m['role'] as String?) ??
                                              'assistant',
                                          'content':
                                              (m['content'] as String?) ?? '',
                                        },
                                      ),
                                    );
                                });
                                Navigator.pop(context);
                                _scrollToBottom();
                              },
                              trailing: IconButton(
                                icon: Icon(
                                  Icons.more_vert,
                                  color: selected
                                      ? const Color(0xFF32a94d)
                                      : const Color(0xFF666666),
                                  size: 20,
                                ),
                                onPressed: () async {
                                  final controller = TextEditingController(
                                    text: title,
                                  );
                                  final newTitle = await showDialog<String>(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      title: const Text('Rename chat'),
                                      content: TextField(
                                        controller: controller,
                                        autofocus: true,
                                        decoration: InputDecoration(
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () => Navigator.pop(
                                            context,
                                            controller.text.trim(),
                                          ),
                                          child: const Text(
                                            'Save',
                                            style: TextStyle(
                                              color: Color(0xFF32a94d),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (newTitle != null && newTitle.isNotEmpty) {
                                    await _repo.renameConversation(
                                      id,
                                      newTitle,
                                    );
                                    _loadConversations();
                                  }
                                },
                              ),
                            ),
                          );
                        },
                      ),
              ),

              const Divider(height: 1, color: Color(0xFFe0e0e0)),

              // Delete Button
              Container(
                margin: const EdgeInsets.all(8),
                child: ListTile(
                  leading: Icon(
                    Icons.delete_outline,
                    color: _conversationId == null
                        ? Colors.grey
                        : const Color(0xFFe74c3c),
                  ),
                  title: Text(
                    'Delete selected',
                    style: TextStyle(
                      color: _conversationId == null
                          ? Colors.grey
                          : const Color(0xFFe74c3c),
                    ),
                  ),
                  onTap: _conversationId == null
                      ? null
                      : () async {
                          await _repo.deleteConversation(_conversationId!);
                          setState(() {
                            _conversationId = null;
                            _msgs.clear();
                          });
                          _loadConversations();
                          Navigator.pop(context);
                        },
                ),
              ),
            ],
          ),
        ),
      ),

      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        centerTitle: true,
        title: Text(
          'chat'.tr(),
          style: const TextStyle(
            color: Color(0xFF2c2c2c),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.asset(
            'assets/logo.png', // Make sure to add your logo asset
            width: 40,
            height: 40,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF32a94d),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.chat_bubble_outline,
                  color: Colors.white,
                  size: 20,
                ),
              );
            },
          ),
        ),
        actions: [
          // In AppBar actions, add this IconButton:
          IconButton(
            onPressed: _conversationId == null || _msgs.isEmpty
                ? null
                : _exportToPdf,
            icon: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: _conversationId == null || _msgs.isEmpty
                    ? Colors.grey[300]!
                    : const Color(0xFFf8f9fa),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.picture_as_pdf,
                color: _conversationId == null || _msgs.isEmpty
                    ? Colors.grey[500]!
                    : const Color(0xFFe74c3c),
                size: 22,
              ),
            ),
            tooltip: 'Export to PDF',
          ),
          if (_models.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFf8f9fa),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: DropdownButton<String>(
                value: _currentModel,
                underline: const SizedBox.shrink(),
                icon: const Icon(
                  Icons.arrow_drop_down,
                  color: Color(0xFF32a94d),
                ),
                items: _models
                    .map(
                      (m) => DropdownMenuItem(
                        value: m,
                        child: Text(
                          m,
                          style: const TextStyle(
                            color: Color(0xFF2c2c2c),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _currentModel = v),
              ),
            ),
          const SizedBox(width: 8),

          IconButton(
            onPressed: _conversationId == null
                ? null
                : () {
                    // Add this null check to be extra safe
                    if (_conversationId != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              SummaryScreen(conversationId: _conversationId!),
                        ),
                      );
                    }
                  },
            icon: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: _conversationId == null
                    ? Colors.grey[300]! // Grey out when disabled
                    : const Color(0xFFf8f9fa),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.summarize_outlined,
                color: _conversationId == null
                    ? Colors.grey[500]! // Grey icon when disabled
                    : const Color(0xFF32a94d),
                size: 22,
              ),
            ),
            tooltip: _conversationId == null
                ? 'Select a conversation first'
                : 'summary'.tr(),
          ),
          const SizedBox(width: 8),

          // 🔒 Logout Button
          IconButton(
            onPressed: _logout,
            icon: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFf8f9fa),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.logout,
                color: Color(0xFF2c2c2c),
                size: 20,
              ),
            ),
            tooltip: 'logout'.tr(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Messages List
          Expanded(
            child: _msgs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: const Color(0xFFf8f9fa),
                            borderRadius: BorderRadius.circular(40),
                          ),
                          child: const Icon(
                            Icons.chat_bubble_outline,
                            color: Color(0xFF32a94d),
                            size: 40,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'start_conversation'.tr(),
                          style: const TextStyle(
                            color: Color(0xFF2c2c2c),
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'type_message_below'.tr(),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(top: 8),
                    itemCount: _msgs.length,
                    itemBuilder: (_, i) {
                      final msg = _msgs[i];
                      final isUser = msg['role'] == 'user';
                      return _buildMessageBubble(msg, isUser);
                    },
                  ),
          ),

          // Typing Indicator
          if (_busy)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFF32a94d),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.smart_toy_outlined,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFf8f9fa),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFF32a94d),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'typing'.tr(),
                          style: const TextStyle(
                            color: Color(0xFF2c2c2c),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Input Area
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey[300]!)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFf8f9fa),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: TextField(
                        controller: _text,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          hintText: 'type_message'.tr(),
                          hintStyle: TextStyle(color: Colors.grey[500]),
                        ),
                        maxLines: null,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFFf8f9fa),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: IconButton(
                      tooltip: _listening ? 'stop'.tr() : 'tap_and_speak'.tr(),
                      onPressed: _toggleListening,
                      icon: Icon(
                        _listening ? Icons.mic : Icons.mic_none,
                        color: _listening
                            ? const Color(0xFF32a94d)
                            : const Color(0xFF2c2c2c),
                        size: 22,
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // ✉️ Send button
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: _canSend
                          ? const Color(0xFF32a94d)
                          : const Color(0xFF32a94d).withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: _canSend ? _send : null,
                      icon: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.send,
                              color: Colors.white,
                              size: 20,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
