import 'package:intl/intl.dart';

/// ₹1,23,456.50 (Indian digit grouping)
final moneyExact = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 2,
);