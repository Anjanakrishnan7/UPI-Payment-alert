import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/payment_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  int _currentIndex = 0;
  bool _showRawDebugInfo = true;
  late TextEditingController _balanceController;
  late FocusNode _balanceFocusNode;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _balanceController = TextEditingController();
    _balanceFocusNode = FocusNode();

    // Setup pulsing animation for listening state
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Refresh permissions when screen mounts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PaymentProvider>().checkPermissions();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _balanceController.dispose();
    _balanceFocusNode.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<PaymentProvider>().checkPermissions();
    }
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return "$hour:$minute $period";
  }

  Color _getTtsStatusColor(TtsStatus status) {
    switch (status) {
      case TtsStatus.initializing:
        return const Color(0xFFFFB300);
      case TtsStatus.initialized:
        return const Color(0xFF4CAF50);
      case TtsStatus.speaking:
        return const Color(0xFF00FFC2);
      case TtsStatus.failed:
        return const Color(0xFFFF5252);
    }
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return "Today";
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (dt.year == yesterday.year && dt.month == yesterday.month &&
        dt.day == yesterday.day) {
      return "Yesterday";
    }
    return "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}";
  }

  Widget _getAppIcon(String packageName, bool isSent) {
    IconData iconData = isSent ? Icons.unfold_less_rounded : Icons.unfold_more_rounded;
    Color brandColor = isSent ? const Color(0xFFFF5252) : const Color(0xFF00FFC2);

    if (packageName.contains("paisa.user")) {
      iconData = Icons.g_mobiledata_rounded;
      brandColor = const Color(0xFF4285F4);
    } else if (packageName.contains("phonepe")) {
      iconData = Icons.flash_on_rounded;
      brandColor = const Color(0xFF5F259F);
    } else if (packageName.contains("paytm")) {
      iconData = Icons.account_balance_wallet_rounded;
      brandColor = const Color(0xFF00B9F5);
    } else if (packageName.contains("upiapp")) {
      iconData = Icons.stars_rounded;
      brandColor = const Color(0xFFF57C00);
    }

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: brandColor.withAlpha(25),
        shape: BoxShape.circle,
        border: Border.all(color: brandColor.withAlpha(80), width: 1.5),
      ),
      child: Center(
        child: Icon(iconData, color: brandColor, size: 26),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<PaymentProvider>(context);

    if (!provider.isInitialized) {
      return const Scaffold(
        backgroundColor: Color(0xFF090D1A),
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF00FFC2),
          ),
        ),
      );
    }

    if (!_balanceFocusNode.hasFocus) {
      _balanceController.text = provider.balance.toStringAsFixed(2);
    }

    // Dynamic title based on tab selection
    String titleText = 'Receive Payments';
    if (_currentIndex == 1) {
      titleText = 'Send Payments';
    } else if (_currentIndex == 2) {
      titleText = 'Listener Diagnostics';
    }

    // Dynamic indicator decoration color
    Color indicatorColor = const Color(0xFF00FFC2);
    if (_currentIndex == 1) {
      indicatorColor = const Color(0xFFFF5252);
    } else if (_currentIndex == 2) {
      indicatorColor = const Color(0xFFFFB300);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF090D1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: indicatorColor.withAlpha(30),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _currentIndex == 0 
                    ? Icons.call_received_rounded 
                    : _currentIndex == 1 
                        ? Icons.call_made_rounded 
                        : Icons.bug_report_rounded,
                color: indicatorColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              titleText,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
            if (provider.isNightModeActive) ...[
              const SizedBox(width: 8),
              const Icon(Icons.mode_night_rounded, color: Color(0xFF00FFC2), size: 20),
            ],
          ],
        ),
        actions: [
          if (_currentIndex != 2)
            IconButton(
              icon: Icon(
                _showRawDebugInfo ? Icons.bug_report_rounded : Icons.bug_report_outlined,
                color: _showRawDebugInfo ? const Color(0xFF00FFC2) : Colors.white60,
              ),
              onPressed: () {
                setState(() {
                  _showRawDebugInfo = !_showRawDebugInfo;
                });
              },
              tooltip: 'Toggle Debug Details',
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            onPressed: () => provider.checkPermissions(),
            tooltip: 'Refresh Status',
          ),
        ],
      ),
      body: _currentIndex == 0
          ? _buildReceiveTab(provider)
          : _currentIndex == 1
              ? _buildSendTab(provider)
              : _buildDiagnosticsTab(provider),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: const Color(0xFF0E1220),
          indicatorColor: indicatorColor.withAlpha(30),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return TextStyle(
                color: indicatorColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              );
            }
            return const TextStyle(color: Colors.white38, fontSize: 12);
          }),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.download_rounded, color: Colors.white38),
              selectedIcon: Icon(Icons.download_rounded, color: Color(0xFF00FFC2)),
              label: 'Receive',
            ),
            NavigationDestination(
              icon: Icon(Icons.upload_rounded, color: Colors.white38),
              selectedIcon: Icon(Icons.upload_rounded, color: Color(0xFFFF5252)),
              label: 'Send',
            ),
            NavigationDestination(
              icon: Icon(Icons.bug_report_outlined, color: Colors.white38),
              selectedIcon: Icon(Icons.bug_report_rounded, color: Color(0xFFFFB300)),
              label: 'Diagnostics',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiveTab(PaymentProvider provider) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!provider.isBatteryOptimizationDisabled) ...[
              _buildBatteryOptimizationCard(provider),
              const SizedBox(height: 20),
            ],
            _buildServiceStatusCard(provider),
            const SizedBox(height: 20),
            _buildAccountFilter(provider),
            if (provider.availableAccounts.isNotEmpty) const SizedBox(height: 20),
            _buildBalanceCard(provider),
            const SizedBox(height: 20),
            _buildStatsDashboard(provider, isSent: false),
            const SizedBox(height: 20),
            _buildSummarySection(provider),
            const SizedBox(height: 20),
            _buildBalanceSettingsCard(provider),
            const SizedBox(height: 20),
            _buildVoiceSettingsCard(provider),
            const SizedBox(height: 20),
            _buildLastPaymentCard(provider, isSent: false),
            const SizedBox(height: 20),
            _buildHistorySection(provider, isSent: false),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildSendTab(PaymentProvider provider) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!provider.isBatteryOptimizationDisabled) ...[
              _buildBatteryOptimizationCard(provider),
              const SizedBox(height: 20),
            ],
            _buildServiceStatusCard(provider),
            const SizedBox(height: 20),
            _buildAccountFilter(provider),
            if (provider.availableAccounts.isNotEmpty) const SizedBox(height: 20),
            _buildBalanceCard(provider),
            const SizedBox(height: 20),
            _buildStatsDashboard(provider, isSent: true),
            const SizedBox(height: 20),
            _buildSummarySection(provider),
            const SizedBox(height: 20),
            _buildLastPaymentCard(provider, isSent: true),
            const SizedBox(height: 20),
            _buildHistorySection(provider, isSent: true),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // Requirement 7: Display live notification feed in app
  Widget _buildDiagnosticsTab(PaymentProvider provider) {
    final isServiceActive = provider.isListenerPermissionGranted && provider.isListening;
    final isChannelOk = provider.isMethodChannelWorking;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Diagnostics Overview Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: const Color(0xFF101424),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0x1FFFB300)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'SYSTEM INTEGRITY',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 18),
                  
                  // Service state
                  _buildDiagnosticRow(
                    label: 'NotificationListenerService Active', // Requirement 5
                    status: isServiceActive ? 'ACTIVE' : 'INACTIVE',
                    isOk: isServiceActive,
                  ),
                  const SizedBox(height: 12),

                  // MethodChannel state
                  _buildDiagnosticRow(
                    label: 'MethodChannel Communication', // Requirement 6
                    status: isChannelOk ? 'WORKING' : 'DISCONNECTED',
                    isOk: isChannelOk,
                  ),
                  const SizedBox(height: 12),

                  // Battery Optimization
                  _buildDiagnosticRow(
                    label: 'Battery Optimization Ignored',
                    status: provider.isBatteryOptimizationDisabled ? 'YES' : 'NO',
                    isOk: provider.isBatteryOptimizationDisabled,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 2. Debug TTS Controls Card (Requirement 8)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: const Color(0xFF161B30),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0x11FFFFFF)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'TTS AUDIO PIPELINE',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Speak parsed summaries for incoming/outgoing payment alerts only.',
                    style: TextStyle(color: Colors.white30, fontSize: 11),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.volume_up_rounded, size: 18),
                      label: const Text('Test TTS Pipeline', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFFFB300),
                        side: const BorderSide(color: Color(0x33FFB300)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => provider.testSpeak(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 3. Live Logger Section (Requirement 7)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'LIVE NOTIFICATION FEED',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                if (provider.rawFeed.isNotEmpty)
                  TextButton(
                    onPressed: () => provider.clearHistory(),
                    style: TextButton.styleFrom(foregroundColor: const Color(0xFFFF5252)),
                    child: const Text('Clear Logger'),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            if (provider.rawFeed.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                decoration: BoxDecoration(
                  color: const Color(0xFF0E1220),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0x08FFFFFF)),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.radar_rounded, color: Colors.white12, size: 44),
                    const SizedBox(height: 14),
                    const Text(
                      'Monitoring All Notifications Live...',
                      style: TextStyle(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Send a message or trigger any app alert (e.g. WhatsApp, SMS, Email) to view raw parsed parameters here instantly.',
                      style: TextStyle(color: Colors.white24, fontSize: 11, height: 1.4),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: provider.rawFeed.length,
                separatorBuilder: (context, index) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final raw = provider.rawFeed[index];
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0E1220),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0x0AFFFFFF)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                raw.appName, // Friendly resolved name
                                style: const TextStyle(color: Color(0xFFFFB300), fontWeight: FontWeight.w900, fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              _formatTime(raw.timestamp),
                              style: const TextStyle(color: Colors.white24, fontSize: 10),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          raw.packageName, // Package name (Requirement 3)
                          style: const TextStyle(color: Colors.white38, fontSize: 10, fontFamily: 'monospace'),
                        ),
                        const SizedBox(height: 10),
                        const Divider(color: Colors.white10, height: 1),
                        const SizedBox(height: 10),
                        RichText(
                          text: TextSpan(
                            style: const TextStyle(fontSize: 12, height: 1.4, fontFamily: 'Inter'),
                            children: [
                              const TextSpan(text: 'Title: ', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
                              TextSpan(text: '${raw.title}\n', style: const TextStyle(color: Colors.white70)), // Title (Requirement 3)
                              const TextSpan(text: 'Body : ', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
                              TextSpan(text: raw.body, style: const TextStyle(color: Colors.white70)), // Body (Requirement 3)
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildDiagnosticRow({required String label, required String status, required bool isOk}) {
    final statusColor = isOk ? const Color(0xFF4CAF50) : const Color(0xFFFF5252);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withAlpha(20),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: statusColor.withAlpha(60)),
          ),
          child: Text(
            status,
            style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
          ),
        ),
      ],
    );
  }

  Widget _buildBatteryOptimizationCard(PaymentProvider provider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2C1E16), Color(0xFF1C130E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFF9800).withAlpha(100), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF9800).withAlpha(15),
            blurRadius: 15,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9800).withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.battery_alert_rounded,
                  color: Color(0xFFFF9800),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Battery Optimization Warning',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Background alerts may get delayed',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'To guarantee real-time payment voice announcements instantly even when the screen is turned off or locked, please disable battery optimization for this application.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => provider.requestIgnoreBatteryOptimization(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF9800),
                foregroundColor: const Color(0xFF090D1A),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              icon: const Icon(Icons.flash_off_rounded, size: 18),
              label: const Text(
                'Disable Battery Optimization',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsDashboard(PaymentProvider provider, {required bool isSent}) {
    final title = isSent ? 'TODAY\'S SENT METRICS' : 'TODAY\'S RECEIVED METRICS';
    final amountToday = isSent ? provider.totalSentToday : provider.totalReceivedToday;
    final transactionsToday = isSent ? provider.totalSentTransactionsToday : provider.totalReceivedTransactionsToday;
    final highestPayment = isSent ? provider.highestSentPayment : provider.highestReceivedPayment;
    final primaryColor = isSent ? const Color(0xFFFF5252) : const Color(0xFF00FFC2);
    final secondaryColor = isSent ? const Color(0xFFFF8A80) : const Color(0xFF00E5FF);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isSent 
                        ? [const Color(0xFF2C161A), const Color(0xFF1C0F11)]
                        : [const Color(0xFF16252C), const Color(0xFF0F181C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: primaryColor.withAlpha(30), width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.currency_rupee_rounded, color: primaryColor, size: 20),
                    const SizedBox(height: 10),
                    Text(
                      isSent ? 'Sent Today' : 'Received Today',
                      style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₹${amountToday.toStringAsFixed(0)}',
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isSent
                        ? [const Color(0xFF251A2E), const Color(0xFF191021)]
                        : [const Color(0xFF1A1A2E), const Color(0xFF131326)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: secondaryColor.withAlpha(20), width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.sync_alt_rounded, color: secondaryColor, size: 20),
                    const SizedBox(height: 10),
                    const Text(
                      'Transactions',
                      style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$transactionsToday',
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isSent
                  ? [const Color(0xFF201625), const Color(0xFF160F1A)]
                  : [const Color(0xFF16252C), const Color(0xFF0F181C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: primaryColor.withAlpha(30), width: 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.military_tech_rounded, color: primaryColor, size: 24),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isSent ? 'Highest Outgoing Payment' : 'Highest Received Payment',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Peak transaction milestone',
                        style: TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
              Text(
                '₹${highestPayment.toStringAsFixed(0)}',
                style: TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildServiceStatusCard(PaymentProvider provider) {
    final isActive = provider.isListening;
    final isPermissionOk = provider.isListenerPermissionGranted;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isActive
              ? [const Color(0xFF162A30), const Color(0xFF0E1F21)]
              : [const Color(0xFF1A1A2E), const Color(0xFF131326)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isActive ? const Color(0x3300FFC2) : const Color(0x22FFFFFF),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isActive ? const Color(0x1500FFC2) : const Color(0x0A000000),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'LISTENER SERVICE STATUS',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (isActive)
                        AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _pulseAnimation.value,
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF00FFC2),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Color(0xFF00FFC2),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    )
                                  ],
                                ),
                              ),
                            );
                          },
                        )
                      else
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Colors.white24,
                            shape: BoxShape.circle,
                          ),
                        ),
                      const SizedBox(width: 8),
                      Text(
                        isActive ? 'ACTIVE' : 'PAUSED',
                        style: TextStyle(
                          color: isActive ? const Color(0xFF00FFC2) : Colors.white60,
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isPermissionOk ? const Color(0x1A4CAF50) : const Color(0x1AFF5252),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isPermissionOk ? const Color(0x334CAF50) : const Color(0x33FF5252),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPermissionOk ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded,
                      color: isPermissionOk ? const Color(0xFF4CAF50) : const Color(0xFFFF5252),
                      size: 13,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isPermissionOk ? 'Listener Active' : 'Permission Required',
                      style: TextStyle(
                        color: isPermissionOk ? const Color(0xFF4CAF50) : const Color(0xFFFF5252),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isActive
                      ? null
                      : () {
                          if (!isPermissionOk) {
                            _showPermissionRequiredDialog();
                          } else {
                            provider.toggleListening(true);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00FFC2),
                    foregroundColor: const Color(0xFF090D1A),
                    disabledBackgroundColor: const Color(0xFF1E2830),
                    disabledForegroundColor: Colors.white24,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: isActive ? 0 : 4,
                    shadowColor: const Color(0x8000FFC2),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded, size: 22),
                  label: const Text(
                    'Start Listening',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: !isActive ? null : () => provider.toggleListening(false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFF5252),
                    side: BorderSide(
                      color: isActive ? const Color(0x66FF5252) : const Color(0x11FFFFFF),
                      width: 1.5,
                    ),
                    disabledForegroundColor: Colors.white24,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.stop_rounded, size: 22),
                  label: const Text(
                    'Stop Listening',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceSettingsCard(PaymentProvider provider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF161B30),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x11FFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Color(0x1A00FFC2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.settings_voice_rounded,
                      color: Color(0xFF00FFC2),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'VOICE CUSTOMIZATIONS',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              Switch.adaptive(
                value: provider.isVoiceAlertEnabled,
                onChanged: (val) => provider.toggleVoiceAlert(val),
                activeColor: const Color(0xFF00FFC2),
              ),
            ],
          ),
          const Divider(color: Colors.white10, height: 28),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Wake Word ("Hey UPI")',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Speak last transaction on command',
                    style: TextStyle(color: Colors.white30, fontSize: 11),
                  ),
                ],
              ),
              Switch.adaptive(
                value: provider.isWakeWordEnabled,
                onChanged: (val) => provider.toggleWakeWord(val),
                activeColor: const Color(0xFF00FFC2),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 16),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Voice Language',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Pronunciation dialect',
                    style: TextStyle(color: Colors.white30, fontSize: 11),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0E1220),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0x22FFFFFF)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: provider.language,
                    dropdownColor: const Color(0xFF0E1220),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF00FFC2)),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                    items: provider.supportedLanguages.entries.map((entry) {
                      return DropdownMenuItem<String>(
                        value: entry.key,
                        child: Text(entry.value),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        provider.setLanguage(val);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Speech Speed',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  Row(
                    children: [
                      Text(
                        '${provider.speechRate.toStringAsFixed(1)}x',
                        style: const TextStyle(color: Color(0xFF00FFC2), fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () => provider.testSpeak(isSent: _currentIndex == 1),
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: const Color(0x2200FFC2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.volume_up_rounded, color: Color(0xFF00FFC2), size: 16),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              SliderTheme(
                data: SliderThemeData(
                  trackHeight: 4,
                  activeTrackColor: const Color(0xFF00FFC2),
                  inactiveTrackColor: Colors.white12,
                  thumbColor: const Color(0xFF00FFC2),
                  overlayColor: const Color(0x2900FFC2),
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                ),
                child: Slider(
                  value: provider.speechRate,
                  min: 0.2,
                  max: 1.0,
                  divisions: 8,
                  onChanged: (val) => provider.setSpeechRate(val),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 20),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Night Mode (Quiet Hours)',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'TTS will be disabled during this time',
                    style: TextStyle(color: Colors.white30, fontSize: 11),
                  ),
                ],
              ),
              if (provider.isNightModeActive)
                const Icon(Icons.mode_night_rounded, color: Color(0xFF00FFC2), size: 20),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Start Hour (24H)', style: TextStyle(color: Colors.white54, fontSize: 12)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0E1220),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0x22FFFFFF)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: provider.nightModeStartHour,
                          dropdownColor: const Color(0xFF0E1220),
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF00FFC2)),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                          isExpanded: true,
                          items: List.generate(24, (index) => index).map((hour) {
                            return DropdownMenuItem<int>(
                              value: hour,
                              child: Text(hour.toString().padLeft(2, '0') + ':00'),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) provider.setNightModeStartHour(val);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('End Hour (24H)', style: TextStyle(color: Colors.white54, fontSize: 12)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0E1220),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0x22FFFFFF)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: provider.nightModeEndHour,
                          dropdownColor: const Color(0xFF0E1220),
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF00FFC2)),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                          isExpanded: true,
                          items: List.generate(24, (index) => index).map((hour) {
                            return DropdownMenuItem<int>(
                              value: hour,
                              child: Text(hour.toString().padLeft(2, '0') + ':00'),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) provider.setNightModeEndHour(val);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 20),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'TTS Status',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _getTtsStatusColor(provider.ttsStatus).withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  provider.ttsStatus.name.toUpperCase(),
                  style: TextStyle(
                    color: _getTtsStatusColor(provider.ttsStatus),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => provider.testVoice(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0E1220),
                foregroundColor: const Color(0xFF00FFC2),
                side: const BorderSide(color: Color(0x3300FFC2)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.record_voice_over_rounded, size: 18),
              label: const Text(
                'Test Voice',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          InkWell(
            onTap: () => _showPermissionDetailsSheet(),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF0E1220),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0x0AFFFFFF)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        provider.isListenerPermissionGranted && provider.isNotificationPermissionGranted
                            ? Icons.security_rounded
                            : Icons.security_update_warning_rounded,
                        color: provider.isListenerPermissionGranted && provider.isNotificationPermissionGranted
                            ? const Color(0xFF4CAF50)
                            : const Color(0xFFFFB300),
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Security & Permissions Config',
                        style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white30, size: 14),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountFilter(PaymentProvider provider) {
    if (provider.availableAccounts.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF161B30),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x22FFFFFF)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: provider.selectedAccount,
          hint: const Text('All Accounts', style: TextStyle(color: Colors.white70)),
          dropdownColor: const Color(0xFF161B30),
          icon: const Icon(Icons.account_balance_rounded, color: Color(0xFF00FFC2), size: 18),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
          isExpanded: true,
          items: [
            const DropdownMenuItem<String>(
              value: null,
              child: Text('All Accounts'),
            ),
            ...provider.availableAccounts.map((account) {
              return DropdownMenuItem<String>(
                value: account,
                child: Text('Account: ****$account'),
              );
            }).toList(),
          ],
          onChanged: (val) {
            provider.setSelectedAccount(val);
          },
        ),
      ),
    );
  }

  Widget _buildBalanceCard(PaymentProvider provider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D1C2E), Color(0xFF102E4E), Color(0xFF144272)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF00FFC2).withAlpha(60), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00FFC2).withAlpha(15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF00FFC2), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'CURRENT WALLET BALANCE',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Hive Sync',
                  style: TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '₹${provider.balance.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Automatically updated on incoming/outgoing alerts',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceSettingsCard(PaymentProvider provider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF161B30),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x11FFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Color(0x1AFFB300),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.edit_road_rounded,
                  color: Color(0xFFFFB300),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'BALANCE CONFIGURATION',
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white10, height: 28),
          const Text(
            'Manual Wallet Balance',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 4),
          const Text(
            'Set your initial balance. Incoming payments will be added, and outgoing payments will be subtracted.',
            style: TextStyle(color: Colors.white30, fontSize: 11),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _balanceController,
                  focusNode: _balanceFocusNode,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    prefixText: '₹ ',
                    prefixStyle: const TextStyle(color: Color(0xFF00FFC2), fontWeight: FontWeight.bold),
                    hintText: '0.00',
                    hintStyle: const TextStyle(color: Colors.white24),
                    filled: true,
                    fillColor: const Color(0xFF0E1220),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.white10),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF00FFC2)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () {
                  final val = double.tryParse(_balanceController.text);
                  if (val != null) {
                    provider.updateBalance(val);
                    _balanceFocusNode.unfocus();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Balance updated successfully!'),
                        backgroundColor: Color(0xFF00FFC2),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00FFC2),
                  foregroundColor: const Color(0xFF090D1A),
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Update', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLastPaymentCard(PaymentProvider provider, {required bool isSent}) {
    final payment = isSent ? provider.lastSentPayment : provider.lastReceivedPayment;
    final primaryColor = isSent ? const Color(0xFFFF5252) : const Color(0xFF00FFC2);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF101424),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: payment != null ? primaryColor.withAlpha(120) : const Color(0x11FFFFFF),
          width: payment != null ? 1.5 : 1.0,
        ),
        boxShadow: payment != null
            ? [
                BoxShadow(
                  color: primaryColor.withAlpha(15),
                  blurRadius: 15,
                  spreadRadius: 2,
                )
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isSent ? 'LIVE DETECTED OUTBOUND PAYMENT' : 'LIVE DETECTED INCOMING PAYMENT',
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              if (payment != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: primaryColor.withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    payment.appName,
                    style: TextStyle(
                      color: primaryColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (payment == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Text(
                isSent 
                    ? 'Waiting for outgoing UPI payments...'
                    : 'Waiting for incoming UPI payments...',
                style: const TextStyle(
                  color: Colors.white30,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '₹${payment.amount.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: primaryColor,
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        shadows: [
                          Shadow(
                            color: primaryColor.withAlpha(60),
                            blurRadius: 15,
                          )
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      isSent ? 'Successfully Sent' : 'Successfully Received',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.person_outline_rounded, color: Colors.white38, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            payment.sender,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (payment.accountNumber != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              'A/c: ****${payment.accountNumber}',
                              style: const TextStyle(color: Color(0xFF00FFC2), fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.access_time_rounded, color: Colors.white38, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      '${_formatDate(payment.timestamp)} at ${_formatTime(payment.timestamp)}',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white38, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            payment.title,
                            style: const TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            payment.body,
                            style: const TextStyle(color: Colors.white30, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }



  Widget _buildHistorySection(PaymentProvider provider, {required bool isSent}) {
    final history = isSent ? provider.sentHistory : provider.receivedHistory;
    final primaryColor = isSent ? const Color(0xFFFF5252) : const Color(0xFF00FFC2);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  isSent ? 'RECENT SENT PAYMENTS' : 'RECENT RECEIVED PAYMENTS',
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                if (history.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: primaryColor.withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${history.length}',
                      style: TextStyle(
                        color: primaryColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ]
              ],
            ),
            if (history.isNotEmpty)
              Flexible(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Flexible(
                      child: TextButton.icon(
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final path = await provider.exportHistoryToCsv();
                          if (path != null) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: const Text('Exported to Downloads/upi_history.csv'),
                                backgroundColor: const Color(0xFF00FFC2),
                                action: SnackBarAction(
                                  label: 'OK',
                                  textColor: const Color(0xFF090D1A),
                                  onPressed: () {},
                                ),
                              ),
                            );
                          } else {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Failed to export history.'),
                                backgroundColor: Color(0xFFFF5252),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.download_rounded, size: 16),
                        label: const FittedBox(child: Text('Export')),
                        style: TextButton.styleFrom(
                          foregroundColor: primaryColor,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                    ),
                    Flexible(
                      child: TextButton(
                        onPressed: () => _showClearHistoryConfirmationDialog(context, provider),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFFF5252),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: const FittedBox(child: Text('Clear History')),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (history.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 36),
            decoration: BoxDecoration(
              color: const Color(0xFF0E1220),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0x08FFFFFF)),
            ),
            child: const Column(
              children: [
                Icon(Icons.history_rounded, color: Colors.white12, size: 36),
                SizedBox(height: 12),
                Text(
                  'No transactions recorded yet',
                  style: TextStyle(color: Colors.white24, fontSize: 13),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: history.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final payment = history[index];
              return Material(
                color: const Color(0xFF0E1220),
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  onTap: () {
                    provider.speakPaymentAmount(payment.amount, isSent);
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0x0AFFFFFF)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            _getAppIcon(payment.packageName, isSent),
                            const SizedBox(width: 14),
                            Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                payment.sender,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (payment.accountNumber != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'A/c: ****${payment.accountNumber}',
                                  style: const TextStyle(color: Color(0xFF00FFC2), fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ],
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    payment.appName,
                                    style: const TextStyle(color: Colors.white30, fontSize: 11),
                                  ),
                                  const SizedBox(width: 6),
                                  const Text('•', style: TextStyle(color: Colors.white12, fontSize: 11)),
                                  const SizedBox(width: 6),
                                  Text(
                                    _formatTime(payment.timestamp),
                                    style: const TextStyle(color: Colors.white30, fontSize: 11),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              isSent 
                                  ? '-₹${payment.amount.toStringAsFixed(0)}'
                                  : '+₹${payment.amount.toStringAsFixed(0)}',
                              style: TextStyle(
                                color: primaryColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatDate(payment.timestamp),
                              style: const TextStyle(
                                color: Colors.white24,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (_showRawDebugInfo) ...[
                      const SizedBox(height: 10),
                      const Divider(color: Colors.white10, height: 1),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF090D1A),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.bug_report_rounded, color: Colors.orangeAccent, size: 12),
                                const SizedBox(width: 6),
                                Text(
                                  'DEBUG: RAW CAPTURE (${payment.appName})',
                                  style: const TextStyle(
                                    color: Colors.orangeAccent,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            RichText(
                              text: TextSpan(
                                style: const TextStyle(fontFamily: 'monospace', fontSize: 10, height: 1.4),
                                children: [
                                  const TextSpan(text: 'Title: ', style: TextStyle(color: Colors.white38, fontWeight: FontWeight.bold)),
                                  TextSpan(text: '${payment.title}\n', style: const TextStyle(color: Colors.white70)),
                                  const TextSpan(text: 'Body : ', style: TextStyle(color: Colors.white38, fontWeight: FontWeight.bold)),
                                  TextSpan(text: payment.body, style: const TextStyle(color: Colors.white70)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              )));
            },
          ),
      ],
    );
  }

  Widget _buildSummarySection(PaymentProvider provider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF14192F),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x1F00FFC2)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A00FFC2),
            blurRadius: 15,
            spreadRadius: 2,
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.pie_chart_rounded, color: Color(0xFF00FFC2), size: 18),
              SizedBox(width: 10),
              Text(
                'TRANSACTION SUMMARY',
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white10, height: 28),
          
          _buildSummaryRow(
            title: 'Today',
            received: provider.totalReceivedToday,
            sent: provider.totalSentToday,
          ),
          const SizedBox(height: 16),
          _buildSummaryRow(
            title: 'This Week',
            received: provider.totalReceivedThisWeek,
            sent: provider.totalSentThisWeek,
          ),
          const SizedBox(height: 16),
          _buildSummaryRow(
            title: 'This Month',
            received: provider.totalReceivedThisMonth,
            sent: provider.totalSentThisMonth,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow({required String title, required double received, required double sent}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
        ),
        RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'sans-serif'),
            children: [
              const TextSpan(text: 'Received ', style: TextStyle(color: Colors.white54)),
              TextSpan(text: '₹${received.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF00FFC2), fontWeight: FontWeight.bold)),
              const TextSpan(text: '  |  ', style: TextStyle(color: Colors.white24)),
              const TextSpan(text: 'Sent ', style: TextStyle(color: Colors.white54)),
              TextSpan(text: '₹${sent.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFFFF5252), fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
    );
  }

  void _showClearHistoryConfirmationDialog(BuildContext context, PaymentProvider provider) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF14192D),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0x1FFF5252)),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFFF5252)),
              SizedBox(width: 10),
              Text(
                'Clear History',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: const Text(
            'Are you sure you want to delete all payment history? This cannot be undone.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5252),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Clear', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.of(context).pop();
                provider.clearHistory();
              },
            ),
          ],
        );
      },
    );
  }

  void _showPermissionRequiredDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final provider = context.read<PaymentProvider>();
        return AlertDialog(
          backgroundColor: const Color(0xFF14192D),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0x1F00FFC2)),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFFFB300)),
              SizedBox(width: 10),
              Text(
                'Permission Needed',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: const Text(
            'To detect payments from Google Pay, PhonePe, Paytm, or BHIM, this app requires special Notification Access. Click grant below to configure this in settings.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00FFC2),
                foregroundColor: const Color(0xFF090D1A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Grant Access', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.of(context).pop();
                provider.requestListenerPermission();
              },
            ),
          ],
        );
      },
    );
  }

  void _showPermissionDetailsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF121629),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Consumer<PaymentProvider>(
          builder: (context, provider, child) {
            final isNotificationOk = provider.isNotificationPermissionGranted;
            final isListenerOk = provider.isListenerPermissionGranted;

            return Padding(
              padding: const EdgeInsets.all(28.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Permissions Panel',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Ensure both configurations are green to enable real-time payment notifications parsing.',
                    style: TextStyle(color: Colors.white38, fontSize: 13),
                  ),
                  const SizedBox(height: 24),

                  Row(
                    children: [
                      Icon(
                        isNotificationOk ? Icons.check_circle_rounded : Icons.cancel_rounded,
                        color: isNotificationOk ? const Color(0xFF4CAF50) : const Color(0xFFFF5252),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Show App Notifications',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isNotificationOk
                                  ? 'Granted'
                                  : 'Required for showing foreground alerts',
                              style: const TextStyle(color: Colors.white38, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      if (!isNotificationOk)
                        ElevatedButton(
                          onPressed: () => provider.requestNotificationPermission(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0x2200FFC2),
                            foregroundColor: const Color(0xFF00FFC2),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('Grant', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Icon(
                        isListenerOk ? Icons.check_circle_rounded : Icons.cancel_rounded,
                        color: isListenerOk ? const Color(0xFF4CAF50) : const Color(0xFFFF5252),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Notification Listener Access',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isListenerOk
                                  ? 'Granted'
                                  : 'Allows reading GPay/PhonePe alerts',
                              style: const TextStyle(color: Colors.white38, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      if (!isListenerOk)
                        ElevatedButton(
                          onPressed: () => provider.requestListenerPermission(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0x2200FFC2),
                            foregroundColor: const Color(0xFF00FFC2),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('Grant', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Icon(
                        provider.isBatteryOptimizationDisabled ? Icons.check_circle_rounded : Icons.cancel_rounded,
                        color: provider.isBatteryOptimizationDisabled ? const Color(0xFF4CAF50) : const Color(0xFFFF5252),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Ignore Battery Optimization',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              provider.isBatteryOptimizationDisabled
                                  ? 'Ignored (Safe background performance)'
                                  : 'Ensures real-time background processing',
                              style: const TextStyle(color: Colors.white38, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      if (!provider.isBatteryOptimizationDisabled)
                        ElevatedButton(
                          onPressed: () => provider.requestIgnoreBatteryOptimization(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0x2200FFC2),
                            foregroundColor: const Color(0xFF00FFC2),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('Grant', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Color(0x1FFFFFFF)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Close Panel', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
