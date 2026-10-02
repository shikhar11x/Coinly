import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/ui_kit.dart';
import '../transactions/txn_providers.dart';
import 'budget_providers.dart';

const _quickAmounts = [2000.0, 5000.0, 10000.0, 20000.0, 50000.0];

Future<void> showBudgetSheet(
  BuildContext context, {
  required String title,
  String? categoryId,
  Budget? existing,
  IconData? icon,
  Color? color,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _BudgetSheet(
      title: title,
      categoryId: categoryId,
      existing: existing,
      icon: icon,
      color: color,
    ),
  );
}

class _BudgetSheet extends ConsumerStatefulWidget {
  const _BudgetSheet({
    required this.title,
    required this.categoryId,
    required this.existing,
    required this.icon,
    required this.color,
  });

  final String title;
  final String? categoryId;
  final Budget? existing;
  final IconData? icon;
  final Color? color;

  @override
  ConsumerState<_BudgetSheet> createState() => _BudgetSheetState();
}

class _BudgetSheetState extends ConsumerState<_BudgetSheet> {
  final _formKey = GlobalKey<FormState>();

  late final _amount = TextEditingController(
    text: widget.existing == null ? '' : _plain(widget.existing!.amount),
  );
  bool _busy = false;

  bool get _isEdit => widget.existing != null;

  static String _plain(double a) =>
      a == a.roundToDouble() ? a.toStringAsFixed(0) : a.toStringAsFixed(2);

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _setAmount(double v) {
    HapticFeedback.selectionClick();
    setState(() {
      _amount.text = _plain(v);
      _amount.selection = TextSelection.collapsed(offset: _amount.text.length);
    });
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      HapticFeedback.mediumImpact();
      return;
    }

    // Grab these before the await so we never use a stale context.
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);

    setState(() => _busy = true);
    try {
      await ref.read(budgetRepoProvider).save(
            categoryId: widget.categoryId,
            amount: double.parse(_amount.text.trim()),
          );
      HapticFeedback.lightImpact();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Budget saved')));
      nav.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(content: Text('Could not save: $e')));
    }
  }

  Future<void> _remove() async {
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove this budget?'),
        content: const Text('Your transactions are not affected.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.red,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 44),
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(budgetRepoProvider).remove(widget.existing!.id);
      HapticFeedback.mediumImpact();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Budget removed')));
      nav.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(content: Text('Could not remove: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final month = ref.watch(selectedMonthProvider);
    final spent = widget.categoryId == null
        ? ref.watch(monthSummaryProvider)?.expense
        : ref.watch(spendByCategoryIdProvider)[widget.categoryId];

    final current = double.tryParse(_amount.text.trim());
    final color = widget.color ?? AppColors.green;
    final monthWord =
        isCurrentMonth(month) ? 'this month' : DateFormat('MMMM').format(month);

    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconBadge(
                  icon: widget.icon ?? Icons.track_changes_rounded,
                  color: color,
                  size: 46,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.title, style: context.tt.titleLarge),
                      const SizedBox(height: 2),
                      Text(
                        'How much do you want to spend per month?',
                        style: TextStyle(fontSize: 12.5, color: context.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ---------- Amount ----------
            TextFormField(
              controller: _amount,
              autofocus: !_isEdit,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              cursorColor: color,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
              ),
              decoration: InputDecoration(
                labelText: 'Monthly budget',
                prefixText: '₹ ',
                prefixStyle: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: context.muted,
                ),
              ),
              onChanged: (_) => setState(() {}),
              onFieldSubmitted: (_) => _save(),
              validator: (v) {
                final n = double.tryParse((v ?? '').trim());
                if (n == null || n <= 0) return 'Enter an amount above 0';
                if (n >= 1e12) return 'That amount is too large';
                return null;
              },
            ),
            const SizedBox(height: 12),

            // ---------- Quick amounts ----------
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final v in _quickAmounts)
                  ChoiceChip(
                    label: Text(moneyWhole.format(v)),
                    selected: current == v,
                    onSelected: (_) => _setAmount(v),
                  ),
              ],
            ),

            // ---------- Spent so far ----------
            if (spent != null && spent > 0) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: context.cs.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: context.cs.onPrimaryContainer,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'You have spent ${moneyWhole.format(spent)} '
                        '$monthWord so far.',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: context.cs.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 22),
            PrimaryButton(
              label: _isEdit ? 'Save budget' : 'Set budget',
              loading: _busy,
              onPressed: _save,
            ),
            if (_isEdit) ...[
              const SizedBox(height: 6),
              TextButton(
                onPressed: _busy ? null : _remove,
                style: TextButton.styleFrom(foregroundColor: AppColors.red),
                child: const Text('Remove budget'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}