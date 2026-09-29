import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase.dart';
import '../auth/auth_providers.dart';
import 'account.dart';

final accountsProvider = FutureProvider<List<Account>>((ref) async {
  ref.watch(authStateProvider); // reload when the user logs in/out
  final client = ref.watch(supabaseProvider);
  if (client.auth.currentUser == null) return [];

  final rows = await client.from('accounts').select().order('created_at');
  return rows.map(Account.fromMap).toList();
});

/// Sum of all account balances (null until the first load finishes).
final totalBalanceProvider = Provider<double?>((ref) {
  final list = ref.watch(accountsProvider).value;
  if (list == null) return null;
  return list.fold<double>(0, (sum, a) => sum + a.balance);
});

final accountsRepoProvider = Provider<AccountsRepo>((ref) => AccountsRepo(ref));

class AccountsRepo {
  AccountsRepo(this._ref);
  final Ref _ref;

  SupabaseClient get _c => _ref.read(supabaseProvider);
  void _refresh() => _ref.invalidate(accountsProvider);

  Future<void> add({
    required String name,
    required AccountType type,
    required double balance,
  }) async {
    // First account ever => make it the default.
    final existing = await _c.from('accounts').select('id').limit(1);

    await _c.from('accounts').insert({
      'name': name,
      'type': type.dbValue,
      'balance': balance,
      'is_default': existing.isEmpty,
    });
    _refresh();
  }

  Future<void> update(
    Account a, {
    required String name,
    required AccountType type,
    required double balance,
  }) async {
    await _c.from('accounts').update({
      'name': name,
      'type': type.dbValue,
      'balance': balance,
    }).eq('id', a.id);
    _refresh();
  }

  Future<void> setDefault(String id) async {
    await _c.rpc('set_default_account', params: {'p_id': id});
    _refresh();
  }

  Future<void> delete(Account a) async {
    await _c.from('accounts').delete().eq('id', a.id);

    if (a.isDefault) {
      final rest =
          await _c.from('accounts').select('id').order('created_at').limit(1);
      if (rest.isNotEmpty) {
        await _c.rpc('set_default_account',
            params: {'p_id': rest.first['id'] as String});
      }
    }
    _refresh();
  }
}