import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

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

  Color _getSecondaryTextColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.white38
        : const Color(0xFF6B7280);
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: _getPrimaryTextColor(context)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Privacy Policy',
          style: TextStyle(
            color: _getPrimaryTextColor(context),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Shield & Safe Icon Header
            Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: accent.withAlpha(20),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.shield_outlined,
                  size: 64,
                  color: accent,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                'Your Privacy is Our Priority',
                style: TextStyle(
                  color: _getPrimaryTextColor(context),
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'UPI Payment Alert is designed with a privacy-first approach.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _getSecondaryTextColor(context),
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Policy Points
            _buildPolicyCard(
              context,
              icon: Icons.notifications_active_outlined,
              title: 'Notification Access Only',
              description: 'Uses notification access only to detect payment notifications and announce them using voice alerts.',
            ),
            const SizedBox(height: 16),
            _buildPolicyCard(
              context,
              icon: Icons.memory_outlined,
              title: 'On-Device Processing',
              description: 'All processing happens entirely on the device. All transaction data is stored locally in an AES-encrypted Hive database. Encryption keys are securely stored using the device\'s secure keystore. No transaction data is uploaded or shared.',
            ),
            const SizedBox(height: 16),
            _buildPolicyCard(
              context,
              icon: Icons.cloud_off_outlined,
              title: 'Offline & Independent',
              description: 'No data is uploaded to any server. We do not track, collect, or store your transactions remotely.',
            ),
            const SizedBox(height: 16),
            _buildPolicyCard(
              context,
              icon: Icons.block_outlined,
              title: 'No Third-Party Sharing',
              description: 'Since we don\'t collect your information, we can\'t and don\'t share any of your data with third parties.',
            ),
            const SizedBox(height: 16),
            _buildPolicyCard(
              context,
              icon: Icons.no_accounts_outlined,
              title: 'No Account Required',
              description: 'No login, sign-up, or user account is required to use UPI Payment Alert. Just install and configure.',
            ),
            const SizedBox(height: 16),
            _buildPolicyCard(
              context,
              icon: Icons.delete_sweep_outlined,
              title: 'Clear History Anytime',
              description: 'Users have full control and can clear all transaction history from the app settings at any moment.',
            ),
            const SizedBox(height: 32),

            // Contact Info Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CONTACT & SUPPORT',
                    style: TextStyle(
                      color: _getSecondaryTextColor(context),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'If you have any questions or feedback regarding our privacy practices, please contact us at:',
                    style: TextStyle(
                      color: _getBodyTextColor(context),
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () {
                      Clipboard.setData(const ClipboardData(text: 'anjanakrishnananil@gmail.com'));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Email address copied to clipboard'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF090D1A) : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.email_outlined, color: accent, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'anjanakrishnananil@gmail.com',
                            style: TextStyle(
                              color: accent,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.copy_rounded, color: _getSecondaryTextColor(context), size: 14),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildPolicyCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = _getCardColor(context);
    final accent = _getTealAccent(context);
    final borderColor = _getBorderColor(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 15 : 5),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accent.withAlpha(12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: _getPrimaryTextColor(context),
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: TextStyle(
                    color: _getBodyTextColor(context),
                    fontSize: 13,
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
}
