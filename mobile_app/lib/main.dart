import 'package:flutter/material.dart';
import 'theme/theme.dart';

void main() {
  runApp(const SteplightApp());
}

class SteplightApp extends StatelessWidget {
  const SteplightApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Steplight',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark, // always dark
      // Task 1 prep: clamp text scaler so oversized system fonts don't break layout
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: MediaQuery.textScalerOf(context)
                .clamp(minScaleFactor: 1.0, maxScaleFactor: 2.5),
          ),
          child: child!,
        );
      },
      home: const _ThemePreviewScreen(),
    );
  }
}

/// Simple screen to visually confirm the theme is applied correctly.
class _ThemePreviewScreen extends StatelessWidget {
  const _ThemePreviewScreen();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Steplight — Theme Preview')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // ── Color swatches ────────────────────────────────────────
          Text('Color Palette', style: tt.titleLarge),
          const SizedBox(height: 12),
          _Swatch(label: 'scaffoldBg  #000000', color: AppTheme.pureBlack, onColor: cs.onSurface),
          _Swatch(label: 'surface     #0A0A0A', color: cs.surface, onColor: cs.onSurface),
          _Swatch(label: 'primary     #7B8CFF  8.1:1', color: cs.primary, onColor: cs.onPrimary),
          _Swatch(label: 'secondary   #00E5FF  9.4:1', color: cs.secondary, onColor: cs.onSecondary),
          _Swatch(label: 'error       #FF6B6B', color: cs.error, onColor: cs.onError),
          const SizedBox(height: 32),

          // ── Typography ────────────────────────────────────────────
          Text('Typography', style: tt.titleLarge),
          const SizedBox(height: 12),
          Text('Display Large', style: tt.displayLarge?.copyWith(fontSize: 32)),
          Text('Headline Medium', style: tt.headlineMedium),
          Text('Title Large', style: tt.titleLarge),
          Text('Body Large — narration text for the user.', style: tt.bodyLarge),
          Text('Label Large', style: tt.labelLarge),
          const SizedBox(height: 32),

          // ── Components ────────────────────────────────────────────
          Text('Components', style: tt.titleLarge),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: () {}, child: const Text('Elevated Button')),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Card on surfaceVariant (#1A1A1A)', style: tt.bodyMedium),
            ),
          ),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.label, required this.color, required this.onColor});
  final String label;
  final Color color;
  final Color onColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      height: 52,
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: AppTheme.outlineColor),
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(label, style: TextStyle(color: onColor, fontWeight: FontWeight.w600)),
    );
  }
}
