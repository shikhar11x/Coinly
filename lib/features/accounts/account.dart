import 'package:flutter/material.dart';

enum AccountType {
  cash,
  bank,
  creditCard,
  savings,
  wallet;

  String get dbValue => this == creditCard ? 'credit_card' : name;

  static AccountType fromDb(String v) => AccountType.values.firstWhere(
        (t) => t.dbValue == v,
        orElse: () => AccountType.bank,
      );

  String get label => switch (this) {
        AccountType.cash => 'Cash',
        AccountType.bank => 'Bank account',
        AccountType.creditCard => 'Credit card',
        AccountType.savings => 'Savings',
        AccountType.wallet => 'Wallet / UPI',
      };

  IconData get icon => switch (this) {
        AccountType.cash => Icons.payments_outlined,
        AccountType.bank => Icons.account_balance,
        AccountType.creditCard => Icons.credit_card,
        AccountType.savings => Icons.savings_outlined,
        AccountType.wallet => Icons.account_balance_wallet_outlined,
      };
}

class Account {
  const Account({
    required this.id,
    required this.name,
    required this.type,
    required this.balance,
    required this.isDefault,
  });

  final String id;
  final String name;
  final AccountType type;
  final double balance;
  final bool isDefault;

  factory Account.fromMap(Map<String, dynamic> m) => Account(
        id: m['id'] as String,
        name: m['name'] as String,
        type: AccountType.fromDb(m['type'] as String),
        balance: (m['balance'] as num).toDouble(),
        isDefault: m['is_default'] as bool,
      );
}