import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../voice/voice_flow.dart';
import '../receipt/scan_flow.dart';
import '../../core/nav.dart';
import '../../core/theme.dart';
import '../accounts/accounts_providers.dart';
import '../auth/auth_providers.dart';
import '../budgets/budget_providers.dart';
import '../budgets/budget_sheet.dart';
import '../transactions/txn_models.dart';
import '../transactions/txn_providers.dart';
import '../transactions/txn_tile.dart';

// Indian-style formatting: ₹2,36,310
final _money = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 0,
);

String _greeting() {
  final h = DateTime.now().hour;
  if (h < 12) return 'Good morning';
  if (h < 17) return 'Good afternoon';
  return 'Good evening';
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          const _Header(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            child: Column(
              children: const [
                _AskAiBar(),
                SizedBox(height: 16),
                _BudgetCard(),
                SizedBox(height: 16),
                _BreakdownCard(),
                SizedBox(height: 16),
                _RecentTransactions(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ======================= HEADER =======================
class _Header extends ConsumerWidget {
  const _Header();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final top = MediaQuery.of(context).padding.top;

    // Real name from the `profiles` table (empty while loading).
    final fullName = ref
        .watch(profileProvider)
        .maybeWhen(
          data: (p) => (p?['name'] as String?) ?? '',
          orElse: () => '',
        );
    final firstName = fullName.trim().split(' ').first;

    // Real total of all accounts (null while loading).
    final total = ref.watch(totalBalanceProvider);

    // Real income / expense for this month (null while loading).
    final summary = ref.watch(monthSummaryProvider);

    return Container(
      padding: EdgeInsets.fromLTRB(20, top + 16, 20, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.dark2, AppColors.dark],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: app name + greeting + avatar
          Row(
            children: [
              const Text(
                'Coinly',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _greeting(),
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                  Text(
                    firstName.isEmpty ? 'there' : firstName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              const CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.dark3,
                child: Icon(Icons.person, color: Colors.white70, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Total balance (tap to manage accounts)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => context.push('/accounts'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Text(
                      'Total balance',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    SizedBox(width: 2),
                    Icon(Icons.chevron_right, color: Colors.white54, size: 16),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  total == null ? '—' : _money.format(total),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Income / expense this month
          Row(
            children: [
              _MiniStat(
                icon: Icons.arrow_upward,
                color: AppColors.green,
                value: _money.format(summary?.income ?? 0),
              ),
              const SizedBox(width: 16),
              _MiniStat(
                icon: Icons.arrow_downward,
                color: AppColors.red,
                value: _money.format(summary?.expense ?? 0),
              ),
              const SizedBox(width: 8),
              const Text(
                'this month',
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Quick actions panel
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.dark3,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _QuickAction(
                  icon: Icons.document_scanner_outlined,
                  label: 'AI Receipt Scan',
                  color: AppColors.blue,
                  onTap: () => startReceiptScan(context, ref),
                ),
                _QuickAction(
                  icon: Icons.mic_none,
                  label: 'Voice Entry',
                  color: AppColors.red,
                  onTap: () => startVoiceEntry(context, ref),
                ),
                _QuickAction(
                  icon: Icons.add,
                  label: 'Add Manually',
                  color: AppColors.green,
                  onTap: () => context.push('/transaction'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.icon,
    required this.color,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

// ======================= WHITE CARD BASE =======================
// One reusable card so all sections look consistent.
class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ======================= ASK AI BAR =======================
class _AskAiBar extends StatelessWidget {
  const _AskAiBar();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {}, // opens AI assistant later
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.auto_awesome, color: AppColors.purple, size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Ask AI anything about your money',
                  style: TextStyle(color: Colors.black54, fontSize: 13),
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.black38),
            ],
          ),
        ),
      ),
    );
  }
}

// ======================= BUDGET CARD =======================
class _BudgetCard extends ConsumerWidget {
  const _BudgetCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetsAsync = ref.watch(budgetsProvider);
    final overall = ref.watch(overallBudgetProvider);
    final spent = ref.watch(monthSummaryProvider)?.expense ?? 0;

    void edit() =>
        showBudgetSheet(context, title: 'Monthly budget', existing: overall);

    Widget content;

    if (!budgetsAsync.hasValue) {
      content = budgetsAsync.hasError
          ? const Text(
              'Could not load your budget.',
              style: TextStyle(color: Colors.black54),
            )
          : const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(),
            );
    } else if (overall == null) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Set a monthly budget to see how much you have left to spend.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: edit,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Set monthly budget'),
          ),
        ],
      );
    } else {
      final ratio = spent / overall.amount;
      final color = budgetColor(ratio);
      final diff = (overall.amount - spent).abs();

      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0),
              minHeight: 8,
              color: color,
              backgroundColor: Colors.black12,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_money.format(spent)} of ${_money.format(overall.amount)} spent '
            '(${(ratio * 100).round()}%)',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 2),
          Text(
            ratio > 1
                ? '${_money.format(diff)} over budget'
                : '${_money.format(diff)} left this month',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      );
    }

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Monthly budget',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              InkWell(
                onTap: () => context.push('/budgets'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    'Categories',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
              if (overall != null) ...[
                const SizedBox(width: 12),
                InkWell(
                  onTap: edit,
                  borderRadius: BorderRadius.circular(12),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(
                      Icons.edit_outlined,
                      size: 16,
                      color: Colors.black38,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          content,
        ],
      ),
    );
  }
}

// ======================= EXPENSE BREAKDOWN =======================
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
    final summary = ref.watch(monthSummaryProvider);
    final items = _topWithOther(summary?.byCategory ?? const []);

    Widget content;
    if (summary == null) {
      content = const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (items.isEmpty) {
      content = const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'No expenses yet this month.',
          style: TextStyle(color: Colors.black54),
        ),
      );
    } else {
      content = Row(
        children: [
          SizedBox(
            width: 130,
            height: 130,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 0,
                sections: [
                  for (final c in items)
                    PieChartSectionData(
                      value: c.amount,
                      color: c.color,
                      radius: 65,
                      showTitle: false,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              children: [
                for (final c in items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: c.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            c.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        Text(
                          _money.format(c.amount),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
    }

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Expense breakdown (this month)',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          content,
        ],
      ),
    );
  }
}

// ======================= RECENT TRANSACTIONS =======================
class _RecentTransactions extends ConsumerWidget {
  const _RecentTransactions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(transactionsProvider);
    final recent = (async.value ?? const <Txn>[]).take(5).toList();

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Recent transactions',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              InkWell(
                onTap: () => ref.read(tabIndexProvider.notifier).set(1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    'See all',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (recent.isEmpty && async.isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (recent.isEmpty && async.hasError)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Could not load transactions.',
                style: TextStyle(color: Colors.black54),
              ),
            )
          else if (recent.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'No transactions yet. Tap + to add your first one.',
                style: TextStyle(color: Colors.black54),
              ),
            )
          else
            for (final t in recent)
              TxnTile(
                txn: t,
                onTap: () => context.push('/transaction', extra: t),
              ),
        ],
      ),
    );
  }
}
