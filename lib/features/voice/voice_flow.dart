import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/working_dialog.dart';
import '../transactions/txn_draft.dart';
import '../transactions/txn_providers.dart';
import 'voice_service.dart';
import 'voice_sheet.dart';

String _short(String s) => s.length <= 70 ? s : '${s.substring(0, 67)}…';

Future<void> startVoiceEntry(BuildContext context, WidgetRef ref) async {
  // Grab these before any await so we never use a stale context.
  final messenger = ScaffoldMessenger.of(context);
  final router = GoRouter.of(context);
  final service = ref.read(voiceServiceProvider);

  // 1. Listen (or let the user type).
  final transcript = await showVoiceSheet(context);
  if (transcript == null || transcript.trim().length < 3) return;
  if (!context.mounted) return;

  final text = transcript.trim();

  // 2. Show a "working" dialog while the AI reads it.
  final close = showWorkingDialog(
    context,
    icon: Icons.mic_none_rounded,
    color: AppColors.red,
    title: 'Understanding that…',
    subtitle: '“${_short(text)}”',
  );

  TxnDraft? draft;
  String? error;
  try {
    final cats = await ref.read(categoriesProvider.future);
    draft = await service.parse(text, cats);
  } on VoiceException catch (e) {
    error = e.message;
  } catch (_) {
    error = 'Something went wrong. Check your internet and try again.';
  }

  close();

  // 3. Open the pre-filled form, or explain what went wrong.
  if (draft != null) {
    router.push('/transaction', extra: draft);
  } else {
    messenger.showSnackBar(SnackBar(content: Text(error ?? 'Voice entry failed.')));
  }
}