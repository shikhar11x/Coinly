enum TxnType { income, expense }

class TxnCategory {
  const TxnCategory({
    required this.id,
    required this.name,
    required this.type,
    this.icon,
    this.color,
  });

  final String id;
  final String name;
  final TxnType type;
  final String? icon;
  final String? color;

  factory TxnCategory.fromMap(Map<String, dynamic> m) => TxnCategory(
        id: m['id'] as String,
        name: m['name'] as String,
        type: m['type'] == 'income' ? TxnType.income : TxnType.expense,
        icon: m['icon'] as String?,
        color: m['color'] as String?,
      );
}

class Txn {
  const Txn({
    required this.id,
    required this.accountId,
    required this.categoryId,
    required this.type,
    required this.amount,
    required this.description,
    required this.date,
    required this.inputMethod,
    this.categoryName,
    this.categoryIcon,
    this.categoryColor,
    this.accountName,
  });

  final String id;
  final String accountId;
  final String? categoryId;
  final TxnType type;
  final double amount;
  final String? description;
  final DateTime date;
  final String inputMethod; // manual | receipt_scan | voice | sms

  // Filled from the joined tables.
  final String? categoryName;
  final String? categoryIcon;
  final String? categoryColor;
  final String? accountName;

  factory Txn.fromMap(Map<String, dynamic> m) {
    final cat = m['categories'] as Map<String, dynamic>?;
    final acc = m['accounts'] as Map<String, dynamic>?;
    return Txn(
      id: m['id'] as String,
      accountId: m['account_id'] as String,
      categoryId: m['category_id'] as String?,
      type: m['type'] == 'income' ? TxnType.income : TxnType.expense,
      amount: (m['amount'] as num).toDouble(),
      description: m['description'] as String?,
      date: DateTime.parse(m['date'] as String).toLocal(),
      inputMethod: (m['input_method'] as String?) ?? 'manual',
      categoryName: cat?['name'] as String?,
      categoryIcon: cat?['icon'] as String?,
      categoryColor: cat?['color'] as String?,
      accountName: acc?['name'] as String?,
    );
  }
}