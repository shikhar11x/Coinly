import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/format.dart';
import '../../core/nav.dart';
import '../../core/theme.dart';
import '../../core/ui_kit.dart';
import '../accounts/accounts_providers.dart';
import '../auth/auth_providers.dart';
import '../budgets/budget_providers.dart';
import '../budgets/budget_sheet.dart';
import '../receipt/scan_flow.dart';
import '../transactions/txn_models.dart';
import '../transactions/txn_providers.dart';
import '../transactions/txn_tile.dart';
import '../voice/voice_flow.dart';

/// Content never gets wider than this (tablets / Chrome).
const double _maxW = 640;

String _greeting() {
  final h = DateTime.now().hour;
  if (h < 12) return 'Good morning';
  if (h < 17) return 'Good afternoon';
  return 'Good evening';
}

// ============================================================
// SCREEN
// ============================================================

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    final month = ref.read(selectedMonthProvider);

    ref.invalidate(accountsProvider);
    ref.invalidate(transactionsProvider);
    ref.invalidate(monthTxnsProvider);
    ref.invalidate(budgetsProvider);
    ref.invalidate(profileProvider);
    try {
      await Future.wait([
        ref.read(accountsProvider.future),
        ref.read(transactionsProvider.future),
        ref.read(monthTxnsProvider(month).future),
        ref.read(budgetsProvider.future),
      ]);
    } catch (_) {
      // Each card shows its own error state.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final needsAccount = ref.watch(accountsProvider).value?.isEmpty ?? false;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // The header is always dark, so status bar icons must be light.
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: RefreshIndicator(
          onRefresh: () => _refresh(ref),
          edgeOffset: MediaQuery.of(context).padding.top,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            children: [
              const _Header(),
              Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _maxW),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 130),
                    child: Column(
                      children: [
                        if (needsAccount) ...[
                          const FadeSlideIn(child: _SetupCard()),
                          const SizedBox(height: 14),
                        ],
                        const FadeSlideIn(
                          delay: Duration(milliseconds: 60),
                          child: _AskAiBar(),
                        ),
                        const SizedBox(height: 14),
                        const FadeSlideIn(
                          delay: Duration(milliseconds: 120),
                          child: _BentoRow(),
                        ),
                        const SizedBox(height: 14),
                        const FadeSlideIn(
                          delay: Duration(milliseconds: 180),
                          child: _BreakdownCard(),
                        ),
                        const SizedBox(height: 14),
                        const FadeSlideIn(
                          delay: Duration(milliseconds: 240),
                          child: _RecentCard(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// HEADER
// ============================================================

class _Header extends ConsumerWidget {
  const _Header();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final top = MediaQuery.of(context).padding.top;

    final name = ref.watch(profileProvider).maybeWhen(
          data: (p) => ((p?['name'] as String?) ?? '').trim(),
          orElse: () => '',
        );
    final firstName = name.isEmpty ? 'there' : name.split(' ').first;
    final initial = name.isEmpty ? null : name[0].toUpperCase();

    final total = ref.watch(totalBalanceProvider);
    final accountCount = ref.watch(accountsProvider).value?.length;

    final month = ref.watch(selectedMonthProvider);
    final summary = ref.watch(monthSummaryProvider);
    final txnsAsync = ref.watch(selectedMonthTxnsProvider);
    final txnsFailed = !txnsAsync.hasValue && txnsAsync.hasError;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(36)),
      child: HeroBackground(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, top + 16, 20, 22),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxW),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ---------- Top row ----------
                  Row(
                    children: [
                      Pressable(
                        onTap: () => ref.read(tabIndexProvider.notifier).set(3),
                        child: _Avatar(initial: initial),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _greeting(),
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              firstName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _HeaderIconButton(
                        icon: Icons.pie_chart_outline_rounded,
                        onTap: () => context.push('/budgets'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 26),

                  // ---------- Balance ----------
                  Pressable(
                    scale: 0.98,
                    onTap: () => context.push('/accounts'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'TOTAL BALANCE',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                              ),
                            ),
                            if (accountCount != null) ...[
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '$accountCount '
                                      '${accountCount == 1 ? 'account' : 'accounts'}',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 2),
                                    const Icon(
                                      Icons.chevron_right_rounded,
                                      color: Colors.white54,
                                      size: 14,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (total == null)
                          const _DarkSkeleton(width: 200, height: 42, radius: 14)
                        else
                          AmountText(
                            total,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 42,
                              height: 1.0,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1.8,
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ---------- Month switcher ----------
                  Row(
                    children: [
                      Expanded(
                        child: _MonthCaption(current: isCurrentMonth(month)),
                      ),
                      const SizedBox(width: 8),
                      const _MonthSwitcher(),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // ---------- Income / Spent ----------
                  Row(
                    children: [
                      Expanded(
                        child: _StatPill(
                          icon: Icons.south_west_rounded,
                          color: AppColors.green,
                          label: 'Income',
                          value: summary?.income,
                          failed: txnsFailed,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatPill(
                          icon: Icons.north_east_rounded,
                          color: AppColors.red,
                          label: 'Spent',
                          value: summary?.expense,
                          failed: txnsFailed,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // ---------- Quick actions ----------
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.07),
                      ),
                    ),
                    child: Row(
                      children: [
                        _QuickAction(
                          icon: Icons.document_scanner_outlined,
                          label: 'Scan receipt',
                          color: AppColors.blue,
                          onTap: () => startReceiptScan(context, ref),
                        ),
                        _QuickAction(
                          icon: Icons.mic_none_rounded,
                          label: 'Voice entry',
                          color: AppColors.red,
                          onTap: () => startVoiceEntry(context, ref),
                        ),
                        _QuickAction(
                          icon: Icons.add_rounded,
                          label: 'Add manually',
                          color: AppColors.green,
                          onTap: () => context.push('/transaction'),
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

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initial});
  final String? initial;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.green.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.green.withValues(alpha: 0.35)),
      ),
      child: initial == null
          ? const Icon(Icons.person_rounded, color: AppColors.green, size: 22)
          : Text(
              initial!,
              style: const TextStyle(
                color: AppColors.green,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
        ),
        child: Icon(icon, color: Colors.white70, size: 22),
      ),
    );
  }
}

/// Skeleton that is visible on the dark header.
class _DarkSkeleton extends StatelessWidget {
  const _DarkSkeleton({
    required this.width,
    required this.height,
    this.radius = 10,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Theme(
      data: t.copyWith(
        colorScheme: t.colorScheme.copyWith(onSurface: Colors.white),
      ),
      child: Skeleton(width: width, height: height, radius: radius),
    );
  }
}

// ---------- Month switcher ----------

/// Left side of the month row: "THIS MONTH", or a link back to it.
class _MonthCaption extends ConsumerWidget {
  const _MonthCaption({required this.current});
  final bool current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (current) {
      return const Text(
        'THIS MONTH',
        style: TextStyle(
          color: Colors.white38,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Pressable(
        onTap: () => ref.read(selectedMonthProvider.notifier).reset(),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.undo_rounded, size: 14, color: AppColors.green),
            SizedBox(width: 5),
            Flexible(
              child: Text(
                'Back to this month',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.green,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthSwitcher extends ConsumerWidget {
  const _MonthSwitcher();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(selectedMonthProvider);
    final notifier = ref.read(selectedMonthProvider.notifier);
    final current = isCurrentMonth(month);

    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MonthChevron(
            icon: Icons.chevron_left_rounded,
            onTap: notifier.previous,
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 66),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Text(
                  DateFormat('MMM y').format(month),
                  key: ValueKey(month),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          // Can't go past the current month.
          _MonthChevron(
            icon: Icons.chevron_right_rounded,
            onTap: current ? null : notifier.next,
          ),
        ],
      ),
    );
  }
}

class _MonthChevron extends StatelessWidget {
  const _MonthChevron({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final child = SizedBox(
      width: 38,
      height: 40,
      child: Icon(
        icon,
        size: 22,
        color: onTap == null ? Colors.white24 : Colors.white70,
      ),
    );

    if (onTap == null) return child;
    return Pressable(onTap: onTap, scale: 0.88, child: child);
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.failed = false,
  });

  final IconData icon;
  final Color color;
  final String label;
  final double? value; // null while loading
  final bool failed;

  @override
  Widget build(BuildContext context) {
    Widget amount;
    if (failed) {
      amount = const Text(
        '—',
        style: TextStyle(
          color: Colors.white54,
          fontSize: 17,
          fontWeight: FontWeight.w800,
        ),
      );
    } else if (value == null) {
      amount = const _DarkSkeleton(width: 64, height: 16, radius: 6);
    } else {
      amount = FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: AmountText(
          value!,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: color, size: 17),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                amount,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Pressable(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 23),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// SETUP CARD (shown only when there are no accounts)
// ============================================================

class _SetupCard extends StatelessWidget {
  const _SetupCard();

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: () => context.push('/accounts'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.green.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.green.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            const IconBadge(
              icon: Icons.account_balance_wallet_outlined,
              color: AppColors.green,
              size: 44,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Add your first account', style: context.tt.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    'You need one before you can record transactions.',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.muted,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_rounded, size: 20, color: context.muted),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// ASK AI
// ============================================================

class _AskAiBar extends ConsumerWidget {
  const _AskAiBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Pressable(
      onTap: () => ref.read(tabIndexProvider.notifier).set(2),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            const IconBadge(
              icon: Icons.auto_awesome_rounded,
              color: AppColors.purple,
              size: 42,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ask Coinly AI', style: context.tt.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    'Get insights about your spending',
                    style: TextStyle(fontSize: 12, color: context.muted),
                  ),
                ],
              ),
            ),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: context.cs.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.arrow_forward_rounded,
                size: 16,
                color: context.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// BENTO ROW: budget ring + insights
// ============================================================

class _BentoRow extends StatelessWidget {
  const _BentoRow();

  @override
  Widget build(BuildContext context) {
    return const IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _BudgetTile()),
          SizedBox(width: 12),
          Expanded(child: _InsightsTile()),
        ],
      ),
    );
  }
}

class _BudgetTile extends ConsumerWidget {
  const _BudgetTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final muted = context.muted;
    final budgetsAsync = ref.watch(budgetsProvider);
    final b = ref.watch(overallBudgetProvider);
    final txnsAsync = ref.watch(selectedMonthTxnsProvider);
    final spent = ref.watch(monthSummaryProvider)?.expense ?? 0;

    final budgetsLoading = !budgetsAsync.hasValue && !budgetsAsync.hasError;
    final budgetsFailed = !budgetsAsync.hasValue && budgetsAsync.hasError;
    final spendLoading = !txnsAsync.hasValue && !txnsAsync.hasError;
    final spendFailed = !txnsAsync.hasValue && txnsAsync.hasError;

    // Without a budget we don't need the spending numbers at all.
    final loading = budgetsLoading || (b != null && spendLoading);
    final failed = budgetsFailed || (b != null && spendFailed);

    final raw = (b != null && b.amount > 0) ? spent / b.amount : 0.0;
    final color = b == null ? muted : budgetColor(raw);

    Widget ring;
    if (loading) {
      ring = const Skeleton(width: 92, height: 92, radius: 46);
    } else if (b == null || failed) {
      ring = _EmptyRing(
        icon: failed ? Icons.cloud_off_rounded : Icons.add_rounded,
      );
    } else {
      ring = _ProgressRing(ratio: raw, color: color);
    }

    Widget label;
    if (loading) {
      label = const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Skeleton(width: 72, height: 14),
          SizedBox(height: 6),
          Skeleton(width: 48, height: 11),
        ],
      );
    } else {
      final String main;
      final String sub;
      if (failed) {
        main = 'Could not load';
        sub = 'Pull down to retry';
      } else if (b == null) {
        main = 'No budget set';
        sub = 'Tap to set one';
      } else {
        final diff = (b.amount - spent).abs();
        main = raw > 1
            ? 'Over by ${moneyWhole.format(diff)}'
            : '${moneyWhole.format(diff)} left';
        sub = 'of ${moneyWhole.format(b.amount)}';
      }
      label = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            main,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: (b == null || failed) ? null : color,
            ),
          ),
          const SizedBox(height: 2),
          Text(sub, style: TextStyle(fontSize: 12, color: muted)),
        ],
      );
    }

    return Pressable(
      onTap: () {
        if (b == null && !loading && !failed) {
          showBudgetSheet(context, title: 'Monthly budget', existing: null);
        } else {
          context.push('/budgets');
        }
      },
      child: AppCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconBadge(
                  icon: Icons.track_changes_rounded,
                  color: color,
                  size: 34,
                ),
                const Spacer(),
                Text(
                  'Budget',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: muted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Center(child: ring),
            const SizedBox(height: 14),
            label,
          ],
        ),
      ),
    );
  }
}

class _ProgressRing extends StatelessWidget {
  const _ProgressRing({required this.ratio, required this.color});

  final double ratio;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      height: 92,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: ratio.clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.expand(
              child: CircularProgressIndicator(
                value: v,
                strokeWidth: 9,
                strokeCap: StrokeCap.round,
                color: color,
                backgroundColor: color.withValues(alpha: 0.14),
              ),
            ),
            Text(
              '${(ratio * 100).round()}%',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyRing extends StatelessWidget {
  const _EmptyRing({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92,
      height: 92,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: context.cs.outline, width: 2),
      ),
      child: Icon(icon, size: 28, color: context.muted),
    );
  }
}

class _InsightsTile extends ConsumerWidget {
  const _InsightsTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(selectedMonthProvider);
    final txnsAsync = ref.watch(selectedMonthTxnsProvider);
    final failed = !txnsAsync.hasValue && txnsAsync.hasError;

    final summary = ref.watch(monthSummaryProvider);
    final avg = summary == null ? null : summary.expense / daysInView(month);
    final top = (summary != null && summary.byCategory.isNotEmpty)
        ? summary.byCategory.first
        : null;

    const dash = Text(
      '—',
      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
    );

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconBadge(
                icon: Icons.insights_rounded,
                color: AppColors.blue,
                size: 34,
              ),
              const Spacer(),
              Text(
                'Insights',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Daily average
          _InsightStat(
            label: 'Daily average',
            sub: isCurrentMonth(month)
                ? 'so far this month'
                : 'for the whole month',
            value: failed
                ? dash
                : avg == null
                    ? const Skeleton(width: 84, height: 22)
                    : FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: AmountText(
                          avg,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ),
          ),

          const Divider(height: 26),

          // Top category
          _InsightStat(
            label: 'Top category',
            sub: summary == null
                ? ' '
                : top == null
                    ? 'No expenses yet'
                    : moneyWhole.format(top.amount),
            value: failed
                ? dash
                : summary == null
                    ? const Skeleton(width: 84, height: 22)
                    : top == null
                        ? dash
                        : Row(
                            children: [
                              Container(
                                width: 9,
                                height: 9,
                                decoration: BoxDecoration(
                                  color: top.color,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                              const SizedBox(width: 7),
                              Flexible(
                                child: Text(
                                  top.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
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

class _InsightStat extends StatelessWidget {
  const _InsightStat({
    required this.label,
    required this.value,
    required this.sub,
  });

  final String label;
  final Widget value;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: context.muted)),
        const SizedBox(height: 4),
        value,
        const SizedBox(height: 3),
        Text(sub, style: TextStyle(fontSize: 11, color: context.muted)),
      ],
    );
  }
}

// ============================================================
// EXPENSE BREAKDOWN
// ============================================================

/// Top [top] categories, with everything smaller grouped as "Other".
List<CategorySpend> _topWithOther(List<CategorySpend> all, {int top = 5}) {
  if (all.length <= top + 1) return all;
  final head = all.take(top).toList();
  final rest = all.skip(top).fold<double>(0, (s, c) => s + c.amount);
  return [...head, CategorySpend('Other', rest, const Color(0xFF90A4AE))];
}

class _BreakdownCard extends ConsumerWidget {
  const _BreakdownCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(selectedMonthProvider);
    final txnsAsync = ref.watch(selectedMonthTxnsProvider);
    final failed = !txnsAsync.hasValue && txnsAsync.hasError;

    final summary = ref.watch(monthSummaryProvider);
    final items = _topWithOther(summary?.byCategory ?? const []);
    final total = items.fold<double>(0, (s, c) => s + c.amount);

    Widget body;
    if (failed) {
      body = const _EmptyBlock(
        icon: Icons.cloud_off_rounded,
        title: 'Could not load',
        subtitle: 'Pull down to try again.',
      );
    } else if (summary == null) {
      body = const _BreakdownSkeleton();
    } else if (items.isEmpty) {
      body = _EmptyBlock(
        icon: Icons.pie_chart_outline_rounded,
        title: 'No expenses',
        subtitle: isCurrentMonth(month)
            ? 'Your spending this month will show up here.'
            : 'No expenses in ${DateFormat('MMMM y').format(month)}.',
      );
    } else {
      body = LayoutBuilder(
        builder: (context, c) {
          final chart = _Donut(items: items, total: total);
          final legend = _Legend(items: items, total: total);

          if (c.maxWidth < 300) {
            return Column(children: [chart, const SizedBox(height: 18), legend]);
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              chart,
              const SizedBox(width: 18),
              Expanded(child: legend),
            ],
          );
        },
      );
    }

    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Where your money went',
                        style: context.tt.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      'Expenses by category',
                      style: TextStyle(fontSize: 12, color: context.muted),
                    ),
                  ],
                ),
              ),
              _Pill(
                label: isCurrentMonth(month)
                    ? 'This month'
                    : DateFormat('MMM y').format(month),
              ),
            ],
          ),
          const SizedBox(height: 20),
          body,
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: context.cs.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: context.cs.onPrimaryContainer,
        ),
      ),
    );
  }
}

class _Donut extends StatelessWidget {
  const _Donut({required this.items, required this.total});

  final List<CategorySpend> items;
  final double total;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 130,
      height: 130,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              sectionsSpace: 3,
              centerSpaceRadius: 42,
              borderData: FlBorderData(show: false),
              sections: [
                for (final c in items)
                  PieChartSectionData(
                    value: c.amount,
                    color: c.color,
                    radius: 22,
                    showTitle: false,
                  ),
              ],
            ),
          ),
          SizedBox(
            width: 78,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Spent',
                    style: TextStyle(fontSize: 11, color: context.muted),
                  ),
                  AmountText(
                    total,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
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

class _Legend extends StatelessWidget {
  const _Legend({required this.items, required this.total});

  final List<CategorySpend> items;
  final double total;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final c in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: c.color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${total > 0 ? (c.amount / total * 100).round() : 0}%',
                        style: TextStyle(fontSize: 10.5, color: context.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  moneyWhole.format(c.amount),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _BreakdownSkeleton extends StatelessWidget {
  const _BreakdownSkeleton();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Skeleton(width: 130, height: 130, radius: 65),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < 4; i++)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 7),
                  child: Skeleton(height: 14),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================
// RECENT TRANSACTIONS (always the latest 5, any month)
// ============================================================

class _RecentCard extends ConsumerWidget {
  const _RecentCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(transactionsProvider);
    final recent = (async.value ?? const <Txn>[]).take(5).toList();

    Widget body;
    if (recent.isEmpty && async.isLoading) {
      body = Column(
        children: [
          for (var i = 0; i < 3; i++) ...[
            const _TxnSkeleton(),
            if (i < 2) const Divider(),
          ],
        ],
      );
    } else if (recent.isEmpty && async.hasError) {
      body = const _EmptyBlock(
        icon: Icons.cloud_off_rounded,
        title: 'Could not load transactions',
        subtitle: 'Pull down to try again.',
      );
    } else if (recent.isEmpty) {
      body = _EmptyBlock(
        icon: Icons.receipt_long_outlined,
        title: 'No transactions yet',
        subtitle: 'Scan a receipt, say it, or type it in.',
        action: FilledButton.icon(
          onPressed: () => context.push('/transaction'),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Add transaction'),
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
        ),
      );
    } else {
      body = Column(
        children: [
          for (var i = 0; i < recent.length; i++) ...[
            TxnTile(
              txn: recent[i],
              onTap: () => context.push('/transaction', extra: recent[i]),
            ),
            if (i < recent.length - 1) const Divider(),
          ],
        ],
      );
    }

    return AppCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconBadge(
                icon: Icons.receipt_long_rounded,
                color: AppColors.greenDark,
                size: 40,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Recent transactions', style: context.tt.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      'Your latest activity',
                      style: TextStyle(fontSize: 12, color: context.muted),
                    ),
                  ],
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => ref.read(tabIndexProvider.notifier).set(1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'See all',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: context.cs.primary,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 14,
                        color: context.cs.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(),
          body,
        ],
      ),
    );
  }
}

class _TxnSkeleton extends StatelessWidget {
  const _TxnSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Skeleton(width: 40, height: 40, radius: 13),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Skeleton(width: 130, height: 13),
                SizedBox(height: 8),
                Skeleton(width: 90, height: 11),
              ],
            ),
          ),
          SizedBox(width: 8),
          Skeleton(width: 56, height: 14),
        ],
      ),
    );
  }
}

// ============================================================
// EMPTY BLOCK
// ============================================================

class _EmptyBlock extends StatelessWidget {
  const _EmptyBlock({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 22),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: context.cs.primaryContainer,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: context.cs.onPrimaryContainer, size: 26),
            ),
            const SizedBox(height: 12),
            Text(title, style: context.tt.titleSmall),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: context.muted, height: 1.4),
            ),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}