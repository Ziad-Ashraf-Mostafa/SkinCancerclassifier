import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/theme.dart';
import '../services/skin_cancer_classifier.dart';

class ResultScreen extends StatefulWidget {
  final String imagePath;
  final ClassificationResult result;

  const ResultScreen({
    super.key,
    required this.imagePath,
    required this.result,
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

                // Bottom button
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Transform.translate(
                    offset: Offset(0, _slideAnimation.value),
                    child: Opacity(
                      opacity: _fadeAnimation.value,
                      child: SizedBox(
                        width: double.infinity,
                        height: 60,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accentTeal,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.camera_alt_rounded, size: 22),
                              SizedBox(width: 10),
                              Text(
                                'Scan Again',
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
