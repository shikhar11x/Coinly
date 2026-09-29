import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Turns the icon name saved in the `categories` table into a real icon.
IconData iconFromName(String? name) {
  return switch (name) {
    'restaurant' => Icons.restaurant,
    'shopping_cart' => Icons.shopping_cart,
    'directions_car' => Icons.directions_car,
    'shopping_bag' => Icons.shopping_bag,
    'receipt_long' => Icons.receipt_long,
    'movie' => Icons.movie,
    'favorite' => Icons.favorite,
    'home' => Icons.home,
    'more_horiz' => Icons.more_horiz,
    'payments' => Icons.payments,
    'work' => Icons.work,
    'add_circle' => Icons.add_circle,
    _ => Icons.category_outlined,
  };
}

/// '#EF5350' -> Color. Falls back to grey if the value is missing or invalid.
Color colorFromHex(String? hex, {Color fallback = const Color(0xFF78909C)}) {
  if (hex == null || !hex.startsWith('#') || hex.length != 7) return fallback;
  final v = int.tryParse(hex.substring(1), radix: 16);
  return v == null ? fallback : Color(0xFF000000 | v);
}

/// "Today", "Yesterday", or "Mon, 29 Sep 2026".
String dayLabel(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  return DateFormat('EEE, d MMM y').format(day);
}