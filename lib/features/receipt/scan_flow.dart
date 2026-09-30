import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../transactions/txn_draft.dart';
import '../transactions/txn_models.dart';
import '../transactions/txn_providers.dart';
import 'receipt_service.dart';

Future<void> startReceiptScan(BuildContext context, WidgetRef ref) async {
  // Grab these before any await so we never use a stale context.
  final messenger = ScaffoldMessenger.of(context);
  final router = GoRouter.of(context);
  final nav = Navigator.of(context, rootNavigator: true);

  // 1. Camera or gallery?
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Take a photo'),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from gallery'),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
        ],
      ),
    ),
  );
  if (source == null) return;

  // 2. Take/pick the photo. Shrinking it keeps the upload fast and cheap.
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

  // 3. Show a "reading" dialog while the AI works.
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Expanded(child: Text('Reading your receipt…')),
          ],
        ),
      ),
    ),
  );

  TxnDraft? draft;
  String? error;
  try {
    final cats = await ref.read(categoriesProvider.future);
    final expenseCats = cats.where((c) => c.type == TxnType.expense).toList();
    draft = await ref.read(receiptServiceProvider).scan(file, expenseCats);
  } on ReceiptException catch (e) {
    error = e.message;
  } catch (_) {
    error = 'Something went wrong. Check your internet and try again.';
  }

  nav.pop(); // close the "reading" dialog

  // 4. Open the pre-filled form, or explain what went wrong.
  if (draft != null) {
    router.push('/transaction', extra: draft);
  } else {
    messenger.showSnackBar(SnackBar(content: Text(error ?? 'Scan failed.')));
  }
}