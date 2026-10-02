import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/nav.dart';
import '../../core/supabase.dart';
import '../../core/theme.dart';
import '../../core/theme_mode.dart';
import '../../core/ui_kit.dart';
import '../accounts/accounts_providers.dart';
import '../auth/auth_providers.dart';
import '../transactions/txn_providers.dart';

/// Content never gets wider than this (tablets / Chrome).
const double _maxW = 560;

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  // ---------- Log out ----------

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);

    final ok = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const IconBadge(
                icon: Icons.logout_rounded,
                color: AppColors.red,
                size: 56,
              ),
              const SizedBox(height: 14),
              Text('Log out of Coinly?', style: ctx.tt.titleLarge),
              const SizedBox(height: 4),
              Text(
                'You can log back in any time. Your data stays safe.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: ctx.muted),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.red,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Log out'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (ok != true) return;

    HapticFeedback.mediumImpact();

    // Next login should open on Home and on the current month.
    ref.read(tabIndexProvider.notifier).set(0);
    ref.read(selectedMonthProvider.notifier).reset();

    try {
      await ref.read(supabaseProvider).auth.signOut();
      // The router sends you to the login screen automatically.
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not log out. Try again.')),
      );
    }
  }

  // ---------- Edit name ----------

  void _editName(BuildContext context, String current) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _EditNameSheet(initial: current),
    );
  }

  // ---------- Build ----------

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(supabaseProvider).auth.currentUser;
    final email = user?.email ?? '';
    final since = DateTime.tryParse(user?.createdAt ?? '')?.toLocal();

    final name = ref.watch(profileProvider).maybeWhen(
          data: (p) => ((p?['name'] as String?) ?? '').trim(),
          orElse: () => '',
        );

    final accountCount = ref.watch(accountsProvider).value?.length;
    final txnCount = ref.watch(transactionsProvider).value?.length;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // The hero is always dark, so status bar icons must be light.
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: ListView(
          padding: EdgeInsets.zero,
          children: [
            _Hero(
              name: name,
              email: email,
              since: since,
              accounts: accountCount?.toString(),
              transactions: txnCount == null
                  ? null
                  : (txnCount >= 500 ? '500+' : txnCount.toString()),
              onEdit: () => _editName(context, name),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _maxW),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 22, 16, 130),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ---------- Money ----------
                      const _Label('MONEY'),
                      const SizedBox(height: 10),
                      FadeSlideIn(
                        child: AppCard(
                          padding: EdgeInsets.zero,
                          child: Column(
                            children: [
                              _Row(
                                icon: Icons.account_balance_wallet_outlined,
                                color: AppColors.green,
                                title: 'My accounts',
                                subtitle: accountCount == null
                                    ? 'Banks, cash, cards'
                                    : '$accountCount '
                                        '${accountCount == 1 ? 'account' : 'accounts'}',
                                onTap: () => context.push('/accounts'),
                              ),
                              const Divider(indent: 66, endIndent: 14),
                              _Row(
                                icon: Icons.pie_chart_outline_rounded,
                                color: AppColors.purple,
                                title: 'Budgets',
                                subtitle: 'Monthly and per category',
                                onTap: () => context.push('/budgets'),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // ---------- Appearance ----------
                      const SizedBox(height: 24),
                      const _Label('APPEARANCE'),
                      const SizedBox(height: 10),
                      const FadeSlideIn(
                        delay: Duration(milliseconds: 80),
                        child: _ThemeCard(),
                      ),

                      // ---------- Account ----------
                      const SizedBox(height: 24),
                      const _Label('ACCOUNT'),
                      const SizedBox(height: 10),
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 160),
                        child: AppCard(
                          padding: EdgeInsets.zero,
                          child: Column(
                            children: [
                              _Row(
                                icon: Icons.badge_outlined,
                                color: AppColors.blue,
                                title: 'Edit name',
                                subtitle: name.isEmpty ? 'Not set' : name,
                                onTap: () => _editName(context, name),
                              ),
                              const Divider(indent: 66, endIndent: 14),
                              _Row(
                                icon: Icons.logout_rounded,
                                color: AppColors.red,
                                title: 'Log out',
                                subtitle: email,
                                danger: true,
                                onTap: () => _confirmLogout(context, ref),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),
                      Center(
                        child: Text(
                          'Coinly',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: context.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Hero header
// ============================================================

class _Hero extends StatelessWidget {
  const _Hero({
    required this.name,
    required this.email,
    required this.since,
    required this.accounts,
    required this.transactions,
    required this.onEdit,
  });

  final String name;
  final String email;
  final DateTime? since;
  final String? accounts; // null while loading
  final String? transactions; // null while loading
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final initial = name.isEmpty ? '?' : name[0].toUpperCase();

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(36)),
      child: HeroBackground(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, top + 16, 20, 24),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxW),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Profile',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.6,
                          ),
                        ),
                      ),
                      Pressable(
                        onTap: onEdit,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.09),
                            ),
                          ),
                          child: const Icon(
                            Icons.edit_outlined,
                            color: Colors.white70,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.green.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: AppColors.green.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Text(
                          initial,
                          style: const TextStyle(
                            color: AppColors.green,
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name.isEmpty ? 'Your profile' : name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 13,
                              ),
                            ),
                            if (since != null) ...[
                              const SizedBox(height: 8),
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
                                  'Member since ${DateFormat('MMM y').format(since!)}',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: _HeroStat(
                          icon: Icons.account_balance_wallet_outlined,
                          label: 'Accounts',
                          value: accounts,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _HeroStat(
                          icon: Icons.receipt_long_outlined,
                          label: 'Transactions',
                          value: transactions,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.green.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: AppColors.green, size: 17),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value ?? '—',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Theme (dark mode) selector
// ============================================================

class _ThemeCard extends ConsumerWidget {
  const _ThemeCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);

    void pick(ThemeMode m) {
      if (m == mode) return;
      HapticFeedback.selectionClick();
      ref.read(themeModeProvider.notifier).set(m);
    }

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _ThemeOption(
                  icon: Icons.brightness_auto_rounded,
                  label: 'System',
                  selected: mode == ThemeMode.system,
                  onTap: () => pick(ThemeMode.system),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ThemeOption(
                  icon: Icons.light_mode_rounded,
                  label: 'Light',
                  selected: mode == ThemeMode.light,
                  onTap: () => pick(ThemeMode.light),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ThemeOption(
                  icon: Icons.dark_mode_rounded,
                  label: 'Dark',
                  selected: mode == ThemeMode.dark,
                  onTap: () => pick(ThemeMode.dark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'System follows your phone\'s setting.',
            style: TextStyle(fontSize: 12, color: context.muted),
          ),
        ],
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.green : context.muted;

    return Pressable(
      onTap: onTap,
      haptic: false, // the caller already vibrates
      scale: 0.95,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.green.withValues(alpha: 0.12)
              : context.cs.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? AppColors.green : context.cs.outline,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24, color: color),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? null : context.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Small pieces
// ============================================================

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
          color: context.muted,
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.color,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.danger = false,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final bool danger;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            IconBadge(icon: icon, color: color, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: danger ? AppColors.red : null,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: context.muted),
                    ),
                  ],
                ],
              ),
            ),
            if (!danger)
              Icon(Icons.chevron_right_rounded, color: context.muted),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Edit name sheet
// ============================================================

class _EditNameSheet extends ConsumerStatefulWidget {
  const _EditNameSheet({required this.initial});
  final String initial;

  @override
  ConsumerState<_EditNameSheet> createState() => _EditNameSheetState();
}

class _EditNameSheetState extends ConsumerState<_EditNameSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initial);
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
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

    final client = ref.read(supabaseProvider);
    final uid = client.auth.currentUser?.id;
    if (uid == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Please log in again.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      // upsert: also works if the profile row was never created.
      await client.from('profiles').upsert({
        'id': uid,
        'name': _name.text.trim(),
      });
      ref.invalidate(profileProvider); // dashboard greeting updates too
      HapticFeedback.lightImpact();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Name updated')));
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
            Text('Edit name', style: context.tt.titleLarge),
            const SizedBox(height: 2),
            Text(
              'This is what Coinly calls you on the home screen.',
              style: TextStyle(fontSize: 13, color: context.muted),
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _name,
              autofocus: true,
              maxLength: 40,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _save(),
              decoration: const InputDecoration(
                labelText: 'Your name',
                prefixIcon: Icon(Icons.person_outline_rounded),
                counterText: '',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: 'Save name',
              loading: _saving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}