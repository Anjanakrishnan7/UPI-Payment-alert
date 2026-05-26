// lib/screens/splash_screen.dart
import 'package:flutter/material.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entryController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;

  late final AnimationController _glowController;
  late final Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    // Entry animation (fade + spring scale)
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
      ),
    );
    _scaleAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOutBack),
      ),
    );
    // Glowing pulse animation
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 12.0, end: 32.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
    // Start entry animation
    _entryController.forward();
    // Auto‑navigate after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (c, a, s) => const HomeScreen(),
          transitionsBuilder: (c, a, s, child) => FadeTransition(opacity: a, child: child),
          transitionDuration: const Duration(milliseconds: 600),
        ),
      );
    });
  }

  @override
  void dispose() {
    _entryController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            colors: [Color(0xFF0F1528), Color(0xFF090D1A), Color(0xFF03050B)],
            stops: [0.0, 0.5, 1.0],
            center: Alignment.center,
            radius: 1.2,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Expanded central content that animates
              Expanded(
                child: Center(
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_entryController, _glowController]),
                    builder: (context, _) {
                      return FadeTransition(
                        opacity: _fadeAnimation,
                        child: ScaleTransition(
                          scale: _scaleAnimation,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Glowing icon
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Pulsing outer ring
                                  Container(
                                    width: 140,
                                    height: 140,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF00FFC2).withAlpha(40),
                                          blurRadius: _glowAnimation.value + 15,
                                          spreadRadius: _glowAnimation.value / 2,
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Inner logo container
                                  Container(
                                    width: 110,
                                    height: 110,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF101424),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: const Color(0xFF00FFC2).withAlpha(100),
                                        width: 2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF00FFC2).withAlpha(60),
                                          blurRadius: _glowAnimation.value,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.offline_bolt_rounded,
                                      color: Color(0xFF00FFC2),
                                      size: 56,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 48),
                              // Title
                              const Text(
                                'UPI Payment Alert',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                  shadows: [
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
                                  color: Colors.white70,
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
              // Persistent loading indicator at the bottom
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
