import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/nav.dart';
import '../../core/theme.dart';
import '../../core/ui_kit.dart';

/// Content never gets wider than this (tablets / Chrome).
const double _maxW = 560;

const _samples = [
  (
    'How much did I spend on food this month?',
    Icons.restaurant_rounded,
    AppColors.red,
  ),
  (
    'Am I on track with my budget?',
    Icons.track_changes_rounded,
    AppColors.green,
  ),
  (
    'What was my biggest expense this week?',
    Icons.trending_up_rounded,
    AppColors.orange,
  ),
  (
    'Compare this month with last month',
    Icons.compare_arrows_rounded,
    AppColors.blue,
  ),
];

class AssistantScreen extends ConsumerWidget {
  const AssistantScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                  // ---------- Title ----------
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
                    child: Row(
                      children: [
                        Text('AI assistant', style: context.tt.headlineLarge),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: context.cs.primaryContainer,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Soon',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: context.cs.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
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
                                  'Soon you can chat with Coinly about your '
                                  'own spending and get answers from your '
                                  'real transactions.',
                                  style: TextStyle(
                                    color: Colors.white60,
                                    fontSize: 13.5,
                                    height: 1.45,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ---------- Sample questions ----------
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(
                      'YOU WILL BE ABLE TO ASK',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                        color: context.muted,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  for (var i = 0; i < _samples.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: FadeSlideIn(
                        delay: Duration(milliseconds: 80 + 60 * i),
                        child: AppCard(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          onTap: () {
                            HapticFeedback.selectionClick();
                            ScaffoldMessenger.of(context)
                              ..hideCurrentSnackBar()
                              ..showSnackBar(
                                const SnackBar(
                                  content:
                                      Text('The assistant is coming soon.'),
                                ),
                              );
                          },
                          child: Row(
                            children: [
                              IconBadge(
                                icon: _samples[i].$2,
                                color: _samples[i].$3,
                                size: 40,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _samples[i].$1,
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

                  // ---------- Meanwhile ----------
                  const SizedBox(height: 14),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 360),
                    child: AppCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Meanwhile', style: context.tt.titleSmall),
                          const SizedBox(height: 4),
                          Text(
                            'Your dashboard already shows your daily average, '
                            'top category and budget.',
                            style: TextStyle(
                              fontSize: 12.5,
                              height: 1.4,
                              color: context.muted,
                            ),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () =>
                                ref.read(tabIndexProvider.notifier).set(0),
                            icon: const Icon(Icons.home_outlined, size: 18),
                            label: const Text('Open dashboard'),
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
    );
  }
}