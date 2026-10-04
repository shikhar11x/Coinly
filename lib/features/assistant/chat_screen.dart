import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/ui_kit.dart';
import 'chat_controller.dart';

/// Content never gets wider than this (tablets / Chrome).
const double _maxW = 640;

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, this.initialQuestion});

  /// Sent automatically when the screen opens (from a suggestion).
  final String? initialQuestion;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    final q = widget.initialQuestion;
    if (q != null && q.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(chatProvider.notifier).send(q);
      });
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  /// [text] given = a chip was tapped; null = send what is typed.
  void _send([String? text]) {
    final q = (text ?? _input.text).trim();
    if (q.isEmpty) return;
    if (ref.read(chatProvider).sending) return;

    HapticFeedback.selectionClick();
    if (text == null) {
      _input.clear();
      setState(() => _hasText = false);
    }
    ref.read(chatProvider.notifier).send(q);
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatProvider);

    ref.listen<ChatState>(chatProvider, (prev, next) {
      if (prev == null ||
          prev.messages.length != next.messages.length ||
          prev.sending != next.sending) {
        _scrollToEnd();
      }
    });

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            const IconBadge(
              icon: Icons.auto_awesome_rounded,
              color: AppColors.purple,
              size: 34,
            ),
            const SizedBox(width: 10),
            Text('Coinly AI', style: context.tt.titleLarge),
          ],
        ),
        actions: [
          if (chat.messages.isNotEmpty)
            IconButton(
              tooltip: 'New chat',
              icon: const Icon(Icons.add_comment_outlined),
              onPressed: chat.sending
                  ? null
                  : () {
                      HapticFeedback.selectionClick();
                      ref.read(chatProvider.notifier).clear();
                    },
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxW),
          child: Column(
            children: [
              Expanded(
                child: chat.messages.isEmpty
                    ? _Welcome(onPick: _send)
                    : ListView.builder(
                        controller: _scroll,
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                        itemCount:
                            chat.messages.length + (chat.sending ? 1 : 0),
                        itemBuilder: (context, i) {
                          if (i == chat.messages.length) {
                            return const _TypingBubble();
                          }
                          final isLast = i == chat.messages.length - 1;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _MessageView(
                              message: chat.messages[i],
                              isLast: isLast && !chat.sending,
                              onFollowUp: _send,
                              onRetry: () =>
                                  ref.read(chatProvider.notifier).retry(),
                            ),
                          );
                        },
                      ),
              ),
              _InputBar(
                controller: _input,
                canSend: _hasText && !chat.sending,
                sending: chat.sending,
                remaining: chat.remaining,
                onChanged: (v) => setState(() => _hasText = v.trim().isNotEmpty),
                onSend: _send,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// Empty chat
// ============================================================

class _Welcome extends StatelessWidget {
  const _Welcome({required this.onPick});
  final void Function(String) onPick;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      children: [
        const Center(
          child: IconBadge(
            icon: Icons.auto_awesome_rounded,
            color: AppColors.purple,
            size: 64,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Ask about your money',
          textAlign: TextAlign.center,
          style: context.tt.headlineMedium,
        ),
        const SizedBox(height: 6),
        Text(
          'I answer from your own transactions, budgets and accounts.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, height: 1.4, color: context.muted),
        ),
        const SizedBox(height: 24),
        for (final s in kAssistantSuggestions)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              onTap: () => onPick(s.$1),
              child: Row(
                children: [
                  IconBadge(icon: s.$2, color: s.$3, size: 38),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      s.$1,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ============================================================
// Messages
// ============================================================

class _MessageView extends StatelessWidget {
  const _MessageView({
    required this.message,
    required this.isLast,
    required this.onFollowUp,
    required this.onRetry,
  });

  final ChatMessage message;
  final bool isLast;
  final void Function(String) onFollowUp;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final maxW = MediaQuery.sizeOf(context).width.clamp(0.0, _maxW) * 0.84;

    if (message.role == 'user') {
      return Align(
        alignment: Alignment.centerRight,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxW),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: AppColors.green,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(6),
              ),
            ),
            child: SelectableText(
              message.text,
              style: const TextStyle(
                color: AppColors.dark,
                fontSize: 14.5,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );
    }

    final isError = message.isError;
    final bubbleColor =
        isError ? AppColors.red.withValues(alpha: 0.10) : context.cs.surface;
    final borderColor =
        isError ? AppColors.red.withValues(alpha: 0.35) : context.cs.outline;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconBadge(
          icon: isError
              ? Icons.error_outline_rounded
              : Icons.auto_awesome_rounded,
          color: isError ? AppColors.red : AppColors.purple,
          size: 30,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxW),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      border: Border.all(color: borderColor),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(6),
                        topRight: Radius.circular(20),
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                      ),
                    ),
                    child: SelectableText(
                      message.text,
                      style: const TextStyle(fontSize: 14.5, height: 1.45),
                    ),
                  ),
                  if (isError && isLast)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: TextButton.icon(
                        onPressed: onRetry,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Try again'),
                      ),
                    ),
                  if (!isError && isLast && message.followUps.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final f in message.followUps)
                            ActionChip(
                              label: Text(f),
                              onPressed: () => onFollowUp(f),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Three bouncing dots while the assistant is thinking.
class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const IconBadge(
            icon: Icons.auto_awesome_rounded,
            color: AppColors.purple,
            size: 30,
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: context.cs.surface,
              border: Border.all(color: context.cs.outline),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(6),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < 3; i++)
                    Container(
                      width: 7,
                      height: 7,
                      margin: EdgeInsets.only(right: i < 2 ? 5 : 0),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: context.muted.withValues(
                          alpha: 0.25 +
                              0.65 *
                                  ((math.sin(
                                            2 * math.pi * (_c.value - i * 0.18),
                                          ) +
                                          1) /
                                      2),
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

// ============================================================
// Input bar
// ============================================================

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.canSend,
    required this.sending,
    required this.remaining,
    required this.onChanged,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool canSend;
  final bool sending;
  final int? remaining;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final caption = remaining == null
        ? 'Answers come from your own data. AI can make mistakes.'
        : remaining == 0
            ? 'No AI actions left today. AI can make mistakes.'
            : '$remaining AI actions left today • AI can make mistakes.';

    return Container(
      decoration: BoxDecoration(
        color: context.cs.surface,
        border: Border(top: BorderSide(color: context.cs.outline)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    maxLength: 400,
                    textInputAction: TextInputAction.send,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: onChanged,
                    onSubmitted: (_) => onSend(),
                    decoration: InputDecoration(
                      hintText: 'Ask about your spending…',
                      counterText: '',
                      fillColor: context.cs.surfaceContainerHighest,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Pressable(
                  onTap: canSend ? onSend : null,
                  haptic: false, // _send() already vibrates
                  scale: 0.92,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: canSend || sending
                          ? AppColors.green
                          : context.cs.outline,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Center(
                      child: sending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: AppColors.dark,
                              ),
                            )
                          : const Icon(
                              Icons.arrow_upward_rounded,
                              color: AppColors.dark,
                            ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              caption,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: context.muted),
            ),
          ],
        ),
      ),
    );
  }
}