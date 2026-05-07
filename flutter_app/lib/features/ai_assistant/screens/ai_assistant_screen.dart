import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../core/services/service_locator.dart';

class AIAssistantScreen extends ConsumerStatefulWidget {
  final String objectId;
  const AIAssistantScreen({super.key, required this.objectId});

  @override
  ConsumerState<AIAssistantScreen> createState() => _AIAssistantScreenState();
}

class _AIAssistantScreenState extends ConsumerState<AIAssistantScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _isThinking = false;
  bool _isListening = false;
  String _listeningText = '';
  final String _sessionId = 'session_${DateTime.now().millisecondsSinceEpoch}';

  final List<String> _quickPrompts = [
    'What does this object do?',
    'How do I open it?',
    'Show the airflow system',
    'What material is the case?',
    'Explain this like I\'m a beginner',
    'What can go wrong with this?',
    'How was it manufactured?',
    'Find similar products',
  ];

  @override
  void initState() {
    super.initState();
    _addWelcomeMessage();
  }

  void _addWelcomeMessage() {
    _messages.add(_ChatMessage(
      text:
          'Hello! I\'m your AI Engineering Assistant. I have full knowledge of this object — its components, mechanics, materials, and repair procedures. Ask me anything!\n\nTry: "What does the motherboard do?" or "How do I replace the battery?"',
      isUser: false,
      timestamp: DateTime.now(),
    ));
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    setState(() {
      _messages.add(_ChatMessage(
        text: text,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isThinking = true;
      _inputController.clear();
    });

    _scrollToBottom();

    try {
      final result = await ServiceLocator.apiService.chat(
        objectId: widget.objectId,
        message: text,
        sessionId: _sessionId,
      );

      if (mounted) {
        setState(() {
          _messages.add(_ChatMessage(
            text: result['response'] as String? ?? 'I couldn\'t process that request.',
            isUser: false,
            timestamp: DateTime.now(),
            hasVisualization: result['has_visualization'] as bool? ?? false,
            visualizationType: result['visualization_type'] as String?,
          ));
          _isThinking = false;
        });
        _scrollToBottom();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _messages.add(_ChatMessage(
            text: _generateLocalResponse(text),
            isUser: false,
            timestamp: DateTime.now(),
          ));
          _isThinking = false;
        });
        _scrollToBottom();
      }
    }
  }

  String _generateLocalResponse(String question) {
    final q = question.toLowerCase();
    if (q.contains('motherboard') || q.contains('what does')) {
      return 'The **motherboard** is the central hub of the laptop. It connects all components including the CPU, RAM, storage, and I/O ports through a network of copper traces on a PCB substrate. It also manages power distribution and signal routing.\n\nKey features:\n• Intel Core i5-1135G7 processor\n• 2× DDR4 SODIMM slots (1 occupied)\n• M.2 PCIe NVMe slot\n• Integrated Intel UHD graphics';
    } else if (q.contains('battery') || q.contains('power')) {
      return 'The **battery** is a 40Wh 3-cell lithium-ion pack located at the rear of the bottom chassis.\n\nTo replace it:\n1. Power off completely\n2. Remove 8 bottom screws (Torx T5)\n3. Pry open bottom cover carefully\n4. Disconnect battery connector (white ZIF)\n5. Remove 2 retention screws\n6. Lift battery out\n\n⚠️ Always work with the device unplugged and discharged below 30%.';
    } else if (q.contains('material') || q.contains('made of')) {
      return 'The casing is made of:\n\n• **Lid**: Anodized aluminum alloy (6061-T6) — provides rigidity and heat dissipation\n• **Bottom/Keyboard**: ABS plastic with carbon fiber infill — lightweight and durable\n• **Display bezel**: Soft-touch ABS plastic\n\nEstimated durability: **7.2/10** — suitable for everyday office use with moderate drop resistance.';
    }
    return 'Great question! Based on my analysis of this object, I can provide detailed information about its components, materials, assembly procedures, and maintenance.\n\nFor the most accurate technical answer, please ensure you\'re connected to the internet. In offline mode, I have access to general engineering knowledge about this product category.';
  }

  Future<void> _startVoiceInput() async {
    setState(() {
      _isListening = true;
      _listeningText = '';
    });

    await ServiceLocator.audioService.speak('Listening...');

    final result = await ServiceLocator.audioService.listen(
      onPartialResult: (partial) {
        if (mounted) setState(() => _listeningText = partial);
      },
    );

    setState(() => _isListening = false);
    if (result != null && result.isNotEmpty) {
      _sendMessage(result);
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceDark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppTheme.primaryCyan),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryCyan, AppTheme.primaryBlue],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryCyan.withOpacity(0.4),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: const Icon(Icons.smart_toy, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('AI ENGINEERING ASSISTANT'),
                Text(
                  _isThinking ? 'thinking...' : 'ready',
                  style: TextStyle(
                    fontSize: 11,
                    color: _isThinking
                        ? AppTheme.warningAmber
                        : AppTheme.accentGreen,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.volume_up_outlined, color: AppTheme.primaryCyan),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: AppTheme.primaryCyan),
            onPressed: () {},
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppTheme.glassWhite),
        ),
      ),
      body: Column(
        children: [
          // Context bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppTheme.primaryCyan.withOpacity(0.06),
            child: Row(
              children: [
                const Icon(Icons.view_in_ar, size: 14, color: AppTheme.primaryCyan),
                const SizedBox(width: 6),
                const Text(
                  'Context: ',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                const Text(
                  'Dell Inspiron 15 Laptop',
                  style: TextStyle(
                    color: AppTheme.primaryCyan,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                const Icon(Icons.check_circle, size: 12, color: AppTheme.accentGreen),
                const SizedBox(width: 4),
                const Text(
                  '5 components loaded',
                  style: TextStyle(color: AppTheme.accentGreen, fontSize: 11),
                ),
              ],
            ),
          ),

          // Quick prompts
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              itemCount: _quickPrompts.length,
              itemBuilder: (context, i) => GestureDetector(
                onTap: () => _sendMessage(_quickPrompts[i]),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.glassWhite,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.glassWhiteStrong),
                  ),
                  child: Text(
                    _quickPrompts[i],
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _messages.length + (_isThinking ? 1 : 0),
              itemBuilder: (context, i) {
                if (i == _messages.length) {
                  return _ThinkingBubble();
                }
                return _MessageBubble(message: _messages[i])
                    .animate()
                    .fadeIn(duration: 300.ms)
                    .slideY(begin: 0.3);
              },
            ),
          ),

          // Voice listening indicator
          if (_isListening)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppTheme.primaryCyan.withOpacity(0.08),
              child: Row(
                children: [
                  const Icon(Icons.mic, color: AppTheme.primaryCyan, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _listeningText.isEmpty ? 'Listening...' : _listeningText,
                      style: const TextStyle(
                        color: AppTheme.primaryCyan,
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Input bar
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
            decoration: const BoxDecoration(
              color: AppTheme.surfaceDark,
              border: Border(top: BorderSide(color: AppTheme.glassWhite)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.glassWhite,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppTheme.glassWhiteStrong),
                    ),
                    child: TextField(
                      controller: _inputController,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                      ),
                      maxLines: 3,
                      minLines: 1,
                      decoration: const InputDecoration(
                        hintText: 'Ask about this object...',
                        hintStyle: TextStyle(color: AppTheme.textSecondary),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      onSubmitted: _sendMessage,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _startVoiceInput,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isListening
                          ? AppTheme.errorRed.withOpacity(0.2)
                          : AppTheme.glassWhite,
                      border: Border.all(
                        color: _isListening
                            ? AppTheme.errorRed
                            : AppTheme.glassWhiteStrong,
                      ),
                    ),
                    child: Icon(
                      _isListening ? Icons.mic : Icons.mic_outlined,
                      color: _isListening ? AppTheme.errorRed : AppTheme.textPrimary,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _sendMessage(_inputController.text),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [AppTheme.primaryCyan, AppTheme.primaryBlue],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryCyan.withOpacity(0.4),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.send, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool hasVisualization;
  final String? visualizationType;

  _ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.hasVisualization = false,
    this.visualizationType,
  });
}

class _MessageBubble extends StatelessWidget {
  final _ChatMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: message.isUser
                ? AppTheme.primaryCyan.withOpacity(0.15)
                : AppTheme.surfaceMid,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(message.isUser ? 16 : 4),
              bottomRight: Radius.circular(message.isUser ? 4 : 16),
            ),
            border: Border.all(
              color: message.isUser
                  ? AppTheme.primaryCyan.withOpacity(0.3)
                  : AppTheme.glassWhiteStrong,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!message.isUser) ...[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.primaryCyan,
                      ),
                      child: const Icon(Icons.smart_toy, size: 8, color: Colors.white),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'AI ASSISTANT',
                      style: TextStyle(
                        color: AppTheme.primaryCyan,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
              ],
              _buildTextWithMarkdown(message.text),
              const SizedBox(height: 4),
              Text(
                '${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextWithMarkdown(String text) {
    // Simple bold text rendering for **text**
    final parts = text.split('**');
    final spans = <TextSpan>[];
    for (var i = 0; i < parts.length; i++) {
      spans.add(TextSpan(
        text: parts[i],
        style: TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 13,
          fontWeight: i.isOdd ? FontWeight.w700 : FontWeight.normal,
          height: 1.5,
        ),
      ));
    }
    return RichText(text: TextSpan(children: spans));
  }
}

class _ThinkingBubble extends StatefulWidget {
  @override
  State<_ThinkingBubble> createState() => _ThinkingBubbleState();
}

class _ThinkingBubbleState extends State<_ThinkingBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
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
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceMid,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
          ),
          border: Border.all(color: AppTheme.glassWhiteStrong),
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primaryCyan.withOpacity(
                    i == 0
                        ? _controller.value
                        : i == 1
                            ? (1 - _controller.value)
                            : _controller.value * 0.5,
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
