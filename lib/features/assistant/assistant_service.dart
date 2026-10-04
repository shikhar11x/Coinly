import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase.dart';

class AssistantException implements Exception {
  AssistantException(this.message);
  final String message;

  @override
  String toString() => message;
}

class AssistantReply {
  const AssistantReply({
    required this.answer,
    required this.followUps,
    this.remaining,
  });

  final String answer;
  final List<String> followUps;
  final int? remaining; // AI actions left today
}

final assistantServiceProvider = Provider<AssistantService>(
  (ref) => AssistantService(ref.watch(supabaseProvider)),
);

class AssistantService {
  AssistantService(this._client);
  final SupabaseClient _client;

    String _errorFrom(FunctionException e) {
    final d = e.details;
    if (d is Map && d['error'] is String) return d['error'] as String;
    if (e.status == 401) return 'Please log in again and retry.';
    if (e.status == 404) return 'The assistant is not deployed yet.';

    // Show what the server said, so problems are easy to find.
    final detail = switch (d) {
      Map m => (m['message'] ?? m['code'] ?? '').toString(),
      String s => s,
      _ => '',
    };
    final short = detail.length > 120 ? '${detail.substring(0, 120)}…' : detail;
    return 'The assistant had a problem '
        '(error ${e.status}${short.isEmpty ? '' : ': $short'}). Try again.';
  }

  Future<AssistantReply> ask(
    String question,
    List<({String role, String text})> history,
  ) async {
    final now = DateTime.now();

    try {
      final res = await _client.functions
          .invoke(
            'assistant',
            body: {
              'question': question,
              'history': [
                for (final h in history) {'role': h.role, 'text': h.text},
              ],
              // The phone's own date/timezone, so "this month" is right in India.
              'today': DateFormat('yyyy-MM-dd').format(now),
              'tz_offset_minutes': now.timeZoneOffset.inMinutes,
            },
          )
          .timeout(const Duration(seconds: 50));

      final data = res.data;
      if (data is! Map || data['answer'] is! String) {
        throw AssistantException('Unexpected reply from the server.');
      }

      final follow = data['follow_ups'];
      return AssistantReply(
        answer: (data['answer'] as String).trim(),
        followUps: [
          if (follow is List)
            for (final f in follow)
              if (f is String && f.trim().isNotEmpty) f.trim(),
        ].take(3).toList(),
        remaining: (data['remaining'] as num?)?.toInt(),
      );
    } on FunctionException catch (e) {
      throw AssistantException(_errorFrom(e));
    } on TimeoutException {
      throw AssistantException(
        'This is taking too long. Check your internet and try again.',
      );
    }
  }
}