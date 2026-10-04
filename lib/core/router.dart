import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase.dart';
import '../features/assistant/chat_screen.dart';
import '../features/accounts/accounts_screen.dart';
import '../features/auth/auth_screen.dart';
import '../features/budgets/budgets_screen.dart';
import '../features/shell/app_shell.dart';
import '../features/transactions/txn_draft.dart';
import '../features/transactions/txn_form_screen.dart';
import '../features/transactions/txn_models.dart';

/// Lets GoRouter re-check redirects whenever login state changes.
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Stream<AuthState> stream) {
    _sub = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<AuthState> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final client = ref.watch(supabaseProvider);
  final refresh = _AuthRefresh(client.auth.onAuthStateChange);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final loggedIn = client.auth.currentSession != null;
      final onLogin = state.matchedLocation == '/login';

      if (!loggedIn && !onLogin) return '/login';
      if (loggedIn && onLogin) return '/';
      return null; // no redirect
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const AppShell()),
      GoRoute(path: '/login', builder: (context, state) => const AuthScreen()),
      GoRoute(
        path: '/accounts',
        builder: (context, state) => const AccountsScreen(),
      ),
      GoRoute(
        path: '/budgets',
        builder: (context, state) => const BudgetsScreen(),
      ),
      GoRoute(
        path: '/transaction',
        // extra: null = new, Txn = edit it, TxnDraft = new but pre-filled
        builder: (context, state) {
          final extra = state.extra;
          return TxnFormScreen(
            existing: extra is Txn ? extra : null,
            draft: extra is TxnDraft ? extra : null,
          );
        },
      ),
            GoRoute(
        path: '/assistant',
        builder: (context, state) => ChatScreen(
          initialQuestion: state.extra is String ? state.extra as String : null,
        ),
      ),
    ],
  );
});