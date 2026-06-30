import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/payment_provider.dart';
import 'home_screen.dart';
import '../widgets/app_logo.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final provider = context.read<PaymentProvider>();
      provider.checkPermissions().then((_) {
        final bothGranted = provider.isListenerPermissionGranted && 
            (provider.isBatteryOptimizationDisabled || provider.batteryOptimizationSkipped);
        if (bothGranted) {
          _navigateToHome();
        }
      });
    }
  }

  void _navigateToHome() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (c, a, s) => const HomeScreen(),
        transitionsBuilder: (c, a, s, child) => FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PaymentProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final scaffoldBg = isDark ? const Color(0xFF090D1A) : const Color(0xFFF7F8FA);
    final cardBg = isDark ? const Color(0xFF121625) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF1F2937);
    final bodyColor = isDark ? Colors.white70 : const Color(0xFF374151);
    final accentColor = isDark ? const Color(0xFF00FFC2) : const Color(0xFF00B894);

    final bool showNotificationGate = !provider.isListenerPermissionGranted;

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const AppLogo(
                  size: 80,
                  showGlow: true,
                  glowValue: 24,
                ),
                const SizedBox(height: 32),
                
                Text(
                  showNotificationGate ? 'Permission Required' : 'Optimize Performance',
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isDark ? Colors.white.withAlpha(8) : Colors.black.withAlpha(8),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(isDark ? 30 : 10),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      )
                    ],
                  ),
                  child: showNotificationGate
                      ? Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: accentColor.withAlpha(20),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.security_rounded,
                                color: accentColor,
                                size: 36,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'UPI Payment Alert needs Notification Listener access to detect and announce your payment notifications.\n\nTap Continue, then find \'UPI Voice Alert\' in the Notification Access list and turn it on. You\'ll be brought back here automatically.',
                              style: TextStyle(
                                color: bodyColor,
                                fontSize: 14,
                                height: 1.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 28),
                            
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () => provider.requestListenerPermission(),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: accentColor,
                                  foregroundColor: isDark ? const Color(0xFF090D1A) : Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  elevation: 0,
                                ),
                                icon: const Icon(Icons.security_rounded, size: 20),
                                label: const Text(
                                  'Continue to Settings',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: accentColor.withAlpha(20),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.battery_alert_rounded,
                                color: accentColor,
                                size: 36,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'To guarantee real-time payment voice announcements instantly even when the screen is turned off or locked, please disable battery optimization for this application.',
                              style: TextStyle(
                                color: bodyColor,
                                fontSize: 14,
                                height: 1.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 28),
                            
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () => provider.requestIgnoreBatteryOptimization(),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: accentColor,
                                  foregroundColor: isDark ? const Color(0xFF090D1A) : Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  elevation: 0,
                                ),
                                icon: const Icon(Icons.flash_off_rounded, size: 20),
                                label: const Text(
                                  'Disable Battery Optimization',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 32),

                if (!showNotificationGate)
                  // Skip Setup Button
                  TextButton(
                    onPressed: () async {
                      await provider.skipBatteryOptimization();
                      _navigateToHome();
                    },
                    child: Text(
                      'Skip Setup & Continue',
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
