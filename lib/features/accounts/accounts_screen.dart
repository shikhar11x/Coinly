import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/ui_kit.dart';
import '../transactions/txn_providers.dart';
import 'account.dart';
import 'account_form_sheet.dart';
import 'accounts_providers.dart';

/// Content never gets wider than this (tablets / Chrome).
const double _maxW = 560;

enum _Menu { edit, makeDefault, delete }

class AccountsScreen extends ConsumerStatefulWidget {
  const AccountsScreen({super.key});

  @override
  ConsumerState<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends ConsumerState<AccountsScreen> {
  /// Accounts being deleted: hidden right away so the list never flickers.
  final Set<String> _deleting = {};

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  // ---------- Actions ----------

  Future<void> _setDefault(Account a) async {
    if (a.isDefault) {
      _snack('"${a.name}" is already your default account');
      return;
    }
    try {
      await ref.read(accountsRepoProvider).setDefault(a.id);
      HapticFeedback.lightImpact();
      _snack('"${a.name}" is now your default account');
    } catch (e) {
      _snack('Could not change default: $e');
    }
  }

  Future<void> _delete(Account a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${a.name}"?'),
        content: const Text(
          'All transactions in this account will be deleted too. '
          'This cannot be undone.',
        ),
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
    if (ok != true || !mounted) return;

    setState(() => _deleting.add(a.id));
    try {
      await ref.read(accountsRepoProvider).delete(a);
      // The account's transactions are gone too: refresh those screens.
      ref.invalidate(transactionsProvider);
      ref.invalidate(monthTxnsProvider);
      HapticFeedback.mediumImpact();
      _snack('"${a.name}" deleted');
    } catch (e) {
      if (mounted) setState(() => _deleting.remove(a.id));
      _snack('Could not delete: $e');
    }
  }

  void _onMenu(Account a, _Menu m) {
    switch (m) {
      case _Menu.edit:
        showAccountForm(context, existing: a);
      case _Menu.makeDefault:
        _setDefault(a);
      case _Menu.delete:
        _delete(a);
    }
  }

  // ---------- Build ----------

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(accountsProvider);

    final visible = <Account>[];
    if (async.hasValue) {
      final all = async.value!.where((a) => !_deleting.contains(a.id));
      // Default account first, the rest keep their order.
      visible
        ..addAll(all.where((a) => a.isDefault))
        ..addAll(all.where((a) => !a.isDefault));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('My accounts')),
      floatingActionButton: visible.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => showAccountForm(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'Add account',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
      body: _frame(_content(async, visible)),
    );
  }

  Widget _frame(Widget child) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxW),
          child: child,
        ),
      );

  Widget _content(AsyncValue<List<Account>> async, List<Account> visible) {
    if (!async.hasValue) {
      if (async.hasError) {
        return ErrorState(
          message: 'Could not load accounts.\n${async.error}',
          onRetry: () => ref.invalidate(accountsProvider),
        );
      }
      return const _LoadingList();
    }

    if (visible.isEmpty) {
      return EmptyState(
        icon: Icons.account_balance_wallet_outlined,
        title: 'No accounts yet',
        subtitle: 'Add your bank account, cash or card\nto start tracking.',
        action: FilledButton.icon(
          onPressed: () => showAccountForm(context),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Add your first account'),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(accountsProvider);
        await ref.read(accountsProvider.future);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
        children: [
          FadeSlideIn(child: _TotalCard(accounts: visible)),
          const SizedBox(height: 22),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Text(
                  'YOUR ACCOUNTS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: context.muted,
                  ),
                ),
                const Spacer(),
                Text(
                  'Swipe → default   ← delete',
                  style: TextStyle(fontSize: 11, color: context.muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < visible.length; i++)
            // Key by id so animations stay attached when the order changes.
            Padding(
              key: ValueKey('row-${visible[i].id}'),
              padding: const EdgeInsets.only(bottom: 12),
              child: FadeSlideIn(
                delay: Duration(milliseconds: 60 + 50 * (i < 5 ? i : 5)),
                child: _buildRow(visible[i]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRow(Account a) {
    return Dismissible(
      key: ValueKey(a.id),
      direction: DismissDirection.horizontal,
      dismissThresholds: const {
        DismissDirection.startToEnd: 0.35,
        DismissDirection.endToStart: 0.35,
      },
      background: const _SwipeBg(
        color: AppColors.green,
        icon: Icons.star_rounded,
        label: 'Default',
        alignment: Alignment.centerLeft,
      ),
      secondaryBackground: const _SwipeBg(
        color: AppColors.red,
        icon: Icons.delete_outline_rounded,
        label: 'Delete',
        alignment: Alignment.centerRight,
      ),
      // We do the action ourselves and always snap back (the list itself
      // updates when the data refreshes), so nothing is ever left half-removed.
      confirmDismiss: (dir) async {
        if (dir == DismissDirection.startToEnd) {
          await _setDefault(a);
        } else {
          await _delete(a);
        }
        return false;
      },
      child: _AccountCard(
        account: a,
        onTap: () => showAccountForm(context, existing: a),
        onMenu: (m) => _onMenu(a, m),
      ),
    );
  }
}

// ============================================================
// Total card
// ============================================================

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.accounts});
  final List<Account> accounts;

  @override
  Widget build(BuildContext context) {
    var total = 0.0;
    var assets = 0.0;
    var owed = 0.0;
    for (final a in accounts) {
      total += a.balance;
      if (a.balance >= 0) {
        assets += a.balance;
      } else {
        owed += -a.balance;
      }
    }
    final n = accounts.length;

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
                        '$n ${n == 1 ? 'account' : 'accounts'}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: AmountText(
                    total,
                    exact: true,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 38,
                      height: 1.0,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.6,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _TotalStat(
                        label: 'Assets',
                        value: assets,
                        color: AppColors.green,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _TotalStat(
                        label: 'Owed',
                        value: owed,
                        color: AppColors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TotalStat extends StatelessWidget {
  const _TotalStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              moneyExact.format(value),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Account card
// ============================================================

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.account,
    required this.onTap,
    required this.onMenu,
  });

  final Account account;
  final VoidCallback onTap;
  final ValueChanged<_Menu> onMenu;

  @override
  Widget build(BuildContext context) {
    final a = account;
    final negative = a.balance < 0;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 14, 4, 14),
      child: Row(
        children: [
          IconBadge(icon: a.type.icon, color: a.type.color, size: 46),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        a.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (a.isDefault) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: context.cs.primaryContainer,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.star_rounded,
                              size: 11,
                              color: context.cs.onPrimaryContainer,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              'Default',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: context.cs.onPrimaryContainer,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  a.type.label,
                  style: TextStyle(fontSize: 12, color: context.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                moneyExact.format(a.balance),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: negative ? AppColors.red : null,
                ),
              ),
              if (negative) ...[
                const SizedBox(height: 2),
                Text('owed', style: TextStyle(fontSize: 11, color: context.muted)),
              ],
            ],
          ),
          PopupMenuButton<_Menu>(
            tooltip: 'More',
            icon: Icon(Icons.more_vert_rounded, color: context.muted),
            onSelected: onMenu,
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: _Menu.edit,
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 20),
                    SizedBox(width: 12),
                    Text('Edit'),
                  ],
                ),
              ),
              if (!a.isDefault)
                const PopupMenuItem(
                  value: _Menu.makeDefault,
                  child: Row(
                    children: [
                      Icon(Icons.star_outline_rounded, size: 20),
                      SizedBox(width: 12),
                      Text('Set as default'),
                    ],
                  ),
                ),
              const PopupMenuItem(
                value: _Menu.delete,
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_outline_rounded,
                      size: 20,
                      color: AppColors.red,
                    ),
                    SizedBox(width: 12),
                    Text('Delete', style: TextStyle(color: AppColors.red)),
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

class _SwipeBg extends StatelessWidget {
  const _SwipeBg({
    required this.color,
    required this.icon,
    required this.label,
    required this.alignment,
  });

  final Color color;
  final IconData icon;
  final String label;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 26),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(kCardRadius),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Loading skeleton
// ============================================================

class _LoadingList extends StatelessWidget {
  const _LoadingList();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      children: const [
        Skeleton(height: 158, radius: 28),
        SizedBox(height: 22),
        Skeleton(width: 100, height: 12),
        SizedBox(height: 14),
        Skeleton(height: 78, radius: 24),
        SizedBox(height: 12),
        Skeleton(height: 78, radius: 24),
        SizedBox(height: 12),
        Skeleton(height: 78, radius: 24),
      ],
    );
  }
}