import 'package:flutter/material.dart';
import '../theme/theme.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOut),
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
                          'About',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 10),

                        // App Info Section
                        Opacity(
                          opacity: _fadeAnimation.value,
                          child: Center(
                            child: Column(
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: AppTheme.primaryGradient,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.accentTeal.withAlpha(
                                          60,
                                        ),
                                        blurRadius: 20,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.health_and_safety_rounded,
                                    size: 40,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Skin Scanner',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Version 1.0.0',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(color: Colors.white54),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 30),

                        // How it Works Section
                        Transform.translate(
                          offset: Offset(0, _slideAnimation.value),
                          child: Opacity(
                            opacity: _fadeAnimation.value,
                            child: _buildSection(
                              context,
                              icon: Icons.lightbulb_outline_rounded,
                              title: 'How It Works',
                              content:
                                  '''Skin Scanner uses an advanced AI model trained on dermatological images to analyze skin lesions and provide preliminary assessments.

The app uses machine learning to identify patterns in skin images that may indicate various skin conditions, including potentially concerning lesions.''',
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Instructions Section
                        Transform.translate(
                          offset: Offset(0, _slideAnimation.value * 1.2),
                          child: Opacity(
                            opacity: _fadeAnimation.value,
                            child: _buildSection(
                              context,
                              icon: Icons.checklist_rounded,
                              title: 'How to Make a Scan',
                              content: null,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildInstructionStep(
                                    context,
                                    number: '1',
                                    title: 'Capture or Upload',
                                    description:
                                        'Use the camera to take a photo of the skin area, or upload an existing image from your gallery.',
                                  ),
                                  _buildInstructionStep(
                                    context,
                                    number: '2',
                                    title: 'Crop the Image',
                                    description:
                                        'Adjust the crop area to focus on the specific skin lesion or area of concern.',
                                  ),
                                  _buildInstructionStep(
                                    context,
                                    number: '3',
                                    title: 'Analyze',
                                    description:
                                        'The AI will process the image and provide a preliminary assessment with confidence level.',
                                  ),
                                  _buildInstructionStep(
                                    context,
                                    number: '4',
                                    title: 'Save Results',
                                    description:
                                        'Optionally save the scan to your history for future reference.',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Tips Section
                        Transform.translate(
                          offset: Offset(0, _slideAnimation.value * 1.4),
                          child: Opacity(
                            opacity: _fadeAnimation.value,
                            child: _buildSection(
                              context,
                              icon: Icons.tips_and_updates_outlined,
                              title: 'Tips for Best Results',
                              content: null,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildTip(
                                    context,
                                    'Good lighting',
                                    'Ensure the area is well-lit with natural or bright artificial light.',
                                  ),
                                  _buildTip(
                                    context,
                                    'Steady focus',
                                    'Keep the camera steady and focus on the skin lesion clearly.',
                                  ),
                                  _buildTip(
                                    context,
                                    'Close-up',
                                    'Get close enough to capture details while keeping the image in focus.',
                                  ),
                                  _buildTip(
                                    context,
                                    'Clean area',
                                    'Remove any obstructions like hair or clothing from the area.',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Disclaimer Section
                        Transform.translate(
                          offset: Offset(0, _slideAnimation.value * 1.6),
                          child: Opacity(
                            opacity: _fadeAnimation.value,
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: AppTheme.dangerRed.withAlpha(20),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: AppTheme.dangerRed.withAlpha(60),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: AppTheme.dangerRed.withAlpha(
                                            30,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.warning_amber_rounded,
                                          color: AppTheme.dangerRed,
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Important Disclaimer',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge
                                            ?.copyWith(
                                              color: AppTheme.dangerRed,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'This application is for EDUCATIONAL PURPOSES ONLY.',
                                    style: Theme.of(context).textTheme.bodyLarge
                                        ?.copyWith(
                                          color: AppTheme.dangerRed,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    '• This app is NOT a medical device and should NOT be used for medical diagnosis.\n\n• The AI analysis is not a substitute for professional medical advice, diagnosis, or treatment.\n\n• Always consult with a qualified healthcare professional or dermatologist for any skin concerns.\n\n• If you notice any changes in moles, skin lesions, or have concerns about your skin health, please seek medical attention immediately.\n\n• The developers are not responsible for any medical decisions made based on this app\'s analysis.',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: AppTheme.dangerRed.withAlpha(
                                            200,
                                          ),
                                          height: 1.5,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 30),

                        // Copyright
                        Opacity(
                          opacity: _fadeAnimation.value * 0.6,
                          child: Center(
                            child: Text(
                              '© 2024 Skin Scanner\nFor Educational Use Only',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: Colors.white38),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),

                        const SizedBox(height: 30),
                      ],
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

  Widget _buildSection(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? content,
    Widget? child,
  }) {
    return GlassmorphicContainer(
      opacity: 0.08,
      borderRadius: 20,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.accentTeal.withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppTheme.accentTeal, size: 24),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (content != null)
            Text(
              content,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white70,
                height: 1.6,
              ),
            ),
          if (child != null) child,
        ],
      ),
    );
  }

  Widget _buildInstructionStep(
    BuildContext context, {
    required String number,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white60,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTip(BuildContext context, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_rounded, color: AppTheme.safeGreen, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$title: ',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  TextSpan(
                    text: description,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.white60),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
