import 'package:flutter/material.dart' show Color;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase.dart';
import '../../core/ui_helpers.dart';
import '../accounts/accounts_providers.dart';
import '../auth/auth_providers.dart';
import 'txn_models.dart';

// "Give me the transaction, plus its category and account details."
const _select = '*, categories(name, icon, color, type), accounts(name)';

final categoriesProvider = FutureProvider<List<TxnCategory>>((ref) async {
  ref.watch(authStateProvider);
  final c = ref.watch(supabaseProvider);
  if (c.auth.currentUser == null) return [];

  final rows = await c.from('categories').select().order('name');
  return rows.map(TxnCategory.fromMap).toList();
});

/// Latest 500 transactions, newest first.
final transactionsProvider = FutureProvider<List<Txn>>((ref) async {
  ref.watch(authStateProvider);
  final c = ref.watch(supabaseProvider);
  if (c.auth.currentUser == null) return [];

  final rows = await c
      .from('transactions')
      .select(_select)
      .order('date', ascending: false)
      .limit(500);
  return rows.map(Txn.fromMap).toList();
});

// ============================================================
// Month selection (dashboard month switcher)
// ============================================================

bool isCurrentMonth(DateTime m) {
  final n = DateTime.now();
  return m.year == n.year && m.month == n.month;
}

/// Days to divide by for "daily average": today's date for the current
/// month, the full length for past months.
int daysInView(DateTime m) {
  if (isCurrentMonth(m)) return DateTime.now().day;
  return DateTime(m.year, m.month + 1, 0).day;
}

/// The first day of the month the dashboard is showing.
class SelectedMonth extends Notifier<DateTime> {
  @override
  DateTime build() {
    final n = DateTime.now();
    return DateTime(n.year, n.month);
  }

  void previous() => state = DateTime(state.year, state.month - 1);

  void next() {
    if (isCurrentMonth(state)) return; // can't go into the future
    state = DateTime(state.year, state.month + 1);
  }

  void reset() {
    final n = DateTime.now();
    state = DateTime(n.year, n.month);
  }
}

final selectedMonthProvider =
    NotifierProvider<SelectedMonth, DateTime>(SelectedMonth.new);

/// Every transaction in one month. One cached entry per month.
final monthTxnsProvider =
    FutureProvider.family<List<Txn>, DateTime>((ref, month) async {
  ref.watch(authStateProvider);
  final c = ref.watch(supabaseProvider);
  if (c.auth.currentUser == null) return [];

  final start = DateTime(month.year, month.month, 1);
  final end = DateTime(month.year, month.month + 1, 1);

  final rows = await c
      .from('transactions')
      .select(_select)
      .gte('date', start.toUtc().toIso8601String())
      .lt('date', end.toUtc().toIso8601String())
      .order('date', ascending: false);
  return rows.map(Txn.fromMap).toList();
});

/// The transactions of whichever month is currently selected.
final selectedMonthTxnsProvider = Provider<AsyncValue<List<Txn>>>((ref) {
  final month = ref.watch(selectedMonthProvider);
  return ref.watch(monthTxnsProvider(month));
});

class CategorySpend {
  const CategorySpend(this.name, this.amount, this.color);
  final String name;
  final double amount;
  final Color color;
}

class MonthSummary {
  const MonthSummary({
    required this.income,
    required this.expense,
    required this.byCategory,
  });
  final double income;
  final double expense;
  final List<CategorySpend> byCategory; // biggest first
}

/// Income, spending and per-category totals for the selected month.
/// null while that month is loading (or failed to load).
final monthSummaryProvider = Provider<MonthSummary?>((ref) {
  final list = ref.watch(selectedMonthTxnsProvider).value;
  if (list == null) return null;

  double income = 0;
  double expense = 0;
  final byCat = <String, CategorySpend>{};

  for (final t in list) {
    if (t.type == TxnType.income) {
      income += t.amount;
      continue;
    }
    expense += t.amount;
    final name = t.categoryName ?? 'Uncategorized';
    final prev = byCat[name];
    byCat[name] = CategorySpend(
      name,
      (prev?.amount ?? 0) + t.amount,
      colorFromHex(t.categoryColor),
    );
  }

  final sorted = byCat.values.toList()
    ..sort((a, b) => b.amount.compareTo(a.amount));
  return MonthSummary(income: income, expense: expense, byCategory: sorted);
});

// ============================================================
// Writes
// ============================================================

final txnRepoProvider = Provider<TxnRepo>((ref) => TxnRepo(ref));

class TxnRepo {
  TxnRepo(this._ref);
  final Ref _ref;

  SupabaseClient get _c => _ref.read(supabaseProvider);

  void _refresh() {
    _ref.invalidate(transactionsProvider);
    _ref.invalidate(monthTxnsProvider); // every cached month
    _ref.invalidate(accountsProvider); // the DB trigger changed balances
  }

  String? _clean(String? s) {
    final t = s?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }

  Future<void> add({
    required TxnType type,
    required double amount,
    required String accountId,
    required String categoryId,
    required DateTime date,
    String? description,
    String inputMethod = 'manual',
    String? voiceTranscript,
    String? receiptUrl,
  }) async {
    await _c.from('transactions').insert({
      'type': type.name, // 'income' | 'expense'
      'amount': amount,
      'account_id': accountId,
      'category_id': categoryId,
      'description': _clean(description),
      'date': date.toUtc().toIso8601String(),
      'input_method': inputMethod,
      'voice_transcript': voiceTranscript,
      'receipt_url': receiptUrl,
    });
    _refresh();
  }

  Future<void> update(
    String id, {
    required TxnType type,
    required double amount,
    required String accountId,
    required String categoryId,
    required DateTime date,
    String? description,
  }) async {
    await _c.from('transactions').update({
      'type': type.name,
      'amount': amount,
      'account_id': accountId,
      'category_id': categoryId,
      'description': _clean(description),
      'date': date.toUtc().toIso8601String(),
    }).eq('id', id);
    _refresh();
  }

  Future<void> delete(String id) async {
    await _c.from('transactions').delete().eq('id', id);
    _refresh();
  }
}