import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ui_kit.dart';
import 'account.dart';
import 'accounts_providers.dart';

const _quickNames = [
  'SBI',
  'HDFC Bank',
  'ICICI Bank',
  'Axis Bank',
  'Kotak',
  'Paytm',
];

Future<void> showAccountForm(BuildContext context, {Account? existing}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true, // lets the sheet rise above the keyboard
    showDragHandle: true,
    builder: (_) => _AccountForm(existing: existing),
  );
}

class _AccountForm extends ConsumerStatefulWidget {
  const _AccountForm({this.existing});
  final Account? existing;

  @override
  ConsumerState<_AccountForm> createState() => _AccountFormState();
}

class _AccountFormState extends ConsumerState<_AccountForm> {
  final _formKey = GlobalKey<FormState>();

  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _balance = TextEditingController(
    text: widget.existing == null ? '' : _plain(widget.existing!.balance),
  );
  late AccountType _type = widget.existing?.type ?? AccountType.bank;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  static String _plain(double a) =>
      a == a.roundToDouble() ? a.toStringAsFixed(0) : a.toStringAsFixed(2);

  @override
  void dispose() {
    _name.dispose();
    _balance.dispose();
    super.dispose();
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

    setState(() => _saving = true);
    final repo = ref.read(accountsRepoProvider);
    final text = _balance.text.trim();
    final balance = text.isEmpty ? 0.0 : double.parse(text);
    final name = _name.text.trim();

    try {
      if (_isEdit) {
        await repo.update(
          widget.existing!,
          name: name,
          type: _type,
          balance: balance,
        );
      } else {
        await repo.add(name: name, type: _type, balance: balance);
      }
      HapticFeedback.lightImpact();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(_isEdit ? 'Account updated' : 'Account added'),
          ),
        );
      nav.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text('Could not save: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
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
            Text(
              _isEdit ? 'Edit account' : 'Add account',
              style: context.tt.titleLarge,
            ),
            const SizedBox(height: 2),
            Text(
              _isEdit
                  ? 'Update the name, type or balance'
                  : 'Bank, cash, card or wallet',
              style: TextStyle(fontSize: 13, color: context.muted),
            ),
            const SizedBox(height: 18),

            // ---------- Name ----------
            TextFormField(
              controller: _name,
              maxLength: 30,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Account name',
                hintText: 'e.g. HDFC Savings',
                counterText: '',
                prefixIcon: Icon(_type.icon),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
            ),

            if (!_isEdit) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final n in _quickNames)
                    ActionChip(
                      label: Text(n),
                      onPressed: () => setState(() {
                        _name.text = n;
                        _name.selection =
                            TextSelection.collapsed(offset: n.length);
                      }),
                    ),
                ],
              ),
            ],

            // ---------- Type ----------
            const SizedBox(height: 20),
            Text(
              'TYPE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
                color: context.muted,
              ),
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, c) {
                const gap = 10.0;
                const cols = 3;
                final w = (c.maxWidth - gap * (cols - 1)) / cols;

                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final t in AccountType.values)
                      SizedBox(
                        width: w,
                        child: _TypeTile(
                          type: t,
                          selected: _type == t,
                          onTap: () => setState(() => _type = t),
                        ),
                      ),
                  ],
                );
              },
            ),

            // ---------- Balance ----------
            const SizedBox(height: 20),
            TextFormField(
              controller: _balance,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d{0,2}')),
              ],
              decoration: InputDecoration(
                labelText: _isEdit ? 'Current balance' : 'Opening balance',
                prefixText: '₹ ',
                helperMaxLines: 2,
                helperText: _isEdit
                    ? 'This changes the balance directly (no transaction is created).'
                    : _type == AccountType.creditCard
                        ? 'Use a minus for money you owe, e.g. -5000. Empty = 0.'
                        : 'Leave empty for 0.',
              ),
              validator: (v) {
                final s = (v ?? '').trim();
                if (s.isEmpty) return null;
                final n = double.tryParse(s);
                if (n == null) return 'Enter a valid number';
                if (n.abs() >= 1e12) return 'That amount is too large';
                return null;
              },
            ),

            const SizedBox(height: 22),
            PrimaryButton(
              label: _isEdit ? 'Save changes' : 'Add account',
              loading: _saving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeTile extends StatelessWidget {
  const _TypeTile({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final AccountType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = type.color;

    return Pressable(
      onTap: onTap,
      scale: 0.95,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
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
            IconBadge(icon: type.icon, color: color, size: 38),
            const SizedBox(height: 8),
            Text(
              type.short,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}