import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/ui_helpers.dart';
import 'txn_models.dart';
import '../../core/ui_kit.dart';

class TxnTile extends StatelessWidget {
  const TxnTile({super.key, required this.txn, this.onTap});

  final Txn txn;
  final VoidCallback? onTap;

  IconData? get _badge => switch (txn.inputMethod) {
    'voice' => Icons.mic_none,
    'receipt_scan' => Icons.document_scanner_outlined,
    'sms' => Icons.sms_outlined,
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final color = colorFromHex(txn.categoryColor);
    final isIncome = txn.type == TxnType.income;
    final hasDesc = txn.description?.trim().isNotEmpty ?? false;
    final title = hasDesc
        ? txn.description!.trim()
        : (txn.categoryName ?? 'Uncategorized');
    final subtitle = [
      txn.categoryName ?? 'Uncategorized',
      if (txn.accountName != null) txn.accountName!,
    ].join(' • ');

    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.15),
        child: Icon(iconFromName(txn.categoryIcon), color: color, size: 20),
      ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      subtitle: Row(
        children: [
          if (_badge != null) ...[
            Icon(_badge, size: 12, color: Colors.black45),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
      trailing: Text(
        '${isIncome ? '+' : '-'}${moneyExact.format(txn.amount)}',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: isIncome ? context.incomeColor : AppColors.red,
        ),
      ),
    );
  }
}
