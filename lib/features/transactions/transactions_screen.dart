import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/ui_helpers.dart';
import '../../core/ui_kit.dart';
import 'txn_models.dart';
import 'txn_providers.dart';
import 'txn_tile.dart';

/// Content never gets wider than this (tablets / Chrome).
const double _maxW = 640;

// ============================================================
// Period filter
// ============================================================

enum _Period {
  any('Any time'),
  today('Today'),
  week('7 days'),
  month('This month'),
  lastMonth('Last month');

  const _Period(this.label);
  final String label;

  bool matches(DateTime d) {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final lm = DateTime(now.year, now.month - 1);

    return switch (this) {
      _Period.any => true,
      _Period.today => day == startOfToday,
      _Period.week => !day.isBefore(
          DateTime(now.year, now.month, now.day - 6),
        ),
      _Period.month => day.year == now.year && day.month == now.month,
      _Period.lastMonth => day.year == lm.year && day.month == lm.month,
    };
  }
}

class _DayGroup {
  _DayGroup(this.day);
  final DateTime day;
  final items = <Txn>[];

  double get spent => items
      .where((t) => t.type == TxnType.expense)
      .fold<double>(0, (s, t) => s + t.amount);
}

// ============================================================
// SCREEN
// ============================================================

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  final _search = TextEditingController();
  String _query = '';
  TxnType? _type; // null = all
  _Period _period = _Period.any;

  /// Swiped-away rows. They stay hidden here until the delete is committed
  /// (so Undo can bring them back).
  final Set<String> _pending = {};

  bool get _hasFilters =>
      _query.trim().isNotEmpty || _type != null || _period != _Period.any;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _clearFilters() {
    _search.clear();
    setState(() {
      _query = '';
      _type = null;
      _period = _Period.any;
    });
  }

  List<Txn> _apply(List<Txn> all) {
    final q = _query.trim().toLowerCase();
    return all.where((t) {
      if (_pending.contains(t.id)) return false;
      if (_type != null && t.type != _type) return false;
      if (!_period.matches(t.date)) return false;
      if (q.isEmpty) return true;
      return (t.description ?? '').toLowerCase().contains(q) ||
          (t.categoryName ?? '').toLowerCase().contains(q) ||
          (t.accountName ?? '').toLowerCase().contains(q) ||
          t.amount.toString().contains(q);
    }).toList();
  }

  // ---------- Swipe to delete (with Undo) ----------

  void _delete(Txn t) {
    HapticFeedback.mediumImpact();

    // Grab these now; the snackbar outlives this widget's build.
    final repo = ref.read(txnRepoProvider);
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _pending.add(t.id));

    messenger.hideCurrentSnackBar(); // commits any earlier pending delete
    messenger
        .showSnackBar(
          SnackBar(
            content: const Text('Transaction deleted'),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Undo',
              textColor: AppColors.green,
              onPressed: () {
                if (mounted) setState(() => _pending.remove(t.id));
              },
            ),
          ),
        )
        .closed
        .then((reason) {
      // Anything except tapping Undo means: really delete it now.
      if (reason != SnackBarClosedReason.action) _commitDelete(repo, t.id);
    });
  }

  Future<void> _commitDelete(TxnRepo repo, String id) async {
    try {
      await repo.delete(id);
      // Keep the id in _pending: the list refreshes right after this.
    } catch (_) {
      if (!mounted) return;
      setState(() => _pending.remove(id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Could not delete. It's back in your list."),
        ),
      );
    }
  }

  // ---------- Build ----------

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(transactionsProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: context.isDark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxW),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context),
                  Expanded(child: _buildBody(context, async)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    Widget chip(String label, bool selected, VoidCallback onTap) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(label),
            selected: selected,
            labelStyle: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              color: selected ? context.cs.onPrimaryContainer : context.muted,
            ),
            onSelected: (_) {
              HapticFeedback.selectionClick();
              onTap();
            },
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Text('Activity', style: context.tt.headlineLarge),
        ),

        // Search
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _search,
            onChanged: (v) => setState(() => _query = v),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search note, category, account or amount',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded),
                      tooltip: 'Clear',
                      onPressed: () {
                        _search.clear();
                        setState(() => _query = '');
                      },
                    ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Type + period filters (scroll sideways)
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              chip('All', _type == null, () => setState(() => _type = null)),
              chip(
                'Income',
                _type == TxnType.income,
                () => setState(() => _type = TxnType.income),
              ),
              chip(
                'Expense',
                _type == TxnType.expense,
                () => setState(() => _type = TxnType.expense),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8, left: 2),
                child: VerticalDivider(
                  width: 1,
                  indent: 9,
                  endIndent: 9,
                  color: context.cs.outline,
                ),
              ),
              for (final p in _Period.values)
                chip(
                  p.label,
                  _period == p,
                  () => setState(() => _period = p),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildBody(BuildContext context, AsyncValue<List<Txn>> async) {
    // First load / error (no data yet)
    if (!async.hasValue) {
      if (async.hasError) {
        return ErrorState(
          message: 'Could not load transactions.\n${async.error}',
          onRetry: () => ref.invalidate(transactionsProvider),
        );
      }
      return const _ListSkeleton();
    }

    final all = async.value!;

    if (all.isEmpty) {
      return EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'No transactions yet',
        subtitle: 'Scan a receipt, say it, or type it in.',
        action: Padding(
          padding: const EdgeInsets.only(bottom: 90),
          child: FilledButton.icon(
            onPressed: () => context.push('/transaction'),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add transaction'),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 46)),
          ),
        ),
      );
    }

    final list = _apply(all);

    if (list.isEmpty) {
      return EmptyState(
        icon: Icons.search_off_rounded,
        title: 'Nothing found',
        subtitle: 'Try a different search or filter.',
        action: Padding(
          padding: const EdgeInsets.only(bottom: 90),
          child: _hasFilters
              ? OutlinedButton(
                  onPressed: _clearFilters,
                  child: const Text('Clear filters'),
                )
              : null,
        ),
      );
    }

    // Group by day (the list is already newest-first).
    final groups = <_DayGroup>[];
    for (final t in list) {
      final day = DateTime(t.date.year, t.date.month, t.date.day);
      if (groups.isEmpty || groups.last.day != day) {
        groups.add(_DayGroup(day));
      }
      groups.last.items.add(t);
    }

    final income = list
        .where((t) => t.type == TxnType.income)
        .fold<double>(0, (s, t) => s + t.amount);
    final expense = list
        .where((t) => t.type == TxnType.expense)
        .fold<double>(0, (s, t) => s + t.amount);

    final showLimitNote = all.length >= 500;
    final extra = showLimitNote ? 1 : 0;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(transactionsProvider);
        await ref.read(transactionsProvider.future);
      },
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 130),
        itemCount: groups.length + 1 + extra,
        itemBuilder: (context, i) {
          // 0 = summary of what is currently shown
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _SummaryCard(
                income: income,
                expense: expense,
                count: list.length,
                filtered: _hasFilters,
              ),
            );
          }

          // last = note when we hit the 500 limit
          if (i == groups.length + 1) {
            return Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Center(
                child: Text(
                  'Showing your latest 500 transactions',
                  style: TextStyle(fontSize: 12, color: context.muted),
                ),
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _DaySection(group: groups[i - 1], onDelete: _delete),
          );
        },
      ),
    );
  }
}

// ============================================================
// Day section: header + card with swipeable rows
// ============================================================

class _DaySection extends StatelessWidget {
  const _DaySection({required this.group, required this.onDelete});

  final _DayGroup group;
  final void Function(Txn) onDelete;

  @override
  Widget build(BuildContext context) {
    final items = group.items;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Row(
            children: [
              Text(
                dayLabel(group.day),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: context.muted,
                ),
              ),
              const Spacer(),
              if (group.spent > 0)
                Text(
                  '-${moneyWhole.format(group.spent)}',
                  style: TextStyle(fontSize: 12, color: context.muted),
                ),
            ],
          ),
        ),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var j = 0; j < items.length; j++) ...[
                Dismissible(
                  key: ValueKey(items[j].id),
                  direction: DismissDirection.endToStart,
                  dismissThresholds: const {DismissDirection.endToStart: 0.4},
                  background: const _DeleteBackground(),
                  onDismissed: (_) => onDelete(items[j]),
                  child: Material(
                    color: context.cs.surface,
                    child: InkWell(
                      onTap: () =>
                          context.push('/transaction', extra: items[j]),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: TxnTile(txn: items[j]),
                      ),
                    ),
                  ),
                ),
                if (j < items.length - 1)
                  const Divider(indent: 66, endIndent: 14),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _DeleteBackground extends StatelessWidget {
  const _DeleteBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.red,
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 24),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.delete_outline_rounded, color: Colors.white, size: 22),
          SizedBox(height: 2),
          Text(
            'Delete',
            style: TextStyle(
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
// Summary card
// ============================================================

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.income,
    required this.expense,
    required this.count,
    required this.filtered,
  });

  final double income;
  final double expense;
  final int count;
  final bool filtered;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                filtered ? 'FILTERED RESULTS' : 'ALL TRANSACTIONS',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: context.muted,
                ),
              ),
              const Spacer(),
              Text(
                '$count ${count == 1 ? 'item' : 'items'}',
                style: TextStyle(fontSize: 11, color: context.muted),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Stat(
                  icon: Icons.south_west_rounded,
                  color: context.incomeColor,
                  label: 'Income',
                  value: moneyWhole.format(income),
                ),
              ),
              Container(width: 1, height: 38, color: context.cs.outline),
              const SizedBox(width: 16),
              Expanded(
                child: _Stat(
                  icon: Icons.north_east_rounded,
                  color: AppColors.red,
                  label: 'Spent',
                  value: moneyWhole.format(expense),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconBadge(icon: icon, color: color, size: 34),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: context.muted)),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================
// Loading skeleton
// ============================================================

class _ListSkeleton extends StatelessWidget {
  const _ListSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      children: [
        const Skeleton(height: 96, radius: 24),
        const SizedBox(height: 22),
        const Skeleton(width: 70, height: 12),
        const SizedBox(height: 10),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Column(
            children: [
              for (var i = 0; i < 5; i++) ...[
                const _RowSkeleton(),
                if (i < 4) const Divider(indent: 52),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _RowSkeleton extends StatelessWidget {
  const _RowSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Skeleton(width: 40, height: 40, radius: 13),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Skeleton(width: 130, height: 13),
                SizedBox(height: 8),
                Skeleton(width: 90, height: 11),
              ],
            ),
          ),
          SizedBox(width: 8),
          Skeleton(width: 56, height: 14),
        ],
      ),
    );
  }
}