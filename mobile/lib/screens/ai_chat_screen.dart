import 'package:flutter/material.dart';

import '../api_client.dart';
import '../theme.dart';
import '../widgets/cc_components.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key, required this.apiClient, required this.elderId});

  final ApiClient apiClient;
  final String elderId;

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _isSending = false;
  bool _isLoadingHistory = true;
  String? _historyError;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _historyError = null;
      _isLoadingHistory = true;
    });
    try {
      final data = await widget.apiClient.aiConversations();
      final conversations = (data['conversations'] as List<dynamic>? ?? const []);
      if (!mounted) return;
      setState(() {
        for (final c in conversations) {
          _messages.add(_ChatMessage(text: c['question']?.toString() ?? '', isUser: true));
          _messages.add(_ChatMessage(
            text: c['answer']?.toString() ?? '',
            isUser: false,
            isEmergency: c['emergencyDetected'] == true,
          ));
        }
        _isLoadingHistory = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingHistory = false;
          _historyError = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
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

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true));
      _isSending = true;
      _controller.clear();
    });
    _scrollToBottom();

    try {
      final response = await widget.apiClient.askAi(elderId: widget.elderId, question: text);
      final conversation = response['conversation'] as Map<String, dynamic>?;
      final answer = conversation?['answer']?.toString() ?? 'No response received.';
      final emergency = conversation?['emergencyDetected'] == true;

      if (mounted) {
        setState(() {
          _messages.add(_ChatMessage(
            text: answer,
            isUser: false,
            isEmergency: emergency,
          ));
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(const _ChatMessage(
            text: 'Sorry, I could not process your request. Please try again.',
            isUser: false,
            isError: true,
          ));
        });
        _scrollToBottom();
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('AI Assistant'),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: AppTheme.spacingSm),
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd, vertical: AppTheme.spacingXs),
            decoration: BoxDecoration(
              color: AppTheme.tealLight,
              borderRadius: BorderRadius.circular(AppTheme.radiusXs),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.smart_toy, size: 16, color: AppTheme.teal),
                SizedBox(width: AppTheme.spacingXs),
                Text('AI', style: TextStyle(color: AppTheme.teal, fontSize: AppTheme.fontSizeSm, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoadingHistory
                ? const CCLoading()
                : _historyError != null
                    ? CCError(message: _historyError!, onRetry: _loadHistory)
                    : _messages.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(AppTheme.spacingXl),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) => _buildBubble(_messages[index]),
                      ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingXl),
              decoration: BoxDecoration(
                color: AppTheme.tealLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.smart_toy, color: AppTheme.teal, size: 40),
            ),
            const SizedBox(height: AppTheme.spacingXl),
            const Text('CareCircle AI Assistant', style: TextStyle(fontSize: AppTheme.fontSizeXxl, fontWeight: FontWeight.w800, color: AppTheme.ink)),
            const SizedBox(height: AppTheme.spacingSm),
            const Text(
              'Ask about general wellness, symptoms, or health topics. '
              'This is not a substitute for professional medical advice.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.muted, fontSize: AppTheme.fontSizeMd, height: 1.4),
            ),
            const SizedBox(height: AppTheme.spacingXxl),
            Wrap(
              spacing: AppTheme.spacingSm,
              runSpacing: AppTheme.spacingSm,
              alignment: WrapAlignment.center,
              children: [
                _suggestionChip('How can I improve my sleep?'),
                _suggestionChip('What are good exercises for elders?'),
                _suggestionChip('I feel dizzy sometimes'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _suggestionChip(String text) {
    return ActionChip(
      label: Text(text, style: const TextStyle(fontSize: AppTheme.fontSizeSm)),
      side: const BorderSide(color: AppTheme.surfaceBorder),
      backgroundColor: AppTheme.surface,
      onPressed: () {
        _controller.text = text;
        _send();
      },
    );
  }

  Widget _buildBubble(_ChatMessage msg) {
    final isUser = msg.isUser;
    final color = isUser
        ? AppTheme.teal
        : msg.isEmergency
            ? AppTheme.sosRed
            : msg.isError
                ? AppTheme.coral
                : AppTheme.surface;
    final textColor = isUser || msg.isEmergency ? AppTheme.surface : AppTheme.ink;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(AppTheme.radiusLarge),
            topRight: const Radius.circular(AppTheme.radiusLarge),
            bottomLeft: Radius.circular(isUser ? AppTheme.radiusLarge : AppTheme.radiusXs),
            bottomRight: Radius.circular(isUser ? AppTheme.radiusXs : AppTheme.radiusLarge),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (msg.isEmergency) ...[
              const Row(
                children: [
                  Icon(Icons.warning_amber, color: AppTheme.surface, size: 18),
                  SizedBox(width: AppTheme.spacingSm),
                  Text('EMERGENCY', style: TextStyle(color: AppTheme.surface, fontWeight: FontWeight.w800, fontSize: AppTheme.fontSizeSm)),
                ],
              ),
              const SizedBox(height: AppTheme.spacingSm),
            ],
            Text(msg.text, style: TextStyle(color: textColor, fontSize: AppTheme.fontSizeLg, height: 1.4)),
            if (msg.isEmergency) ...[
              const SizedBox(height: AppTheme.spacingMd),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _showSosConfirmation,
                  icon: const Icon(Icons.emergency, size: 18),
                  label: const Text('Trigger SOS'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.surface,
                    foregroundColor: AppTheme.sosRed,
                    padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingMd),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusSmall)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showSosConfirmation() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning_amber, color: AppTheme.sosRed, size: 40),
        title: const Text('Trigger SOS Alert?'),
        content: const Text(
          'This will send an emergency alert to your CareCircle. '
          'They will be notified immediately.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _triggerSos();
            },
            style: FilledButton.styleFrom(backgroundColor: AppTheme.sosRed),
            child: const Text('Send SOS'),
          ),
        ],
      ),
    );
  }

  Future<void> _triggerSos() async {
    try {
      await widget.apiClient.triggerSos(elderId: widget.elderId, location: 'Mobile app');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('SOS alert sent. Your CareCircle has been notified.'),
            backgroundColor: AppTheme.sosRed,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send SOS: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: AppTheme.sosRed,
          ),
        );
      }
    }
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(AppTheme.spacingXl, AppTheme.spacingMd, AppTheme.spacingXl, AppTheme.spacingXxl),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.surfaceBorder)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                maxLines: null,
                decoration: InputDecoration(
                  hintText: 'Ask a health question...',
                  hintStyle: const TextStyle(color: AppTheme.subtle),
                  filled: true,
                  fillColor: AppTheme.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLg, vertical: AppTheme.spacingMd),
                ),
              ),
            ),
            const SizedBox(width: AppTheme.spacingMd),
            Container(
              decoration: const BoxDecoration(color: AppTheme.teal, shape: BoxShape.circle),
              child: IconButton(
                onPressed: _isSending ? null : _send,
                icon: _isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.surface),
                      )
                    : const Icon(Icons.send, color: AppTheme.surface, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatMessage {
  const _ChatMessage({required this.text, required this.isUser, this.isEmergency = false, this.isError = false});

  final String text;
  final bool isUser;
  final bool isEmergency;
  final bool isError;
}
