import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/supabase.dart';

/// Emits an event whenever the user logs in, logs out, or the token refreshes.
final authStateProvider = StreamProvider((ref) {
  return ref.watch(supabaseProvider).auth.onAuthStateChange;
});

/// The logged-in user's row from the `profiles` table (or null if logged out).
final profileProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  ref.watch(authStateProvider); // re-fetch whenever auth changes
  final client = ref.watch(supabaseProvider);
  final user = client.auth.currentUser;
  if (user == null) return null;

  return client.from('profiles').select().eq('id', user.id).maybeSingle();
});