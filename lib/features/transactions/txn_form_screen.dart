import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/ui_helpers.dart';
import '../../core/ui_kit.dart';
import '../accounts/account.dart';
import '../accounts/accounts_providers.dart';
import 'txn_draft.dart';
import 'txn_models.dart';
import 'txn_providers.dart';

/// Content never gets wider than this (tablets / Chrome).
const double _maxW = 560;

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
  bool _catError = false;

  bool get _isEdit => widget.existing != null;

  static String _plain(double a) =>
      a == a.roundToDouble() ? a.toStringAsFixed(0) : a.toStringAsFixed(2);

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

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

  // ---------- Amount helpers ----------

  void _bump(double v) {
    final cur = double.tryParse(_amount.text.trim()) ?? 0;
    final next = cur + v;
    if (next >= 1e12) return;
    HapticFeedback.selectionClick();
    setState(() {
      _amount.text = _plain(next);
      _amount.selection = TextSelection.collapsed(offset: _amount.text.length);
    });
  }

  // ---------- Date helpers ----------

  /// Change the day but keep the time of day (never in the future).
  void _setDay(DateTime day) {
    final now = DateTime.now();
    var next = DateTime(day.year, day.month, day.day, _date.hour, _date.minute);
    if (next.isAfter(now)) next = now;
    setState(() => _date = next);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.isAfter(now) ? now : _date,
      firstDate: DateTime(2000),
      lastDate: now,
    );
    if (picked != null) _setDay(picked);
  }

  // ---------- Save / delete ----------

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final messenger = ScaffoldMessenger.of(context);

    final formOk = _formKey.currentState!.validate();
    final accounts = ref.read(accountsProvider).value ?? const <Account>[];
    final accountId = _accountId ?? _defaultAccount(accounts)?.id;

    if (_categoryId == null) setState(() => _catError = true);

    if (!formOk || _categoryId == null) {
      HapticFeedback.mediumImpact();
      return;
    }
    if (accountId == null) {
      HapticFeedback.mediumImpact();
      _snack('Add an account first.');
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
      HapticFeedback.lightImpact();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(_isEdit ? 'Changes saved' : 'Transaction added'),
          ),
        );
      if (mounted) context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack('Could not save: $e');
    }
  }

  Future<void> _delete() async {
    final messenger = ScaffoldMessenger.of(context);

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
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.red,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 44),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _saving = true);
    try {
      await ref.read(txnRepoProvider).delete(widget.existing!.id);
      HapticFeedback.mediumImpact();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Transaction deleted')));
      if (mounted) context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack('Could not delete: $e');
    }
  }

  // ---------- Build ----------

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);
    final accounts = accountsAsync.value ?? const <Account>[];
    final accountId = _accountId ?? _defaultAccount(accounts)?.id;

    final catsAsync = ref.watch(categoriesProvider);
    final categories = (catsAsync.value ?? const <TxnCategory>[])
        .where((c) => c.type == _type)
        .toList();

    final isIncome = _type == TxnType.income;
    final amountColor = isIncome ? context.incomeColor : AppColors.red;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Close',
          onPressed: () => context.pop(),
        ),
        title: Text(_isEdit ? 'Edit transaction' : 'New transaction'),
        actions: [
          if (_isEdit)
            IconButton(
              tooltip: 'Delete',
              onPressed: _saving ? null : _delete,
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.red,
              ),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxW),
          child: Column(
            children: [
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    children: [
                      // ---------- AI banner ----------
                      if (widget.draft != null && !_isEdit) ...[
                        _AiBanner(missingAmount: widget.draft!.amount == null),
                        const SizedBox(height: 14),
                      ],

                      // ---------- Hero: type + amount ----------
                      AppCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _TypeToggle(
                              type: _type,
                              onChanged: (t) {
                                if (t == _type) return;
                                HapticFeedback.selectionClick();
                                setState(() {
                                  _type = t;
                                  _categoryId = null; // categories differ
                                  _catError = false;
                                });
                              },
                            ),
                            const SizedBox(height: 22),
                            Text(
                              'AMOUNT',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.1,
                                color: context.muted,
                              ),
                            ),
                            const SizedBox(height: 4),
                            TextFormField(
                              controller: _amount,
                              autofocus: !_isEdit && _startAmount == null,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d*\.?\d{0,2}'),
                                ),
                              ],
                              cursorColor: amountColor,
                              style: TextStyle(
                                fontSize: 44,
                                height: 1.1,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -1.5,
                                color: amountColor,
                              ),
                              decoration: InputDecoration(
                                hintText: '0',
                                hintStyle: TextStyle(
                                  fontSize: 44,
                                  height: 1.1,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -1.5,
                                  color: context.cs.onSurface
                                      .withValues(alpha: 0.18),
                                ),
                                prefixText: '₹ ',
                                prefixStyle: TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w700,
                                  color: context.muted,
                                ),
                                filled: false,
                                isDense: true,
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 6),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                errorBorder: InputBorder.none,
                                focusedErrorBorder: InputBorder.none,
                              ),
                              onChanged: (_) => setState(() {}),
                              validator: (v) {
                                final n = double.tryParse((v ?? '').trim());
                                if (n == null || n <= 0) {
                                  return 'Enter an amount above 0';
                                }
                                if (n >= 1e12) return 'That amount is too large';
                                return null;
                              },
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                _QuickChip('+100', () => _bump(100)),
                                const SizedBox(width: 8),
                                _QuickChip('+500', () => _bump(500)),
                                const SizedBox(width: 8),
                                _QuickChip('+1,000', () => _bump(1000)),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // ---------- Category ----------
                      const SizedBox(height: 22),
                      const _Label('CATEGORY'),
                      const SizedBox(height: 10),
                      _buildCategories(catsAsync, categories),
                      if (_catError)
                        const Padding(
                          padding: EdgeInsets.only(top: 8, left: 4),
                          child: Text(
                            'Pick a category',
                            style: TextStyle(
                              color: AppColors.red,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),

                      // ---------- Account ----------
                      const SizedBox(height: 22),
                      const _Label('ACCOUNT'),
                      const SizedBox(height: 10),
                      _buildAccounts(accountsAsync, accounts, accountId),

                      // ---------- Date ----------
                      const SizedBox(height: 22),
                      const _Label('DATE'),
                      const SizedBox(height: 10),
                      _buildDate(),

                      // ---------- Note ----------
                      const SizedBox(height: 22),
                      const _Label('NOTE (OPTIONAL)'),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _desc,
                        maxLength: 120,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          hintText: 'e.g. Dinner with friends',
                          prefixIcon: Icon(Icons.notes_rounded),
                          counterText: '',
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ---------- Fixed save bar ----------
              Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                decoration: BoxDecoration(
                  color: context.cs.surface,
                  border: Border(top: BorderSide(color: context.cs.outline)),
                ),
                child: SafeArea(
                  top: false,
                  child: PrimaryButton(
                    label: _isEdit
                        ? 'Save changes'
                        : (isIncome ? 'Add income' : 'Add expense'),
                    loading: _saving,
                    onPressed: _save,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategories(
    AsyncValue<List<TxnCategory>> catsAsync,
    List<TxnCategory> categories,
  ) {
    if (!catsAsync.hasValue) {
      if (catsAsync.hasError) {
        return Row(
          children: [
            Expanded(
              child: Text(
                'Could not load categories.',
                style: TextStyle(color: context.muted),
              ),
            ),
            TextButton(
              onPressed: () => ref.invalidate(categoriesProvider),
              child: const Text('Retry'),
            ),
          ],
        );
      }
      return const Row(
        children: [
          Expanded(child: Skeleton(height: 84, radius: 18)),
          SizedBox(width: 10),
          Expanded(child: Skeleton(height: 84, radius: 18)),
          SizedBox(width: 10),
          Expanded(child: Skeleton(height: 84, radius: 18)),
          SizedBox(width: 10),
          Expanded(child: Skeleton(height: 84, radius: 18)),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, c) {
        const gap = 10.0;
        final cols = c.maxWidth >= 360 ? 4 : 3;
        final w = (c.maxWidth - gap * (cols - 1)) / cols;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final cat in categories)
              SizedBox(
                width: w,
                child: _CategoryTile(
                  category: cat,
                  selected: _categoryId == cat.id,
                  onTap: () => setState(() {
                    _categoryId = cat.id;
                    _catError = false;
                  }),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildAccounts(
    AsyncValue<List<Account>> accountsAsync,
    List<Account> accounts,
    String? selectedId,
  ) {
    if (!accountsAsync.hasValue) {
      return accountsAsync.hasError
          ? Row(
              children: [
                Expanded(
                  child: Text(
                    'Could not load accounts.',
                    style: TextStyle(color: context.muted),
                  ),
                ),
                TextButton(
                  onPressed: () => ref.invalidate(accountsProvider),
                  child: const Text('Retry'),
                ),
              ],
            )
          : const Skeleton(height: 66, radius: 18);
    }

    if (accounts.isEmpty) {
      return AppCard(
        onTap: () => context.push('/accounts'),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const IconBadge(
              icon: Icons.account_balance_wallet_outlined,
              color: AppColors.green,
              size: 42,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Add an account first', style: context.tt.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    'You need one to record transactions.',
                    style: TextStyle(fontSize: 12, color: context.muted),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: context.muted),
          ],
        ),
      );
    }

    return SizedBox(
      height: 66,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: accounts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final a = accounts[i];
          return _AccountTile(
            account: a,
            selected: selectedId == a.id,
            onTap: () => setState(() => _accountId = a.id),
          );
        },
      ),
    );
  }

  Widget _buildDate() {
    final now = DateTime.now();
    final isToday = _sameDay(_date, now);
    final isYesterday = _sameDay(_date, now.subtract(const Duration(days: 1)));
    final custom = !isToday && !isYesterday;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(
          label: const Text('Today'),
          selected: isToday,
          onSelected: (_) => _setDay(now),
        ),
        ChoiceChip(
          label: const Text('Yesterday'),
          selected: isYesterday,
          onSelected: (_) => _setDay(now.subtract(const Duration(days: 1))),
        ),
        ChoiceChip(
          avatar: const Icon(Icons.calendar_today_outlined, size: 15),
          label: Text(custom ? DateFormat('d MMM y').format(_date) : 'Pick date'),
          selected: custom,
          onSelected: (_) => _pickDate(),
        ),
      ],
    );
  }
}

// ============================================================
// Pieces
// ============================================================

class _Label extends StatelessWidget {
  const _Label(this.text);
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

class _AiBanner extends StatelessWidget {
  const _AiBanner({required this.missingAmount});
  final bool missingAmount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.blue.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.blue.withValues(alpha: 0.30)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.auto_awesome_rounded, size: 18, color: AppColors.blue),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              missingAmount
                  ? "AI couldn't read the total. Please enter the amount."
                  : 'Filled in by AI. Please check the details before saving.',
              style: const TextStyle(fontSize: 12.5, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeToggle extends StatelessWidget {
  const _TypeToggle({required this.type, required this.onChanged});

  final TxnType type;
  final ValueChanged<TxnType> onChanged;

  @override
  Widget build(BuildContext context) {
    final isExpense = type == TxnType.expense;

    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.cs.outlineVariant,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            alignment: isExpense ? Alignment.centerLeft : Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                decoration: BoxDecoration(
                  color: isExpense ? AppColors.red : AppColors.green,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _Segment(
                  icon: Icons.north_east_rounded,
                  label: 'Expense',
                  selected: isExpense,
                  selectedColor: Colors.white,
                  onTap: () => onChanged(TxnType.expense),
                ),
              ),
              Expanded(
                child: _Segment(
                  icon: Icons.south_west_rounded,
                  label: 'Income',
                  selected: !isExpense,
                  selectedColor: AppColors.dark,
                  onTap: () => onChanged(TxnType.income),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.icon,
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? selectedColor : context.muted;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: color,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip(this.label, this.onTap);

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      haptic: false,
      scale: 0.94,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: context.cs.outlineVariant,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: context.muted,
          ),
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final TxnCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = colorFromHex(category.color);

    return Pressable(
      onTap: onTap,
      scale: 0.95,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : context.cs.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? color : context.cs.outline,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconBadge(
              icon: iconFromName(category.icon),
              color: color,
              size: 38,
            ),
            const SizedBox(height: 8),
            Text(
              category.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.account,
    required this.selected,
    required this.onTap,
  });

  final Account account;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.96,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 172,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.green.withValues(alpha: 0.10)
              : context.cs.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? AppColors.green : context.cs.outline,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            IconBadge(
              icon: account.type.icon,
              color: AppColors.green,
              size: 38,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    account.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    moneyWhole.format(account.balance),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, color: context.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}