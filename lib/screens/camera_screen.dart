import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import '../theme/theme.dart';
import '../services/skin_cancer_classifier.dart';
import 'result_screen.dart';

// Constants for the targeting box
const double _targetBoxSize = 220.0;

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

      if (!widget.classifier.isReady) {
        _showError('AI model is not loaded. Please restart the app.');
        setState(() => _isCapturing = false);
        return;
      }

      // Crop the image to the target box region
      final croppedFile = await _cropToTargetBox(File(image.path));
      if (croppedFile == null) {
        _showError('Failed to process image. Please try again.');
        setState(() => _isCapturing = false);
        return;
      }

      final result = await widget.classifier.classifyImage(croppedFile);

      if (result == null) {
        _showError('Failed to analyze image. Please try again.');
        setState(() => _isCapturing = false);
        return;
      }

      if (mounted) {
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                ResultScreen(imagePath: croppedFile.path, result: result),
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

                  // Camera switch
                  _buildControlButton(
                    icon: Icons.cameraswitch_rounded,
                    onPressed: _switchCamera,
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

  /// Crops the captured image to only include the region within the target box.
  Future<File?> _cropToTargetBox(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final originalImage = img.decodeImage(bytes);

      if (originalImage == null) {
        debugPrint('Failed to decode image for cropping');
        return null;
      }

      // Get screen dimensions
      final screenSize = MediaQuery.of(context).size;
      final screenWidth = screenSize.width;
      final screenHeight = screenSize.height;

      // The camera preview uses LayoutBuilder with these calculations:
      // aspectRatio = 3.0 / 4.0 (width / height for portrait)
      // previewWidth = constraints.maxWidth (= screenWidth since it's in a Stack)
      // previewHeight = previewWidth / aspectRatio = screenWidth / (3/4) = screenWidth * 4/3
      final previewWidth = screenWidth;
      final previewHeight = screenWidth * (4.0 / 3.0);

      // The preview is centered on screen
      final previewTop = (screenHeight - previewHeight) / 2;
      final previewLeft = 0.0;

      // Target box is centered on the screen
      final boxCenterX = screenWidth / 2;
      final boxCenterY = screenHeight / 2;

      // Target box position relative to the preview area
      final boxRelativeX = boxCenterX - previewLeft;
      final boxRelativeY = boxCenterY - previewTop;

      // Now we need to figure out how the captured image maps to the preview
      // The camera uses BoxFit.cover, which scales the image to fill the container
      // while maintaining aspect ratio, cropping the excess

      final imageWidth = originalImage.width.toDouble();
      final imageHeight = originalImage.height.toDouble();

      final previewAspect = previewWidth / previewHeight;
      final imageAspect = imageWidth / imageHeight;

      double visibleImageWidth, visibleImageHeight;
      double imageOffsetX = 0, imageOffsetY = 0;
      double scale;

      if (imageAspect > previewAspect) {
        // Image is wider than preview - height fills, sides are cropped
        // The image height matches the preview height
        scale = imageHeight / previewHeight;
        visibleImageWidth = previewWidth * scale;
        visibleImageHeight = imageHeight;
        imageOffsetX = (imageWidth - visibleImageWidth) / 2;
        imageOffsetY = 0;
      } else {
        // Image is taller than preview - width fills, top/bottom are cropped
        // The image width matches the preview width
        scale = imageWidth / previewWidth;
        visibleImageWidth = imageWidth;
        visibleImageHeight = previewHeight * scale;
        imageOffsetX = 0;
        imageOffsetY = (imageHeight - visibleImageHeight) / 2;
      }

      // Calculate the crop region in original image coordinates
      // Position of box center in image coordinates
      final imageCropCenterX = imageOffsetX + (boxRelativeX * scale);
      final imageCropCenterY = imageOffsetY + (boxRelativeY * scale);

      // Size of the crop region (the target box size scaled to image coordinates)
      final cropSize = _targetBoxSize * scale;

      // Calculate crop bounds
      int cropX = (imageCropCenterX - cropSize / 2).round();
      int cropY = (imageCropCenterY - cropSize / 2).round();
      int cropWidth = cropSize.round();
      int cropHeight = cropSize.round();

      // Clamp to image bounds
      cropX = cropX.clamp(0, originalImage.width - 1);
      cropY = cropY.clamp(0, originalImage.height - 1);
      cropWidth = cropWidth.clamp(1, originalImage.width - cropX);
      cropHeight = cropHeight.clamp(1, originalImage.height - cropY);

      debugPrint('Image size: ${originalImage.width}x${originalImage.height}');
      debugPrint('Preview size: ${previewWidth}x$previewHeight');
      debugPrint('Scale: $scale, Offset: ($imageOffsetX, $imageOffsetY)');
      debugPrint('Box relative: ($boxRelativeX, $boxRelativeY)');
      debugPrint('Crop center: ($imageCropCenterX, $imageCropCenterY)');
      debugPrint(
        'Cropping from ($cropX, $cropY) size ${cropWidth}x$cropHeight',
      );

      // Perform the crop
      final croppedImage = img.copyCrop(
        originalImage,
        x: cropX,
        y: cropY,
        width: cropWidth,
        height: cropHeight,
      );

      // Save cropped image to a temporary file
      final croppedBytes = img.encodeJpg(croppedImage, quality: 95);
      final tempDir = await Directory.systemTemp.createTemp('cropped_');
      final croppedFile = File('${tempDir.path}/cropped_image.jpg');
      await croppedFile.writeAsBytes(croppedBytes);

      return croppedFile;
    } catch (e, stackTrace) {
      debugPrint('Error cropping image: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
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

            return ClipRRect(
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
