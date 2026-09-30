import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../transactions/txn_draft.dart';
import '../transactions/txn_providers.dart';
import 'voice_service.dart';
import 'voice_sheet.dart';

Future<void> startVoiceEntry(BuildContext context, WidgetRef ref) async {
  // Grab these before any await so we never use a stale context.
  final messenger = ScaffoldMessenger.of(context);
  final router = GoRouter.of(context);
  final nav = Navigator.of(context, rootNavigator: true);

  // 1. Listen (or let the user type).
  final transcript = await showVoiceSheet(context);
  if (transcript == null || transcript.trim().length < 3) return;
  if (!context.mounted) return;

  // 2. Show a "working" dialog while the AI reads it.
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
            Expanded(child: Text('Understanding that…')),
          ],
        ),
      ),
    ),
  );

  TxnDraft? draft;
  String? error;
  try {
    final cats = await ref.read(categoriesProvider.future);
    draft = await ref.read(voiceServiceProvider).parse(transcript.trim(), cats);
  } on VoiceException catch (e) {
    error = e.message;
  } catch (_) {
    error = 'Something went wrong. Check your internet and try again.';
  }

  nav.pop(); // close the "working" dialog

  // 3. Open the pre-filled form, or explain what went wrong.
  if (draft != null) {
    router.push('/transaction', extra: draft);
  } else {
    messenger.showSnackBar(SnackBar(content: Text(error ?? 'Voice entry failed.')));
  }
}