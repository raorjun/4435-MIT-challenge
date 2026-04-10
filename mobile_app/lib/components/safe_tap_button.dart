import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/theme.dart';

/// A large, high-contrast tap target designed for low-vision users.
/// Minimum height of 96dp — well above the 48dp accessibility minimum.
///
/// Set [iconOnly] to true to show just the icon (text hidden visually but
/// still present in the semantics label for screen readers).
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
    this.iconOnly = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  final Color? textColor;
  final Color? borderColor;
  final double height;
  final String? semanticsLabel;

  /// When true, only the icon is rendered. The [label] is still exposed
  /// to screen readers via [semanticsLabel] ?? [label].
  final bool iconOnly;

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
          child: iconOnly
              ? Center(
                  child: Icon(icon, size: 40, color: resolvedTextColor),
                )
              : Row(
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
