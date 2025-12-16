import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../theme/theme.dart';
import '../services/skin_cancer_classifier.dart';
import '../services/scan_storage_service.dart';
import 'home_screen.dart';

class ResultScreen extends StatefulWidget {
  final String imagePath;
  final ClassificationResult result;
  final List<CameraDescription> cameras;
  final SkinCancerClassifier classifier;

  const ResultScreen({
    super.key,
    required this.imagePath,
    required this.result,
    required this.cameras,
    required this.classifier,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _progressAnimation;

  bool _isSaving = false;
  bool _isSaved = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<double>(begin: 50.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 0.7, curve: Curves.easeOut),
      ),
    );

    _progressAnimation =
        Tween<double>(begin: 0.0, end: widget.result.confidence).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
          ),
        );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _navigateToHome() {
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            HomeScreen(cameras: widget.cameras, classifier: widget.classifier),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
      (route) => false,
    );
  }

  Future<void> _saveAndGoHome() async {
    if (_isSaving || _isSaved) return;

    setState(() => _isSaving = true);

    try {
      await ScanStorageService.instance.initialize();
      final record = await ScanStorageService.instance.saveScan(
        imageFile: File(widget.imagePath),
        result: widget.result,
      );

      if (record != null) {
        setState(() {
          _isSaved = true;
          _isSaving = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.white),
                  SizedBox(width: 10),
                  Text('Scan saved successfully'),
                ],
              ),
              backgroundColor: AppTheme.safeGreen,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              duration: const Duration(seconds: 2),
            ),
          );

          // Wait a moment then navigate home
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) {
            _navigateToHome();
          }
        }
      } else {
        throw Exception('Failed to save scan');
      }
    } catch (e) {
      debugPrint('Error saving scan: $e');
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to save scan. Please try again.'),
            backgroundColor: AppTheme.dangerRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCancerous = widget.result.isCancerous;
    final statusColor = isCancerous ? AppTheme.dangerRed : AppTheme.safeGreen;
    final statusGradient = isCancerous
        ? AppTheme.dangerGradient
        : AppTheme.safeGradient;

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
                        onTap: _navigateToHome,
                        child: GlassmorphicContainer(
                          opacity: 0.15,
                          borderRadius: 14,
                          padding: const EdgeInsets.all(12),
                          child: const Icon(Icons.home_rounded, size: 20),
                        ),
                      ),
                      const Spacer(),
                      Opacity(
                        opacity: _fadeAnimation.value,
                        child: Text(
                          'Analysis Result',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(width: 48), // Balance
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        const SizedBox(height: 10),

                        // Image preview
                        Opacity(
                          opacity: _fadeAnimation.value,
                          child: Container(
                            height: 200,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: statusColor.withAlpha(128),
                                width: 2,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: Image.file(
                                File(widget.imagePath),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 30),

                        // Result card
                        Transform.translate(
                          offset: Offset(0, _slideAnimation.value),
                          child: Opacity(
                            opacity: _fadeAnimation.value,
                            child: GlassmorphicContainer(
                              opacity: 0.1,
                              borderRadius: 24,
                              borderColor: statusColor.withAlpha(77),
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                children: [
                                  // Status indicator
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: statusGradient,
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          isCancerous
                                              ? Icons.warning_rounded
                                              : Icons.check_circle_rounded,
                                          color: Colors.white,
                                          size: 22,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          isCancerous
                                              ? 'Medical Attention Advised'
                                              : 'Likely Benign',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 30),

                                  // Confidence indicator
                                  SizedBox(
                                    width: 160,
                                    height: 160,
                                    child: CustomPaint(
                                      painter: ConfidenceRingPainter(
                                        progress: _progressAnimation.value,
                                        color: statusColor,
                                      ),
                                      child: Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              '${(_progressAnimation.value * 100).toInt()}%',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .displayLarge
                                                  ?.copyWith(
                                                    color: statusColor,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                            ),
                                            Text(
                                              'Confidence',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium
                                                  ?.copyWith(
                                                    color: Colors.white54,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 30),

                                  // Classification label
                                  Text(
                                    widget.result.label,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium
                                        ?.copyWith(color: Colors.white),
                                    textAlign: TextAlign.center,
                                  ),

                                  const SizedBox(height: 12),

                                  // Description
                                  Text(
                                    widget.result.description,
                                    style: Theme.of(context).textTheme.bodyLarge
                                        ?.copyWith(
                                          color: Colors.white60,
                                          height: 1.5,
                                        ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Disclaimer
                        Transform.translate(
                          offset: Offset(0, _slideAnimation.value),
                          child: Opacity(
                            opacity: _fadeAnimation.value * 0.8,
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppTheme.warningYellow.withAlpha(26),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AppTheme.warningYellow.withAlpha(77),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.info_outline_rounded,
                                    color: AppTheme.warningYellow,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'This is for educational purposes only and should not replace professional medical diagnosis.',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: AppTheme.warningYellow,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),

                // Bottom buttons
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Transform.translate(
                    offset: Offset(0, _slideAnimation.value),
                    child: Opacity(
                      opacity: _fadeAnimation.value,
                      child: Column(
                        children: [
                          // Save button
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: (_isSaving || _isSaved)
                                  ? null
                                  : _saveAndGoHome,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.accentTeal,
                                foregroundColor: Colors.black,
                                disabledBackgroundColor: _isSaved
                                    ? AppTheme.safeGreen
                                    : AppTheme.accentTeal.withAlpha(100),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: _isSaving
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          _isSaved
                                              ? Icons.check_rounded
                                              : Icons.save_rounded,
                                          size: 22,
                                          color: _isSaved ? Colors.white : null,
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          _isSaved
                                              ? 'Saved!'
                                              : 'Save & Return Home',
                                          style: TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w600,
                                            color: _isSaved
                                                ? Colors.white
                                                : null,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Return home without saving button
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: OutlinedButton(
                              onPressed: _navigateToHome,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white70,
                                side: BorderSide(
                                  color: Colors.white.withAlpha(60),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.home_rounded, size: 22),
                                  SizedBox(width: 10),
                                  Text(
                                    'Return to Home',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
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
}

class ConfidenceRingPainter extends CustomPainter {
  final double progress;
  final Color color;

  ConfidenceRingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;

    // Background ring
    final bgPaint = Paint()
      ..color = Colors.white.withAlpha(26)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    // Progress ring
    final progressPaint = Paint()
      ..shader = LinearGradient(
        colors: [color, color.withAlpha(153)],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );

    // Glow effect
    final glowPaint = Paint()
      ..color = color.withAlpha(77)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      glowPaint,
    );
  }

  @override
  bool shouldRepaint(covariant ConfidenceRingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
