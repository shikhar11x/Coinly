import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/supabase.dart';
import '../../core/theme.dart';
import '../auth/auth_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(supabaseProvider);
    final profile = ref.watch(profileProvider);
    final email = client.auth.currentUser?.email ?? '';

    final name = profile.maybeWhen(
      data: (p) => (p?['name'] as String?) ?? '',
      orElse: () => '',
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 24),
            const CircleAvatar(
              radius: 40,
              backgroundColor: AppColors.dark,
              child: Icon(Icons.person, color: Colors.white70, size: 40),
            ),
            const SizedBox(height: 16),
            Text(
              name.isEmpty ? 'Your profile' : name,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(email, style: const TextStyle(color: Colors.black54)),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => client.auth.signOut(),
                icon: const Icon(Icons.logout),
                label: const Text('Log out'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.red,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 100), // space above floating nav bar
          ],
        ),
      ),
    );
  }
}