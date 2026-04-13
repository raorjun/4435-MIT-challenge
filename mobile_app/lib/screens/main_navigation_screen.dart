import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
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

/// Resolves backend URL from compile-time define → emulator fallback → localhost.
String _defaultBackendUrl() {
  const fromDefine = String.fromEnvironment(
    'STEP_LIGHT_BACKEND_URL',
    defaultValue: '',
  );
  if (fromDefine.isNotEmpty) return fromDefine;
  if (defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:5000';
  }
  return 'http://127.0.0.1:5000';
}

// ── Root screen ─────────────────────────────────────────────────────────────

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  // Shared settings — passed down to both tabs
  bool _showDebugInfo = false;
  double _speechRate = 1.0;
  String _narrationStyle = 'Concise'; // 'Concise' | 'Detailed'
  String _backendUrl = _defaultBackendUrl();
  bool _useMap = false; // off by default — maps are often wrong; flip on at a real venue

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
          _CameraView(
            isActive: _selectedIndex == 0,
            showDebugInfo: _showDebugInfo,
            speechRate: _speechRate,
            narrationStyle: _narrationStyle,
            backendUrl: _backendUrl,
            useMap: _useMap,
          ),
          _SettingsPage(
            showDebugInfo: _showDebugInfo,
            speechRate: _speechRate,
            narrationStyle: _narrationStyle,
            backendUrl: _backendUrl,
            useMap: _useMap,
            onShowDebugChanged: (v) => setState(() => _showDebugInfo = v),
            onSpeechRateChanged: (v) => setState(() => _speechRate = v),
            onNarrationStyleChanged: (v) => setState(() => _narrationStyle = v),
            onBackendUrlChanged: (v) => setState(() => _backendUrl = v),
            onUseMapChanged: (v) => setState(() => _useMap = v),
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
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

// ── Camera / Navigate tab ───────────────────────────────────────────────────

class _CameraView extends StatefulWidget {
  const _CameraView({
    required this.isActive,
    required this.showDebugInfo,
    required this.speechRate,
    required this.narrationStyle,
    required this.backendUrl,
    required this.useMap,
  });

  final bool isActive;
  final bool showDebugInfo;
  final double speechRate;
  final String narrationStyle;
  final String backendUrl;
  final bool useMap;

  @override
  State<_CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<_CameraView> {
  final GlobalKey<CameraFeedWindowState> _cameraKey =
      GlobalKey<CameraFeedWindowState>();
  final FlutterTts _tts = FlutterTts();
  final SpeechToText _stt = SpeechToText();

  static const Duration _captureInterval = Duration(seconds: 15);
  static const Duration _listenFor = Duration(seconds: 8);
  static const Duration _pauseFor = Duration(seconds: 2);
  static const Duration _requestTimeout = Duration(seconds: 25);
  // enter_venue does Places API + Tavily search + Gemini extraction — allow more time
  static const Duration _venueTimeout = Duration(seconds: 25);
  static const String _defaultDestination = 'the nearest exit';

  String _narration = _kPlaceholderNarration;
  String _destination = _defaultDestination;
  String _voiceStatus = 'Tap voice button and say where you want to go.';
  String _cameraStatus = 'Initializing...';
  bool _isSyncing = false;
  bool _isRequestInFlight = false;
  bool _isSttReady = false;
  bool _isListening = false;
  // Guards _startCaptureLoop from firing before venue init completes
  bool _venueInitialized = false;
  // Stored after GPS acquisition; reused in navigate calls
  Position? _lastPosition;
  Timer? _captureTimer;

  @override
  void initState() {
    super.initState();
    _initializeSession();
  }

  @override
  void didUpdateWidget(covariant _CameraView oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Re-apply TTS speed when user adjusts it in Settings
    if (widget.speechRate != oldWidget.speechRate) {
      _applySpeechRate(widget.speechRate);
    }

    // Only start/stop the loop after venue init is complete
    if (widget.isActive && !oldWidget.isActive && _venueInitialized) {
      _startCaptureLoop();
    } else if (!widget.isActive && oldWidget.isActive) {
      _stopCaptureLoop();
    }
  }

  // ── Initialization pipeline ────────────────────────────────────────────────

  Future<void> _initializeSession() async {
    await _configureTts();
    await _initializeSpeechToText();

    if (!mounted) return;
    setState(() => _cameraStatus = 'Locating venue...');
    await _speakNarration('Finding your location, please wait.');

    await _enterVenue();

    if (!mounted) return;
    setState(() => _venueInitialized = true);
    if (widget.isActive) {
      _startCaptureLoop();
    }
  }

  Future<void> _enterVenue() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled on this device.');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Location permission denied (status: $permission).');
      }

      if (!mounted) return;
      setState(() => _cameraStatus = 'Getting GPS fix...');

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      ).timeout(const Duration(seconds: 10));

      _lastPosition = position;
      print('[Steplight] GPS acquired: ${position.latitude}, ${position.longitude}');

      if (!mounted) return;
      setState(() => _cameraStatus = 'Contacting venue service...');

      final response = await http
          .post(
            Uri.parse('${widget.backendUrl}/enter_venue'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'lat': position.latitude,
              'lng': position.longitude,
              'use_map': widget.useMap,
            }),
          )
          .timeout(_venueTimeout);

      if (response.statusCode != 200) {
        throw Exception('Backend error: HTTP ${response.statusCode}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final venueName = data['venue'] as String? ?? 'this location';
      final mapFound = data['map_found'] as bool? ?? false;
      final storesFound = data['stores_found'] as int? ?? 0;
      final bathroomsFound = data['bathrooms_found'] as int? ?? 0;

      print(
        '[Steplight] enter_venue → venue="$venueName" '
        'map_found=$mapFound stores=$storesFound bathrooms=$bathroomsFound',
      );

      if (!mounted) return;

      if (mapFound && storesFound > 0) {
        setState(() => _cameraStatus = '$venueName — map loaded');
        await _speakNarration('$venueName loaded. Say your destination.');
      } else if (mapFound) {
        setState(() => _cameraStatus = '$venueName — limited map');
        await _speakNarration(
            '$venueName found. Limited map data. Navigating by camera.');
      } else {
        setState(() => _cameraStatus = '$venueName — camera only');
        await _speakNarration('No floor plan found. Navigating by camera only.');
      }
    } catch (e) {
      print('[Steplight] Venue init failed: $e');
      if (!mounted) return;
      setState(() => _cameraStatus = 'Camera only — no venue data');
      await _speakNarration('No floor plan found. Navigating by camera only.');
    }
  }

  Future<void> _configureTts() async {
    await _applySpeechRate(widget.speechRate);
    await _tts.setPitch(1.0);
  }

  /// Maps the user-facing rate (0.5–2.0) to the platform TTS rate scale.
  /// Android: 0.0–2.0 where 1.0 = normal.
  /// iOS:     0.0–1.0 where ≈0.5 = normal (1.0x maps to 0.5 on iOS).
  Future<void> _applySpeechRate(double rate) async {
    final ttsRate = Platform.isIOS ? rate * 0.5 : rate;
    await _tts.setSpeechRate(ttsRate);
  }

  Future<void> _initializeSpeechToText() async {
    final isAvailable = await _stt.initialize(
      onStatus: _handleSpeechStatus,
      onError: (e) {
        if (!mounted) return;
        setState(() {
          _voiceStatus = 'Mic error: ${e.errorMsg}. Tap mic to retry.';
          _isListening = false;
        });
      },
    );

    if (!mounted) return;
    setState(() {
      _isSttReady = isAvailable;
      if (!isAvailable) {
        _voiceStatus = 'Mic unavailable — check microphone permission in device settings, then tap mic.';
      }
    });
  }

  void _handleSpeechStatus(String status) {
    if (!mounted) return;
    final listening = status == 'listening';
    if (!listening && _isListening) {
      setState(() => _isListening = false);
    }
  }

  // ── Voice destination ──────────────────────────────────────────────────────

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

    // Cancel any in-progress session before starting a new one.
    // On some platforms listen() silently fails if the previous session wasn't
    // fully torn down — cancel() guarantees a clean slate.
    if (_stt.isListening) {
      await _stt.cancel();
    }

    // `listen()` is typed Future<bool> but some native implementations return null.
    // Receive as dynamic and compare with == true to avoid the cast crash.
    final dynamic listenResult = await _stt.listen(
      onResult: (result) {
        if (!mounted) return;
        final spoken = result.recognizedWords.trim();
        setState(() {
          _voiceStatus = spoken.isEmpty ? 'Listening...' : 'Heard: $spoken';
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
    final bool hasStarted = listenResult == true;

    if (!mounted) return;
    setState(() {
      _isListening = hasStarted;
      _voiceStatus = hasStarted
          ? 'Listening for destination...'
          : 'Could not start listening. Try again.';
    });
  }

  void _applySpokenIntent(String spokenText) {
    _stt.stop();

    final destination = spokenText.trim().isEmpty ? _defaultDestination : spokenText.trim();
    setState(() {
      _destination = destination;
      _voiceStatus = 'Destination set: $destination';
      _isListening = false;
    });

    // Fire guidance immediately instead of waiting up to 15 s for the next tick.
    // The narration response itself confirms the destination — no separate "Got it."
    _tts.stop();
    _captureAndNavigate();
  }

  // ── Capture loop ───────────────────────────────────────────────────────────

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

  Future<Uint8List> _preprocessImage(Uint8List bytes) async {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;
    final processed =
        decoded.width > 1024 ? img.copyResize(decoded, width: 1024) : decoded;
    return Uint8List.fromList(img.encodeJpg(processed, quality: 70));
  }

  Future<void> _captureAndNavigate() async {
    if (!mounted || !widget.isActive || _isRequestInFlight) return;

    final frame = await _cameraKey.currentState?.captureFrameBytes();
    if (frame == null || frame.isEmpty) return;

    _isRequestInFlight = true;
    if (mounted) setState(() => _isSyncing = true);

    try {
      final processedFrame = await _preprocessImage(frame);
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${widget.backendUrl}/vision/navigate'),
      );

      request.fields['destination'] = _destination;
      request.fields['narration_style'] = widget.narrationStyle;
      request.fields['lat'] = _lastPosition?.latitude.toString() ?? '0.0';
      request.fields['lng'] = _lastPosition?.longitude.toString() ?? '0.0';
      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          processedFrame,
          filename: 'frame.jpg',
        ),
      );

      final streamed = await request.send().timeout(_requestTimeout);
      final responseBody =
          await streamed.stream.bytesToString().timeout(_requestTimeout);

      // 503 = backend rate-limited by Gemini; back off and restart timer later.
      if (streamed.statusCode == 503 || streamed.statusCode == 429) {
        if (!mounted) return;
        const busyMsg = 'System busy — will retry shortly.';
        setState(() => _narration = busyMsg);
        await _speakNarration('System busy, waiting.');
        _stopCaptureLoop();
        Future.delayed(const Duration(seconds: 20), () {
          if (mounted && widget.isActive && _venueInitialized) {
            _startCaptureLoop();
          }
        });
        return;
      }

      if (streamed.statusCode != 200) {
        if (!mounted) return;
        setState(() {
          _narration =
              'Navigation service unavailable (${streamed.statusCode}).';
        });
        await _speakNarration(_narration);
        return;
      }

      final parsed = jsonDecode(responseBody);
      final narration = parsed is Map<String, dynamic>
          ? (parsed['narration']?.toString() ?? _kPlaceholderNarration)
          : _kPlaceholderNarration;

      if (!mounted) return;
      setState(() => _narration = narration);
      HapticFeedback.lightImpact();
      await _speakNarration(narration);
    } on TimeoutException {
      if (!mounted) return;
      setState(() => _narration = 'Navigation request timed out. Please wait.');
      await _speakNarration(_narration);
    } catch (_) {
      if (!mounted) return;
      setState(
          () => _narration = 'Unable to sync camera with navigation service.');
      await _speakNarration(_narration);
    } finally {
      _isRequestInFlight = false;
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _speakNarration(String text) async {
    await _tts.stop();
    await _tts.speak(text);
  }

  void _updateCameraStatus(String status) {
    if (_venueInitialized) return;
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

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      child: Column(
        children: [
          _StatusBar(label: _cameraStatus, isSyncing: _isSyncing),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Container(
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(AppTheme.cornerRadius),
                  border: Border.all(color: cs.secondary, width: 4),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.cornerRadius),
                  child: CameraFeedWindow(
                    key: _cameraKey,
                    width: double.infinity,
                    height: double.infinity,
                    // Flip-camera overlay removed per accessibility design
                    showControls: false,
                    onStatusChanged: _updateCameraStatus,
                  ),
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: SafeTapButton(
                    label: _isListening ? 'Stop Listening' : 'Voice Destination',
                    icon: _isListening ? Icons.mic_off : Icons.mic,
                    color: AppTheme.surfaceVariant,
                    textColor: AppTheme.onDark,
                    borderColor: AppTheme.secondarySeed,
                    onTap: _toggleListening,
                    semanticsLabel: _isListening
                        ? 'Stop voice input'
                        : 'Set destination by voice',
                    height: 88,
                    iconOnly: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SafeTapButton(
                    label: 'Repeat Narration',
                    icon: Icons.replay,
                    color: cs.primary,
                    textColor: cs.onPrimary,
                    onTap: _repeatNarration,
                    semanticsLabel: 'Repeat last narration',
                    height: 88,
                    iconOnly: true,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Debug block — only visible when enabled in Settings
          if (widget.showDebugInfo)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(AppTheme.cornerRadius),
                  border: Border.all(color: AppTheme.secondarySeed, width: 2),
                ),
                child: Text(
                  'Destination: $_destination\nVoice: $_voiceStatus',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppTheme.onDark,
                        height: 1.4,
                      ),
                ),
              ),
            ),

          if (widget.showDebugInfo) const SizedBox(height: 12),

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

// ── Settings tab ────────────────────────────────────────────────────────────

class _SettingsPage extends StatefulWidget {
  const _SettingsPage({
    required this.showDebugInfo,
    required this.speechRate,
    required this.narrationStyle,
    required this.backendUrl,
    required this.useMap,
    required this.onShowDebugChanged,
    required this.onSpeechRateChanged,
    required this.onNarrationStyleChanged,
    required this.onBackendUrlChanged,
    required this.onUseMapChanged,
  });

  final bool showDebugInfo;
  final double speechRate;
  final String narrationStyle;
  final String backendUrl;
  final bool useMap;
  final ValueChanged<bool> onShowDebugChanged;
  final ValueChanged<double> onSpeechRateChanged;
  final ValueChanged<String> onNarrationStyleChanged;
  final ValueChanged<String> onBackendUrlChanged;
  final ValueChanged<bool> onUseMapChanged;

  @override
  State<_SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<_SettingsPage> {
  late final TextEditingController _urlController;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.backendUrl);
  }

  @override
  void didUpdateWidget(covariant _SettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Keep field in sync if the URL changed externally
    if (oldWidget.backendUrl != widget.backendUrl &&
        _urlController.text != widget.backendUrl) {
      _urlController.text = widget.backendUrl;
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // ── Section 1: Voice & Narration ───────────────────────────────────
          _SectionHeader(label: 'Voice & Narration'),

          // Speech Rate
          ListTile(
            minVerticalPadding: 20,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            title: Text(
              'Speech Rate',
              style: tt.titleLarge?.copyWith(color: cs.onSurface, fontWeight: FontWeight.w700),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AppTheme.primaryMint,
                    inactiveTrackColor: AppTheme.outlineColor,
                    thumbColor: AppTheme.primaryMint,
                    overlayColor: AppTheme.primaryMint.withValues(alpha: 0.15),
                    valueIndicatorColor: AppTheme.primaryMint,
                    valueIndicatorTextStyle:
                        tt.labelLarge?.copyWith(color: const Color(0xFF18331A)),
                  ),
                  child: Slider(
                    value: widget.speechRate,
                    min: 0.5,
                    max: 2.0,
                    divisions: 3,
                    label: '${widget.speechRate}×',
                    onChanged: widget.onSpeechRateChanged,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: ['0.5×', '1.0×', '1.5×', '2.0×']
                        .map(
                          (t) => Text(
                            t,
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurface.withValues(alpha: 0.55),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Narration Detail
          ListTile(
            minVerticalPadding: 20,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            title: Text(
              'Narration Detail',
              style: tt.titleLarge?.copyWith(color: cs.onSurface, fontWeight: FontWeight.w700),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'Concise',
                    label: Text('Concise'),
                    icon: Icon(Icons.short_text),
                  ),
                  ButtonSegment(
                    value: 'Detailed',
                    label: Text('Detailed'),
                    icon: Icon(Icons.subject),
                  ),
                ],
                selected: {widget.narrationStyle},
                onSelectionChanged: (s) =>
                    widget.onNarrationStyleChanged(s.first),
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return AppTheme.primaryMint.withValues(alpha: 0.18);
                    }
                    return Colors.transparent;
                  }),
                  foregroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return AppTheme.primaryMint;
                    }
                    return AppTheme.inactiveLabel;
                  }),
                  side: WidgetStateProperty.all(
                    const BorderSide(color: AppTheme.outlineColor),
                  ),
                  iconColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return AppTheme.primaryMint;
                    }
                    return AppTheme.inactiveLabel;
                  }),
                ),
              ),
            ),
          ),

          const SizedBox(height: 28),

          // ── Section 2: Navigation Mode ─────────────────────────────────────
          _SectionHeader(label: 'Navigation Mode'),

          SwitchListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            title: Text(
              'Search for Venue Map',
              style: tt.titleLarge?.copyWith(color: cs.onSurface, fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              widget.useMap
                  ? 'On — will search for a floor plan on entry. Turn off if map is wrong.'
                  : 'Off — camera only. No map will be loaded or saved.',
              style: tt.bodyLarge
                  ?.copyWith(color: cs.onSurface.withValues(alpha: 0.6)),
            ),
            value: widget.useMap,
            activeThumbColor: AppTheme.primaryMint,
            activeTrackColor: AppTheme.primaryMint.withValues(alpha: 0.4),
            onChanged: widget.onUseMapChanged,
          ),

          const SizedBox(height: 28),

          // ── Section 3: Developer ───────────────────────────────────────────
          _SectionHeader(label: 'Developer'),

          // Debug Overlay toggle
          SwitchListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            title: Text(
              'Debug Overlay',
              style: tt.titleLarge?.copyWith(color: cs.onSurface, fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              'Show destination and voice status on the Navigate screen.',
              style: tt.bodyLarge
                  ?.copyWith(color: cs.onSurface.withValues(alpha: 0.6)),
            ),
            value: widget.showDebugInfo,
            activeThumbColor: AppTheme.primaryMint,
            activeTrackColor: AppTheme.primaryMint.withValues(alpha: 0.4),
            onChanged: widget.onShowDebugChanged,
          ),

          const Divider(height: 1),

          // Backend URL field
          ListTile(
            minVerticalPadding: 20,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            title: Text(
              'Backend URL',
              style: tt.titleLarge?.copyWith(color: cs.onSurface, fontWeight: FontWeight.w700),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: TextField(
                controller: _urlController,
                style: tt.bodyMedium?.copyWith(color: cs.onSurface),
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: InputDecoration(
                  hintText: 'http://192.168.x.x:5000',
                  hintStyle: tt.bodyMedium
                      ?.copyWith(color: cs.onSurface.withValues(alpha: 0.35)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppTheme.cornerRadius),
                    borderSide: const BorderSide(
                        color: AppTheme.outlineColor, width: 2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppTheme.cornerRadius),
                    borderSide: const BorderSide(
                        color: AppTheme.primaryMint, width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.black,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.check_rounded,
                        color: AppTheme.primaryMint),
                    tooltip: 'Apply URL',
                    onPressed: () {
                      final url = _urlController.text.trim();
                      widget.onBackendUrlChanged(url);
                      FocusScope.of(context).unfocus();
                    },
                  ),
                ),
                onSubmitted: (v) {
                  widget.onBackendUrlChanged(v.trim());
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section header ──────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppTheme.primaryMint,
              letterSpacing: 1.8,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
