import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../components/safe_tap_button.dart';
import '../components/narration_box.dart';
import '../components/camera_feed.dart';
import '../theme/theme.dart';

const String _kPlaceholderNarration =
    'Tap the on-screen button to repeat the last narration.';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  void _onNavTap(int index) {
    HapticFeedback.lightImpact();
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.scrim,
      body: IndexedStack(
        index: _selectedIndex,
        children: const [
          _CameraView(),
          _PlaceholderPage(
            icon: Icons.bookmark_rounded,
            label: 'Saved Places',
            message: 'Your saved locations will appear here.',
          ),
          _PlaceholderPage(
            icon: Icons.settings_rounded,
            label: 'Settings',
            message: 'App settings coming soon.',
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onNavTap,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: 'Navigate',
          ),
          NavigationDestination(
            icon: Icon(Icons.bookmark_outline_rounded),
            selectedIcon: Icon(Icons.bookmark_rounded),
            label: 'Saved',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

// ── Camera view (tab 0) ─────────────────────────────────────────────────────

class _CameraView extends StatefulWidget {
  const _CameraView();

  @override
  State<_CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<_CameraView> {
  final String _narration = _kPlaceholderNarration;
  String _cameraStatus = 'Initializing camera...';

  void _updateCameraStatus(String status) {
    if (!mounted || _cameraStatus == status) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _cameraStatus == status) return;
      setState(() => _cameraStatus = status);
    });
  }

  void _repeatNarration() {
    HapticFeedback.lightImpact();
    // TODO: trigger TTS replay when backend is wired.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_narration), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      child: Column(
        children: [
          // ── Status bar ──────────────────────────────────────────
          _StatusBar(label: _cameraStatus),

          // ── Camera frame ────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Container(
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(AppTheme.cornerRadius),
                  border: Border.all(
                    color: cs.secondary,
                    width: 4,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.cornerRadius),
                  child: CameraFeedWindow( // use camera widget
                    width: double.infinity,
                    height: double.infinity,
                    showControls: true,
                    onStatusChanged: _updateCameraStatus,
                  ),
                ),
              ),
            ),
          ),

          // ── Repeat narration button ──────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SafeTapButton(
              label: 'Repeat Narration',
              icon: Icons.volume_up_rounded,
              color: cs.primary,
              textColor: cs.onPrimary,
              onTap: _repeatNarration,
              semanticsLabel: 'Repeat last narration',
            ),
          ),

          const SizedBox(height: 12),

          // ── Narration box ────────────────────────────────────────
          NarrationBox(text: _narration),
        ],
      ),
    );
  }
}

// ── Status bar ──────────────────────────────────────────────────────────────

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      color: cs.scrim,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.circle, color: cs.secondary, size: 14),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tt.titleMedium?.copyWith(
                color: cs.secondary,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Placeholder pages (tabs 1 & 2) ─────────────────────────────────────────

class _PlaceholderPage extends StatelessWidget {
  const _PlaceholderPage({
    required this.icon,
    required this.label,
    required this.message,
  });

  final IconData icon;
  final String label;
  final String message;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 72, color: cs.secondary),
              const SizedBox(height: 24),
              Text(label, style: tt.headlineSmall),
              const SizedBox(height: 12),
              Text(
                message,
                style: tt.bodyLarge?.copyWith(color: cs.onSurface.withValues(alpha: 0.75)),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

