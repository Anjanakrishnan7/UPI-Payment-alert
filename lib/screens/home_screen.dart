import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/payment_provider.dart';
import '../models/payment_record.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  int _currentIndex = 0; // 0 for Receive, 1 for Send
  String _currentSection = 'home'; // 'home', 'profile', 'report', 'settings', 'diagnostics'
  late TextEditingController _balanceController;
  late FocusNode _balanceFocusNode;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _balanceController = TextEditingController();
    _balanceFocusNode = FocusNode();

    // Pulse animation for listening state indicator
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

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

  Widget _getAppIcon(String packageName, bool isSent) {
    IconData iconData = isSent ? Icons.unfold_less_rounded : Icons.unfold_more_rounded;
    Color brandColor = isSent ? const Color(0xFFFF5252) : const Color(0xFF00FFC2);

    final pkg = packageName.toLowerCase();
    if (pkg.contains("paisa.user")) {
      iconData = Icons.g_mobiledata_rounded;
      brandColor = const Color(0xFF4285F4);
    } else if (pkg.contains("phonepe")) {
      iconData = Icons.flash_on_rounded;
      brandColor = const Color(0xFF5F259F);
    } else if (pkg.contains("paytm")) {
      iconData = Icons.account_balance_wallet_rounded;
      brandColor = const Color(0xFF00B9F5);
    } else if (pkg.contains("upiapp")) {
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

  Future<void> _sendEmailReport(PaymentProvider provider, String period) async {
    final now = DateTime.now();
    final String subject = "UPI Payment Alert Report - $period";
    
    double totalRec = 0;
    double totalSent = 0;
    int countRec = 0;
    int countSent = 0;
    
    final filtered = provider.paymentHistory.where((p) {
      if (period == 'Daily') {
        return p.timestamp.year == now.year && p.timestamp.month == now.month && p.timestamp.day == now.day;
      } else if (period == 'Weekly') {
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        return p.timestamp.isAfter(startOfWeek);
      } else {
        return p.timestamp.year == now.year && p.timestamp.month == now.month;
      }
    }).toList();

    for (final p in filtered) {
      if (p.isSent) {
        totalSent += p.amount;
        countSent++;
      } else {
        totalRec += p.amount;
        countRec++;
      }
    }

    String bodyText = "Hello,\n\nHere is your UPI Payment Alert report ($period):\n\n"
        "Summary:\n"
        "- Total Received: INR ${totalRec.toStringAsFixed(2)} ($countRec transactions)\n"
        "- Total Sent: INR ${totalSent.toStringAsFixed(2)} ($countSent transactions)\n\n"
        "Recent Transactions:\n";
        
    for (int i = 0; i < min(10, filtered.length); i++) {
      final p = filtered[i];
      final type = p.isSent ? "Sent to" : "Received from";
      bodyText += "- ${p.timestamp.toIso8601String().substring(0, 16)}: $type ${p.sender} - INR ${p.amount.toStringAsFixed(2)} via ${p.appName}\n";
    }
    
    bodyText += "\nGenerated by UPI Payment Alert app.";
    final Uri mailtoUri = Uri(
      scheme: 'mailto',
      path: '',
      queryParameters: {
        'subject': subject,
        'body': bodyText,
      },
    );

    if (await canLaunchUrl(mailtoUri)) {
      await launchUrl(mailtoUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open email application.')),
        );
      }
    }
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

    // Dynamic color setup
    Color indicatorColor = const Color(0xFF00FFC2);
    if (_currentIndex == 1) {
      indicatorColor = const Color(0xFFFF5252);
    }

    // Build the body based on drawer section
    Widget bodyContent;
    String appBarTitle = 'UPI Payment Alert';

    if (_currentSection == 'home') {
      appBarTitle = _currentIndex == 0 ? 'Receive Payments' : 'Send Payments';
      bodyContent = _currentIndex == 0 ? _buildReceiveTab(provider) : _buildSendTab(provider);
    } else if (_currentSection == 'profile') {
      appBarTitle = 'User Profile';
      bodyContent = _buildProfileSection(provider);
    } else if (_currentSection == 'report') {
      appBarTitle = 'Payment Reports';
      bodyContent = _buildReportSection(provider);
    } else if (_currentSection == 'settings') {
      appBarTitle = 'Customization Settings';
      bodyContent = _buildSettingsSection(provider);
    } else {
      appBarTitle = 'Diagnostics Dashboard';
      bodyContent = _buildDiagnosticsSection(provider);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF090D1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Builder(
          builder: (context) {
            // Fix: All secondary screens' back arrows now open the side drawer instead of popping to Home
            if (_currentSection != 'home') {
              return IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () {
                  Scaffold.of(context).openDrawer();
                },
              );
            }
            return IconButton(
              icon: const Icon(Icons.menu_rounded, color: Colors.white),
              onPressed: () => Scaffold.of(context).openDrawer(),
            );
          },
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: indicatorColor.withAlpha(30),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _currentSection != 'home'
                    ? (_currentSection == 'profile'
                        ? Icons.person_rounded
                        : _currentSection == 'report'
                            ? Icons.bar_chart_rounded
                            : _currentSection == 'settings'
                                ? Icons.settings_rounded
                                : Icons.bug_report_rounded)
                    : (_currentIndex == 0 ? Icons.call_received_rounded : Icons.call_made_rounded),
                color: indicatorColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                appBarTitle,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (provider.isNightModeActive) ...[
              const Icon(Icons.mode_night_rounded, color: Color(0xFF00FFC2), size: 20),
              const SizedBox(width: 8),
            ],
          ],
        ),
      ),
      drawer: _buildDrawer(provider),
      body: bodyContent,
      bottomNavigationBar: _currentSection == 'home'
          ? NavigationBarTheme(
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
                ],
              ),
            )
          : null,
    );
  }

  Widget _buildDrawer(PaymentProvider provider) {
    return Drawer(
      backgroundColor: const Color(0xFF101424),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Drawer Header
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFF00FFC2).withAlpha(25),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF00FFC2).withAlpha(80), width: 2),
                    ),
                    child: const Icon(
                      Icons.offline_bolt_rounded,
                      color: Color(0xFF00FFC2),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'UPI Voice Alert',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'v1.0.0 Pro',
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white10),
            
            // Drawer Navigation items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                children: [
                  _buildDrawerItem(
                    icon: Icons.home_rounded,
                    label: 'Dashboard Home',
                    selected: _currentSection == 'home',
                    onTap: () {
                      setState(() {
                        _currentSection = 'home';
                      });
                      Navigator.pop(context);
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.person_rounded,
                    label: 'User Profile',
                    selected: _currentSection == 'profile',
                    onTap: () {
                      setState(() {
                        _currentSection = 'profile';
                      });
                      Navigator.pop(context);
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.bar_chart_rounded,
                    label: 'Payment Reports',
                    selected: _currentSection == 'report',
                    onTap: () {
                      setState(() {
                        _currentSection = 'report';
                      });
                      Navigator.pop(context);
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.settings_rounded,
                    label: 'Voice Customization',
                    selected: _currentSection == 'settings',
                    onTap: () {
                      setState(() {
                        _currentSection = 'settings';
                      });
                      Navigator.pop(context);
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.bug_report_rounded,
                    label: 'System Diagnostics',
                    selected: _currentSection == 'diagnostics',
                    onTap: () {
                      setState(() {
                        _currentSection = 'diagnostics';
                      });
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
            
            // Drawer Footer
            const Padding(
              padding: EdgeInsets.all(24.0),
              child: Text(
                'Secured Local Assistant',
                style: TextStyle(color: Colors.white24, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final activeColor = const Color(0xFF00FFC2);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Icon(icon, color: selected ? activeColor : Colors.white60),
        title: Text(
          label,
          style: TextStyle(
            color: selected ? activeColor : Colors.white,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
          ),
        ),
        tileColor: selected ? activeColor.withAlpha(20) : Colors.transparent,
        onTap: onTap,
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
            _buildBalanceSettingsCard(provider),
            const SizedBox(height: 20),
            _buildStatsDashboard(provider, isSent: false),
            const SizedBox(height: 20),
            _buildSummarySection(provider),
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

  // 1. User Profile Section
  Widget _buildProfileSection(PaymentProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00FFC2).withAlpha(15),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF00FFC2).withAlpha(50), width: 3),
                  ),
                ),
                const Icon(Icons.person_rounded, size: 64, color: Color(0xFF00FFC2)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'UPI Merchant Account',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'merchant@upi.wallet',
            style: TextStyle(color: Colors.white38, fontSize: 13),
          ),
          const SizedBox(height: 30),
          _buildInfoRow('Registered ID', 'UPI-9876543210@bank'),
          _buildInfoRow('Assigned Devices', 'Pixel 8 Pro (Active)'),
          _buildInfoRow('Notification Service', provider.isListenerPermissionGranted ? 'Fully Enabled' : 'Action Required'),
          _buildInfoRow('Total Transactions Logged', '${provider.paymentHistory.length}'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF101424),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.white60, fontSize: 13)),
            Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  // 2. Report Section (Weekly/Monthly fl_chart visualizations)
  Widget _buildReportSection(PaymentProvider provider) {
    final history = provider.paymentHistory;
    final weeklyMap = _getWeeklyTotals(history);
    final maxAmount = weeklyMap.values.fold(100.0, (double prev, elem) => max(prev, max(elem['received']!, elem['sent']!)));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fix 2: Suffix changed from "TXNs" to "Transactions"
          const Text(
            'Today\'s Transaction Analytics',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF101424),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Received Today', style: TextStyle(color: Colors.white38, fontSize: 11)),
                      const SizedBox(height: 4),
                      Text(
                        '${provider.totalReceivedTransactionsToday} Transactions',
                        style: const TextStyle(color: Color(0xFF00FFC2), fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF101424),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Sent Today', style: TextStyle(color: Colors.white38, fontSize: 11)),
                      const SizedBox(height: 4),
                      Text(
                        '${provider.totalSentTransactionsToday} Transactions',
                        style: const TextStyle(color: Color(0xFFFF5252), fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Weekly Performance Trends',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Comparing received vs sent funds over the last 7 days.',
            style: TextStyle(color: Colors.white30, fontSize: 12),
          ),
          const SizedBox(height: 24),

          // fl_chart BarChart implementation
          Container(
            height: 220,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF101424),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white10),
            ),
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxAmount * 1.2,
                barTouchData: BarTouchData(enabled: true),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                        if (value >= 0 && value < 7) {
                          return Text(days[value.toInt()], style: const TextStyle(color: Colors.white54, fontSize: 10));
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(7, (index) {
                  final key = weeklyMap.keys.elementAt(index);
                  final double recVal = weeklyMap[key]?['received'] ?? 0.0;
                  final double sentVal = weeklyMap[key]?['sent'] ?? 0.0;

                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: recVal,
                        color: const Color(0xFF00FFC2),
                        width: 8,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      BarChartRodData(
                        toY: sentVal,
                        color: const Color(0xFFFF5252),
                        width: 8,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem(const Color(0xFF00FFC2), 'Received'),
              const SizedBox(width: 24),
              _buildLegendItem(const Color(0xFFFF5252), 'Sent'),
            ],
          ),
          const SizedBox(height: 32),

          // Action: Email Report Section
          const Text(
            'Export Report & Data',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF161B30),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Email Summary Reports',
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Instantly draft an email summary of your local ledger using mail intent.',
                  style: TextStyle(color: Colors.white30, fontSize: 11),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0E1220),
                          foregroundColor: const Color(0xFF00FFC2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: const Icon(Icons.mail_outline_rounded, size: 18),
                        label: const Text('Weekly Report', style: TextStyle(fontSize: 12)),
                        onPressed: () => _sendEmailReport(provider, 'Weekly'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0E1220),
                          foregroundColor: const Color(0xFF00FFC2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: const Icon(Icons.mail_outline_rounded, size: 18),
                        label: const Text('Monthly Report', style: TextStyle(fontSize: 12)),
                        onPressed: () => _sendEmailReport(provider, 'Monthly'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
        ),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(color: Colors.white60, fontSize: 12)),
      ],
    );
  }

  Map<String, Map<String, double>> _getWeeklyTotals(List<PaymentRecord> history) {
    final Map<String, Map<String, double>> data = {};
    final now = DateTime.now();
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dateStr = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
      data[dateStr] = {'received': 0.0, 'sent': 0.0};
    }

    for (final record in history) {
      final dateStr = record.timestamp.toIso8601String().substring(0, 10);
      if (data.containsKey(dateStr)) {
        if (record.isSent) {
          data[dateStr]!['sent'] = data[dateStr]!['sent']! + record.amount;
        } else {
          data[dateStr]!['received'] = data[dateStr]!['received']! + record.amount;
        }
      }
    }
    return data;
  }

  // 3. Settings Section
  Widget _buildSettingsSection(PaymentProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildVoiceSettingsCard(provider),
          const SizedBox(height: 20),
          _buildBalanceSettingsCard(provider),
        ],
      ),
    );
  }

  // 4. Diagnostics Section
  Widget _buildDiagnosticsSection(PaymentProvider provider) {
    final isServiceActive = provider.isListenerPermissionGranted && provider.isListening;
    final isChannelOk = provider.isMethodChannelWorking;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Diagnostics Overview
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
                  _buildDiagnosticRow(
                    label: 'Notification Listener Active',
                    status: isServiceActive ? 'ACTIVE' : 'INACTIVE',
                    isOk: isServiceActive,
                  ),
                  const SizedBox(height: 12),
                  _buildDiagnosticRow(
                    label: 'Method Channel Pipeline',
                    status: isChannelOk ? 'WORKING' : 'DISCONNECTED',
                    isOk: isChannelOk,
                  ),
                  const SizedBox(height: 12),
                  _buildDiagnosticRow(
                    label: 'Battery Optimization Ignored',
                    status: provider.isBatteryOptimizationDisabled ? 'YES' : 'NO',
                    isOk: provider.isBatteryOptimizationDisabled,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Live Logger Logs
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'LIVE NOTIFICATION LOGS',
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
                    child: const Text('Clear Log Feed'),
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
                      'Send a payment or generic app notification to verify parser regex extraction parameters.',
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
                                raw.appName,
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
                          raw.packageName,
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
                              TextSpan(text: '${raw.title}\n', style: const TextStyle(color: Colors.white70)),
                              const TextSpan(text: 'Body : ', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
                              TextSpan(text: raw.body, style: const TextStyle(color: Colors.white70)),
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
                      'Battery Optimization Active',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Background alerts may get delayed',
                      style: TextStyle(color: Colors.white60, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'To guarantee real-time payment voice announcements instantly even when the screen is turned off or locked, please disable battery optimization for this application.',
            style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                    // Fix 2: Changed suffix from "TXNs" to "Transactions"
                    Text(
                      '$transactionsToday Transactions',
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
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
                        style: TextStyle(color: Colors.white38, fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
              Text(
                '₹${highestPayment.toStringAsFixed(0)}',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildServiceStatusCard(PaymentProvider provider) {
    final activeColor = provider.isListening ? const Color(0xFF00FFC2) : const Color(0xFFFF5252);
    final granted = provider.isListenerPermissionGranted;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF101424),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withAlpha(10), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(40),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'LISTENER STATUS',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: activeColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    provider.isListening ? 'RUNNING' : 'PAUSED',
                    style: TextStyle(
                      color: activeColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: provider.isListening ? _pulseAnimation.value : 1.0,
                    child: Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: activeColor.withAlpha(30),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        provider.isListening ? Icons.hearing_rounded : Icons.hearing_disabled_rounded,
                        color: activeColor,
                        size: 26,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      provider.isListening ? 'Listening for Payments' : 'Listener Offline',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      !granted 
                          ? 'Missing notification listener permissions' 
                          : 'Monitoring background UPI events...',
                      style: TextStyle(
                        color: !granted ? const Color(0xFFFF5252) : Colors.white54,
                        fontSize: 12,
                        fontWeight: !granted ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              if (!granted)
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => provider.requestListenerPermission(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF5252),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Grant Permissions', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                  ),
                )
              else
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => provider.toggleListening(!provider.isListening),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: provider.isListening ? const Color(0xFFFF5252) : const Color(0xFF00FFC2),
                            side: BorderSide(
                              color: provider.isListening 
                                  ? const Color(0xFFFF5252).withAlpha(100) 
                                  : const Color(0xFF00FFC2).withAlpha(100),
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text(
                            provider.isListening ? 'Stop Alerting' : 'Start Alerting',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAccountFilter(PaymentProvider provider) {
    if (provider.availableAccounts.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ACCOUNT LEDGER FILTER',
          style: TextStyle(
            color: Colors.white38,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 42,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: provider.availableAccounts.length + 1,
            separatorBuilder: (context, index) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final isAll = index == 0;
              final account = isAll ? null : provider.availableAccounts[index - 1];
              final isSelected = provider.selectedAccount == account;

              return ChoiceChip(
                label: Text(
                  isAll ? 'All Accounts' : 'A/C ...$account',
                  style: TextStyle(
                    color: isSelected ? const Color(0xFF090D1A) : Colors.white70,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                selected: isSelected,
                selectedColor: const Color(0xFF00FFC2),
                backgroundColor: const Color(0xFF101424),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isSelected ? const Color(0xFF00FFC2) : Colors.white.withAlpha(10),
                  ),
                ),
                onSelected: (_) => provider.setSelectedAccount(account),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBalanceCard(PaymentProvider provider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF101424), Color(0xFF161A30)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withAlpha(10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'LOCAL LEDGER BALANCE',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              Icon(Icons.account_balance_rounded, color: Colors.white24, size: 20),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '₹${provider.balance.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  // Fix 3: Add Today row above This Week in Transaction Summary
  Widget _buildSummarySection(PaymentProvider provider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF101424),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withAlpha(10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TRANSACTION SUMMARY',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          _buildSummaryRow(
            label: 'Today',
            received: provider.totalReceivedToday,
            sent: provider.totalSentToday,
          ),
          const SizedBox(height: 14),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 14),
          _buildSummaryRow(
            label: 'This Week',
            received: provider.totalReceivedThisWeek,
            sent: provider.totalSentThisWeek,
          ),
          const SizedBox(height: 14),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 14),
          _buildSummaryRow(
            label: 'This Month',
            received: provider.totalReceivedThisMonth,
            sent: provider.totalSentThisMonth,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow({required String label, required double received, required double sent}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
        ),
        Row(
          children: [
            Text(
              '+₹${received.toStringAsFixed(0)}',
              style: const TextStyle(color: Color(0xFF00FFC2), fontSize: 13, fontWeight: FontWeight.w900),
            ),
            const SizedBox(width: 14),
            Text(
              '-₹${sent.toStringAsFixed(0)}',
              style: const TextStyle(color: Color(0xFFFF5252), fontSize: 13, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildVoiceSettingsCard(PaymentProvider provider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF101424),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withAlpha(10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'VOICE CUSTOMIZATION',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getTtsStatusColor(provider.ttsStatus).withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  provider.ttsStatus.name.toUpperCase(),
                  style: TextStyle(
                    color: _getTtsStatusColor(provider.ttsStatus),
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Speech Output Switch
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Audio Confirmation Alerts', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  SizedBox(height: 2),
                  Text('Speak out incoming/outgoing payments', style: TextStyle(color: Colors.white38, fontSize: 11)),
                ],
              ),
              Switch(
                value: provider.isVoiceAlertEnabled,
                onChanged: (val) => provider.toggleVoiceAlert(val),
                activeColor: const Color(0xFF00FFC2),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 18),

          // Speech Language Selector
          const Text('Voice Alert Language', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF090D1A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: provider.language,
                dropdownColor: const Color(0xFF101424),
                isExpanded: true,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                items: provider.supportedLanguages.entries.map((e) {
                  return DropdownMenuItem(
                    value: e.key,
                    child: Text(e.value),
                  );
                }).toList(),
                onChanged: (lang) => provider.setLanguage(lang ?? 'en-IN'),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Speech Speed Rate Slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Voice Speed Rate', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              Text('${(provider.speechRate * 100).toInt()}%', style: const TextStyle(color: Color(0xFF00FFC2), fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
          Slider(
            value: provider.speechRate,
            min: 0.3,
            max: 0.8,
            divisions: 5,
            activeColor: const Color(0xFF00FFC2),
            inactiveColor: Colors.white12,
            onChanged: (rate) => provider.setSpeechRate(rate),
          ),
          const SizedBox(height: 14),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 18),

          // Wake word settings
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Wake Word Trigger ("Hey UPI")', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  SizedBox(height: 2),
                  Text('Listen for voice commands to replay', style: TextStyle(color: Colors.white38, fontSize: 11)),
                ],
              ),
              Switch(
                value: provider.isWakeWordEnabled,
                onChanged: (val) => provider.toggleWakeWord(val),
                activeColor: const Color(0xFF00FFC2),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 18),

          // Night Mode Quiet Hours
          const Text('Night Mode (Quiet Hours)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Start Hour', style: TextStyle(color: Colors.white38, fontSize: 11)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(color: const Color(0xFF090D1A), borderRadius: BorderRadius.circular(10)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: provider.nightModeStartHour,
                          dropdownColor: const Color(0xFF101424),
                          items: List.generate(24, (i) => DropdownMenuItem(value: i, child: Text('$i:00'))),
                          onChanged: (hr) => provider.setNightModeStartHour(hr ?? 0),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('End Hour', style: TextStyle(color: Colors.white38, fontSize: 11)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(color: const Color(0xFF090D1A), borderRadius: BorderRadius.circular(10)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: provider.nightModeEndHour,
                          dropdownColor: const Color(0xFF101424),
                          items: List.generate(24, (i) => DropdownMenuItem(value: i, child: Text('$i:00'))),
                          onChanged: (hr) => provider.setNightModeEndHour(hr ?? 0),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),

          // Test TTS button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.volume_up_rounded, size: 18),
              label: const Text('Test Output TTS Engine', style: TextStyle(fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF00FFC2),
                side: const BorderSide(color: Color(0x3300FFC2)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => provider.testSpeak(),
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
        color: const Color(0xFF101424),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withAlpha(10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fix 1: Restore Manual Wallet Balance section on Home with label and helpers
          const Text(
            'BALANCE CONFIGURATION',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _balanceController,
                  focusNode: _balanceFocusNode,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Manual Wallet Balance',
                    labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
                    hintText: 'Enter custom balance',
                    hintStyle: const TextStyle(color: Colors.white24),
                    prefixText: '₹ ',
                    prefixStyle: const TextStyle(color: Color(0xFF00FFC2)),
                    filled: true,
                    fillColor: const Color(0xFF090D1A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () {
                  final newBal = double.tryParse(_balanceController.text);
                  if (newBal != null) {
                    provider.updateBalance(newBal);
                    _balanceFocusNode.unfocus();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Balance modified to ₹${newBal.toStringAsFixed(2)}')),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00FFC2),
                  foregroundColor: const Color(0xFF090D1A),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
                ),
                child: const Text('Update', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Set your initial balance. Incoming payments will be added, and outgoing payments will be subtracted.',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLastPaymentCard(PaymentProvider provider, {required bool isSent}) {
    final payment = isSent ? provider.lastSentPayment : provider.lastReceivedPayment;
    final primaryColor = isSent ? const Color(0xFFFF5252) : const Color(0xFF00FFC2);

    if (payment == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF101424),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withAlpha(5)),
        ),
        child: const Column(
          children: [
            Icon(Icons.payment_rounded, color: Colors.white12, size: 36),
            SizedBox(height: 12),
            Text(
              'No payments recorded yet',
              style: TextStyle(color: Colors.white38, fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF101424),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: primaryColor.withAlpha(40), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withAlpha(10),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'LAST CAPTURED PAYMENT',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              IconButton(
                icon: Icon(Icons.volume_up_rounded, color: primaryColor),
                onPressed: () => provider.speakPaymentAmount(payment.amount, payment.isSent),
                tooltip: 'Replay audio alert',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _getAppIcon(payment.packageName, payment.isSent),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      payment.sender,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_formatDate(payment.timestamp)} at ${_formatTime(payment.timestamp)}',
                      style: const TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${isSent ? "-" : "+"}₹${payment.amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: primaryColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (payment.accountNumber != null)
                    Text(
                      'A/C ...${payment.accountNumber}',
                      style: const TextStyle(color: Colors.white24, fontSize: 10),
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
    final list = isSent ? provider.sentHistory : provider.receivedHistory;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'TRANSACTION HISTORY',
          style: TextStyle(
            color: Colors.white38,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        if (list.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 40),
            alignment: Alignment.center,
            child: const Text('No records found matching criteria', style: TextStyle(color: Colors.white24, fontSize: 12)),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: list.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = list[index];
              final itemColor = item.isSent ? const Color(0xFFFF5252) : const Color(0xFF00FFC2);

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0E1220),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withAlpha(5)),
                ),
                child: Row(
                  children: [
                    _getAppIcon(item.packageName, item.isSent),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.sender,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_formatDate(item.timestamp)} • ${_formatTime(item.timestamp)}',
                            style: const TextStyle(color: Colors.white38, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${item.isSent ? "-" : "+"}₹${item.amount.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: itemColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                        if (item.accountNumber != null)
                          Text(
                            'A/C ...${item.accountNumber}',
                            style: const TextStyle(color: Colors.white24, fontSize: 9),
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
}
