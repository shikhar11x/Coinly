import 'package:flutter/material.dart';

import 'ui_kit.dart';

/// Shows a blocking "working" dialog and returns a function that closes it.
///
/// Call the returned function when the work is done (safe to call twice).
VoidCallback showWorkingDialog(
  BuildContext context, {
  required IconData icon,
  required Color color,
  required String title,
  String? subtitle,
}) {
  final nav = Navigator.of(context, rootNavigator: true);
  var open = true;

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: _WorkingDialog(
        icon: icon,
        color: color,
        title: title,
        subtitle: subtitle,
      ),
    ),
  );

  return () {
    if (!open) return;
    open = false;
    nav.pop();
  };
}

class _WorkingDialog extends StatefulWidget {
  const _WorkingDialog({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;

  @override
  State<_WorkingDialog> createState() => _WorkingDialogState();
}

class _WorkingDialogState extends State<_WorkingDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 96,
                height: 96,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _c,
                      builder: (context, _) {
                        final t = _c.value;
                        final size = 56 + 38 * t;
                        return Container(
                          width: size,
                          height: size,
                          decoration: BoxDecoration(
                            color: widget.color.withValues(
                              alpha: 0.20 * (1 - t),
                            ),
                            borderRadius: BorderRadius.circular(size * 0.32),
                          ),
                        );
                      },
                    ),
                    IconBadge(icon: widget.icon, color: widget.color, size: 56),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: context.tt.titleMedium,
              ),
              if (widget.subtitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  widget.subtitle!,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: context.muted,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 6,
                  color: widget.color,
                  backgroundColor: widget.color.withValues(alpha: 0.14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}