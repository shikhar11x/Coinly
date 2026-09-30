import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import 'budget_providers.dart';

Future<void> showBudgetSheet(
  BuildContext context, {
  required String title,
  String? categoryId,
  Budget? existing,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _BudgetSheet(
      title: title,
      categoryId: categoryId,
      existing: existing,
    ),
  );
}

class _BudgetSheet extends ConsumerStatefulWidget {
  const _BudgetSheet({
    required this.title,
    required this.categoryId,
    required this.existing,
  });

  final String title;
  final String? categoryId;
  final Budget? existing;

  @override
  ConsumerState<_BudgetSheet> createState() => _BudgetSheetState();
}

class _BudgetSheetState extends ConsumerState<_BudgetSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _amount = TextEditingController(
    text: widget.existing == null
        ? ''
        : widget.existing!.amount.toStringAsFixed(
            widget.existing!.amount == widget.existing!.amount.roundToDouble()
                ? 0
                : 2),
  );
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _snack(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ref.read(budgetRepoProvider).save(
            categoryId: widget.categoryId,
            amount: double.parse(_amount.text.trim()),
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack('Could not save: $e');
    }
  }

  Future<void> _remove() async {
    setState(() => _busy = true);
    try {
      await ref.read(budgetRepoProvider).remove(widget.existing!.id);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack('Could not remove: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
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
            Text(widget.title,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('Amount you want to spend per month.',
                style: TextStyle(color: Colors.black54)),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amount,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Monthly budget',
                prefixText: '₹ ',
              ),
              validator: (v) {
                final n = double.tryParse((v ?? '').trim());
                if (n == null || n <= 0) return 'Enter an amount above 0';
                if (n >= 1e12) return 'That amount is too large';
                return null;
              },
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.green,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Save budget'),
            ),
            if (widget.existing != null) ...[
              const SizedBox(height: 8),
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