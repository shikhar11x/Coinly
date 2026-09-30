import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase.dart';
import '../transactions/txn_draft.dart';
import '../transactions/txn_models.dart';

class ReceiptException implements Exception {
  ReceiptException(this.message);
  final String message;

  @override
  String toString() => message;
}

final receiptServiceProvider = Provider<ReceiptService>(
  (ref) => ReceiptService(ref.watch(supabaseProvider)),
);

class ReceiptService {
  ReceiptService(this._client);
  final SupabaseClient _client;

  String _mime(String path) {
    final p = path.toLowerCase();
    if (p.endsWith('.png')) return 'image/png';
    if (p.endsWith('.webp')) return 'image/webp';
    if (p.endsWith('.heic')) return 'image/heic';
    if (p.endsWith('.heif')) return 'image/heif';
    return 'image/jpeg';
  }

  String _errorFrom(FunctionException e) {
    final d = e.details;
    if (d is Map && d['error'] is String) return d['error'] as String;
    if (e.status == 401) return 'Please log in again and retry.';
    if (e.status == 404) return 'The receipt reader is not deployed yet.';
    return 'The receipt reader had a problem. Try again.';
  }

  Future<TxnDraft> scan(
    XFile file,
    List<TxnCategory> expenseCategories,
  ) async {
    final bytes = await file.readAsBytes();
    if (bytes.length > 5 * 1024 * 1024) {
      throw ReceiptException('That photo is too large. Try a smaller one.');
    }

    final Map<dynamic, dynamic> data;
    try {
      final res = await _client.functions
          .invoke(
            'parse-receipt',
            body: {
              'image_base64': base64Encode(bytes),
              'mime_type': _mime(file.path),
              'categories': [for (final c in expenseCategories) c.name],
            },
          )
          .timeout(const Duration(seconds: 45));

      if (res.data is! Map) {
        throw ReceiptException('Unexpected reply from the server.');
      }
      data = res.data as Map;
    } on FunctionException catch (e) {
      throw ReceiptException(_errorFrom(e));
    } on TimeoutException {
      throw ReceiptException(
        'This is taking too long. Check your internet and try again.',
      );
    }

    // Category name -> your category id (fallback: "Other").
    final wanted = ((data['category'] as String?) ?? 'Other').toLowerCase();
    TxnCategory? cat;
    for (final c in expenseCategories) {
      if (c.name.toLowerCase() == wanted) {
        cat = c;
        break;
      }
    }
    cat ??= expenseCategories.where((c) => c.name == 'Other').firstOrNull;

    // Receipt date + current time of day, never in the future.
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
      type: TxnType.expense,
      amount: (data['amount'] as num?)?.toDouble(),
      categoryId: cat?.id,
      description: data['description'] as String?,
      date: date,
      inputMethod: 'receipt_scan',
    );
  }
}