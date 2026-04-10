import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import '../theme/theme.dart';

/// Camera Feed Widget - Displays live camera in a specific area
class CameraFeedWindow extends StatefulWidget {
  final double width;
  final double height;
  final bool showControls;
  final ValueChanged<String>? onStatusChanged;

  const CameraFeedWindow({
    super.key,
    this.width = 300,
    this.height = 400,
    this.showControls = true,
    this.onStatusChanged,
  });

  @override
  State<CameraFeedWindow> createState() => CameraFeedWindowState();
}

class CameraFeedWindowState extends State<CameraFeedWindow> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _isCapturing = false;
  String? _error;
  static const Duration _cameraInitTimeout = Duration(seconds: 10);

  Future<Uint8List?> captureFrameBytes() async {
    if (!_isInitialized || _controller == null || _isCapturing) {
      return null;
    }

    try {
      _isCapturing = true;
      final picture = await _controller!.takePicture();
      return await picture.readAsBytes();
    } catch (_) {
      return null;
    } finally {
      _isCapturing = false;
    }
  }

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  void _emitStatus(String status) {
    widget.onStatusChanged?.call(status);
  }

  void _setErrorStatus(String message, {String? status}) {
    if (mounted) {
      setState(() {
        _error = message;
        _isInitialized = false;
      });
    }
    _emitStatus(status ?? message);
  }

  Future<bool> _ensureCameraPermission() async {
    final status = await Permission.camera.status;
    if (status.isGranted) return true;

    if (status.isPermanentlyDenied || status.isRestricted) {
      _setErrorStatus(
        'Camera permission denied. Enable it in Settings.',
        status: 'Camera inaccessible',
      );
      return false;
    }

    final requestStatus = await Permission.camera.request();
    if (requestStatus.isGranted) return true;

    if (requestStatus.isPermanentlyDenied || requestStatus.isRestricted) {
      _setErrorStatus(
        'Camera permission denied. Enable it in Settings.',
        status: 'Camera inaccessible',
      );
    } else {
      _setErrorStatus(
        'Camera permission required',
        status: 'Camera inaccessible',
      );
    }
    return false;
  }

  Future<void> _initializeCamera() async {
    _emitStatus('Initializing camera...');
    if (mounted) {
      setState(() {
        _error = null;
        _isInitialized = false;
      });
    }

    final hasPermission = await _ensureCameraPermission();
    if (!hasPermission) return;

    try {
      // Get available cameras
      _cameras = await availableCameras().timeout(_cameraInitTimeout);

      if (_cameras == null || _cameras!.isEmpty) {
        _setErrorStatus('No camera available');
        return;
      }

      final selectedCamera = _cameras!.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras!.first,
      );

      // Prefer back camera, but fall back to first available camera.
      _controller = CameraController(
        selectedCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _controller!.initialize().timeout(_cameraInitTimeout);
      // Keep flash off at all times — auto-flash causes glare for light-sensitive users.
      await _controller!.setFlashMode(FlashMode.off);

      if (mounted) {
        setState(() => _isInitialized = true);
        _emitStatus('Camera Ready');
      }
    } on CameraException catch (e) {
      final isPermissionIssue =
          e.code == 'CameraAccessDenied' ||
          e.code == 'CameraAccessDeniedWithoutPrompt' ||
          e.code == 'CameraAccessRestricted';

      final message = isPermissionIssue
          ? 'Camera permission required'
          : 'Camera error: ${e.description ?? e.code}';

      _setErrorStatus(
        message,
        status: isPermissionIssue ? 'Camera inaccessible' : null,
      );
    } on TimeoutException {
      _setErrorStatus('Camera initialization timed out');
    } catch (e) {
      final message = 'Camera error: $e';
      _setErrorStatus(message);
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras == null || _cameras!.length < 2) return;

    final currentIndex = _cameras!.indexOf(_controller!.description);
    final newIndex = (currentIndex + 1) % _cameras!.length;

    final newCamera = _cameras![newIndex];

    await _controller?.dispose();

    _controller = CameraController(
      newCamera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    try {
      await _controller!.initialize().timeout(_cameraInitTimeout);
      await _controller!.setFlashMode(FlashMode.off);
      setState(() {});
      _emitStatus('Camera Ready');
    } on CameraException catch (e) {
      final message = 'Camera error: ${e.description ?? e.code}';
      _setErrorStatus(message);
    } on TimeoutException {
      _setErrorStatus('Camera initialization timed out');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: cs.scrim,
        borderRadius: BorderRadius.circular(AppTheme.cornerRadius),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.cornerRadius),
        child: Stack(
          children: [
            // Camera preview or error/loading state
            if (_error != null)
              _buildError()
            else if (!_isInitialized)
              _buildLoading()
            else
              _buildCameraPreview(),

            // Controls overlay
            if (widget.showControls && _isInitialized) _buildControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const SizedBox();
    }

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _controller!.value.previewSize!.height,
          height: _controller!.value.previewSize!.width,
          child: CameraPreview(_controller!),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: cs.secondary),
          const SizedBox(height: 16),
          Text(
            'Initializing camera...',
            style: TextStyle(color: cs.onSurface, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: cs.error, size: 48),
            const SizedBox(height: 16),
            Text(
              _error ?? 'Camera error',
              style: TextStyle(color: cs.onSurface, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _error = null;
                  _isInitialized = false;
                });
                _initializeCamera();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
              ),
              child: const Text('Retry'),
            ),
            if ((_error ?? '').contains('Settings')) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: openAppSettings,
                child: const Text('Open Settings'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildControls() {
    final cs = Theme.of(context).colorScheme;

    return Positioned(
      bottom: 16,
      right: 16,
      child: Column(
        children: [
          // Switch camera button (if multiple cameras)
          if (_cameras != null && _cameras!.length > 1)
            FloatingActionButton(
              mini: true,
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
              onPressed: _switchCamera,
              child: const Icon(Icons.flip_camera_ios),
            ),
        ],
      ),
    );
  }
}

/// Example: How to use the camera feed in your screen
class CameraFeedExample extends StatelessWidget {
  const CameraFeedExample({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.scrim,
      appBar: AppBar(
        title: const Text('Camera Feed'),
        backgroundColor: cs.primary,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            const Center(
              child: CameraFeedWindow(
                width: 350,
                height: 500,
                showControls: true,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Camera feed above',
              style: TextStyle(color: cs.onSurface, fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }
}

/// Example: Camera feed in a corner (floating)
class FloatingCameraExample extends StatelessWidget {
  const FloatingCameraExample({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.scrim,
      body: Stack(
        children: [
          Center(
            child: Text(
              'Main Content',
              style: TextStyle(color: cs.onSurface, fontSize: 24),
            ),
          ),
          const Positioned(
            top: 20,
            right: 20,
            child: CameraFeedWindow(
              width: 200,
              height: 300,
              showControls: true,
            ),
          ),
        ],
      ),
    );
  }
}
