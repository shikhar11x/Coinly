import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/ui_helpers.dart';
import '../../core/ui_kit.dart';
import '../transactions/txn_models.dart';
import '../transactions/txn_providers.dart';
import 'budget_providers.dart';
import 'budget_sheet.dart';

/// Content never gets wider than this (tablets / Chrome).
const double _maxW = 560;

class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    final month = ref.read(selectedMonthProvider);
    ref.invalidate(categoriesProvider);
    ref.invalidate(budgetsProvider);
    ref.invalidate(monthTxnsProvider);
    try {
      await Future.wait([
        ref.read(categoriesProvider.future),
        ref.read(budgetsProvider.future),
        ref.read(monthTxnsProvider(month).future),
      ]);
    } catch (_) {
      // The screen shows its own error state.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cats = ref.watch(categoriesProvider);
    final budgets = ref.watch(budgetsProvider);
    final txns = ref.watch(selectedMonthTxnsProvider);

    final states = <AsyncValue<Object?>>[cats, budgets, txns];
    final failed = states.any((s) => !s.hasValue && s.hasError);
    final loading = states.any((s) => !s.hasValue && !s.hasError);

    Widget body;
    if (failed) {
      body = ErrorState(
        message: 'Could not load budgets.',
        onRetry: () {
          ref.invalidate(categoriesProvider);
          ref.invalidate(budgetsProvider);
          ref.invalidate(monthTxnsProvider);
        },
      );
    } else if (loading) {
      body = const _LoadingList();
    } else {
      body = RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: _Content(
          categories:
              cats.value!.where((c) => c.type == TxnType.expense).toList(),
          budgets: budgets.value!,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Budgets')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxW),
          child: body,
        ),
      ),
    );
  }
}

// ============================================================
// Content
// ============================================================

class _Content extends ConsumerWidget {
  const _Content({required this.categories, required this.budgets});

  final List<TxnCategory> categories;
  final List<Budget> budgets;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(selectedMonthProvider);
    final overall = ref.watch(overallBudgetProvider);
    final spent = ref.watch(monthSummaryProvider)?.expense ?? 0;
    final spendById = ref.watch(spendByCategoryIdProvider);

    final byCat = {
      for (final b in budgets)
        if (b.categoryId != null) b.categoryId!: b,
    };

    double ratioOf(TxnCategory c) {
      final b = byCat[c.id]!;
      return b.amount <= 0 ? 0 : (spendById[c.id] ?? 0) / b.amount;
    }

    // Categories that have a budget: most used first.
    final withBudget = categories.where((c) => byCat.containsKey(c.id)).toList()
      ..sort((a, b) => ratioOf(b).compareTo(ratioOf(a)));

    // The rest: biggest spenders first, then A-Z.
    final without = categories.where((c) => !byCat.containsKey(c.id)).toList()
      ..sort((a, b) {
        final bySpend =
            (spendById[b.id] ?? 0).compareTo(spendById[a.id] ?? 0);
        return bySpend != 0 ? bySpend : a.name.compareTo(b.name);
      });

    final categoryTotal = withBudget.fold<double>(
      0,
      (s, c) => s + byCat[c.id]!.amount,
    );
    final tooMuch = overall != null && categoryTotal > overall.amount;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
      children: [
        if (!isCurrentMonth(month)) _PastMonthNote(month: month),

        FadeSlideIn(
          child: _OverallCard(
            budget: overall,
            spent: spent,
            month: month,
            onEdit: () => showBudgetSheet(
              context,
              title: 'Monthly budget',
              existing: overall,
            ),
          ),
        ),

        if (tooMuch) ...[
          const SizedBox(height: 12),
          _WarningNote(
            text: 'Your category budgets add up to '
                '${moneyWhole.format(categoryTotal)}, which is more than your '
                'monthly budget of ${moneyWhole.format(overall.amount)}.',
          ),
        ],

        // ---------- Category budgets ----------
        const SizedBox(height: 24),
        const _SectionLabel('CATEGORY BUDGETS'),
        const SizedBox(height: 10),
        if (withBudget.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'No category budgets yet. Pick a category below to set a limit '
              'for it, e.g. Food or Shopping.',
              style: TextStyle(fontSize: 13, color: context.muted, height: 1.4),
            ),
          )
        else
          for (var i = 0; i < withBudget.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: FadeSlideIn(
                delay: Duration(milliseconds: 60 + 40 * (i < 6 ? i : 6)),
                child: _CategoryBudgetRow(
                  category: withBudget[i],
                  budget: byCat[withBudget[i].id]!,
                  spent: spendById[withBudget[i].id] ?? 0,
                  onTap: () => _openCategory(
                    context,
                    withBudget[i],
                    byCat[withBudget[i].id],
                  ),
                ),
              ),
            ),

        // ---------- Categories without a budget ----------
        if (without.isNotEmpty) ...[
          const SizedBox(height: 22),
          const _SectionLabel('ADD A CATEGORY BUDGET'),
          const SizedBox(height: 10),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < without.length; i++) ...[
                  _NoBudgetTile(
                    category: without[i],
                    spent: spendById[without[i].id] ?? 0,
                    onTap: () => _openCategory(context, without[i], null),
                  ),
                  if (i < without.length - 1)
                    const Divider(indent: 66, endIndent: 14),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  void _openCategory(BuildContext context, TxnCategory c, Budget? existing) {
    showBudgetSheet(
      context,
      title: '${c.name} budget',
      categoryId: c.id,
      existing: existing,
      icon: iconFromName(c.icon),
      color: colorFromHex(c.color),
    );
  }
}

// ============================================================
// Overall budget card
// ============================================================

class _OverallCard extends StatelessWidget {
  const _OverallCard({
    required this.budget,
    required this.spent,
    required this.month,
    required this.onEdit,
  });

  final Budget? budget;
  final double spent;
  final DateTime month;
  final VoidCallback onEdit;

  /// "At this pace..." line for the current month (null = don't show).
  ({String text, Color color})? _projection() {
    final b = budget;
    if (b == null || !isCurrentMonth(month) || spent <= 0) return null;

    final day = DateTime.now().day;
    if (day < 3) return null; // too early to say anything useful

    final days = DateTime(month.year, month.month + 1, 0).day;
    final projected = spent / day * days;

    if (projected > b.amount) {
      return (
        text: 'At this pace: ${moneyWhole.format(projected)} by month end '
            '(over budget)',
        color: AppColors.orange,
      );
    }
    return (
      text: 'On track: about ${moneyWhole.format(projected)} by month end',
      color: AppColors.green,
    );
  }

  @override
  Widget build(BuildContext context) {
    final b = budget;
    final raw = (b != null && b.amount > 0) ? spent / b.amount : 0.0;
    final color = b == null ? Colors.white54 : budgetColor(raw);
    final projection = _projection();

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: HeroBackground(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ---------- Title row ----------
                Row(
                  children: [
                    const Text(
                      'MONTHLY BUDGET',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
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
                      child: Text(
                        DateFormat('MMM y').format(month),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (b != null)
                      Pressable(
                        onTap: onEdit,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.edit_outlined,
                            color: Colors.white70,
                            size: 18,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 18),

                if (b == null)
                  _NoBudgetBody(spent: spent, onSet: onEdit)
                else
                  Row(
                    children: [
                      _Ring(ratio: raw, color: color),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                raw > 1
                                    ? 'Over by ${moneyWhole.format(spent - b.amount)}'
                                    : '${moneyWhole.format(b.amount - spent)} left',
                                style: TextStyle(
                                  color: color,
                                  fontSize: 26,
                                  height: 1.1,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.8,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'of ${moneyWhole.format(b.amount)} budget',
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${moneyWhole.format(spent)} spent',
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                if (projection != null) ...[
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: projection.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: projection.color.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.trending_up_rounded,
                          size: 18,
                          color: projection.color,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            projection.text,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NoBudgetBody extends StatelessWidget {
  const _NoBudgetBody({required this.spent, required this.onSet});

  final double spent;
  final VoidCallback onSet;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'No budget set',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          spent > 0
              ? 'You have spent ${moneyWhole.format(spent)} so far. '
                  'Set a limit to see how much is left.'
              : 'Set a limit and Coinly shows how much you have left to spend.',
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: onSet,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Set monthly budget'),
          style: FilledButton.styleFrom(minimumSize: const Size(0, 46)),
        ),
      ],
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({required this.ratio, required this.color});

  final double ratio;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      height: 100,
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
                strokeWidth: 10,
                strokeCap: StrokeCap.round,
                color: color,
                backgroundColor: Colors.white.withValues(alpha: 0.10),
              ),
            ),
            Text(
              '${(ratio * 100).round()}%',
              style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Category rows
// ============================================================

class _CategoryBudgetRow extends StatelessWidget {
  const _CategoryBudgetRow({
    required this.category,
    required this.budget,
    required this.spent,
    required this.onTap,
  });

  final TxnCategory category;
  final Budget budget;
  final double spent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final catColor = colorFromHex(category.color);
    final ratio = budget.amount <= 0 ? 0.0 : spent / budget.amount;
    final status = budgetColor(ratio);
    final left = budget.amount - spent;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            children: [
              IconBadge(
                icon: iconFromName(category.icon),
                color: catColor,
                size: 42,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${moneyWhole.format(spent)} of '
                      '${moneyWhole.format(budget.amount)}',
                      style: TextStyle(fontSize: 12, color: context.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: status.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${(ratio * 100).round()}%',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: status,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: ratio.clamp(0.0, 1.0)),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 8,
                color: status,
                backgroundColor: context.cs.outlineVariant,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              left >= 0
                  ? '${moneyWhole.format(left)} left'
                  : 'Over by ${moneyWhole.format(-left)}',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: left >= 0 ? context.muted : status,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoBudgetTile extends StatelessWidget {
  const _NoBudgetTile({
    required this.category,
    required this.spent,
    required this.onTap,
  });

  final TxnCategory category;
  final double spent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            IconBadge(
              icon: iconFromName(category.icon),
              color: colorFromHex(category.color),
              size: 38,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                category.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (spent > 0) ...[
              Text(
                '${moneyWhole.format(spent)} spent',
                style: TextStyle(fontSize: 12, color: context.muted),
              ),
              const SizedBox(width: 10),
            ],
            Icon(
              Icons.add_circle_outline_rounded,
              size: 20,
              color: context.cs.primary,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Small pieces
// ============================================================

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
          color: context.muted,
        ),
      ),
    );
  }
}

class _WarningNote extends StatelessWidget {
  const _WarningNote({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.orange.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 20,
            color: AppColors.orange,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12.5, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown when the dashboard's month switcher is on a past month.
class _PastMonthNote extends ConsumerWidget {
  const _PastMonthNote({required this.month});
  final DateTime month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
        decoration: BoxDecoration(
          color: context.cs.primaryContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(
              Icons.history_rounded,
              size: 18,
              color: context.cs.onPrimaryContainer,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Showing ${DateFormat('MMMM y').format(month)}',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: context.cs.onPrimaryContainer,
                ),
              ),
            ),
            TextButton(
              onPressed: () => ref.read(selectedMonthProvider.notifier).reset(),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
              child: const Text('This month'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingList extends StatelessWidget {
  const _LoadingList();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      children: const [
        Skeleton(height: 190, radius: 28),
        SizedBox(height: 24),
        Skeleton(width: 130, height: 12),
        SizedBox(height: 12),
        Skeleton(height: 92, radius: 24),
        SizedBox(height: 10),
        Skeleton(height: 92, radius: 24),
      ],
    );
  }
}