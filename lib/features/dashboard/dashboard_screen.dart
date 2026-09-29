import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/nav.dart';
import '../../core/theme.dart';
import '../accounts/accounts_providers.dart';
import '../auth/auth_providers.dart';
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

// ---------- Sample data (replaced in Step 6) ----------
const _sampleCategories = [
  ('Transport', 19087.0, Color(0xFF26A69A)),
  ('Groceries', 16457.0, Color(0xFF66BB6A)),
  ('Food & Dining', 14841.0, Color(0xFFEF5350)),
  ('Entertainment', 14602.0, Color(0xFFFF7043)),
  ('Utilities', 11538.0, Color(0xFF42A5F5)),
  ('Shopping', 10280.0, Color(0xFFAB47BC)),
];

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
                _BudgetCard(spent: 64320, budget: 80000),
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
                  onTap: () {}, // Step 7
                ),
                _QuickAction(
                  icon: Icons.mic_none,
                  label: 'Voice Entry',
                  color: AppColors.red,
                  onTap: () {}, // Step 8
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
class _BudgetCard extends StatelessWidget {
  const _BudgetCard({required this.spent, required this.budget});
  final double spent;
  final double budget;

  @override
  Widget build(BuildContext context) {
    final ratio = (spent / budget).clamp(0.0, 1.0);
    // Green until 80%, orange until 100%, then red.
    final color = ratio < 0.8
        ? AppColors.green
        : ratio < 1.0
        ? AppColors.orange
        : AppColors.red;

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
              const Icon(Icons.edit_outlined, size: 16, color: Colors.black38),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              color: color,
              backgroundColor: Colors.black12,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_money.format(spent)} of ${_money.format(budget)} spent '
            '(${(ratio * 100).round()}%)',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

// ======================= EXPENSE BREAKDOWN =======================
class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard();

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Expense breakdown (this month)',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox(
                width: 130,
                height: 130,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 0,
                    sections: [
                      for (final c in _sampleCategories)
                        PieChartSectionData(
                          value: c.$2,
                          color: c.$3,
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
                    for (final c in _sampleCategories)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: c.$3,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                c.$1,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            Text(
                              _money.format(c.$2),
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
          ),
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