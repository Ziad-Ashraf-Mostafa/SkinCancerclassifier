import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../theme/theme.dart';
import '../services/skin_cancer_classifier.dart';
import 'preprocessing_screen.dart';

class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  final SkinCancerClassifier classifier;

  const CameraScreen({
    super.key,
    required this.cameras,
    required this.classifier,
  });

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with TickerProviderStateMixin {
  CameraController? _controller;
  int _currentCameraIndex = 0;
  bool _isFlashOn = false;
  bool _isCapturing = false;
  bool _isSwitching = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initializeCamera();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Future<void> _initializeCamera() async {
    if (widget.cameras.isEmpty) return;

    final camera = widget.cameras[_currentCameraIndex];
    _controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
    );

    try {
      await _controller!.initialize();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  Future<void> _switchCamera() async {
    if (_isSwitching || widget.cameras.length < 2) return;

    setState(() {
      _isSwitching = true;
      _isFlashOn = false;
    });

    await _controller?.dispose();

    _currentCameraIndex = (_currentCameraIndex + 1) % widget.cameras.length;

    final camera = widget.cameras[_currentCameraIndex];
    _controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
    );

    try {
      await _controller!.initialize();
    } catch (e) {
      debugPrint('Error switching camera: $e');
    }

    if (mounted) {
      setState(() {
        _isSwitching = false;
      });
    }
  }

  Future<void> _toggleFlash() async {
    if (_controller == null || !_isBackCamera) return;

    try {
      if (_isFlashOn) {
        await _controller!.setFlashMode(FlashMode.off);
      } else {
        await _controller!.setFlashMode(FlashMode.torch);
      }
      setState(() {
        _isFlashOn = !_isFlashOn;
      });
    } catch (e) {
      debugPrint('Error toggling flash: $e');
    }
  }

  bool get _isBackCamera {
    if (widget.cameras.isEmpty) return false;
    return widget.cameras[_currentCameraIndex].lensDirection ==
        CameraLensDirection.back;
  }

  Future<void> _onTapToFocus(
    TapDownDetails details,
    BoxConstraints constraints,
  ) async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    final offset = Offset(
      details.localPosition.dx / constraints.maxWidth,
      details.localPosition.dy / constraints.maxHeight,
    );

    try {
      await _controller!.setFocusPoint(offset);
      await _controller!.setExposurePoint(offset);
    } catch (e) {
      // Focus/exposure point not supported on this device
      debugPrint('Focus not supported: $e');
    }
  }

  Future<void> _captureAndAnalyze() async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _isCapturing) {
      return;
    }

    setState(() {
      _isCapturing = true;
    });

    try {
      // Turn off flash for capture
      if (_isFlashOn) {
        await _controller!.setFlashMode(FlashMode.off);
      }

      final XFile image = await _controller!.takePicture();

      // Restore flash state
      if (_isFlashOn) {
        await _controller!.setFlashMode(FlashMode.torch);
      }

      if (mounted) {
        // Navigate to preprocessing screen for cropping
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                PreprocessingScreen(
                  imagePath: image.path,
                  classifier: widget.classifier,
                  cameras: widget.cameras,
                ),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
            transitionDuration: const Duration(milliseconds: 300),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error capturing image: $e');
      _showError('An error occurred. Please try again.');
    }

    if (mounted) {
      setState(() {
        _isCapturing = false;
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.dangerRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera Preview
          _buildCameraPreview(),

          // Top gradient overlay
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withAlpha(179), Colors.transparent],
                ),
              ),
            ),
          ),

          // Bottom gradient overlay
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 200,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withAlpha(204), Colors.transparent],
                ),
              ),
            ),
          ),

          // Top controls
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back button
                  _buildControlButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onPressed: () => Navigator.pop(context),
                  ),

                  // Title
                  GlassmorphicContainer(
                    opacity: 0.15,
                    borderRadius: 16,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppTheme.safeGreen,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Skin Scanner',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),

                  // Camera controls row
                  Row(
                    children: [
                      // Flash toggle (only for back camera)
                      AnimatedOpacity(
                        opacity: _isBackCamera ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: _buildControlButton(
                          icon: _isFlashOn
                              ? Icons.flash_on_rounded
                              : Icons.flash_off_rounded,
                          onPressed: _isBackCamera ? _toggleFlash : null,
                          isActive: _isFlashOn,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Camera switch
                      _buildControlButton(
                        icon: Icons.cameraswitch_rounded,
                        onPressed: _switchCamera,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Bottom controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 40),
                child: Column(
                  children: [
                    // Instructions
                    Padding(
                      padding: const EdgeInsets.only(bottom: 30),
                      child: Text(
                        'Position the affected area in the center',
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                      ),
                    ),

                    // Capture button
                    _buildCaptureButton(),
                  ],
                ),
              ),
            ),
          ),

          // Center focus indicator
          Center(
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppTheme.accentTeal.withAlpha(153),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Stack(
                children: [
                  // Corner accents
                  ..._buildCornerAccents(),
                ],
              ),
            ),
          ),

          // Loading overlay
          if (_isCapturing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      color: AppTheme.accentTeal,
                      strokeWidth: 3,
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Analyzing...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (_controller == null || !_controller!.value.isInitialized) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: AppTheme.accentTeal),
        ),
      );
    }

    // Use 4:3 aspect ratio like a normal phone camera
    return Center(
      child: AnimatedOpacity(
        opacity: _isSwitching ? 0.5 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Camera preview with 4:3 aspect ratio
            const double aspectRatio = 3.0 / 4.0; // Width / Height for portrait
            final previewWidth = constraints.maxWidth;
            final previewHeight = previewWidth / aspectRatio;

            return GestureDetector(
              onTapDown: (details) => _onTapToFocus(details, constraints),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  width: previewWidth,
                  height: previewHeight,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withAlpha(30),
                      width: 2,
                    ),
                  ),
                  child: FittedBox(
                    fit: BoxFit.cover,
                    clipBehavior: Clip.hardEdge,
                    child: SizedBox(
                      width: _controller!.value.previewSize!.height,
                      height: _controller!.value.previewSize!.width,
                      child: CameraPreview(_controller!),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    VoidCallback? onPressed,
    bool isActive = false,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: GlassmorphicContainer(
        opacity: isActive ? 0.3 : 0.15,
        borderRadius: 16,
        padding: const EdgeInsets.all(12),
        borderColor: isActive ? AppTheme.accentTeal.withAlpha(128) : null,
        child: Icon(
          icon,
          color: isActive ? AppTheme.accentTeal : Colors.white,
          size: 26,
        ),
      ),
    );
  }

  Widget _buildCaptureButton() {
    return GestureDetector(
      onTap: _captureAndAnalyze,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _pulseAnimation.value,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppTheme.primaryGradient,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accentTeal.withAlpha(102),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Container(
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildCornerAccents() {
    return [
      // Top-left
      Positioned(top: -1, left: -1, child: _buildCorner(0)),
      // Top-right
      Positioned(top: -1, right: -1, child: _buildCorner(90)),
      // Bottom-right
      Positioned(bottom: -1, right: -1, child: _buildCorner(180)),
      // Bottom-left
      Positioned(bottom: -1, left: -1, child: _buildCorner(270)),
    ];
  }

  Widget _buildCorner(double rotation) {
    return Transform.rotate(
      angle: rotation * math.pi / 180,
      child: Container(
        width: 30,
        height: 30,
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AppTheme.accentTeal, width: 3),
            left: BorderSide(color: AppTheme.accentTeal, width: 3),
          ),
          borderRadius: BorderRadius.only(topLeft: Radius.circular(8)),
        ),
      ),
    );
  }
}
