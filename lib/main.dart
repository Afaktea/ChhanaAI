import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

import 'chat_api_service.dart';

const Color _burgundy = Color(0xFF6D0019);
const Color _darkBurgundy = Color(0xFF4C0011);
const Color _cream = Color(0xFFF8F3ED);
const Color _sidebarColor = Color(0xFF2A2022);
const Color _panel = Color(0xFFFFFDFA);
const Color _blush = Color(0xFFF7EEEA);
const Color _ink = Color(0xFF261316);
const Color _mutedInk = Color(0xFF866F70);
const String _thinkingLogoAsset = 'assets/chhanai-logo-transparent.png';
const String _notesStorageKey = 'chhanai_saved_notes_v1';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ChhanaAI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Inter',
        colorScheme: ColorScheme.fromSeed(
          seedColor: _burgundy,
          surface: _panel,
        ),
        scaffoldBackgroundColor: _panel,
        appBarTheme: const AppBarTheme(
          backgroundColor: _panel,
          foregroundColor: _ink,
          elevation: 0,
          centerTitle: false,
        ),
      ),
      home: const ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatApiService _chatApi = ChatApiService();
  final List<_ChatMessage> _messages = [];
  final Set<_ChatMessage> _savedMessages = {};
  List<_SavedNote> _savedNotes = [];
  Map<String, dynamic>? _pendingWord;
  bool _isSending = false;
  bool _isDesktopDrawerOpen = false;
  int _conversationGeneration = 0;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _chatApi.close();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    final generation = _conversationGeneration;
    final conversation =
        [
              ..._messages.where((message) => !message.isError),
              _ChatMessage(text: text, isUser: true),
            ]
            .map(
              (message) => {
                'role': message.isUser ? 'user' : 'assistant',
                'content': message.text,
              },
            )
            .toList();

    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true));
      _isSending = true;
    });
    _messageController.clear();
    _scrollToLatest();

    try {
      final response = await _chatApi.sendMessage(
        messages: conversation,
        pendingWord: _pendingWord,
      );
      if (!mounted || generation != _conversationGeneration) return;

      setState(() {
        _messages.add(_ChatMessage(text: response.reply, isUser: false));
        _pendingWord = response.pendingWord;
      });
      _scrollToLatest();
    } on ChatApiException catch (error) {
      if (!mounted || generation != _conversationGeneration) return;
      setState(() {
        _messages.add(
          _ChatMessage(text: error.message, isUser: false, isError: true),
        );
      });
      _scrollToLatest();
    } catch (_) {
      if (!mounted || generation != _conversationGeneration) return;
      setState(() {
        _messages.add(
          const _ChatMessage(
            text: 'Something unexpected happened. Please try again.',
            isUser: false,
            isError: true,
          ),
        );
      });
      _scrollToLatest();
    } finally {
      if (mounted && generation == _conversationGeneration) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _openAttachmentMenu() async {
    final selection = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a picture'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file_outlined),
              title: const Text('Choose a file'),
              onTap: () => Navigator.pop(context, 'file'),
            ),
          ],
        ),
      ),
    );
    if (selection == null || !mounted) return;

    String? name;
    try {
      if (selection == 'camera' || selection == 'gallery') {
        final image = await ImagePicker().pickImage(
          source: selection == 'camera' ? ImageSource.camera : ImageSource.gallery,
        );
        name = image?.name;
      } else {
        final result = await FilePicker.platform.pickFiles();
        name = result?.files.single.name;
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the attachment picker.')),
      );
      return;
    }

    if (name == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Selected $name. Attachments are not sent to the current chat backend yet.',
        ),
      ),
    );
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    });
  }

  void _startNewChat() {
    setState(() {
      _conversationGeneration++;
      _messages.clear();
      _savedMessages.clear();
      _pendingWord = null;
      _isSending = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) _scrollController.jumpTo(0);
    });
  }

  Future<void> _startTest() async {
    if (_isSending) return;
    if (!_messages.any((message) => message.isUser)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ask ChhanAI about a topic first, then press Test.'),
        ),
      );
      return;
    }

    final quizPrompt = [
      'Start a short quiz based on the main topic discussed in this conversation.',
      'Use the conversation as the source for choosing the topic. Ask 5 questions, one at a time.',
      'Start by briefly naming the topic and asking Question 1 only. Do not reveal the answer or list all questions.',
      'Wait for my answer before asking the next question. After each answer, say whether it is correct, explain briefly, and then ask the next question.',
      'At the end, give my score out of 5 and a short encouraging summary.',
      'If the conversation does not contain enough educational content for a quiz, ask me what topic I want to be tested on.',
    ].join(' ');
    _messageController.text = quizPrompt;
    await _sendMessage();
  }

  Future<List<_SavedNote>> _readSavedNotes({
    SharedPreferencesAsync? preferences,
  }) async {
    final store = preferences ?? SharedPreferencesAsync();
    final encoded = await store.getString(_notesStorageKey);
    if (encoded == null || encoded.isEmpty) return [];
    final decoded = jsonDecode(encoded);
    if (decoded is! List) return [];
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(_SavedNote.fromJson)
        .toList();
  }

  Future<void> _saveNote(_ChatMessage message) async {
    try {
      final preferences = SharedPreferencesAsync();
      final notes = await _readSavedNotes(preferences: preferences);
      final userMessages = _messages.where((item) => item.isUser).toList();
      final firstQuestion = userMessages.isEmpty
          ? null
          : userMessages.first.text;
      final title = firstQuestion == null || firstQuestion.isEmpty
          ? 'ChhanAI answer'
          : firstQuestion.length > 34
          ? '${firstQuestion.substring(0, 34)}…'
          : firstQuestion;
      notes.insert(
        0,
        _SavedNote(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          title: title,
          content: message.text,
          savedAt: DateTime.now(),
        ),
      );
      await preferences.setString(
        _notesStorageKey,
        jsonEncode(notes.map((note) => note.toJson()).toList()),
      );
      if (!mounted) return;
      setState(() {
        _savedNotes = notes;
        _savedMessages.add(message);
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Saved to Notes.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save this note.')),
      );
    }
  }

  Future<void> _openNotes() async {
    try {
      final notes = await _readSavedNotes();
      if (!mounted) return;
      setState(() => _savedNotes = notes);
      await showDialog<void>(
        context: context,
        builder: (context) => _NotesDialog(notes: notes, onDelete: _deleteNote),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open your saved notes.')),
      );
    }
  }

  Future<void> _deleteNote(_SavedNote note) async {
    try {
      final notes = _savedNotes.where((item) => item.id != note.id).toList();
      await SharedPreferencesAsync().setString(
        _notesStorageKey,
        jsonEncode(notes.map((item) => item.toJson()).toList()),
      );
      if (mounted) setState(() => _savedNotes = notes);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not delete this note.')),
        );
      }
      rethrow;
    }
  }

  void _handleSidebarAction(String action) {
    setState(() => _isDesktopDrawerOpen = false);
    switch (action) {
      case 'Chat':
        _scrollToLatest();
        return;
      case 'New chat':
        _startNewChat();
        return;
      case 'Test':
        _startTest();
        return;
      case 'Notes':
        _openNotes();
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 760;
        return Scaffold(
          backgroundColor: _cream,
          drawer: isDesktop ? null : _buildDrawer(),
          appBar: isDesktop ? null : _buildMobileAppBar(),
          body: isDesktop
              ? SafeArea(
                  child: Stack(
                    children: [
                      Positioned.fill(child: _buildChatContent()),
                      if (_isDesktopDrawerOpen)
                        Positioned.fill(
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _isDesktopDrawerOpen = false),
                            child: Container(color: Colors.black26),
                          ),
                        ),
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutCubic,
                        top: 0,
                        bottom: 0,
                        left: _isDesktopDrawerOpen ? 0 : -288,
                        width: 280,
                        child: _buildSidebarPanel(desktop: true),
                      ),
                      Positioned(
                        top: 8,
                        left: _isDesktopDrawerOpen ? 280 : 8,
                        child: Material(
                          color: _isDesktopDrawerOpen
                              ? _sidebarColor
                              : Colors.white.withValues(alpha: 0.82),
                          borderRadius: BorderRadius.circular(12),
                          child: IconButton(
                            tooltip: _isDesktopDrawerOpen
                                ? 'Close sidebar'
                                : 'Open sidebar',
                            onPressed: () => setState(
                              () =>
                                  _isDesktopDrawerOpen = !_isDesktopDrawerOpen,
                            ),
                            icon: Icon(
                              _isDesktopDrawerOpen ? Icons.close : Icons.menu,
                              color: _isDesktopDrawerOpen ? Colors.white : _ink,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : SafeArea(top: false, child: _buildChatContent()),
        );
      },
    );
  }

  PreferredSizeWidget _buildMobileAppBar() {
    return AppBar(
      backgroundColor: _cream,
      surfaceTintColor: Colors.transparent,
      titleSpacing: 4,
      leading: Builder(
        builder: (context) => IconButton(
          icon: const Icon(Icons.menu),
          color: _ink,
          tooltip: 'Open sidebar',
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
      ),
      title: const Text(
        'ChhanAI',
        style: TextStyle(
          fontFamily: 'SpaceGrotesk',
          color: _ink,
          fontWeight: FontWeight.w700,
          fontSize: 20,
          letterSpacing: -0.25,
        ),
      ),
    );
  }

  Widget _buildChatContent() {
    return Container(
      decoration: const BoxDecoration(
        color: _cream,
        gradient: RadialGradient(
          center: Alignment(0, -0.32),
          radius: 1.15,
          colors: [Color(0xFFFFFEFC), _cream],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final minHeight = constraints.maxHeight > 44
                    ? constraints.maxHeight - 44
                    : 0.0;
                final isWelcome = _messages.isEmpty;
                return ListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(minHeight: minHeight),
                      child: Align(
                        alignment: isWelcome
                            ? Alignment.center
                            : Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 800),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (isWelcome) const _ChatWelcome(),
                              for (final message in _messages)
                                _MessageBubble(
                                  message: message,
                                  isSaved: _savedMessages.contains(message),
                                  onSave: !message.isUser && !message.isError
                                      ? () => _saveNote(message)
                                      : null,
                                ),
                              if (_isSending) const _ThinkingIndicator(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          _MessageComposer(
            controller: _messageController,
            onSend: _sendMessage,
            onAttach: _openAttachmentMenu,
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: _sidebarColor,
      child: _buildSidebarPanel(desktop: false),
    );
  }

  Widget _buildSidebarPanel({required bool desktop}) {
    return Material(
      color: _sidebarColor,
      child: SizedBox(
        width: 280,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 16, 24),
                child: Row(
                  children: [
                    Image.asset(
                      _thinkingLogoAsset,
                      width: 42,
                      height: 42,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'ChhanAI',
                      style: TextStyle(
                        fontFamily: 'SpaceGrotesk',
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(
                color: Color(0x40FFFFFF),
                height: 1,
                indent: 16,
                endIndent: 16,
              ),
              const SizedBox(height: 12),
              _sidebarTile(
                icon: Icons.chat_bubble_outline,
                title: 'Chat',
                selected: true,
                onTap: () => _dispatchSidebarAction('Chat', desktop),
              ),
              _sidebarTile(
                icon: Icons.add_comment_outlined,
                title: 'New chat',
                onTap: () => _dispatchSidebarAction('New chat', desktop),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'TOOLS',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              _sidebarTile(
                icon: Icons.quiz_outlined,
                title: 'Test',
                onTap: () => _dispatchSidebarAction('Test', desktop),
              ),
              _sidebarTile(
                icon: Icons.sticky_note_2_outlined,
                title: 'Notes',
                onTap: () => _dispatchSidebarAction('Notes', desktop),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sidebarTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool selected = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: ListTile(
        leading: Icon(icon, color: Colors.white, size: 20),
        title: Text(title),
        textColor: Colors.white,
        selected: selected,
        selectedTileColor: const Color(0xFF4C3037),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onTap: onTap,
      ),
    );
  }

  void _dispatchSidebarAction(String action, bool desktop) {
    if (!desktop) Navigator.pop(context);
    _handleSidebarAction(action);
  }
}

class _ChatMessage {
  const _ChatMessage({
    required this.text,
    required this.isUser,
    this.isError = false,
  });

  final String text;
  final bool isUser;
  final bool isError;
}

class _SavedNote {
  const _SavedNote({
    required this.id,
    required this.title,
    required this.content,
    required this.savedAt,
  });

  final String id;
  final String title;
  final String content;
  final DateTime savedAt;

  Map<String, Object> toJson() => {
    'id': id,
    'title': title,
    'content': content,
    'savedAt': savedAt.toIso8601String(),
  };

  factory _SavedNote.fromJson(Map<String, dynamic> json) {
    final savedAt = json['savedAt'];
    return _SavedNote(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'ChhanAI answer',
      content: json['content']?.toString() ?? '',
      savedAt: savedAt is String
          ? DateTime.tryParse(savedAt) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class _NotesDialog extends StatefulWidget {
  const _NotesDialog({required this.notes, required this.onDelete});

  final List<_SavedNote> notes;
  final Future<void> Function(_SavedNote note) onDelete;

  @override
  State<_NotesDialog> createState() => _NotesDialogState();
}

class _NotesDialogState extends State<_NotesDialog> {
  late List<_SavedNote> _notes;

  @override
  void initState() {
    super.initState();
    _notes = List.of(widget.notes);
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.78;
    return Dialog(
      backgroundColor: _panel,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 620, maxHeight: maxHeight),
        child: SizedBox(
          width: 620,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'My Notes',
                        style: TextStyle(
                          fontFamily: 'SpaceGrotesk',
                          color: _ink,
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close notes',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const Divider(height: 1),
                if (_notes.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 34, horizontal: 12),
                    child: Text(
                      'No notes saved yet. Use Save to Notes under a ChhanAI answer to keep it here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _mutedInk, height: 1.5),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.only(top: 14),
                      itemCount: _notes.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final note = _notes[index];
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: _blush,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFF0E8E5)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                note.title,
                                style: const TextStyle(
                                  color: _ink,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              SelectableText(
                                note.content,
                                style: const TextStyle(
                                  height: 1.5,
                                  color: _ink,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  TextButton.icon(
                                    onPressed: () async {
                                      await Clipboard.setData(
                                        ClipboardData(text: note.content),
                                      );
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                            const SnackBar(
                                              content: Text('Note copied.'),
                                            ),
                                          );
                                    },
                                    icon: const Icon(Icons.copy, size: 16),
                                    label: const Text('Copy'),
                                  ),
                                  TextButton.icon(
                                    onPressed: () async {
                                      try {
                                        await widget.onDelete(note);
                                      } catch (_) {
                                        return;
                                      }
                                      if (!mounted) return;
                                      setState(
                                        () => _notes.removeWhere(
                                          (item) => item.id == note.id,
                                        ),
                                      );
                                    },
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      size: 16,
                                    ),
                                    label: const Text('Delete'),
                                  ),
                                  const Spacer(),
                                  Text(
                                    _formatSavedDate(note.savedAt),
                                    style: const TextStyle(
                                      color: _mutedInk,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatSavedDate(DateTime date) {
    final local = date.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }
}

class _ChatWelcome extends StatelessWidget {
  const _ChatWelcome();

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 500;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            children: [
              ColorFiltered(
                colorFilter: const ColorFilter.mode(_burgundy, BlendMode.srcIn),
                child: Image.asset(
                  _thinkingLogoAsset,
                  width: 112,
                  height: 112,
                  fit: BoxFit.contain,
                  semanticLabel: 'ChhanAI logo',
                ),
              ),
              const SizedBox(height: 26),
              Text(
                'Chat with ChhanAI',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'SpaceGrotesk',
                  color: _ink,
                  fontSize: isCompact ? 30 : 36,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.8,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                '\u{1F44B} How can I help you?',
                textAlign: TextAlign.center,
                style: TextStyle(color: _mutedInk, fontSize: 17, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    this.onSave,
    this.isSaved = false,
  });

  final _ChatMessage message;
  final VoidCallback? onSave;
  final bool isSaved;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: isUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Container(
            constraints: const BoxConstraints(maxWidth: 320),
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              color: isUser ? null : _blush,
              gradient: isUser
                  ? const LinearGradient(
                      colors: [_burgundy, _darkBurgundy],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isUser ? 18 : 5),
                bottomRight: Radius.circular(isUser ? 5 : 18),
              ),
              border: isUser
                  ? null
                  : Border.all(color: const Color(0xFFF0E8E5)),
            ),
            child: Text(
              message.text,
              style: TextStyle(
                color: isUser ? Colors.white : _ink,
                fontSize: 15,
                height: 1.45,
              ),
            ),
          ),
          if (onSave != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextButton.icon(
                onPressed: isSaved ? null : onSave,
                icon: Icon(
                  isSaved ? Icons.check_rounded : Icons.bookmark_add_outlined,
                  size: 16,
                ),
                label: Text(isSaved ? 'Saved' : 'Save to Notes'),
                style: TextButton.styleFrom(
                  foregroundColor: _mutedInk,
                  visualDensity: VisualDensity.compact,
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),
            )
          else
            const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _ThinkingIndicator extends StatefulWidget {
  const _ThinkingIndicator();

  @override
  State<_ThinkingIndicator> createState() => _ThinkingIndicatorState();
}

class _ThinkingIndicatorState extends State<_ThinkingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    final pulse = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _scale = Tween<double>(begin: 0.94, end: 1.06).animate(pulse);
    _opacity = Tween<double>(begin: 0.62, end: 1).animate(pulse);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _controller,
              child: Image.asset(
                _thinkingLogoAsset,
                width: 40,
                height: 40,
                fit: BoxFit.contain,
                semanticLabel: 'ChhanaAI',
              ),
              builder: (context, logo) => Opacity(
                opacity: _opacity.value,
                child: Transform.scale(scale: _scale.value, child: logo),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'ChhanAI is thinking…',
              style: TextStyle(color: _mutedInk, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class _SendMessageIntent extends Intent {
  const _SendMessageIntent();
}

class _MessageComposer extends StatelessWidget {
  const _MessageComposer({
    required this.controller,
    required this.onSend,
    required this.onAttach,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onAttach;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
      color: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: SizedBox(
                width: double.infinity,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 9, 10, 9),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFEDE6E0)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x124C0011),
                        blurRadius: 26,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      IconButton(
                        onPressed: onAttach,
                        icon: const Icon(Icons.add_circle_outline),
                        tooltip: 'Attach files or photos',
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Shortcuts(
                            shortcuts: const <ShortcutActivator, Intent>{
                              SingleActivator(LogicalKeyboardKey.enter):
                                  _SendMessageIntent(),
                            },
                            child: Actions(
                              actions: <Type, Action<Intent>>{
                                _SendMessageIntent:
                                    CallbackAction<_SendMessageIntent>(
                                      onInvoke: (_) {
                                        onSend();
                                        return null;
                                      },
                                    ),
                              },
                              child: TextField(
                                controller: controller,
                                minLines: 1,
                                maxLines: 5,
                                keyboardType: TextInputType.multiline,
                                textInputAction: TextInputAction.send,
                                onSubmitted: (_) => onSend(),
                                decoration: const InputDecoration(
                                  hintText: 'Message ChhanAI...',
                                  hintStyle: TextStyle(color: _mutedInk),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 2,
                                    vertical: 11,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Tooltip(
                        message: 'Send message',
                        child: Material(
                          color: Colors.transparent,
                          child: Ink(
                            width: 43,
                            height: 43,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [_burgundy, _darkBurgundy],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: InkWell(
                              onTap: onSend,
                              borderRadius: BorderRadius.circular(13),
                              child: const Center(
                                child: Icon(
                                  Icons.arrow_upward_rounded,
                                  color: Colors.white,
                                  size: 21,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 9),
          const Text(
            'ChhanAI can make mistakes. Check important information.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFFA09AB9), fontSize: 10),
          ),
        ],
      ),
    );
  }
}
