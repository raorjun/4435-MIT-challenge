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
    this.color = AppTheme.primaryIndigo,
    this.textColor = AppTheme.pureBlack,
    this.borderColor,
    this.height = 96,
    this.semanticsLabel,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  final Color textColor;
  final Color? borderColor;
  final double height;

  /// Override the screen-reader label if it differs from [label].
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

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
            color: color,
            borderRadius: BorderRadius.circular(20),
            border: borderColor != null
                ? Border.all(color: borderColor!, width: 3)
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: textColor),
              const SizedBox(width: 16),
              Text(
                label,
                style: tt.titleLarge?.copyWith(
                  color: textColor,
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
