import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

/// Camera Feed Widget - Displays live camera in a specific area
class CameraFeedWindow extends StatefulWidget {
  final double width;
  final double height;
  final bool showControls;
  
  const CameraFeedWindow({
    Key? key,
    this.width = 300,
    this.height = 400,
    this.showControls = true,
  }) : super(key: key);

  @override
  State<CameraFeedWindow> createState() => _CameraFeedWindowState();
}

class _CameraFeedWindowState extends State<CameraFeedWindow> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      // Get available cameras
      _cameras = await availableCameras();
      
      if (_cameras == null || _cameras!.isEmpty) {
        setState(() => _error = 'No cameras found');
        return;
      }

      // Use the back camera (index 0) by default
      _controller = CameraController(
        _cameras![0],
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _controller!.initialize();
      
      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (e) {
      setState(() => _error = 'Camera error: $e');
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
      ResolutionPreset.high,
      enableAudio: false,
    );

    await _controller!.initialize();
    setState(() {});
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
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
            if (widget.showControls && _isInitialized)
              _buildControls(),
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
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: Color(0xFF00E5FF),
          ),
          SizedBox(height: 16),
          Text(
            'Initializing camera...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Color(0xFFFF6B6B),
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              _error ?? 'Camera error',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
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
                backgroundColor: const Color(0xFF7B8CFF),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Positioned(
      bottom: 16,
      right: 16,
      child: Column(
        children: [
          // Switch camera button (if multiple cameras)
          if (_cameras != null && _cameras!.length > 1)
            FloatingActionButton(
              mini: true,
              backgroundColor: const Color(0xFF7B8CFF),
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
  const CameraFeedExample({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        title: const Text('Camera Feed'),
        backgroundColor: const Color(0xFF7B8CFF),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            
            // Camera feed window - you can position this anywhere
            const Center(
              child: CameraFeedWindow(
                width: 350,
                height: 500,
                showControls: true,
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Your other content below camera
            const Text(
              'Camera feed above',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }
}


/// Example: Camera feed in a corner (floating)
class FloatingCameraExample extends StatelessWidget {
  const FloatingCameraExample({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: Stack(
        children: [
          // Your main content
          const Center(
            child: Text(
              'Main Content',
              style: TextStyle(color: Colors.white, fontSize: 24),
            ),
          ),
          
          // Floating camera feed in corner
          Positioned(
            top: 20,
            right: 20,
            child: const CameraFeedWindow(
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