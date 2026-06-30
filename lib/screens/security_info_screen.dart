import 'package:flutter/material.dart';

class SecurityInfoScreen extends StatelessWidget {
  const SecurityInfoScreen({super.key});

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
          'Security Information',
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
            // Safe Security Header Icon
            Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: accent.withAlpha(20),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.gpp_good_outlined,
                  size: 64,
                  color: accent,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                'Bank-Grade Local Security',
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
                'Your payment details are isolated and protected.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _getSecondaryTextColor(context),
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Security Points
            _buildSecurityCard(
              context,
              icon: Icons.storage_rounded,
              title: 'AES-Encrypted Local Database',
              description: 'All parsed payment records are saved inside a highly optimized, encrypted local Hive database on your device.',
            ),
            const SizedBox(height: 16),
            _buildSecurityCard(
              context,
              icon: Icons.vpn_key_rounded,
              title: 'Secure Key Storage',
              description: 'Database encryption keys are securely stored using the device\'s secure hardware-backed keystore.',
            ),
            const SizedBox(height: 16),
            _buildSecurityCard(
              context,
              icon: Icons.sync_disabled_rounded,
              title: 'No Cloud Synchronization',
              description: 'There is zero automated cloud sync or remote backups. Your history never leaves the offline environment.',
            ),
            const SizedBox(height: 16),
            _buildSecurityCard(
              context,
              icon: Icons.block_outlined,
              title: 'No Third-Party Sharing',
              description: 'All system triggers and voice configurations are kept private. Your financial records are never shared.',
            ),
            const SizedBox(height: 16),
            _buildSecurityCard(
              context,
              icon: Icons.memory_outlined,
              title: 'All Processing Happens On-Device',
              description: 'All operations, including notification capturing, payment parsing, and text-to-speech generation, happen locally on your device.',
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityCard(
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
