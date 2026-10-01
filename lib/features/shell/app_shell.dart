import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/nav.dart';
import '../../core/theme.dart';
import '../../core/ui_kit.dart';
import '../dashboard/dashboard_screen.dart';
import '../profile/profile_screen.dart';
import '../receipt/scan_flow.dart';
import '../transactions/transactions_screen.dart';
import '../voice/voice_flow.dart';

/// Set to false if the blur feels slow (e.g. software rendering in Chrome).
const bool _kGlassBlur = true;

enum _AddAction { scan, voice, manual }

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  bool _addOpen = false;

  void _go(int i) {
    if (i == ref.read(tabIndexProvider)) return;
    HapticFeedback.selectionClick();
    ref.read(tabIndexProvider.notifier).set(i);
  }

  Future<void> _openAdd() async {
    HapticFeedback.mediumImpact();
    setState(() => _addOpen = true);

    final action = await showModalBottomSheet<_AddAction>(
      context: context,
      showDragHandle: true,
      builder: (_) => const _AddSheet(),
    );

    if (!mounted) return;
    setState(() => _addOpen = false);
    if (action == null) return;

    switch (action) {
      case _AddAction.scan:
        startReceiptScan(context, ref);
      case _AddAction.voice:
        startVoiceEntry(context, ref);
      case _AddAction.manual:
        context.push('/transaction');
    }
  }

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(tabIndexProvider);

    final pages = <Widget>[
      const DashboardScreen(),
      const TransactionsScreen(),
      const _AssistantSoon(),
      const ProfileScreen(),
    ];

    return PopScope(
      // Back button: first return to Home, then exit.
      canPop: index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _go(0);
      },
      child: Scaffold(
        extendBody: true, // content scrolls under the floating bar
        body: IndexedStack(
          index: index,
          children: [
            for (var i = 0; i < pages.length; i++)
              _TabPage(active: i == index, child: pages[i]),
          ],
        ),
        bottomNavigationBar: _NavBar(
          index: index,
          addOpen: _addOpen,
          onSelect: _go,
          onAdd: _openAdd,
        ),
      ),
    );
  }
}

// ============================================================
// Tab page: fade + small slide when it becomes active
// ============================================================

class _TabPage extends StatefulWidget {
  const _TabPage({required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  State<_TabPage> createState() => _TabPageState();
}

class _TabPageState extends State<_TabPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
    value: widget.active ? 1 : 0,
  );
  late final Animation<double> _a =
      CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);

  @override
  void didUpdateWidget(covariant _TabPage old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _a,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: _a.value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, (1 - _a.value) * 10),
          child: child,
        ),
      ),
    );
  }
}

// ============================================================
// Floating glass navigation bar
// ============================================================

class _NavBar extends StatelessWidget {
  const _NavBar({
    required this.index,
    required this.addOpen,
    required this.onSelect,
    required this.onAdd,
  });

  final int index;
  final bool addOpen;
  final ValueChanged<int> onSelect;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final bar = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.dark.withValues(alpha: _kGlassBlur ? 0.80 : 0.96),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _NavItem(
            icon: Icons.home_outlined,
            activeIcon: Icons.home_rounded,
            label: 'Home',
            selected: index == 0,
            onTap: () => onSelect(0),
          ),
          _NavItem(
            icon: Icons.receipt_long_outlined,
            activeIcon: Icons.receipt_long_rounded,
            label: 'Activity',
            selected: index == 1,
            onTap: () => onSelect(1),
          ),
          _AddButton(open: addOpen, onTap: onAdd),
          _NavItem(
            icon: Icons.auto_awesome_outlined,
            activeIcon: Icons.auto_awesome_rounded,
            label: 'AI',
            selected: index == 2,
            onTap: () => onSelect(2),
          ),
          _NavItem(
            icon: Icons.person_outline_rounded,
            activeIcon: Icons.person_rounded,
            label: 'Profile',
            selected: index == 3,
            onTap: () => onSelect(3),
          ),
        ],
      ),
    );

    return SafeArea(
      top: false,
      child: Align(
        heightFactor: 1,
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.28),
                    blurRadius: 28,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: _kGlassBlur
                    ? BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                        child: bar,
                      )
                    : bar,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.green : Colors.white60;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Pressable(
        onTap: onTap,
        haptic: false, // the shell already vibrates on tab change
        scale: 0.92,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(
            horizontal: selected ? 14 : 11,
            vertical: 11,
          ),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.green.withValues(alpha: 0.16)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(selected ? activeIcon : icon, color: color, size: 24),
              AnimatedSize(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                alignment: Alignment.centerLeft,
                child: selected
                    ? Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text(
                          label,
                          maxLines: 1,
                          style: const TextStyle(
                            color: AppColors.green,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.open, required this.onTap});

  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Add transaction',
      child: Pressable(
        onTap: onTap,
        haptic: false,
        scale: 0.9,
        child: Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.green, AppColors.greenDark],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.green.withValues(alpha: 0.45),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          // 45 degree turn makes the + look like an ×
          child: AnimatedRotation(
            turns: open ? 0.125 : 0,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutBack,
            child: const Icon(
              Icons.add_rounded,
              color: AppColors.dark,
              size: 30,
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// Add sheet
// ============================================================

class _AddSheet extends StatelessWidget {
  const _AddSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add transaction', style: context.tt.titleLarge),
            const SizedBox(height: 2),
            Text(
              'Choose how you want to log it',
              style: TextStyle(fontSize: 13, color: context.muted),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _BigTile(
                    icon: Icons.document_scanner_outlined,
                    color: AppColors.blue,
                    title: 'Scan receipt',
                    subtitle: 'AI reads the bill',
                    onTap: () => Navigator.pop(context, _AddAction.scan),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _BigTile(
                    icon: Icons.mic_none_rounded,
                    color: AppColors.red,
                    title: 'Voice entry',
                    subtitle: 'Just say it',
                    onTap: () => Navigator.pop(context, _AddAction.voice),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _WideTile(
              icon: Icons.edit_outlined,
              color: AppColors.green,
              title: 'Add manually',
              subtitle: 'Type it in yourself',
              onTap: () => Navigator.pop(context, _AddAction.manual),
            ),
          ],
        ),
      ),
    );
  }
}

BoxDecoration _tileDecoration(BuildContext context) => BoxDecoration(
      color: context.cs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: context.cs.outline),
    );

class _BigTile extends StatelessWidget {
  const _BigTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: _tileDecoration(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconBadge(icon: icon, color: color, size: 46),
            const SizedBox(height: 14),
            Text(title, style: context.tt.titleMedium),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(fontSize: 12, color: context.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _WideTile extends StatelessWidget {
  const _WideTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: _tileDecoration(context),
        child: Row(
          children: [
            IconBadge(icon: icon, color: color, size: 44),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.tt.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: context.muted),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_rounded, size: 18, color: context.muted),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// AI tab placeholder (real assistant comes later)
// ============================================================

class _AssistantSoon extends StatelessWidget {
  const _AssistantSoon();

  static const _samples = [
    'How much did I spend on food?',
    'Am I on track this month?',
    'Biggest expense this week?',
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 90),
        child: EmptyState(
          icon: Icons.auto_awesome_rounded,
          title: 'AI assistant is coming',
          subtitle: 'Soon you can ask things like:',
          action: Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [for (final q in _samples) _SampleChip(q)],
          ),
        ),
      ),
    );
  }
}

class _SampleChip extends StatelessWidget {
  const _SampleChip(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: context.cs.outline),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: context.muted,
        ),
      ),
    );
  }
}