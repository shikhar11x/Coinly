import 'package:flutter/material.dart' show Color;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase.dart';
import '../../core/theme.dart';
import '../auth/auth_providers.dart';
import '../transactions/txn_models.dart';
import '../transactions/txn_providers.dart';

class Budget {
  const Budget({
    required this.id,
    required this.categoryId,
    required this.amount,
  });

  final String id;
  final String? categoryId; // null = overall monthly budget
  final double amount;

  factory Budget.fromMap(Map<String, dynamic> m) => Budget(
        id: m['id'] as String,
        categoryId: m['category_id'] as String?,
        amount: (m['amount'] as num).toDouble(),
      );
}

final budgetsProvider = FutureProvider<List<Budget>>((ref) async {
  ref.watch(authStateProvider);
  final c = ref.watch(supabaseProvider);
  if (c.auth.currentUser == null) return [];

  final rows = await c.from('budgets').select();
  return rows.map(Budget.fromMap).toList();
});

/// The overall monthly budget, or null if none is set (or still loading).
final overallBudgetProvider = Provider<Budget?>((ref) {
  final list = ref.watch(budgetsProvider).value;
  if (list == null) return null;
  for (final b in list) {
    if (b.categoryId == null) return b;
  }
  return null;
});

/// This month's expense total per category id.
final spendByCategoryIdProvider = Provider<Map<String, double>>((ref) {
  final list = ref.watch(monthTxnsProvider).value ?? const <Txn>[];
  final map = <String, double>{};
  for (final t in list) {
    if (t.type != TxnType.expense || t.categoryId == null) continue;
    map[t.categoryId!] = (map[t.categoryId!] ?? 0) + t.amount;
  }
  return map;
});

/// Green until 80%, orange until 100%, then red.
Color budgetColor(double ratio) {
  if (ratio < 0.8) return AppColors.green;
  if (ratio < 1.0) return AppColors.orange;
  return AppColors.red;
}

final budgetRepoProvider = Provider<BudgetRepo>((ref) => BudgetRepo(ref));

class BudgetRepo {
  BudgetRepo(this._ref);
  final Ref _ref;

  SupabaseClient get _c => _ref.read(supabaseProvider);

  /// Create or change the budget for [categoryId] (null = overall).
  Future<void> save({String? categoryId, required double amount}) async {
    var q = _c.from('budgets').select('id');
    q = categoryId == null
        ? q.isFilter('category_id', null)
        : q.eq('category_id', categoryId);
    final existing = await q.maybeSingle();

    if (existing == null) {
      await _c.from('budgets').insert({
        'category_id': categoryId,
        'amount': amount,
      });
    } else {
      await _c
          .from('budgets')
          .update({'amount': amount}).eq('id', existing['id'] as String);
    }
    _ref.invalidate(budgetsProvider);
  }

  Future<void> remove(String id) async {
    await _c.from('budgets').delete().eq('id', id);
    _ref.invalidate(budgetsProvider);
  }
}