import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/ui_helpers.dart';
import '../transactions/txn_models.dart';
import '../transactions/txn_providers.dart';
import 'budget_providers.dart';
import 'budget_sheet.dart';

class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cats = ref.watch(categoriesProvider);
    final budgets = ref.watch(budgetsProvider);
    final spendById = ref.watch(spendByCategoryIdProvider);
    final summary = ref.watch(monthSummaryProvider);
    final overall = ref.watch(overallBudgetProvider);

    final byCat = {
      for (final b in budgets.value ?? const <Budget>[])
        if (b.categoryId != null) b.categoryId!: b,
    };

    Widget body;
    if (cats.hasError || budgets.hasError) {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Could not load budgets.'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                ref.invalidate(categoriesProvider);
                ref.invalidate(budgetsProvider);
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    } else if (!cats.hasValue || !budgets.hasValue) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      final expenseCats =
          cats.value!.where((c) => c.type == TxnType.expense).toList();

      body = ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          const _SectionLabel('Overall'),
          _BudgetRow(
            icon: Icons.account_balance_wallet_outlined,
            color: AppColors.green,
            title: 'Monthly budget',
            spent: summary?.expense ?? 0,
            budget: overall,
            onTap: () => showBudgetSheet(
              context,
              title: 'Monthly budget',
              existing: overall,
            ),
          ),
          const SizedBox(height: 20),
          const _SectionLabel('By category (optional)'),
          for (final c in expenseCats) ...[
            _BudgetRow(
              icon: iconFromName(c.icon),
              color: colorFromHex(c.color),
              title: c.name,
              spent: spendById[c.id] ?? 0,
              budget: byCat[c.id],
              onTap: () => showBudgetSheet(
                context,
                title: '${c.name} budget',
                categoryId: c.id,
                existing: byCat[c.id],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Budgets'),
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
      ),
      body: body,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.black54,
          ),
        ),
      );
}

class _BudgetRow extends StatelessWidget {
  const _BudgetRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.spent,
    required this.budget,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final double spent;
  final Budget? budget;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final b = budget;
    final ratio = b == null ? 0.0 : spent / b.amount;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.15),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 6),
                    if (b == null)
                      Text(
                        spent > 0
                            ? 'No budget set • spent ${moneyWhole.format(spent)}'
                            : 'No budget set',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black54),
                      )
                    else ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: ratio.clamp(0.0, 1.0),
                          minHeight: 6,
                          color: budgetColor(ratio),
                          backgroundColor: Colors.black12,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${moneyWhole.format(spent)} of '
                        '${moneyWhole.format(b.amount)}',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                b == null ? Icons.add_circle_outline : Icons.edit_outlined,
                size: 20,
                color: Colors.black38,
              ),
            ],
          ),
        ),
      ),
    );
  }
}