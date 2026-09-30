import 'package:intl/intl.dart';

/// ₹1,23,456.50 (Indian digit grouping, 2 decimals)
final moneyExact = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 2,
);

/// ₹1,23,456 (Indian digit grouping, no decimals)
final moneyWhole = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 0,
);