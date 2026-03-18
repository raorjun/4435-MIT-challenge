import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/theme.dart';

/// A large, high-contrast tap target designed for low-vision users.
/// Minimum height of 96dp — well above the 48dp accessibility minimum.
class SafeTapButton extends StatelessWidget {
  const SafeTapButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.color,
    this.textColor,
    this.borderColor,
    this.height = 96,
    this.semanticsLabel,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  final Color? textColor;
  final Color? borderColor;
  final double height;

  /// Override the screen-reader label if it differs from [label].
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final resolvedColor = color ?? cs.primary;
    final resolvedTextColor = textColor ?? cs.onPrimary;

    return Semantics(
      button: true,
      label: semanticsLabel ?? label,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: resolvedColor,
            borderRadius: BorderRadius.circular(AppTheme.cornerRadius),
            border: borderColor != null
                ? Border.all(color: borderColor!, width: 3)
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: resolvedTextColor),
              const SizedBox(width: 16),
              Text(
                label,
                style: tt.headlineSmall?.copyWith(
                  color: resolvedTextColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
