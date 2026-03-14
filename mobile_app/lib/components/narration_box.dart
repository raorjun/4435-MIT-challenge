import 'package:flutter/material.dart';
import '../theme/theme.dart';

/// Semi-transparent narration overlay pinned to the bottom of the camera view.
/// Displays the most recent VLM narration string.
class NarrationBox extends StatelessWidget {
  const NarrationBox({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.80),
        border: const Border(
          top: BorderSide(color: AppTheme.secondaryCyan, width: 3),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Semantics(
        liveRegion: true, // tells screen readers to announce changes
        label: 'Narration: $text',
        child: Text(
          text,
          style: tt.bodyLarge?.copyWith(color: AppTheme.onDark, height: 1.5),
        ),
      ),
    );
  }
}
