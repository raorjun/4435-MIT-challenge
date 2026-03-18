import 'package:flutter/material.dart';

/// Semi-transparent narration overlay pinned to the bottom of the camera view.
/// Displays the most recent VLM narration string.
class NarrationBox extends StatelessWidget {
  const NarrationBox({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cs.scrim.withValues(alpha: 0.80),
        border: Border(
          top: BorderSide(color: cs.secondary, width: 3),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Semantics(
        liveRegion: true,
        label: 'Narration: $text',
        child: Text(
          text,
          style: tt.bodyLarge?.copyWith(color: cs.onSurface, height: 1.5),
        ),
      ),
    );
  }
}
