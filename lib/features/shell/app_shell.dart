import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../dashboard/dashboard_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  // Placeholder pages; we replace these in later steps.
  static const _pages = <Widget>[
    DashboardScreen(),
    Center(child: Text('Transactions')),
    Center(child: Text('AI Assistant')),
    Center(child: Text('Profile')),
  ];

  void _showAddSheet() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.document_scanner_outlined,
                  color: AppColors.blue),
              title: const Text('Scan receipt with AI'),
              onTap: () => Navigator.pop(context), // Step 7
            ),
            ListTile(
              leading: const Icon(Icons.mic_none, color: AppColors.red),
              title: const Text('Voice entry'),
              onTap: () => Navigator.pop(context), // Step 8
            ),
            ListTile(
              leading: const Icon(Icons.add, color: AppColors.green),
              title: const Text('Add manually'),
              onTap: () => Navigator.pop(context), // Step 5
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, // lets page content scroll under the floating bar
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.dark,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.home_rounded,
                label: 'Home',
                selected: _index == 0,
                onTap: () => setState(() => _index = 0),
              ),
              _NavItem(
                icon: Icons.receipt_long_rounded,
                label: 'Transactions',
                selected: _index == 1,
                onTap: () => setState(() => _index = 1),
              ),
              // Center Add button
              GestureDetector(
                onTap: _showAddSheet,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    color: AppColors.green,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 28),
                ),
              ),
              _NavItem(
                icon: Icons.auto_awesome,
                label: 'Assistant',
                selected: _index == 2,
                onTap: () => setState(() => _index = 2),
              ),
              _NavItem(
                icon: Icons.person_rounded,
                label: 'Profile',
                selected: _index == 3,
                onTap: () => setState(() => _index = 3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
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
    final color = selected ? AppColors.green : Colors.white54;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: color, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}