import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import '../theme/theme.dart';
import '../services/skin_cancer_classifier.dart';
import 'result_screen.dart';

class PreprocessingScreen extends StatefulWidget {
  final String imagePath;
  final SkinCancerClassifier classifier;
  final List<CameraDescription> cameras;

  const PreprocessingScreen({
    super.key,
    required this.imagePath,
    required this.classifier,
    required this.cameras,
  });

  @override
  State<PreprocessingScreen> createState() => _PreprocessingScreenState();
}

class _PreprocessingScreenState extends State<PreprocessingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Crop rectangle state
  Rect _cropRect = Rect.zero;
  Size _imageSize = Size.zero;
  Size _displaySize = Size.zero;
  final GlobalKey _imageKey = GlobalKey();

  bool _isLoading = false;
  bool _imageLoaded = false;

  // Dragging state
  _DragHandle? _activeDragHandle;
  Offset _dragStartOffset = Offset.zero;
  Rect _dragStartRect = Rect.zero;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();
    _loadImageInfo();
  }

  Future<void> _loadImageInfo() async {
    final bytes = await File(widget.imagePath).readAsBytes();
    final image = img.decodeImage(bytes);
    if (image != null) {
      setState(() {
        _imageSize = Size(image.width.toDouble(), image.height.toDouble());
        _imageLoaded = true;
      });
    }
  }

  void _initCropRect(Size displaySize) {
    if (_cropRect == Rect.zero && displaySize != Size.zero) {
      _displaySize = displaySize;
      // Initial crop rectangle - centered square
      final minDimension = math.min(displaySize.width, displaySize.height);
      final cropSize = minDimension * 0.6;
      final left = (displaySize.width - cropSize) / 2;
      final top = (displaySize.height - cropSize) / 2;
      _cropRect = Rect.fromLTWH(left, top, cropSize, cropSize);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _proceedToAnalysis() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      // Crop the image based on selection
      final croppedFile = await _cropImage();
      if (croppedFile == null) {
        _showError('Failed to process image. Please try again.');
        setState(() => _isLoading = false);
        return;
      }

      // Analyze the cropped image
      if (!widget.classifier.isReady) {
        _showError('AI model is not loaded. Please restart the app.');
        setState(() => _isLoading = false);
        return;
      }

      final result = await widget.classifier.classifyImage(croppedFile);
      if (result == null) {
        _showError('Failed to analyze image. Please try again.');
        setState(() => _isLoading = false);
        return;
      }

      if (mounted) {
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                ResultScreen(
                  imagePath: croppedFile.path,
                  result: result,
                  cameras: widget.cameras,
                  classifier: widget.classifier,
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
      debugPrint('Error processing image: $e');
      _showError('An error occurred. Please try again.');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<File?> _cropImage() async {
    try {
      final bytes = await File(widget.imagePath).readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) return null;

      // Calculate crop coordinates in original image space
      final scaleX = _imageSize.width / _displaySize.width;
      final scaleY = _imageSize.height / _displaySize.height;

      final cropX = (_cropRect.left * scaleX).round();
      final cropY = (_cropRect.top * scaleY).round();
      final cropWidth = (_cropRect.width * scaleX).round();
      final cropHeight = (_cropRect.height * scaleY).round();

      // Ensure crop bounds are within image
      final safeX = cropX.clamp(0, image.width - 1);
      final safeY = cropY.clamp(0, image.height - 1);
      final safeWidth = cropWidth.clamp(1, image.width - safeX);
      final safeHeight = cropHeight.clamp(1, image.height - safeY);

      // Crop the image
      final croppedImage = img.copyCrop(
        image,
        x: safeX,
        y: safeY,
        width: safeWidth,
        height: safeHeight,
      );

      // Save to temp file
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final croppedPath = '${tempDir.path}/cropped_$timestamp.jpg';
      final croppedFile = File(croppedPath);
      await croppedFile.writeAsBytes(img.encodeJpg(croppedImage, quality: 95));

      return croppedFile;
    } catch (e) {
      debugPrint('Error cropping image: $e');
      return null;
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.dangerRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: GlassmorphicContainer(
                          opacity: 0.15,
                          borderRadius: 14,
                          padding: const EdgeInsets.all(12),
                          child: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 20,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Opacity(
                        opacity: _fadeAnimation.value,
                        child: Text(
                          'Crop Image',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),

                // Instructions
                Opacity(
                  opacity: _fadeAnimation.value,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'Drag the corners to adjust the crop area around the skin lesion',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.white60),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Image with crop overlay
                Expanded(
                  child: Opacity(
                    opacity: _fadeAnimation.value,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppTheme.accentTeal.withAlpha(80),
                          width: 2,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: _imageLoaded
                            ? LayoutBuilder(
                                builder: (context, constraints) {
                                  final displaySize = Size(
                                    constraints.maxWidth,
                                    constraints.maxHeight,
                                  );
                                  _initCropRect(displaySize);

                                  return Stack(
                                    key: _imageKey,
                                    fit: StackFit.expand,
                                    children: [
                                      // Image
                                      Image.file(
                                        File(widget.imagePath),
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        height: double.infinity,
                                      ),

                                      // Dark overlay outside crop area
                                      CustomPaint(
                                        painter: CropOverlayPainter(
                                          cropRect: _cropRect,
                                          overlayColor: Colors.black.withAlpha(
                                            150,
                                          ),
                                        ),
                                        size: displaySize,
                                      ),

                                      // Crop rectangle border
                                      Positioned(
                                        left: _cropRect.left,
                                        top: _cropRect.top,
                                        child: Container(
                                          width: _cropRect.width,
                                          height: _cropRect.height,
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: AppTheme.accentTeal,
                                              width: 2,
                                            ),
                                          ),
                                        ),
                                      ),

                                      // Corner handles
                                      _buildCornerHandle(
                                        _DragHandle.topLeft,
                                        _cropRect.topLeft,
                                      ),
                                      _buildCornerHandle(
                                        _DragHandle.topRight,
                                        _cropRect.topRight,
                                      ),
                                      _buildCornerHandle(
                                        _DragHandle.bottomLeft,
                                        _cropRect.bottomLeft,
                                      ),
                                      _buildCornerHandle(
                                        _DragHandle.bottomRight,
                                        _cropRect.bottomRight,
                                      ),

                                      // Edge handles
                                      _buildEdgeHandle(
                                        _DragHandle.top,
                                        Offset(
                                          _cropRect.center.dx,
                                          _cropRect.top,
                                        ),
                                      ),
                                      _buildEdgeHandle(
                                        _DragHandle.bottom,
                                        Offset(
                                          _cropRect.center.dx,
                                          _cropRect.bottom,
                                        ),
                                      ),
                                      _buildEdgeHandle(
                                        _DragHandle.left,
                                        Offset(
                                          _cropRect.left,
                                          _cropRect.center.dy,
                                        ),
                                      ),
                                      _buildEdgeHandle(
                                        _DragHandle.right,
                                        Offset(
                                          _cropRect.right,
                                          _cropRect.center.dy,
                                        ),
                                      ),

                                      // Center drag area
                                      Positioned(
                                        left: _cropRect.left + 20,
                                        top: _cropRect.top + 20,
                                        child: GestureDetector(
                                          onPanStart: (details) {
                                            _activeDragHandle =
                                                _DragHandle.center;
                                            _dragStartOffset =
                                                details.localPosition;
                                            _dragStartRect = _cropRect;
                                          },
                                          onPanUpdate: (details) => _handleDrag(
                                            details.localPosition,
                                          ),
                                          onPanEnd: (_) =>
                                              _activeDragHandle = null,
                                          child: Container(
                                            width: _cropRect.width - 40,
                                            height: _cropRect.height - 40,
                                            color: Colors.transparent,
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              )
                            : const Center(
                                child: CircularProgressIndicator(
                                  color: AppTheme.accentTeal,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Proceed button
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Opacity(
                    opacity: _fadeAnimation.value,
                    child: SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _proceedToAnalysis,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentTeal,
                          foregroundColor: Colors.black,
                          disabledBackgroundColor: AppTheme.accentTeal
                              .withAlpha(100),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.analytics_rounded, size: 22),
                                  SizedBox(width: 10),
                                  Text(
                                    'Proceed to Analysis',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildCornerHandle(_DragHandle handle, Offset position) {
    const handleSize = 24.0;
    return Positioned(
      left: position.dx - handleSize / 2,
      top: position.dy - handleSize / 2,
      child: GestureDetector(
        onPanStart: (details) {
          _activeDragHandle = handle;
          _dragStartOffset = details.localPosition;
          _dragStartRect = _cropRect;
        },
        onPanUpdate: (details) => _handleDrag(details.localPosition),
        onPanEnd: (_) => _activeDragHandle = null,
        child: Container(
          width: handleSize,
          height: handleSize,
          decoration: BoxDecoration(
            color: AppTheme.accentTeal,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(100),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEdgeHandle(_DragHandle handle, Offset position) {
    const handleWidth = 20.0;
    const handleHeight = 6.0;
    final isHorizontal =
        handle == _DragHandle.top || handle == _DragHandle.bottom;

    return Positioned(
      left: position.dx - (isHorizontal ? handleWidth / 2 : handleHeight / 2),
      top: position.dy - (isHorizontal ? handleHeight / 2 : handleWidth / 2),
      child: GestureDetector(
        onPanStart: (details) {
          _activeDragHandle = handle;
          _dragStartOffset = details.localPosition;
          _dragStartRect = _cropRect;
        },
        onPanUpdate: (details) => _handleDrag(details.localPosition),
        onPanEnd: (_) => _activeDragHandle = null,
        child: Container(
          width: isHorizontal ? handleWidth : handleHeight,
          height: isHorizontal ? handleHeight : handleWidth,
          decoration: BoxDecoration(
            color: AppTheme.accentTeal,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }

  void _handleDrag(Offset localPosition) {
    if (_activeDragHandle == null) return;

    final delta = localPosition - _dragStartOffset;
    const minSize = 60.0;

    setState(() {
      switch (_activeDragHandle!) {
        case _DragHandle.topLeft:
          final newLeft = (_dragStartRect.left + delta.dx).clamp(
            0.0,
            _cropRect.right - minSize,
          );
          final newTop = (_dragStartRect.top + delta.dy).clamp(
            0.0,
            _cropRect.bottom - minSize,
          );
          _cropRect = Rect.fromLTRB(
            newLeft,
            newTop,
            _cropRect.right,
            _cropRect.bottom,
          );
          break;
        case _DragHandle.topRight:
          final newRight = (_dragStartRect.right + delta.dx).clamp(
            _cropRect.left + minSize,
            _displaySize.width,
          );
          final newTop = (_dragStartRect.top + delta.dy).clamp(
            0.0,
            _cropRect.bottom - minSize,
          );
          _cropRect = Rect.fromLTRB(
            _cropRect.left,
            newTop,
            newRight,
            _cropRect.bottom,
          );
          break;
        case _DragHandle.bottomLeft:
          final newLeft = (_dragStartRect.left + delta.dx).clamp(
            0.0,
            _cropRect.right - minSize,
          );
          final newBottom = (_dragStartRect.bottom + delta.dy).clamp(
            _cropRect.top + minSize,
            _displaySize.height,
          );
          _cropRect = Rect.fromLTRB(
            newLeft,
            _cropRect.top,
            _cropRect.right,
            newBottom,
          );
          break;
        case _DragHandle.bottomRight:
          final newRight = (_dragStartRect.right + delta.dx).clamp(
            _cropRect.left + minSize,
            _displaySize.width,
          );
          final newBottom = (_dragStartRect.bottom + delta.dy).clamp(
            _cropRect.top + minSize,
            _displaySize.height,
          );
          _cropRect = Rect.fromLTRB(
            _cropRect.left,
            _cropRect.top,
            newRight,
            newBottom,
          );
          break;
        case _DragHandle.top:
          final newTop = (_dragStartRect.top + delta.dy).clamp(
            0.0,
            _cropRect.bottom - minSize,
          );
          _cropRect = Rect.fromLTRB(
            _cropRect.left,
            newTop,
            _cropRect.right,
            _cropRect.bottom,
          );
          break;
        case _DragHandle.bottom:
          final newBottom = (_dragStartRect.bottom + delta.dy).clamp(
            _cropRect.top + minSize,
            _displaySize.height,
          );
          _cropRect = Rect.fromLTRB(
            _cropRect.left,
            _cropRect.top,
            _cropRect.right,
            newBottom,
          );
          break;
        case _DragHandle.left:
          final newLeft = (_dragStartRect.left + delta.dx).clamp(
            0.0,
            _cropRect.right - minSize,
          );
          _cropRect = Rect.fromLTRB(
            newLeft,
            _cropRect.top,
            _cropRect.right,
            _cropRect.bottom,
          );
          break;
        case _DragHandle.right:
          final newRight = (_dragStartRect.right + delta.dx).clamp(
            _cropRect.left + minSize,
            _displaySize.width,
          );
          _cropRect = Rect.fromLTRB(
            _cropRect.left,
            _cropRect.top,
            newRight,
            _cropRect.bottom,
          );
          break;
        case _DragHandle.center:
          var newLeft = _dragStartRect.left + delta.dx;
          var newTop = _dragStartRect.top + delta.dy;
          // Keep within bounds
          newLeft = newLeft.clamp(0.0, _displaySize.width - _cropRect.width);
          newTop = newTop.clamp(0.0, _displaySize.height - _cropRect.height);
          _cropRect = Rect.fromLTWH(
            newLeft,
            newTop,
            _cropRect.width,
            _cropRect.height,
          );
          break;
      }
    });
  }
}

enum _DragHandle {
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
  top,
  bottom,
  left,
  right,
  center,
}

class CropOverlayPainter extends CustomPainter {
  final Rect cropRect;
  final Color overlayColor;

  CropOverlayPainter({required this.cropRect, required this.overlayColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = overlayColor;

    // Draw dark overlay outside crop area
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRect(cropRect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);

    // Draw grid lines inside crop area
    final gridPaint = Paint()
      ..color = Colors.white.withAlpha(60)
      ..strokeWidth = 1;

    // Vertical lines (rule of thirds)
    final thirdWidth = cropRect.width / 3;
    canvas.drawLine(
      Offset(cropRect.left + thirdWidth, cropRect.top),
      Offset(cropRect.left + thirdWidth, cropRect.bottom),
      gridPaint,
    );
    canvas.drawLine(
      Offset(cropRect.left + thirdWidth * 2, cropRect.top),
      Offset(cropRect.left + thirdWidth * 2, cropRect.bottom),
      gridPaint,
    );

    // Horizontal lines
    final thirdHeight = cropRect.height / 3;
    canvas.drawLine(
      Offset(cropRect.left, cropRect.top + thirdHeight),
      Offset(cropRect.right, cropRect.top + thirdHeight),
      gridPaint,
    );
    canvas.drawLine(
      Offset(cropRect.left, cropRect.top + thirdHeight * 2),
      Offset(cropRect.right, cropRect.top + thirdHeight * 2),
      gridPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CropOverlayPainter oldDelegate) {
    return oldDelegate.cropRect != cropRect;
  }
}
