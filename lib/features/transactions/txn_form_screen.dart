import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../core/ui_helpers.dart';
import '../accounts/account.dart';
import '../accounts/accounts_providers.dart';
import 'txn_draft.dart';
import 'txn_models.dart';
import 'txn_providers.dart';

class TxnFormScreen extends ConsumerStatefulWidget {
  const TxnFormScreen({super.key, this.existing, this.draft});

  /// Editing this transaction (null = adding a new one).
  final Txn? existing;

  /// Pre-filled values from AI receipt scan or voice entry.
  final TxnDraft? draft;

  @override
  ConsumerState<TxnFormScreen> createState() => _TxnFormScreenState();
}

class _TxnFormScreenState extends ConsumerState<TxnFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final double? _startAmount =
      widget.existing?.amount ?? widget.draft?.amount;

  late final _amount = TextEditingController(
    text: _startAmount == null ? '' : _plain(_startAmount!),
  );
  late final _desc = TextEditingController(
    text: widget.existing?.description ?? widget.draft?.description ?? '',
  );

  late TxnType _type =
      widget.existing?.type ?? widget.draft?.type ?? TxnType.expense;
  late String? _categoryId =
      widget.existing?.categoryId ?? widget.draft?.categoryId;
  late String? _accountId = widget.existing?.accountId;
  late DateTime _date =
      widget.existing?.date ?? widget.draft?.date ?? DateTime.now();
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  static String _plain(double a) =>
      a == a.roundToDouble() ? a.toStringAsFixed(0) : a.toStringAsFixed(2);

  @override
  void dispose() {
    _amount.dispose();
    _desc.dispose();
    super.dispose();
  }

  Account? _defaultAccount(List<Account> list) {
    if (list.isEmpty) return null;
    return list.firstWhere((a) => a.isDefault, orElse: () => list.first);
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    // Change the day but keep the time of day.
    setState(() {
      _date = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _date.hour,
        _date.minute,
      );
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final accounts = ref.read(accountsProvider).value ?? const <Account>[];
    final accountId = _accountId ?? _defaultAccount(accounts)?.id;

    if (accountId == null) {
      _snack('Add an account first.');
      return;
    }
    if (_categoryId == null) {
      _snack('Pick a category.');
      return;
    }

    setState(() => _saving = true);
    final repo = ref.read(txnRepoProvider);
    final amount = double.parse(_amount.text.trim());

    try {
      if (_isEdit) {
        await repo.update(
          widget.existing!.id,
          type: _type,
          amount: amount,
          accountId: accountId,
          categoryId: _categoryId!,
          date: _date,
          description: _desc.text,
        );
      } else {
        await repo.add(
          type: _type,
          amount: amount,
          accountId: accountId,
          categoryId: _categoryId!,
          date: _date,
          description: _desc.text,
          inputMethod: widget.draft?.inputMethod ?? 'manual',
          voiceTranscript: widget.draft?.voiceTranscript,
        );
      }
      if (mounted) context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack('Could not save: $e');
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this transaction?'),
        content: const Text('The account balance will be adjusted back.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _saving = true);
    try {
      await ref.read(txnRepoProvider).delete(widget.existing!.id);
      if (mounted) context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack('Could not delete: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);
    final accounts = accountsAsync.value ?? const <Account>[];
    final accountId = _accountId ?? _defaultAccount(accounts)?.id;

    final allCategories = ref.watch(categoriesProvider).value;
    final categories = (allCategories ?? const <TxnCategory>[]).where(
      (c) => c.type == _type,
    );

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit transaction' : 'Add transaction'),
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        actions: [
          if (_isEdit)
            IconButton(
              tooltip: 'Delete',
              onPressed: _saving ? null : _delete,
              icon: const Icon(Icons.delete_outline, color: AppColors.red),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            // Banner shown when values came from AI
            if (widget.draft != null && !_isEdit) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.blue.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.auto_awesome,
                      size: 18,
                      color: AppColors.blue,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.draft!.amount == null
                            ? "AI couldn't read the total. Please enter the amount."
                            : 'Filled in by AI. Please check the details before saving.',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Income / Expense switch
            SegmentedButton<TxnType>(
              segments: const [
                ButtonSegment(
                  value: TxnType.expense,
                  icon: Icon(Icons.arrow_downward),
                  label: Text('Expense'),
                ),
                ButtonSegment(
                  value: TxnType.income,
                  icon: Icon(Icons.arrow_upward),
                  label: Text('Income'),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() {
                _type = s.first;
                _categoryId = null; // categories differ per type
              }),
            ),
            const SizedBox(height: 20),

            // Amount
            TextFormField(
              controller: _amount,
              autofocus: !_isEdit && _startAmount == null,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
              decoration: const InputDecoration(
                labelText: 'Amount',
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

            // Category
            const Text('Category', style: TextStyle(color: Colors.black54)),
            const SizedBox(height: 8),
            if (allCategories == null)
              const LinearProgressIndicator()
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in categories)
                    ChoiceChip(
                      avatar: Icon(
                        iconFromName(c.icon),
                        size: 18,
                        color: colorFromHex(c.color),
                      ),
                      label: Text(c.name),
                      selected: _categoryId == c.id,
                      onSelected: (_) => setState(() => _categoryId = c.id),
                    ),
                ],
              ),
            const SizedBox(height: 20),

            // Account
            const Text('Account', style: TextStyle(color: Colors.black54)),
            const SizedBox(height: 8),
            if (accountsAsync.hasValue && accounts.isEmpty)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.account_balance_wallet_outlined),
                  title: const Text('You have no accounts yet'),
                  subtitle: const Text('Add one to record transactions.'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/accounts'),
                ),
              )
            else if (!accountsAsync.hasValue)
              const LinearProgressIndicator()
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final a in accounts)
                    ChoiceChip(
                      avatar: Icon(a.type.icon, size: 18),
                      label: Text(a.name),
                      selected: accountId == a.id,
                      onSelected: (_) => setState(() => _accountId = a.id),
                    ),
                ],
              ),
            const SizedBox(height: 20),

            // Date
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(4),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date',
                  suffixIcon: Icon(Icons.calendar_today_outlined),
                ),
                child: Text(DateFormat('EEE, d MMM y').format(_date)),
              ),
            ),
            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _desc,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                hintText: 'e.g. Dinner with friends',
              ),
            ),
            const SizedBox(height: 28),

            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.green,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(_isEdit ? 'Save changes' : 'Add transaction'),
            ),
          ],
        ),
      ),
    );
  }
}