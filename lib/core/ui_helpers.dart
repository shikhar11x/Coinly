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

/// Converts '#EF5350' to a Flutter Color.
///
/// Falls back to grey if the value is missing or invalid.
Color colorFromHex(
  String? hex, {
  Color fallback = const Color(0xFF78909C),
}) {
  if (hex == null ||
      !hex.startsWith('#') ||
      hex.length != 7) {
    return fallback;
  }

  final value = int.tryParse(
    hex.substring(1),
    radix: 16,
  );

  return value == null
      ? fallback
      : Color(0xFF000000 | value);
}

/// Returns "Today", "Yesterday", or "Mon, 29 Sep 2026".
String dayLabel(DateTime d) {
  final now = DateTime.now();

  final today = DateTime(
    now.year,
    now.month,
    now.day,
  );

  final day = DateTime(
    d.year,
    d.month,
    d.day,
  );

  final diff = today.difference(day).inDays;

  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';

  return DateFormat(
    'EEE, d MMM y',
  ).format(day);
}

/// Common rounded card decoration for screens that need
/// a Container instead of a Card widget.
BoxDecoration appCardDecoration(
  BuildContext context, {
  double radius = 20,
  bool highlighted = false,
}) {
  final theme = Theme.of(context);

  final color = theme.colorScheme.surface;

  return BoxDecoration(
    color:
        highlighted
            ? theme.colorScheme.primary.withValues(
                alpha: 0.08,
              )
            : color,

    borderRadius: BorderRadius.circular(radius),

    border: Border.all(
      color: theme.colorScheme.outline.withValues(
        alpha: 0.75,
      ),
    ),
  );
}

/// Creates a soft icon container that automatically
/// follows the current light/dark theme.
Widget iconContainer(
  BuildContext context,
  IconData icon, {
  Color? color,
  double size = 44,
  double iconSize = 20,
}) {
  final theme = Theme.of(context);

  final accent =
      color ?? theme.colorScheme.primary;

  return Container(
    width: size,
    height: size,

    decoration: BoxDecoration(
      color: accent.withValues(alpha: 0.11),
      borderRadius: BorderRadius.circular(
        size * 0.28,
      ),
    ),

    alignment: Alignment.center,

    child: Icon(
      icon,
      size: iconSize,
      color: accent,
    ),
  );
}

/// Small pill/badge useful for transaction types,
/// statuses, etc.
Widget appPill(
  BuildContext context,
  String text, {
  Color? color,
  IconData? icon,
}) {
  final theme = Theme.of(context);

  final accent =
      color ?? theme.colorScheme.primary;

  return Container(
    padding: const EdgeInsets.symmetric(
      horizontal: 10,
      vertical: 6,
    ),

    decoration: BoxDecoration(
      color: accent.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(999),
    ),

    child: Row(
      mainAxisSize: MainAxisSize.min,

      children: [
        if (icon != null) ...[
          Icon(
            icon,
            size: 14,
            color: accent,
          ),

          const SizedBox(width: 5),
        ],

        Text(
          text,

          style: TextStyle(
            color: accent,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

/// Consistent page padding across the app.
EdgeInsets pagePadding(
  BuildContext context,
) {
  final width =
      MediaQuery.sizeOf(context).width;

  if (width >= 1200) {
    return const EdgeInsets.symmetric(
      horizontal: 32,
      vertical: 24,
    );
  }

  if (width >= 700) {
    return const EdgeInsets.symmetric(
      horizontal: 24,
      vertical: 20,
    );
  }

  return const EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 16,
  );
}

/// Keeps content from becoming excessively wide
/// on desktop/web.
Widget constrainedPage({
  required BuildContext context,
  required Widget child,
  double maxWidth = 1200,
}) {
  return Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: maxWidth,
      ),
      child: child,
    ),
  );
}