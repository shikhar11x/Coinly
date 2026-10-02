import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme.dart';
import '../../core/ui_kit.dart';
import '../../core/working_dialog.dart';
import '../transactions/txn_draft.dart';
import '../transactions/txn_models.dart';
import '../transactions/txn_providers.dart';
import 'receipt_service.dart';

Future<void> startReceiptScan(BuildContext context, WidgetRef ref) async {
  // Grab these before any await so we never use a stale context.
  final messenger = ScaffoldMessenger.of(context);
  final router = GoRouter.of(context);
  final service = ref.read(receiptServiceProvider);

  // 1. Camera or gallery?
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    showDragHandle: true,
    builder: (_) => const _SourceSheet(),
  );
  if (source == null) return;

  // 2. Take / pick the photo. Shrinking it keeps the upload fast and cheap.
  XFile? file;
  try {
    file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 80,
    );
  } catch (_) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Could not open the camera or gallery. Check permissions.'),
      ),
    );
    return;
  }
  if (file == null) return; // user cancelled
  if (!context.mounted) return;

  // 3. Show the "reading" dialog while the AI works.
  final close = showWorkingDialog(
    context,
    icon: Icons.document_scanner_outlined,
    color: AppColors.blue,
    title: 'Reading your receipt…',
    subtitle: 'AI is finding the total, category and date.',
  );

  TxnDraft? draft;
  String? error;
  try {
    final cats = await ref.read(categoriesProvider.future);
    final expenseCats = cats.where((c) => c.type == TxnType.expense).toList();
    draft = await service.scan(file, expenseCats);
  } on ReceiptException catch (e) {
    error = e.message;
  } catch (_) {
    error = 'Something went wrong. Check your internet and try again.';
  }

  close();

  // 4. Open the pre-filled form, or explain what went wrong.
  if (draft != null) {
    router.push('/transaction', extra: draft);
  } else {
    messenger.showSnackBar(SnackBar(content: Text(error ?? 'Scan failed.')));
  }
}

// ============================================================
// Source sheet
// ============================================================

class _SourceSheet extends StatelessWidget {
  const _SourceSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Scan a receipt', style: context.tt.titleLarge),
            const SizedBox(height: 2),
            Text(
              'AI reads the amount, category and date for you',
              style: TextStyle(fontSize: 13, color: context.muted),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _SourceTile(
                    icon: Icons.photo_camera_outlined,
                    color: AppColors.blue,
                    title: 'Take a photo',
                    subtitle: 'Use the camera',
                    onTap: () => Navigator.pop(context, ImageSource.camera),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SourceTile(
                    icon: Icons.photo_library_outlined,
                    color: AppColors.purple,
                    title: 'Gallery',
                    subtitle: 'Pick a saved photo',
                    onTap: () => Navigator.pop(context, ImageSource.gallery),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.cs.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lightbulb_outline_rounded,
                    size: 18,
                    color: context.cs.onPrimaryContainer,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Lay the receipt flat, use good light and keep the '
                      'total in view.',
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                        color: context.cs.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({
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
        decoration: BoxDecoration(
          color: context.cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: context.cs.outline),
        ),
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