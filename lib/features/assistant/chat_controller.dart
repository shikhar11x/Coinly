import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase.dart';
import '../../core/theme.dart';
import '../auth/auth_providers.dart';
import 'assistant_service.dart';

const kAssistantSuggestions = [
  (
    'How much did I spend on food this month?',
    Icons.restaurant_rounded,
    AppColors.red,
  ),
  (
    'Am I on track with my budget?',
    Icons.track_changes_rounded,
    AppColors.green,
  ),
  (
    'What was my biggest expense this week?',
    Icons.trending_up_rounded,
    AppColors.orange,
  ),
  (
    'Compare this month with last month',
    Icons.compare_arrows_rounded,
    AppColors.blue,
  ),
  (
    'Where can I cut my spending?',
    Icons.content_cut_rounded,
    AppColors.purple,
  ),
  (
    'Which account has the most money?',
    Icons.account_balance_wallet_outlined,
    AppColors.green,
  ),
];

class ChatMessage {
  const ChatMessage({
    required this.role, // 'user' | 'assistant'
    required this.text,
    this.followUps = const [],
    this.isError = false,
  });

  final String role;
  final String text;
  final List<String> followUps;
  final bool isError;
}

class ChatState {
  const ChatState({
    this.messages = const [],
    this.sending = false,
    this.remaining,
  });

  final List<ChatMessage> messages;
  final bool sending;
  final int? remaining; // AI actions left today (known after the first reply)

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? sending,
    int? remaining,
  }) =>
      ChatState(
        messages: messages ?? this.messages,
        sending: sending ?? this.sending,
        remaining: remaining ?? this.remaining,
      );
}

/// The logged-in user's id. Only changes when a different user logs in
/// (not on token refresh), so chat is reset per user.
final currentUserIdProvider = Provider<String?>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(supabaseProvider).auth.currentUser?.id;
});

class ChatNotifier extends Notifier<ChatState> {
  @override
  ChatState build() {
    ref.watch(currentUserIdProvider); // a new user starts a fresh chat
    return const ChatState();
  }

  Future<void> send(String raw) async {
    var question = raw.trim();
    if (question.isEmpty || state.sending) return;
    if (question.length > 400) question = question.substring(0, 400);

    final uid = ref.read(currentUserIdProvider);
    bool changedUser() => ref.read(currentUserIdProvider) != uid;

    // History = earlier real messages (no errors), last 6.
    final all = [
      for (final m in state.messages)
        if (!m.isError) (role: m.role, text: m.text),
    ];
    final history = all.length > 6 ? all.sublist(all.length - 6) : all;

    state = state.copyWith(
      messages: [...state.messages, ChatMessage(role: 'user', text: question)],
      sending: true,
    );

    ChatMessage reply;
    int? remaining;
    try {
      final r = await ref.read(assistantServiceProvider).ask(question, history);
      reply = ChatMessage(
        role: 'assistant',
        text: r.answer,
        followUps: r.followUps,
      );
      remaining = r.remaining;
    } on AssistantException catch (e) {
      reply = ChatMessage(role: 'assistant', text: e.message, isError: true);
    } catch (_) {
      reply = const ChatMessage(
        role: 'assistant',
        text: 'Something went wrong. Check your internet and try again.',
        isError: true,
      );
    }

    if (changedUser()) return; // logged out / switched while waiting

    state = state.copyWith(
      messages: [...state.messages, reply],
      sending: false,
      remaining: remaining,
    );
  }

  /// Re-sends the last question after an error.
  Future<void> retry() async {
    if (state.sending) return;
    final msgs = [...state.messages];
    if (msgs.isEmpty || !msgs.last.isError) return;

    msgs.removeLast();
    if (msgs.isEmpty || msgs.last.role != 'user') {
      state = state.copyWith(messages: msgs);
      return;
    }
    final question = msgs.removeLast().text;
    state = state.copyWith(messages: msgs);
    await send(question);
  }

  void clear() {
    if (state.sending) return;
    state = const ChatState();
  }
}

final chatProvider =
    NotifierProvider<ChatNotifier, ChatState>(ChatNotifier.new);