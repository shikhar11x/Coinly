import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/ui_kit.dart';
import 'chat_controller.dart';

/// Content never gets wider than this (tablets / Chrome).
const double _maxW = 560;

class AssistantScreen extends ConsumerWidget {
  const AssistantScreen({super.key});

  void _open(BuildContext context, [String? question]) {
    HapticFeedback.selectionClick();
    context.push('/assistant', extra: question);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chat = ref.watch(chatProvider);
    final last = chat.messages.isEmpty ? null : chat.messages.last;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: context.isDark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxW),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 130),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
                    child: Text('AI assistant', style: context.tt.headlineLarge),
                  ),

                  // ---------- Hero ----------
                  FadeSlideIn(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: HeroBackground(
                        child: Padding(
                          padding: const EdgeInsets.all(22),
                          child: SizedBox(
                            width: double.infinity,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const IconBadge(
                                  icon: Icons.auto_awesome_rounded,
                                  color: AppColors.purple,
                                  size: 54,
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Ask about\nyour money',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    height: 1.1,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.9,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  'Coinly reads your own transactions, '
                                  'budgets and accounts, and answers in '
                                  'plain words.',
                                  style: TextStyle(
                                    color: Colors.white60,
                                    fontSize: 13.5,
                                    height: 1.45,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Pressable(
                                  onTap: () => _open(context),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.09,
                                      ),
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.12,
                                        ),
                                      ),
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(
                                          Icons.chat_bubble_outline_rounded,
                                          color: Colors.white70,
                                          size: 20,
                                        ),
                                        SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            'Ask anything about your spending…',
                                            style: TextStyle(
                                              color: Colors.white70,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                        Icon(
                                          Icons.arrow_forward_rounded,
                                          color: AppColors.green,
                                          size: 20,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ---------- Continue ----------
                  if (last != null) ...[
                    const SizedBox(height: 16),
                    FadeSlideIn(
                      child: AppCard(
                        padding: const EdgeInsets.all(14),
                        onTap: () => _open(context),
                        child: Row(
                          children: [
                            const IconBadge(
                              icon: Icons.forum_outlined,
                              color: AppColors.blue,
                              size: 42,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Continue conversation',
                                    style: context.tt.titleSmall,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    last.text,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: context.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: context.muted,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // ---------- Suggestions ----------
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(
                      'TRY ASKING',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                        color: context.muted,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  for (var i = 0; i < kAssistantSuggestions.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: FadeSlideIn(
                        delay: Duration(milliseconds: 80 + 50 * i),
                        child: AppCard(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          onTap: () =>
                              _open(context, kAssistantSuggestions[i].$1),
                          child: Row(
                            children: [
                              IconBadge(
                                icon: kAssistantSuggestions[i].$2,
                                color: kAssistantSuggestions[i].$3,
                                size: 40,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  kAssistantSuggestions[i].$1,
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
                    ),

                  // ---------- Info ----------
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: context.cs.primaryContainer,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 18,
                          color: context.cs.onPrimaryContainer,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Each question uses one of your daily AI actions '
                            '(receipts, voice and chat share them). Your '
                            'data is sent to Google Gemini to answer.',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.4,
                              fontWeight: FontWeight.w600,
                              color: context.cs.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}