import 'txn_models.dart';

/// Values to pre-fill the Add Transaction form (from AI receipt or voice).
class TxnDraft {
  const TxnDraft({
    this.type = TxnType.expense,
    this.amount,
    this.categoryId,
    this.description,
    this.date,
    this.inputMethod = 'manual',
    this.voiceTranscript,
  });

  final TxnType type;
  final double? amount;
  final String? categoryId;
  final String? description;
  final DateTime? date;
  final String inputMethod; // manual | receipt_scan | voice | sms
  final String? voiceTranscript;
}