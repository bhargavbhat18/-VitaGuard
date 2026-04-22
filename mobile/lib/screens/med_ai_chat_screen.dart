import 'dart:async';
import 'package:flutter/material.dart';
import 'package:vitalguard/models/vitals_model.dart';
import 'package:vitalguard/services/med_ai_service.dart';

class MedAiChatScreen extends StatefulWidget {
  final VitalsModel? vitals;
  const MedAiChatScreen({super.key, this.vitals});

  @override
  State<MedAiChatScreen> createState() => _MedAiChatScreenState();
}

class _MedAiChatScreenState extends State<MedAiChatScreen>
    with TickerProviderStateMixin {
  final _controller = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<MedAiMessage> _messages = [];
  late final MedAiService _ai;
  bool _typing = false;

  @override
  void initState() {
    super.initState();
    _ai = MedAiService(vitals: widget.vitals);
    _messages.add(MedAiMessage(
      text: '👋 Hi! I\'m **MedAI** — your VitalGuard medication assistant.\n\n'
            'I can recommend medications and give advice based on your symptoms '
            'and live vitals. Ask me anything, or tap a suggestion below!',
      isUser: false,
      suggestions: MedAiService.starterSuggestions.take(4).toList(),
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _controller.clear();
    setState(() {
      _messages.add(MedAiMessage(text: trimmed, isUser: true));
      _typing = true;
    });
    _scrollToBottom();
    await Future.delayed(const Duration(milliseconds: 700));
    final reply = _ai.respond(trimmed);
    if (!mounted) return;
    setState(() { _typing = false; _messages.add(reply); });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF4F6FA),
    appBar: _buildAppBar(),
    body: Column(children: [
      Expanded(
        child: ListView.builder(
          controller: _scrollCtrl,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          itemCount: _messages.length + (_typing ? 1 : 0),
          itemBuilder: (ctx, i) {
            if (_typing && i == _messages.length) return _TypingBubble();
            return _MessageBubble(message: _messages[i], onSuggestion: _send);
          },
        ),
      ),
      _InputBar(onSend: _send, controller: _controller),
    ]),
  );

  PreferredSizeWidget _buildAppBar() => AppBar(
    backgroundColor: Colors.white, elevation: 0,
    leading: IconButton(
      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Color(0xFF1A1C1C)),
      onPressed: () => Navigator.pop(context)),
    title: Row(children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6C63FF), Color(0xFF9B59B6)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(10)),
        child: const Icon(Icons.assistant_rounded, color: Colors.white, size: 20)),
      const SizedBox(width: 10),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('MedAI', style: TextStyle(fontSize: 15,
          fontWeight: FontWeight.w900, color: Color(0xFF1A1C1C))),
        Row(children: [
          Container(width: 6, height: 6,
            decoration: const BoxDecoration(color: Color(0xFF16a34a), shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text('Medication Assistant', style: TextStyle(fontSize: 10,
            color: Colors.grey[500], fontWeight: FontWeight.w500)),
        ]),
      ]),
    ]),
    actions: [
      if (widget.vitals != null)
        Padding(
          padding: const EdgeInsets.only(right: 6),
          child: TextButton.icon(
            onPressed: () => _send('Check my vitals'),
            icon: const Icon(Icons.monitor_heart_rounded, size: 14, color: Color(0xFFB6171E)),
            label: const Text('Vitals', style: TextStyle(fontSize: 12,
              color: Color(0xFFB6171E), fontWeight: FontWeight.w700)),
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFFFFDAD6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
          )),
      const SizedBox(width: 6),
    ],
  );
}

// ── Message Bubble ─────────────────────────────────────────────
class _MessageBubble extends StatelessWidget {
  final MedAiMessage message;
  final void Function(String) onSuggestion;
  const _MessageBubble({required this.message, required this.onSuggestion});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Column(
      crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isUser)
              Container(
                width: 28, height: 28,
                margin: const EdgeInsets.only(right: 8, bottom: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF6C63FF), Color(0xFF9B59B6)]),
                  borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.assistant_rounded, color: Colors.white, size: 16)),
            Flexible(
              child: Container(
                margin: EdgeInsets.only(
                  bottom: message.suggestions.isEmpty ? 12 : 6,
                  left: isUser ? 60 : 0,
                  right: isUser ? 0 : 60),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isUser ? const Color(0xFF6C63FF) : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isUser ? 18 : 4),
                    bottomRight: Radius.circular(isUser ? 4 : 18)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06),
                    blurRadius: 10, offset: const Offset(0, 3))]),
                child: _buildText(isUser))),
          ]),
        if (message.suggestions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 36, bottom: 16),
            child: Wrap(spacing: 8, runSpacing: 8,
              children: message.suggestions.map((s) =>
                _SuggestionChip(label: s, onTap: () => onSuggestion(s))).toList())),
        Padding(
          padding: EdgeInsets.only(left: isUser ? 0 : 36, right: isUser ? 4 : 0, bottom: 4),
          child: Text(_fmt(message.time),
            style: TextStyle(fontSize: 9, color: Colors.grey[400]))),
      ]);
  }

  Widget _buildText(bool isUser) {
    final raw = message.text;
    final spans = <TextSpan>[];
    final regex = RegExp(r'\*\*(.+?)\*\*|\*(.+?)\*|`(.+?)`');
    int last = 0;
    for (final match in regex.allMatches(raw)) {
      if (match.start > last) spans.add(TextSpan(text: raw.substring(last, match.start)));
      if (match.group(1) != null) {
        spans.add(TextSpan(text: match.group(1),
          style: const TextStyle(fontWeight: FontWeight.w800)));
      } else if (match.group(2) != null) {
        spans.add(TextSpan(text: match.group(2),
          style: const TextStyle(fontStyle: FontStyle.italic)));
      } else if (match.group(3) != null) {
        spans.add(TextSpan(text: match.group(3),
          style: TextStyle(fontFamily: 'monospace',
            backgroundColor: isUser
              ? Colors.white.withOpacity(0.2)
              : Colors.grey.shade100)));
      }
      last = match.end;
    }
    if (last < raw.length) spans.add(TextSpan(text: raw.substring(last)));
    return RichText(text: TextSpan(
      style: TextStyle(fontSize: 13,
        color: isUser ? Colors.white : const Color(0xFF1A1C1C), height: 1.55),
      children: spans));
  }

  String _fmt(DateTime t) =>
      '${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}';
}

// ── Typing indicator ───────────────────────────────────────────
class _TypingBubble extends StatefulWidget {
  @override State<_TypingBubble> createState() => _TypingBubbleState();
}
class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
  }
  @override void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Container(
        width: 28, height: 28,
        margin: const EdgeInsets.only(right: 8, bottom: 4),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF6C63FF), Color(0xFF9B59B6)]),
          borderRadius: BorderRadius.circular(8)),
        child: const Icon(Icons.assistant_rounded, color: Colors.white, size: 16)),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18), topRight: Radius.circular(18),
            bottomRight: Radius.circular(18), bottomLeft: Radius.circular(4)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10)]),
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) => Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              final t = (_c.value - i * 0.2).clamp(0.0, 1.0);
              final opacity = (t < 0.5 ? t * 2 : (1 - t) * 2).clamp(0.3, 1.0);
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: 7, height: 7,
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF).withOpacity(opacity),
                  shape: BoxShape.circle));
            })))),
    ]));
}

// ── Suggestion chip ────────────────────────────────────────────
class _SuggestionChip extends StatelessWidget {
  final String label; final VoidCallback onTap;
  const _SuggestionChip({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.4)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)]),
      child: Text(label, style: const TextStyle(fontSize: 12,
        fontWeight: FontWeight.w600, color: Color(0xFF6C63FF)))));
}

// ── Input bar ──────────────────────────────────────────────────
class _InputBar extends StatelessWidget {
  final void Function(String) onSend;
  final TextEditingController controller;
  const _InputBar({required this.onSend, required this.controller});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
    decoration: BoxDecoration(
      color: Colors.white,
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06),
        blurRadius: 16, offset: const Offset(0, -4))]),
    child: Row(children: [
      Expanded(
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF4F6FA),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.grey.shade200)),
          child: TextField(
            controller: controller,
            onSubmitted: onSend,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Ask about medications...',
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12))))),
      const SizedBox(width: 10),
      GestureDetector(
        onTap: () => onSend(controller.text),
        child: Container(
          width: 46, height: 46,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6C63FF), Color(0xFF9B59B6)],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(23),
            boxShadow: [BoxShadow(color: const Color(0xFF6C63FF).withOpacity(0.35),
              blurRadius: 12, offset: const Offset(0, 4))]),
          child: const Icon(Icons.send_rounded, color: Colors.white, size: 20))),
    ]));
}
