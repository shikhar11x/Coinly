import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase.dart';
import '../transactions/txn_draft.dart';
import '../transactions/txn_models.dart';

class VoiceException implements Exception {
  VoiceException(this.message);
  final String message;

  @override
  String toString() => message;
}

final voiceServiceProvider = Provider<VoiceService>(
  (ref) => VoiceService(ref.watch(supabaseProvider)),
);

class VoiceService {
  VoiceService(this._client);
  final SupabaseClient _client;

  String _errorFrom(FunctionException e) {
    final d = e.details;
    if (d is Map && d['error'] is String) return d['error'] as String;
    if (e.status == 401) return 'Please log in again and retry.';
    if (e.status == 404) return 'The voice reader is not deployed yet.';
    return 'The voice reader had a problem. Try again.';
  }

  Future<TxnDraft> parse(String transcript, List<TxnCategory> categories) async {
    List<String> names(TxnType t) => [
          for (final c in categories)
            if (c.type == t) c.name,
        ];

    final Map<dynamic, dynamic> data;
    try {
      final res = await _client.functions
          .invoke(
            'parse-voice',
            body: {
              'transcript': transcript,
              'expense_categories': names(TxnType.expense),
              'income_categories': names(TxnType.income),
              // The phone's local date, so "yesterday" is correct in your timezone.
              'today': DateFormat('yyyy-MM-dd').format(DateTime.now()),
            },
          )
          .timeout(const Duration(seconds: 40));

      if (res.data is! Map) {
        throw VoiceException('Unexpected reply from the server.');
      }
      data = res.data as Map;
    } on FunctionException catch (e) {
      throw VoiceException(_errorFrom(e));
    } on TimeoutException {
      throw VoiceException(
        'This is taking too long. Check your internet and try again.',
      );
    }

    final type = data['type'] == 'income' ? TxnType.income : TxnType.expense;
    final pool = categories.where((c) => c.type == type).toList();

    // Category name -> your category id (fallback: "Other" / "Other Income").
    final wanted = ((data['category'] as String?) ?? '').toLowerCase();
    TxnCategory? cat;
    for (final c in pool) {
      if (c.name.toLowerCase() == wanted) {
        cat = c;
        break;
      }
    }
    final fallback = type == TxnType.income ? 'Other Income' : 'Other';
    cat ??= pool.where((c) => c.name == fallback).firstOrNull;

    // Spoken date + current time of day, never in the future.
    DateTime? date;
    final ds = data['date'];
    if (ds is String) {
      final d = DateTime.tryParse(ds);
      if (d != null) {
        final now = DateTime.now();
        final withTime = DateTime(d.year, d.month, d.day, now.hour, now.minute);
        date = withTime.isAfter(now) ? now : withTime;
      }
    }

    return TxnDraft(
      type: type,
      amount: (data['amount'] as num?)?.toDouble(),
      categoryId: cat?.id,
      description: data['description'] as String?,
      date: date,
      inputMethod: 'voice',
      voiceTranscript: transcript,
    );
  }
}