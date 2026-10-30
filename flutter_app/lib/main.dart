import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

// ======================================================
// APP
// ======================================================

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      title: 'AI Chat',

      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),

      home: const ChatScreen(),
    );
  }
}

// ======================================================
// CHAT MESSAGE MODEL
// ======================================================

class ChatMessage {
  String text;

  final bool isUser;

  ChatMessage({required this.text, required this.isUser});

  Map<String, dynamic> toJson() {
    return {'role': isUser ? 'user' : 'assistant', 'content': text};
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      text: json['content']?.toString() ?? '',

      isUser: json['role'] == 'user',
    );
  }
}
// ======================================================
// CHAT SCREEN
// ======================================================

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

// ======================================================
// CHAT STATE
// ======================================================

class _ChatScreenState extends State<ChatScreen> {
  // --------------------------------------------------
  // Controllers
  // --------------------------------------------------

  final TextEditingController _controller = TextEditingController();

  final ScrollController _scrollController = ScrollController();

  // --------------------------------------------------
  // Conversation messages
  // --------------------------------------------------

  final List<ChatMessage> _messages = [];

  // --------------------------------------------------
  // Loading state
  // --------------------------------------------------

  bool _isLoading = false;

  // --------------------------------------------------
  // SharedPreferences storage key
  // --------------------------------------------------

  static const String _storageKey = 'chat_messages';

  // ====================================================
  // INITIALIZATION
  // ====================================================

  @override
  void initState() {
    super.initState();

    _loadMessages();
  }

  // ====================================================
  // LOAD SAVED CONVERSATION
  // ====================================================

  Future<void> _loadMessages() async {
    final prefs = await SharedPreferences.getInstance();

    final savedMessages = prefs.getString(_storageKey);

    // Nothing saved yet
    if (savedMessages == null) {
      return;
    }

    try {
      final List<dynamic> decoded = jsonDecode(savedMessages);

      final loadedMessages = decoded.map((item) {
        return ChatMessage.fromJson(Map<String, dynamic>.from(item));
      }).toList();

      if (!mounted) {
        return;
      }

      setState(() {
        _messages.clear();

        _messages.addAll(loadedMessages);
      });

      _scrollToBottom();
    } catch (error) {
      debugPrint('Failed to load saved messages: $error');
    }
  }

  // ====================================================
  // SAVE CONVERSATION
  // ====================================================

  Future<void> _saveMessages() async {
    final prefs = await SharedPreferences.getInstance();

    final messagesJson = _messages.map((message) => message.toJson()).toList();

    final encoded = jsonEncode(messagesJson);

    await prefs.setString(_storageKey, encoded);
  }

  // ====================================================
  // CLEAR CONVERSATION
  // ====================================================

  Future<void> _clearConversation() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_storageKey);

    if (!mounted) {
      return;
    }

    setState(() {
      _messages.clear();
    });
  }

  // ====================================================
  // SEND MESSAGE
  // ====================================================

  Future<void> sendMessage() async {
    final message = _controller.text.trim();

    if (message.isEmpty || _isLoading) {
      return;
    }

    // --------------------------------------------
    // Add user message
    // --------------------------------------------

    setState(() {
      _messages.add(ChatMessage(text: message, isUser: true));

      _isLoading = true;
    });

    _controller.clear();

    await _saveMessages();

    _scrollToBottom();

    // --------------------------------------------
    // Create history BEFORE adding empty AI bubble
    // --------------------------------------------

    final history = _messages.map((message) => message.toJson()).toList();

    // --------------------------------------------
    // Create empty assistant message
    // --------------------------------------------

    final assistantMessage = ChatMessage(text: '', isUser: false);

    setState(() {
      _messages.add(assistantMessage);
    });

    final assistantIndex = _messages.length - 1;

    try {
      final url = Uri.parse('http://127.0.0.1:8000/chat/stream');

      // ------------------------------------------
      // Create streaming HTTP request
      // ------------------------------------------

      final request = http.Request('POST', url);

      request.headers['Content-Type'] = 'application/json';

      request.body = jsonEncode({'messages': history});

      // ------------------------------------------
      // Send request
      // ------------------------------------------

      final streamedResponse = await request.send();

      // ------------------------------------------
      // Success
      // ------------------------------------------

      if (streamedResponse.statusCode == 200) {
        // The response arrives as bytes.
        // Convert them to text chunks.

        await for (final chunk in streamedResponse.stream.transform(
          utf8.decoder,
        )) {
          if (!mounted) {
            return;
          }

          setState(() {
            _messages[assistantIndex].text += chunk;
          });

          _scrollToBottom();
        }

        // No output received

        if (_messages[assistantIndex].text.isEmpty) {
          setState(() {
            _messages[assistantIndex].text = 'No response received.';
          });
        }

        // Save full response after stream ends

        await _saveMessages();
      }
      // ------------------------------------------
      // Server error
      // ------------------------------------------
      else {
        final errorBody = await streamedResponse.stream.bytesToString();

        if (!mounted) {
          return;
        }

        setState(() {
          _messages[assistantIndex].text =
              'Server error: '
              '${streamedResponse.statusCode}\n'
              '$errorBody';
        });

        await _saveMessages();
      }
    }
    // --------------------------------------------
    // Connection error
    // --------------------------------------------
    catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _messages[assistantIndex].text = 'Connection error:\n$error';
      });

      await _saveMessages();
    }
    // --------------------------------------------
    // Finish
    // --------------------------------------------
    finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        _scrollToBottom();
      }
    }
  }

  // ====================================================
  // AUTO SCROLL
  // ====================================================

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!_scrollController.hasClients) {
        return;
      }

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,

        duration: const Duration(milliseconds: 300),

        curve: Curves.easeOut,
      );
    });
  }

  // ====================================================
  // MESSAGE BUBBLE
  // ====================================================

  Widget _buildMessageBubble(ChatMessage message) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,

      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),

        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),

        constraints: const BoxConstraints(maxWidth: 600),

        decoration: BoxDecoration(
          color: message.isUser ? Colors.blue : Colors.grey.shade200,

          borderRadius: BorderRadius.circular(18),
        ),

        child: SelectableText(
          message.text,

          style: TextStyle(
            fontSize: 16,

            height: 1.4,

            color: message.isUser ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }

  // ====================================================
  // UI
  // ====================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ------------------------------------------------
      // APP BAR
      // ------------------------------------------------

      appBar: AppBar(
        title: const Text('AI Chat'),

        actions: [
          // Clear chat button

          if (_messages.isNotEmpty)
            IconButton(
              tooltip: 'Clear conversation',

              onPressed: _isLoading ? null : _clearConversation,

              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),

      // ------------------------------------------------
      // MAIN BODY
      // ------------------------------------------------
      body: Column(
        children: [
          // ============================================
          // MESSAGES
          // ============================================

          Expanded(
            child: _messages.isEmpty
                // Empty conversation
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,

                      children: [
                        Icon(
                          Icons.chat_bubble_outline,

                          size: 48,

                          color: Colors.grey,
                        ),

                        SizedBox(height: 12),

                        Text(
                          'Start a conversation',

                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                // Existing messages
                : ListView.builder(
                    controller: _scrollController,

                    padding: const EdgeInsets.symmetric(vertical: 12),

                    itemCount: _messages.length,

                    itemBuilder: (context, index) {
                      return _buildMessageBubble(_messages[index]);
                    },
                  ),
          ),

          // ============================================
          // LOADING INDICATOR
          // ============================================
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),

              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,

                children: [
                  SizedBox(
                    width: 18,

                    height: 18,

                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),

                  SizedBox(width: 10),

                  Text('AI is responding...'),
                ],
              ),
            ),

          // ============================================
          // INPUT AREA
          // ============================================
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),

              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,

                children: [
                  // ------------------------------------
                  // MESSAGE INPUT
                  // ------------------------------------

                  Expanded(
                    child: TextField(
                      controller: _controller,

                      minLines: 1,

                      maxLines: 5,

                      textInputAction: TextInputAction.send,

                      decoration: InputDecoration(
                        hintText: 'Type a message...',

                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),

                      onSubmitted: (_) {
                        sendMessage();
                      },
                    ),
                  ),

                  const SizedBox(width: 8),

                  // ------------------------------------
                  // SEND BUTTON
                  // ------------------------------------
                  IconButton.filled(
                    onPressed: _isLoading ? null : sendMessage,

                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ====================================================
  // CLEANUP
  // ====================================================

  @override
  void dispose() {
    _controller.dispose();

    _scrollController.dispose();

    super.dispose();
  }
}
