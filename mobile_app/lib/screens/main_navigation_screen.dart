import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
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
        children: [
          _CameraView(isActive: _selectedIndex == 0),
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
  const _CameraView({required this.isActive});

  final bool isActive;

  @override
  State<_CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<_CameraView> {
  final GlobalKey<CameraFeedWindowState> _cameraKey =
      GlobalKey<CameraFeedWindowState>();
  final FlutterTts _tts = FlutterTts();
  final SpeechToText _stt = SpeechToText();

  static const Duration _captureInterval = Duration(seconds: 5);
  static const Duration _listenFor = Duration(seconds: 8);
  static const Duration _pauseFor = Duration(seconds: 2);
  static const Duration _requestTimeout = Duration(seconds: 12);
  static const String _defaultDestination = 'the nearest exit';
  static const String _defaultIntent =
      'Help me navigate safely to a nearby exit.';
  static const String _backendUrlFromDefine = String.fromEnvironment(
    'STEP_LIGHT_BACKEND_URL',
    defaultValue: '',
  );

  String _narration = _kPlaceholderNarration;
  String _destination = _defaultDestination;
  String _intent = _defaultIntent;
  String _voiceStatus = 'Tap voice button and say where you want to go.';
  String _cameraStatus = 'Initializing camera...';
  bool _isSyncing = false;
  bool _isRequestInFlight = false;
  bool _isSttReady = false;
  bool _isListening = false;
  Timer? _captureTimer;

  @override
  void initState() {
    super.initState();
    _initializeAudioAndVoice();
    if (widget.isActive) {
      _startCaptureLoop();
    }
  }

  @override
  void didUpdateWidget(covariant _CameraView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _startCaptureLoop();
    } else if (!widget.isActive && oldWidget.isActive) {
      _stopCaptureLoop();
    }
  }

  Future<void> _initializeAudioAndVoice() async {
    await _configureTts();
    await _initializeSpeechToText();
    await _speakNarration('Where would you like to go?');
  }

  Future<void> _configureTts() async {
    await _tts.setSpeechRate(2.0);
    await _tts.setPitch(1.0);
  }

  Future<void> _initializeSpeechToText() async {
    final isAvailable = await _stt.initialize(
      onStatus: _handleSpeechStatus,
      onError: (_) {
        if (!mounted) return;
        setState(() {
          _voiceStatus = 'Voice input unavailable. You can still use camera sync.';
          _isListening = false;
        });
      },
    );

    if (!mounted) return;
    setState(() {
      _isSttReady = isAvailable;
      if (!isAvailable) {
        _voiceStatus = 'Voice setup failed. Tap again to retry.';
      }
    });
  }

  void _handleSpeechStatus(String status) {
    if (!mounted) return;

    final listening = status == 'listening';
    if (!listening && _isListening) {
      setState(() {
        _isListening = false;
      });
    }
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _stt.stop();
      if (!mounted) return;
      setState(() {
        _isListening = false;
        _voiceStatus = 'Voice capture stopped.';
      });
      return;
    }

    if (!_isSttReady) {
      await _initializeSpeechToText();
      if (!_isSttReady) return;
    }

    final hasStarted = await _stt.listen(
      onResult: (result) {
        if (!mounted) return;

        final spoken = result.recognizedWords.trim();
        setState(() {
          _voiceStatus = spoken.isEmpty
              ? 'Listening...'
              : 'Heard: $spoken';
        });

        if (result.finalResult && spoken.isNotEmpty) {
          _applySpokenIntent(spoken);
        }
      },
      listenFor: _listenFor,
      pauseFor: _pauseFor,
      listenOptions: SpeechListenOptions(
        cancelOnError: true,
        partialResults: true,
      ),
    );

    if (!mounted) return;
    setState(() {
      _isListening = hasStarted;
      _voiceStatus = hasStarted
          ? 'Listening for destination...'
          : 'Could not start listening. Try again.';
    });
  }

  void _applySpokenIntent(String spokenText) {
    final normalizedDestination = _resolveDestination(spokenText);

    setState(() {
      _intent = spokenText;
      _destination = normalizedDestination;
      _voiceStatus = 'Destination set: $normalizedDestination';
      _isListening = false;
    });

    _speakNarration('Got it. Heading toward $normalizedDestination.');
  }

  String _resolveDestination(String spokenText) {
    final value = spokenText.toLowerCase().trim();
    if (value.isEmpty) return _defaultDestination;

    if (value.contains('sports') || value.contains('athletic')) {
      return 'a sports clothing store';
    }
    if (value.contains('coffee') || value.contains('cafe')) {
      return 'a coffee shop';
    }
    if (value.contains('food') || value.contains('eat') || value.contains('restaurant')) {
      return 'a food court entrance';
    }
    if (value.contains('restroom') || value.contains('bathroom') || value.contains('toilet')) {
      return 'the nearest restroom';
    }
    if (value.contains('exit') || value.contains('outside')) {
      return 'the nearest exit';
    }

    return spokenText.trim();
  }

  void _startCaptureLoop() {
    _captureTimer?.cancel();
    _captureTimer = Timer.periodic(_captureInterval, (_) {
      _captureAndNavigate();
    });
  }

  void _stopCaptureLoop() {
    _captureTimer?.cancel();
    _captureTimer = null;
  }

  String _backendBaseUrl() {
    if (_backendUrlFromDefine.isNotEmpty) {
      return _backendUrlFromDefine;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:5000';
    }
    return 'http://127.0.0.1:5000';
  }

  Future<Uint8List> _preprocessImage(Uint8List bytes) async {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      return bytes;
    }

    final processed = decoded.width > 1024
        ? img.copyResize(decoded, width: 1024)
        : decoded;

    return Uint8List.fromList(img.encodeJpg(processed, quality: 70));
  }

  Future<void> _captureAndNavigate() async {
    if (!mounted || !widget.isActive || _isRequestInFlight) {
      return;
    }

    final frame = await _cameraKey.currentState?.captureFrameBytes();
    if (frame == null || frame.isEmpty) {
      return;
    }

    _isRequestInFlight = true;
    if (mounted) {
      setState(() {
        _isSyncing = true;
      });
    }

    try {
      final processedFrame = await _preprocessImage(frame);
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${_backendBaseUrl()}/vision/navigate'),
      );

      request.fields['destination'] = _destination;
      request.fields['intent'] = _intent;
      request.fields['lat'] = '0.0';
      request.fields['lng'] = '0.0';
      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          processedFrame,
          filename: 'frame.jpg',
        ),
      );

        final streamed = await request.send().timeout(_requestTimeout);
        final responseBody = await streamed.stream
          .bytesToString()
          .timeout(_requestTimeout);

      if (streamed.statusCode != 200) {
        if (!mounted) return;
        setState(() {
          _narration = 'Navigation service unavailable (${streamed.statusCode}).';
        });
        await _speakNarration(_narration);
        return;
      }

      final parsed = jsonDecode(responseBody);
      final narration = parsed is Map<String, dynamic>
          ? (parsed['narration']?.toString() ?? _kPlaceholderNarration)
          : _kPlaceholderNarration;

      if (!mounted) return;
      setState(() {
        _narration = narration;
      });
      HapticFeedback.lightImpact();
      await _speakNarration(narration);
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _narration = 'Navigation request timed out. Please try again.';
      });
      await _speakNarration(_narration);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _narration = 'Unable to sync camera with navigation service.';
      });
      await _speakNarration(_narration);
    } finally {
      _isRequestInFlight = false;
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  Future<void> _speakNarration(String text) async {
    await _tts.stop();
    await _tts.speak(text);
  }

  void _updateCameraStatus(String status) {
    if (!mounted || _cameraStatus == status) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _cameraStatus == status) return;
      setState(() => _cameraStatus = status);
    });
  }

  void _repeatNarration() {
    HapticFeedback.lightImpact();
    _speakNarration(_narration);
  }

  @override
  void dispose() {
    _stopCaptureLoop();
    _stt.stop();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      child: Column(
        children: [
          // ── Status bar ──────────────────────────────────────────
          _StatusBar(label: _cameraStatus, isSyncing: _isSyncing),

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
                    key: _cameraKey,
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
            child: Row(
              children: [
                Expanded(
                  child: SafeTapButton(
                    label: _isListening ? 'Stop Listening' : 'Voice Destination',
                    icon: _isListening ? Icons.mic_off_rounded : Icons.mic_rounded,
                    color: AppTheme.surfaceVariant,
                    textColor: AppTheme.onDark,
                    borderColor: AppTheme.secondarySeed,
                    onTap: _toggleListening,
                    semanticsLabel: 'Set destination by voice',
                    height: 88,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SafeTapButton(
                    label: 'Repeat Narration',
                    icon: Icons.volume_up_rounded,
                    color: cs.primary,
                    textColor: cs.onPrimary,
                    onTap: _repeatNarration,
                    semanticsLabel: 'Repeat last narration',
                    height: 88,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceVariant,
                borderRadius: BorderRadius.circular(AppTheme.cornerRadius),
                border: Border.all(color: AppTheme.secondarySeed, width: 2),
              ),
              child: Text(
                'Intent: $_intent\nDestination: $_destination\nVoice: $_voiceStatus',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppTheme.onDark,
                      height: 1.4,
                    ),
              ),
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
  const _StatusBar({required this.label, required this.isSyncing});

  final String label;
  final bool isSyncing;

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
          Icon(
            Icons.circle,
            color: isSyncing ? AppTheme.primaryMint : AppTheme.secondarySeed,
            size: 14,
          ),
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
          if (isSyncing)
            Text(
              'Syncing...',
              style: tt.titleSmall?.copyWith(
                color: AppTheme.primaryMint,
                fontWeight: FontWeight.w700,
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

