import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'setup_screen.dart';
import '../widgets/app_logo.dart';
import 'package:provider/provider.dart';
import '../providers/payment_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  AnimationController? _entryController;
  Animation<double>? _fadeAnimation;
  Animation<double>? _scaleAnimation;

  AnimationController? _glowController;
  Animation<double>? _glowAnimation;

  @override
  void initState() {
    super.initState();
    debugPrint("[SplashScreen] initState started.");

    try {
      debugPrint("[SplashScreen] Setting up _entryController...");
      _entryController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1500),
      );

      _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _entryController!,
          curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
        ),
      );

      _scaleAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
        CurvedAnimation(
          parent: _entryController!,
          curve: const Interval(0.0, 0.8, curve: Curves.easeOutBack),
        ),
      );

      debugPrint("[SplashScreen] Setting up _glowController...");
      _glowController = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 2),
      );

      _glowAnimation = Tween<double>(begin: 12.0, end: 32.0).animate(
        CurvedAnimation(parent: _glowController!, curve: Curves.easeInOut),
      );

      debugPrint("[SplashScreen] Initiating animations execution...");
      _entryController!.forward();
      _glowController!.repeat(reverse: true);
      debugPrint("[SplashScreen] Animations started successfully.");
    } catch (e) {
      debugPrint("[SplashScreen] Animations setup failed: $e");
    }

    // Navigating after 3 seconds
    debugPrint("[SplashScreen] Scheduling delayed navigation...");
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      final provider = context.read<PaymentProvider>();
      final showSetup = !provider.isListenerPermissionGranted || (!provider.isBatteryOptimizationDisabled && !provider.batteryOptimizationSkipped);
      final Widget targetScreen = showSetup ? const SetupScreen() : const HomeScreen();
      
      debugPrint("[SplashScreen] 3 seconds timer fired. Navigating to ${targetScreen.runtimeType}...");
      try {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (c, a, s) => targetScreen,
            transitionsBuilder: (c, a, s, child) => FadeTransition(opacity: a, child: child),
            transitionDuration: const Duration(milliseconds: 600),
          ),
        );
        debugPrint("[SplashScreen] Route navigation executed successfully via PageRouteBuilder.");
      } catch (e) {
        debugPrint("[SplashScreen] PageRouteBuilder navigation failed: $e. Falling back to MaterialPageRoute...");
        try {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => targetScreen),
          );
          debugPrint("[SplashScreen] Fallback MaterialPageRoute executed successfully.");
        } catch (navErr) {
          debugPrint("[SplashScreen] Critical: All navigation attempts failed: $navErr");
        }
      }
    });
  }

  @override
  void dispose() {
    debugPrint("[SplashScreen] dispose called.");
    try {
      _entryController?.dispose();
      _glowController?.dispose();
      debugPrint("[SplashScreen] Controllers disposed successfully.");
    } catch (e) {
      debugPrint("[SplashScreen] Error during controller disposal: $e");
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("[SplashScreen] build called.");
    
    // Safety check in case animation setup failed
    final opacityAnim = _fadeAnimation ?? const AlwaysStoppedAnimation(1.0);
    final scaleAnim = _scaleAnimation ?? const AlwaysStoppedAnimation(1.0);
    final glowValueAnim = _glowAnimation ?? const AlwaysStoppedAnimation(20.0);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? const Color(0xFF090D1A) : const Color(0xFFF7F8FA);
    final radialColors = isDark
        ? [const Color(0xFF0F1528), const Color(0xFF090D1A), const Color(0xFF03050B)]
        : [const Color(0xFFFFFFFF), const Color(0xFFF7F8FA), const Color(0xFFECEFF1)];
    final titleColor = isDark ? Colors.white : const Color(0xFF1F2937);
    final subtitleColor = isDark ? Colors.white70 : const Color(0xFF6B7280);

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            colors: radialColors,
            stops: const [0.0, 0.5, 1.0],
            center: Alignment.center,
            radius: 1.2,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: AnimatedBuilder(
                    animation: Listenable.merge([
                      if (_entryController != null) _entryController,
                      if (_glowController != null) _glowController,
                    ]),
                    builder: (context, _) {
                      return FadeTransition(
                        opacity: opacityAnim,
                        child: ScaleTransition(
                          scale: scaleAnim,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Glowing Center App Logo
                              AppLogo(
                                size: 110,
                                showGlow: true,
                                glowValue: glowValueAnim.value,
                              ),
                              const SizedBox(height: 48),
                              
                              // App Title
                              Text(
                                'UPI Payment Alert',
                                style: TextStyle(
                                  color: titleColor,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                  shadows: const [
                                    Shadow(
                                      color: Color(0x3300FFC2),
                                      blurRadius: 15,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              
                              // Subtitle
                              Text(
                                'Smart Voice Payment Assistant',
                                style: TextStyle(
                                  color: subtitleColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              
              // Persistent loading spinner at the bottom
              const Padding(
                padding: EdgeInsets.only(bottom: 24.0),
                child: CircularProgressIndicator(
                  color: Color(0xFF00FFC2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
