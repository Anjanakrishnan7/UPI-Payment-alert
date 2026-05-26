import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/payment_provider.dart';
import 'send_payment_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
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
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-check permissions when user resumes the app from settings
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

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return "Today";
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (dt.year == yesterday.year && dt.month == yesterday.month && dt.day == yesterday.day) {
      return "Yesterday";
    }
    return "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}";
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
                color: const Color(0x1F00FFC2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _currentIndex == 0 ? Icons.wallet_giftcard_rounded : Icons.send_rounded,
                color: const Color(0xFF00FFC2),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              _currentIndex == 0 ? 'UPI Payment Alert' : 'Send Payment',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        actions: [
          if (_currentIndex == 0)
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
              onPressed: () => provider.checkPermissions(),
              tooltip: 'Refresh Status',
            ),
        ],
      ),
      body: _currentIndex == 0 ? _buildVoiceAlertsTab(provider) : const SendPaymentTab(),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: const Color(0xFF0E1220),
          indicatorColor: const Color(0xFF00FFC2).withAlpha(30),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(color: Color(0xFF00FFC2), fontSize: 12, fontWeight: FontWeight.bold);
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
              icon: Icon(Icons.record_voice_over_outlined, color: Colors.white38),
              selectedIcon: Icon(Icons.record_voice_over_rounded, color: Color(0xFF00FFC2)),
              label: 'Voice Alerts',
            ),
            NavigationDestination(
              icon: Icon(Icons.send_outlined, color: Colors.white38),
              selectedIcon: Icon(Icons.send_rounded, color: Color(0xFF00FFC2)),
              label: 'Send UPI',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceAlertsTab(PaymentProvider provider) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Core Listening Service Card
            _buildServiceStatusCard(provider),
            const SizedBox(height: 24),

            // 2. Permission and Voice Alerts Settings
            _buildSettingsRow(provider),
            const SizedBox(height: 24),

            // 3. Last Payment Box
            _buildLastPaymentCard(provider),
            const SizedBox(height: 24),

            // 4. Quick Testing Simulator
            _buildSimulatorCard(provider),
            const SizedBox(height: 24),

            // 5. Payment Log History
            _buildHistorySection(provider),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceStatusCard(PaymentProvider provider) {
    final isActive = provider.isListening;
    final isPermissionOk = provider.isListenerPermissionGranted;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
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
                    'LISTENER STATUS',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 12,
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isPermissionOk ? 'Service Ready' : 'Permission Required',
                      style: TextStyle(
                        color: isPermissionOk ? const Color(0xFF4CAF50) : const Color(0xFFFF5252),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
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
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: isActive ? 0 : 4,
                    shadowColor: const Color(0x8000FFC2),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded, size: 22),
                  label: const Text(
                    'Start Listening',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(width: 16),
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
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.stop_rounded, size: 22),
                  label: const Text(
                    'Stop Listening',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsRow(PaymentProvider provider) {
    return Row(
      children: [
        // Voice Toggle Card
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF161B30),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0x11FFFFFF)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0x1A00E5FF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.record_voice_over_rounded,
                        color: Color(0xFF00E5FF),
                        size: 20,
                      ),
                    ),
                    Switch.adaptive(
                      value: provider.isVoiceAlertEnabled,
                      onChanged: (val) => provider.toggleVoiceAlert(val),
                      activeColor: const Color(0xFF00E5FF),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  'Voice Alert',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  provider.isVoiceAlertEnabled ? 'Enabled (TTS)' : 'Silent Mode',
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Permissions Card
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF161B30),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0x11FFFFFF)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: provider.isListenerPermissionGranted && provider.isNotificationPermissionGranted
                            ? const Color(0x1A4CAF50)
                            : const Color(0x1AFFB300),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        provider.isListenerPermissionGranted && provider.isNotificationPermissionGranted
                            ? Icons.security_rounded
                            : Icons.security_update_warning_rounded,
                        color: provider.isListenerPermissionGranted && provider.isNotificationPermissionGranted
                            ? const Color(0xFF4CAF50)
                            : const Color(0xFFFFB300),
                        size: 20,
                      ),
                    ),
                    TextButton(
                      onPressed: () => _showPermissionDetailsSheet(),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(40, 30),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Details',
                        style: TextStyle(color: Color(0xFF00FFC2), fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  'Permissions',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  provider.isListenerPermissionGranted && provider.isNotificationPermissionGranted
                      ? 'All Settings Active'
                      : 'Setup Required',
                  style: TextStyle(
                    color: provider.isListenerPermissionGranted && provider.isNotificationPermissionGranted
                        ? Colors.white38
                        : const Color(0xFFFFB300),
                    fontSize: 12,
                    fontWeight: provider.isListenerPermissionGranted && provider.isNotificationPermissionGranted
                        ? FontWeight.normal
                        : FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLastPaymentCard(PaymentProvider provider) {
    final payment = provider.lastPayment;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF101424),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: payment != null ? const Color(0x2200FFC2) : const Color(0x11FFFFFF),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'LAST DETECTED PAYMENT',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              if (payment != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0x1F00FFC2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    payment.appName,
                    style: const TextStyle(
                      color: Color(0xFF00FFC2),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (payment == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12.0),
              child: Text(
                'Waiting for incoming UPI payments...\nUse the test simulator below to check instant TTS audio.',
                style: TextStyle(
                  color: Colors.white30,
                  fontSize: 14,
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
                      style: const TextStyle(
                        color: Color(0xFF00FFC2),
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        shadows: [
                          Shadow(
                            color: Color(0x4000FFC2),
                            blurRadius: 15,
                          )
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Received',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.person_outline_rounded, color: Colors.white38, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        payment.sender,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.access_time_rounded, color: Colors.white38, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      '${_formatDate(payment.timestamp)} at ${_formatTime(payment.timestamp)}',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 13,
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

  Widget _buildSimulatorCard(PaymentProvider provider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF121829),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x1F00E5FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Color(0x1A00E5FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.terminal_rounded,
                  color: Color(0xFF00E5FF),
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'TEST SIMULATOR (MOCK ALERTS)',
                style: TextStyle(
                  color: Color(0xFF00E5FF),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Simulate payment notifications to test text-to-speech audio alerts directly in the app. Make sure "Listener Status" is ACTIVE to process simulated alerts.',
            style: TextStyle(
              color: Colors.white30,
              fontSize: 12,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildSimulatorBtn(
                  context: context,
                  provider: provider,
                  amount: 50.0,
                  sender: 'Rohit Sharma',
                  appName: 'PhonePe',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSimulatorBtn(
                  context: context,
                  provider: provider,
                  amount: 250.0,
                  sender: 'Aarav Mehta',
                  appName: 'Google Pay',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSimulatorBtn(
                  context: context,
                  provider: provider,
                  amount: 1200.0,
                  sender: 'Priya Patel',
                  appName: 'Paytm',
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildSimulatorBtn({
    required BuildContext context,
    required PaymentProvider provider,
    required double amount,
    required String sender,
    required String appName,
  }) {
    final active = provider.isListening;
    return ElevatedButton(
      onPressed: () {
        if (!active) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cannot simulate. Please Start Listening first!'),
              backgroundColor: Color(0xFFFF5252),
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          provider.mockPaymentReceived(
            amount: amount,
            sender: sender,
            appName: appName,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Simulated ₹${amount.toInt()} from $sender'),
              backgroundColor: const Color(0xFF00FFC2),
              duration: const Duration(seconds: 1),
            ),
          );
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0x11FFFFFF),
        foregroundColor: Colors.white70,
        surfaceTintColor: Colors.transparent,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0x15FFFFFF)),
        ),
        elevation: 0,
      ),
      child: Text(
        '₹${amount.toInt()}',
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
    );
  }

  Widget _buildHistorySection(PaymentProvider provider) {
    final history = provider.paymentHistory;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Text(
                  'RECENT TRANSACTIONS',
                  style: TextStyle(
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
                      color: const Color(0x1F00FFC2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${history.length}',
                      style: const TextStyle(
                        color: Color(0xFF00FFC2),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ]
              ],
            ),
            if (history.isNotEmpty)
              TextButton(
                onPressed: () => provider.clearHistory(),
                style: TextButton.styleFrom(foregroundColor: const Color(0xFFFF5252)),
                child: const Text('Clear All'),
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
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final payment = history[index];
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0E1220),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0x0AFFFFFF)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: Color(0x0D00FFC2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.call_received_rounded,
                        color: Color(0xFF00FFC2),
                        size: 18,
                      ),
                    ),
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
                          '+₹${payment.amount.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: Color(0xFF00FFC2),
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
              );
            },
          ),
      ],
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
            'To detect incoming payments from your payment applications, this app requires special Notification Access. Click grant below to configure this in settings.',
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
                  
                  // 1. Notification Permission
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
                              isNotificationOk ? 'Granted' : 'Required for showing foreground alerts',
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
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Grant', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 2. Notification Listener Permission
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
                              isListenerOk ? 'Granted' : 'Allows reading GPay/PhonePe alerts',
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
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
