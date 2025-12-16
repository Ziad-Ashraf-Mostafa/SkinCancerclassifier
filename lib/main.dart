import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'theme/theme.dart';
import 'screens/home_screen.dart';
import 'services/skin_cancer_classifier.dart';
import 'services/scan_storage_service.dart';

List<CameraDescription> cameras = [];
final SkinCancerClassifier classifier = SkinCancerClassifier();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.primaryDark,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Get available cameras
  try {
    cameras = await availableCameras();
  } catch (e) {
    debugPrint('Error getting cameras: $e');
  }

  runApp(const SkinCancerDetectorApp());
}

class SkinCancerDetectorApp extends StatelessWidget {
  const SkinCancerDetectorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Skin Cancer Detector',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  bool _permissionGranted = false;
  bool _modelLoaded = false;
  String _loadingStatus = 'Starting...';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _animationController.forward();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Request camera permission
    setState(() => _loadingStatus = 'Requesting camera access...');
    await Future.delayed(const Duration(milliseconds: 300));

    final status = await Permission.camera.request();
    _permissionGranted = status.isGranted;

    if (!_permissionGranted) {
      setState(() {
        _errorMessage = 'Camera permission is required';
      });
      return;
    }

    // Request storage permission (for saving scans)
    setState(() => _loadingStatus = 'Setting up storage...');
    await Permission.storage.request();

    // Initialize scan storage service
    await ScanStorageService.instance.initialize();

    // Load AI model
    setState(() => _loadingStatus = 'Loading AI model...');

    final modelSuccess = await classifier.initialize();
    _modelLoaded = modelSuccess;

    if (!_modelLoaded) {
      setState(() {
        _errorMessage = 'Failed to load AI model';
      });
      return;
    }

    setState(() => _loadingStatus = 'Ready!');
    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted) {
      _navigateToHome();
    }
  }

  void _navigateToHome() {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            HomeScreen(cameras: cameras, classifier: classifier),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
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
      body: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppTheme.primaryDark,
                  AppTheme.surfaceDark,
                  AppTheme.accentTeal.withAlpha(13),
                ],
              ),
            ),
            child: SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),

                  // Logo
                  Opacity(
                    opacity: _fadeAnimation.value,
                    child: Transform.scale(
                      scale: _scaleAnimation.value,
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppTheme.primaryGradient,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.accentTeal.withAlpha(102),
                              blurRadius: 40,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.health_and_safety_rounded,
                          size: 70,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Title
                  Opacity(
                    opacity: _fadeAnimation.value,
                    child: Column(
                      children: [
                        Text(
                          'Skin Scanner',
                          style: Theme.of(context).textTheme.displayLarge
                              ?.copyWith(
                                fontSize: 36,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -1,
                              ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'AI-Powered Skin Analysis',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                color: AppTheme.accentTeal,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // Loading or error status
                  Opacity(
                    opacity: _fadeAnimation.value,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: _errorMessage != null
                          ? Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: AppTheme.dangerRed.withAlpha(26),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: AppTheme.dangerRed.withAlpha(77),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.error_outline,
                                        color: AppTheme.dangerRed,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          _errorMessage!,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                color: AppTheme.dangerRed,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),
                                if (!_permissionGranted)
                                  ElevatedButton(
                                    onPressed: () => openAppSettings(),
                                    child: const Text('Open Settings'),
                                  )
                                else
                                  ElevatedButton(
                                    onPressed: () {
                                      setState(() {
                                        _errorMessage = null;
                                      });
                                      _initializeApp();
                                    },
                                    child: const Text('Retry'),
                                  ),
                              ],
                            )
                          : Column(
                              children: [
                                const SizedBox(
                                  width: 40,
                                  height: 40,
                                  child: CircularProgressIndicator(
                                    color: AppTheme.accentTeal,
                                    strokeWidth: 3,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  _loadingStatus,
                                  style: const TextStyle(color: Colors.white70),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                    ),
                  ),

                  const Spacer(flex: 2),

                  // Footer
                  Opacity(
                    opacity: _fadeAnimation.value * 0.6,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 30),
                      child: Text(
                        'For educational purposes only',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: Colors.white38),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
