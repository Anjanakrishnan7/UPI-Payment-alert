import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/payment_provider.dart';
import '../widgets/app_logo.dart';
import 'privacy_policy_screen.dart';
import 'setup_screen.dart';
import 'home_screen.dart';

class PrivacyNoticeScreen extends StatelessWidget {
  const PrivacyNoticeScreen({super.key});

  Color _getCardColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF121625)
        : const Color(0xFFFFFFFF);
  }

  Color _getTealAccent(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0xFF00FFC2) : const Color(0xFF00B894);
  }

  Color _getPrimaryTextColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : const Color(0xFF1F2937);
  }


  Color _getBodyTextColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.white70
        : const Color(0xFF374151);
  }

  Color _getBorderColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.white.withAlpha(8)
        : Colors.black.withAlpha(8);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = _getTealAccent(context);
    final cardColor = _getCardColor(context);
    final borderColor = _getBorderColor(context);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0E1A) : const Color(0xFFF7F8FA),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App Logo
                const AppLogo(
                  size: 90,
                  showGlow: true,
                  glowValue: 24,
                ),
                const SizedBox(height: 32),

                // Title
                Text(
                  'Welcome to\nUPI Payment Alert',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _getPrimaryTextColor(context),
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 24),

                // Message Box
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: borderColor),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(isDark ? 20 : 6),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      )
                    ],
                  ),
                  child: Column(
                    children: [
                      // Point 1
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.devices_rounded, color: accent, size: 20),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              'UPI Payment Alert processes payment notifications entirely on your device.',
                              style: TextStyle(
                                color: _getBodyTextColor(context),
                                fontSize: 14,
                                height: 1.45,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      
                      // Point 2
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.cloud_off_rounded, color: accent, size: 20),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              'No data is uploaded, collected, or shared with any third party.',
                              style: TextStyle(
                                color: _getBodyTextColor(context),
                                fontSize: 14,
                                height: 1.45,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Point 3
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.assignment_turned_in_outlined, color: accent, size: 20),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              'By continuing, you acknowledge and agree to the Privacy Policy.',
                              style: TextStyle(
                                color: _getBodyTextColor(context),
                                fontSize: 14,
                                height: 1.45,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),

                // View Privacy Policy Button
                OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => const PrivacyPolicyScreen()),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: accent,
                    side: BorderSide(color: accent.withAlpha(80)),
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text(
                    'View Privacy Policy',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                const SizedBox(height: 14),

                // Continue Button
                ElevatedButton(
                  onPressed: () async {
                    final provider = context.read<PaymentProvider>();
                    await provider.acceptPrivacyNotice();

                    if (!context.mounted) return;

                    final showSetup = !provider.isListenerPermissionGranted || 
                        (!provider.isBatteryOptimizationDisabled && !provider.batteryOptimizationSkipped);
                    final Widget targetScreen = showSetup ? const SetupScreen() : const HomeScreen();

                    Navigator.of(context).pushReplacement(
                      PageRouteBuilder(
                        pageBuilder: (c, a, s) => targetScreen,
                        transitionsBuilder: (c, a, s, child) => FadeTransition(opacity: a, child: child),
                        transitionDuration: const Duration(milliseconds: 600),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black),
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
