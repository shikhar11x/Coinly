import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../core/ui_helpers.dart';
import 'txn_models.dart';
import 'txn_providers.dart';
import 'txn_tile.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  final _search = TextEditingController();
  String _query = '';
  TxnType? _type; // null = all

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Txn> _apply(List<Txn> all) {
    final q = _query.trim().toLowerCase();
    return all.where((t) {
      if (_type != null && t.type != _type) return false;
      if (q.isEmpty) return true;
      return (t.description ?? '').toLowerCase().contains(q) ||
          (t.categoryName ?? '').toLowerCase().contains(q) ||
          (t.accountName ?? '').toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(transactionsProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Text(
                'Transactions',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              ),
            ),

            // Search
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _search,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Search transactions',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _search.clear();
                            setState(() => _query = '');
                          },
                        ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Type filter
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('All'),
                    selected: _type == null,
                    onSelected: (_) => setState(() => _type = null),
                  ),
                  ChoiceChip(
                    label: const Text('Income'),
                    selected: _type == TxnType.income,
                    onSelected: (_) => setState(() => _type = TxnType.income),
                  ),
                  ChoiceChip(
                    label: const Text('Expense'),
                    selected: _type == TxnType.expense,
                    onSelected: (_) => setState(() => _type = TxnType.expense),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            Expanded(
              child: async.when(
                skipLoadingOnReload: true,
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Could not load transactions.\n$e',
                            textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () => ref.invalidate(transactionsProvider),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (all) {
                  if (all.isEmpty) {
                    return const _Empty(
                      icon: Icons.receipt_long_outlined,
                      title: 'No transactions yet',
                      subtitle: 'Tap the + button to add your first one.',
                    );
                  }

                  final list = _apply(all);
                  if (list.isEmpty) {
                    return const _Empty(
                      icon: Icons.search_off,
                      title: 'Nothing found',
                      subtitle: 'Try a different search or filter.',
                    );
                  }

                  // Flatten into: day header, txn, txn, day header, txn...
                  final rows = <Object>[];
                  DateTime? lastDay;
                  for (final t in list) {
                    final day = DateTime(t.date.year, t.date.month, t.date.day);
                    if (lastDay != day) {
                      rows.add(day);
                      lastDay = day;
                    }
                    rows.add(t);
                  }

                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(transactionsProvider);
                      await ref.read(transactionsProvider.future);
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
                      itemCount: rows.length,
                      itemBuilder: (context, i) {
                        final row = rows[i];

                        if (row is DateTime) {
                          return Padding(
                            padding: EdgeInsets.fromLTRB(4, i == 0 ? 0 : 12, 4, 8),
                            child: Text(
                              dayLabel(row),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.black54,
                              ),
                            ),
                          );
                        }

                        final t = row as Txn;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: TxnTile(
                            txn: t,
                            onTap: () => context.push('/transaction', extra: t),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Colors.black26),
            const SizedBox(height: 12),
            Text(title,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}