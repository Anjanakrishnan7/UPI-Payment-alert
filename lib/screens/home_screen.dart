import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/pdf_report_service.dart';
import '../providers/payment_provider.dart';
import '../models/payment_record.dart';
import '../widgets/app_logo.dart';

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
  String _currentSection = 'home'; // 'home', 'report', 'settings', 'diagnostics'
  late TextEditingController _balanceController;
  late FocusNode _balanceFocusNode;
  bool _isGeneratingPdf = false;

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

  Color _getDividerColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.white10
        : Colors.black12;
  }

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
        return _getTealAccent(context);
      case TtsStatus.failed:
        return const Color(0xFFFF5252);
    }
  }

  Widget _getAppIcon(String packageName, bool isSent) {
    IconData iconData = isSent ? Icons.unfold_less_rounded : Icons.unfold_more_rounded;
    Color brandColor = isSent ? const Color(0xFFFF5252) : _getTealAccent(context);

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

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<PaymentProvider>(context);

    if (!provider.isInitialized) {
      return Scaffold(
        backgroundColor: const Color(0xFF090D1A),
        body: Center(
          child: CircularProgressIndicator(
            color: _getTealAccent(context),
          ),
        ),
      );
    }

    if (!_balanceFocusNode.hasFocus) {
      _balanceController.text = provider.balance.toStringAsFixed(2);
    }

    // Dynamic color setup
    Color indicatorColor = _getTealAccent(context);
    if (_currentIndex == 1) {
      indicatorColor = const Color(0xFFFF5252);
    }

    // Build the body based on drawer section
    Widget bodyContent;
    String appBarTitle = 'UPI Payment Alert';

    if (_currentSection == 'home') {
      appBarTitle = _currentIndex == 0 ? 'Receive Payments' : 'Send Payments';
      bodyContent = _currentIndex == 0 ? _buildReceiveTab(provider) : _buildSendTab(provider);
    } else if (_currentSection == 'report') {
      appBarTitle = 'Payment Reports';
      bodyContent = _buildReportSection(provider);
    } else if (_currentSection == 'settings') {
      appBarTitle = 'Customization Settings';
      bodyContent = _buildSettingsSection(provider);
    } else {
      appBarTitle = 'Settings';
      bodyContent = _buildDiagnosticsSection(provider);
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0E1A) : const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Builder(
          builder: (context) {
            // Fix: All secondary screens' back arrows now open the side drawer instead of popping to Home
            if (_currentSection != 'home') {
              return IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: _getPrimaryTextColor(context)),
                onPressed: () {
                  Scaffold.of(context).openDrawer();
                },
              );
            }
            return IconButton(
              icon: Icon(Icons.menu_rounded, color: _getPrimaryTextColor(context)),
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
                    ? (_currentSection == 'report'
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
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: _getPrimaryTextColor(context),
                  letterSpacing: 0.5,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (provider.isNightModeActive) ...[
              Icon(Icons.mode_night_rounded, color: _getTealAccent(context), size: 20),
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
                backgroundColor: _getCardColor(context),
                indicatorColor: indicatorColor.withAlpha(30),
                labelTextStyle: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return TextStyle(
                      color: indicatorColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    );
                  }
                  return TextStyle(color: _getSecondaryTextColor(context), fontSize: 12);
                }),
              ),
              child: NavigationBar(
                backgroundColor: _getCardColor(context),
                selectedIndex: _currentIndex,
                onDestinationSelected: (index) {
                  setState(() {
                    _currentIndex = index;
                  });
                },
                destinations: [
                  NavigationDestination(
                    icon: Icon(Icons.download_rounded, color: _getSecondaryTextColor(context)),
                    selectedIcon: Icon(Icons.download_rounded, color: _getTealAccent(context)),
                    label: 'Receive',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.upload_rounded, color: _getSecondaryTextColor(context)),
                    selectedIcon: const Icon(Icons.upload_rounded, color: Color(0xFFFF5252)),
                    label: 'Send',
                  ),
                ],
              ),
            )
          : null,
    );
  }

  Widget _buildDrawer(PaymentProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Drawer(
      backgroundColor: isDark ? const Color(0xFF101424) : const Color(0xFFF5F6F9),
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
                  const AppLogo(
                    size: 56,
                    showGlow: false,
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'UPI Voice Alert',
                        style: TextStyle(
                          color: _getPrimaryTextColor(context),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'v1.0.0 Pro',
                        style: TextStyle(
                          color: _getSecondaryTextColor(context),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Theme Switch toggle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        provider.isLightMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                        color: provider.isLightMode ? const Color(0xFFFFB300) : _getTealAccent(context),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        provider.isLightMode ? 'Light Mode' : 'Dark Mode',
                        style: TextStyle(
                          color: _getPrimaryTextColor(context),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Switch(
                    value: !provider.isLightMode,
                    thumbColor: WidgetStateProperty.resolveWith((states) {
                      final isDark = Theme.of(context).brightness == Brightness.dark;
                      return isDark ? const Color(0xFF6E6E73) : const Color(0xFF2D2D30);
                    }),
                    trackColor: WidgetStateProperty.resolveWith((states) {
                      final isDark = Theme.of(context).brightness == Brightness.dark;
                      return isDark ? const Color(0xFF2D2D30) : Colors.white;
                    }),
                    trackOutlineColor: WidgetStateProperty.all(const Color(0xFF4A4A4F)),
                    onChanged: (val) {
                      provider.toggleThemeMode(!val);
                    },
                  ),
                ],
              ),
            ),
            Divider(color: _getDividerColor(context)),
            
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
                    label: 'Settings',
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
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                'Secured Local Assistant',
                style: TextStyle(color: _getSecondaryTextColor(context), fontSize: 11),
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
    final activeColor = _getTealAccent(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Icon(icon, color: selected ? activeColor : _getSecondaryTextColor(context)),
        title: Text(
          label,
          style: TextStyle(
            color: selected ? activeColor : _getPrimaryTextColor(context),
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
            _buildServiceStatusCard(provider),
            const SizedBox(height: 20),
            _buildAccountFilter(provider),
            if (provider.availableAccounts.isNotEmpty) const SizedBox(height: 20),
            _buildBalanceCard(provider),
            const SizedBox(height: 20),
            _buildBankBreakdownCard(provider),
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



  // 2. Report Section (Weekly/Monthly fl_chart visualizations)
  Widget _buildReportSection(PaymentProvider provider) {
    final history = provider.paymentHistory;
    final weeklyMap = _getWeeklyTotals(history);
    final maxAmount = weeklyMap.values.fold(100.0, (double prev, elem) => max(prev, max(elem['received']!, elem['sent']!)));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fix 2: Suffix changed from "TXNs" to "Transactions"
          Text(
            'Today\'s Transaction Analytics',
            style: TextStyle(color: _getPrimaryTextColor(context), fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _getCardColor(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _getBorderColor(context)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Received Today', style: TextStyle(color: _getSecondaryTextColor(context), fontSize: 11)),
                      const SizedBox(height: 4),
                      Text(
                        '${provider.totalReceivedTransactionsToday} Transactions',
                        style: TextStyle(color: _getTealAccent(context), fontSize: 16, fontWeight: FontWeight.bold),
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
                    color: _getCardColor(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _getBorderColor(context)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Sent Today', style: TextStyle(color: _getSecondaryTextColor(context), fontSize: 11)),
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
          Text(
            'Weekly Performance Trends',
            style: TextStyle(color: _getPrimaryTextColor(context), fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Comparing received vs sent funds over the last 7 days.',
            style: TextStyle(color: _getSecondaryTextColor(context), fontSize: 12),
          ),
          const SizedBox(height: 24),

          // fl_chart BarChart implementation
          Container(
            height: 220,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _getCardColor(context),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _getBorderColor(context)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(isDark ? 30 : 10),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                )
              ],
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
                        final valInt = value.toInt();
                        if (valInt >= 0 && valInt < 7) {
                          final date = DateTime.now().subtract(Duration(days: 6 - valInt));
                          const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                          return Padding(
                            padding: const EdgeInsets.only(top: 6.0),
                            child: Text(days[date.weekday - 1], style: TextStyle(color: _getSecondaryTextColor(context), fontSize: 10)),
                          );
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
                        color: _getTealAccent(context),
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
              _buildLegendItem(_getTealAccent(context), 'Received'),
              const SizedBox(width: 24),
              _buildLegendItem(const Color(0xFFFF5252), 'Sent'),
            ],
          ),
          const SizedBox(height: 32),

          // Action: Email Report Section
          Text(
            'Export Report & Data',
            style: TextStyle(color: _getPrimaryTextColor(context), fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _getCardColor(context),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _getBorderColor(context)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(isDark ? 30 : 10),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Download Reports',
                  style: TextStyle(color: _getPrimaryTextColor(context), fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Generate and save a professional PDF summary of your local ledger.',
                  style: TextStyle(color: _getSecondaryTextColor(context), fontSize: 11),
                ),
                const SizedBox(height: 16),
                _isGeneratingPdf
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: CircularProgressIndicator(
                            color: _getTealAccent(context),
                          ),
                        ),
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isDark ? const Color(0xFF0E1220) : const Color(0xFFF3F4F6),
                                foregroundColor: _getTealAccent(context),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                elevation: 0,
                              ),
                              icon: const Icon(Icons.file_download_outlined, size: 16),
                              label: const Text('Daily PDF', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                              onPressed: () async {
                                setState(() {
                                  _isGeneratingPdf = true;
                                });
                                try {
                                  await PdfReportService.generateAndShareReport(provider, 'Daily');
                                } catch (e) {
                                  debugPrint("PDF generation error: $e");
                                } finally {
                                  if (mounted) {
                                    setState(() {
                                      _isGeneratingPdf = false;
                                    });
                                  }
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isDark ? const Color(0xFF0E1220) : const Color(0xFFF3F4F6),
                                foregroundColor: _getTealAccent(context),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                elevation: 0,
                              ),
                              icon: const Icon(Icons.file_download_outlined, size: 16),
                              label: const Text('Weekly PDF', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                              onPressed: () async {
                                setState(() {
                                  _isGeneratingPdf = true;
                                });
                                try {
                                  await PdfReportService.generateAndShareReport(provider, 'Weekly');
                                } catch (e) {
                                  debugPrint("PDF generation error: $e");
                                } finally {
                                  if (mounted) {
                                    setState(() {
                                      _isGeneratingPdf = false;
                                    });
                                  }
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isDark ? const Color(0xFF0E1220) : const Color(0xFFF3F4F6),
                                foregroundColor: _getTealAccent(context),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                elevation: 0,
                              ),
                              icon: const Icon(Icons.file_download_outlined, size: 16),
                              label: const Text('Monthly PDF', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                              onPressed: () async {
                                setState(() {
                                  _isGeneratingPdf = true;
                                });
                                try {
                                  await PdfReportService.generateAndShareReport(provider, 'Monthly');
                                } catch (e) {
                                  debugPrint("PDF generation error: $e");
                                } finally {
                                  if (mounted) {
                                    setState(() {
                                      _isGeneratingPdf = false;
                                    });
                                  }
                                }
                              },
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
        Text(text, style: TextStyle(color: _getSecondaryTextColor(context), fontSize: 12)),
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
        ],
      ),
    );
  }

  // 4. Diagnostics Section
  Widget _buildDiagnosticsSection(PaymentProvider provider) {
    final isChannelOk = provider.isMethodChannelWorking;
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                color: _getCardColor(context),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: isDark ? const Color(0x1FFFB300) : Colors.amber.withAlpha(80)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(isDark ? 30 : 10),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SYSTEM INTEGRITY',
                    style: TextStyle(
                      color: _getSecondaryTextColor(context),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 18),
                   _buildDiagnosticRow(
                    label: 'Notification Listener Active',
                    status: provider.isListenerPermissionGranted ? 'ACTIVE' : 'INACTIVE',
                    isOk: provider.isListenerPermissionGranted,
                    description: 'Required to capture and parse UPI transaction alerts from notifications.',
                    action: provider.isListenerPermissionGranted
                        ? OutlinedButton(
                            onPressed: () => provider.requestListenerPermission(),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFFF5252),
                              side: const BorderSide(color: Color(0x33FF5252)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Disallow', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                          )
                        : ElevatedButton(
                            onPressed: () => provider.requestListenerPermission(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _getTealAccent(context),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              minimumSize: Size.zero,
                              elevation: 0,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Allow', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
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
                    description: 'Disabling battery optimization ensures payment alerts are announced instantly, even when the screen is off.',
                    action: provider.isBatteryOptimizationDisabled
                        ? OutlinedButton(
                            onPressed: () => provider.openBatteryOptimizationSettings(),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFFF5252),
                              side: const BorderSide(color: Color(0x33FF5252)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Disallow', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                          )
                        : ElevatedButton(
                            onPressed: () => provider.requestIgnoreBatteryOptimization(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _getTealAccent(context),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              minimumSize: Size.zero,
                              elevation: 0,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Allow', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Live Logger Logs
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'LIVE NOTIFICATION LOGS',
                  style: TextStyle(
                    color: _getSecondaryTextColor(context),
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
                  color: _getCardColor(context),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _getBorderColor(context)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(isDark ? 30 : 10),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    )
                  ],
                ),
                child: Column(
                  children: [
                    Icon(Icons.radar_rounded, color: _getSecondaryTextColor(context).withAlpha(40), size: 44),
                    const SizedBox(height: 14),
                    Text(
                      'Monitoring All Notifications Live...',
                      style: TextStyle(color: _getPrimaryTextColor(context), fontSize: 14, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Send a payment or generic app notification to verify parser regex extraction parameters.',
                      style: TextStyle(color: _getSecondaryTextColor(context), fontSize: 11, height: 1.4),
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
                      color: _getCardColor(context),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: _getBorderColor(context)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(isDark ? 20 : 8),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
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
                              style: TextStyle(color: _getSecondaryTextColor(context), fontSize: 10),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          raw.packageName,
                          style: TextStyle(color: _getSecondaryTextColor(context), fontSize: 10, fontFamily: 'monospace'),
                        ),
                        const SizedBox(height: 10),
                        Divider(color: _getDividerColor(context), height: 1),
                        const SizedBox(height: 10),
                        RichText(
                          text: TextSpan(
                            style: TextStyle(fontSize: 12, height: 1.4, fontFamily: 'Inter', color: _getBodyTextColor(context)),
                            children: [
                              TextSpan(text: 'Title: ', style: TextStyle(color: _getSecondaryTextColor(context), fontWeight: FontWeight.bold)),
                              TextSpan(text: '${raw.title}\n', style: TextStyle(color: _getBodyTextColor(context))),
                              TextSpan(text: 'Body : ', style: TextStyle(color: _getSecondaryTextColor(context), fontWeight: FontWeight.bold)),
                              TextSpan(text: raw.body, style: TextStyle(color: _getBodyTextColor(context))),
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

  Widget _buildDiagnosticRow({
    required String label,
    required String status,
    required bool isOk,
    String? description,
    Widget? action,
    VoidCallback? onTap,
  }) {
    final statusColor = isOk ? const Color(0xFF4CAF50) : const Color(0xFFFF5252);
    return InkWell(
      onTap: action == null ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(color: _getPrimaryTextColor(context), fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withAlpha(20),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: statusColor.withAlpha(60)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            status,
                            style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                          ),
                          if (onTap != null && action == null) ...[
                            const SizedBox(width: 4),
                            Icon(Icons.open_in_new_rounded, color: statusColor, size: 10),
                          ],
                        ],
                      ),
                    ),
                    if (action != null) ...[
                      const SizedBox(width: 8),
                      action,
                    ],
                  ],
                ),
              ],
            ),
            if (description != null) ...[
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(color: _getSecondaryTextColor(context), fontSize: 10, height: 1.4),
              ),
            ],
          ],
        ),
      ),
    );
  }



  Widget _buildStatsDashboard(PaymentProvider provider, {required bool isSent}) {
    final title = isSent ? 'TODAY\'S SENT METRICS' : 'TODAY\'S RECEIVED METRICS';
    final amountToday = isSent ? provider.totalSentToday : provider.totalReceivedToday;
    final transactionsToday = isSent ? provider.totalSentTransactionsToday : provider.totalReceivedTransactionsToday;
    final highestPayment = isSent ? provider.highestSentPayment : provider.highestReceivedPayment;
    final primaryColor = isSent ? const Color(0xFFFF5252) : _getTealAccent(context);
    final secondaryColor = isSent ? const Color(0xFFFF8A80) : const Color(0xFF00E5FF);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: _getSecondaryTextColor(context),
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
                    colors: isDark 
                        ? (isSent 
                            ? [const Color(0xFF2C161A), const Color(0xFF1C0F11)]
                            : [const Color(0xFF16252C), const Color(0xFF0F181C)])
                        : (isSent
                            ? [const Color(0xFFFFF1F1), const Color(0xFFFFE3E3)]
                            : [const Color(0xFFF0FDF4), const Color(0xFFDCFCE7)]),
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: primaryColor.withAlpha(isDark ? 30 : 60), width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.currency_rupee_rounded, color: primaryColor, size: 20),
                    const SizedBox(height: 10),
                    Text(
                      isSent ? 'Sent Today' : 'Received Today',
                      style: TextStyle(color: _getSecondaryTextColor(context), fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₹${amountToday.toStringAsFixed(0)}',
                      style: TextStyle(color: _getPrimaryTextColor(context), fontSize: 18, fontWeight: FontWeight.w900),
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
                    colors: isDark
                        ? (isSent
                            ? [const Color(0xFF251A2E), const Color(0xFF191021)]
                            : [const Color(0xFF1A1A2E), const Color(0xFF131326)])
                        : (isSent
                            ? [const Color(0xFFFAF5FF), const Color(0xFFF3E8FF)]
                            : [const Color(0xFFEEF2FF), const Color(0xFFE0E7FF)]),
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: secondaryColor.withAlpha(isDark ? 20 : 50), width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.sync_alt_rounded, color: secondaryColor, size: 20),
                    const SizedBox(height: 10),
                    Text(
                      'Transactions',
                      style: TextStyle(color: _getSecondaryTextColor(context), fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    // Fix 2: Changed suffix from "TXNs" to "Transactions"
                    Text(
                      '$transactionsToday Transactions',
                      style: TextStyle(color: _getPrimaryTextColor(context), fontSize: 13, fontWeight: FontWeight.bold),
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
              colors: isDark
                  ? (isSent
                      ? [const Color(0xFF201625), const Color(0xFF160F1A)]
                      : [const Color(0xFF16252C), const Color(0xFF0F181C)])
                  : (isSent
                      ? [const Color(0xFFFAF5FF), const Color(0xFFF3E8FF)]
                      : [const Color(0xFFF0FDF4), const Color(0xFFDCFCE7)]),
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: primaryColor.withAlpha(isDark ? 30 : 60), width: 1),
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
                        style: TextStyle(color: _getPrimaryTextColor(context), fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Peak transaction milestone',
                        style: TextStyle(color: _getSecondaryTextColor(context), fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
              Text(
                '₹${highestPayment.toStringAsFixed(0)}',
                style: TextStyle(color: _getPrimaryTextColor(context), fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildServiceStatusCard(PaymentProvider provider) {
    final activeColor = provider.isListening ? _getTealAccent(context) : const Color(0xFFFF5252);
    final granted = provider.isListenerPermissionGranted;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _getCardColor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _getBorderColor(context), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 30 : 10),
            blurRadius: 15,
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
              Text(
                'LISTENER STATUS',
                style: TextStyle(
                  color: _getSecondaryTextColor(context),
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
                      style: TextStyle(
                        color: _getPrimaryTextColor(context),
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
                        color: !granted ? const Color(0xFFFF5252) : _getSecondaryTextColor(context),
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
              if (!provider.isListenerPermissionGranted)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => provider.requestListenerPermission(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFF5252),
                      side: const BorderSide(color: Color(0x33FF5252)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.security_rounded, size: 18),
                    label: const Text('Grant Notification Access', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                )
              else if (!provider.isBatteryOptimizationDisabled && !provider.batteryOptimizationSkipped)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => provider.requestIgnoreBatteryOptimization(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFF9800),
                      side: const BorderSide(color: Color(0x33FF9800)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.battery_alert_rounded, size: 18),
                    label: const Text('Optimize Battery Usage', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
                            foregroundColor: provider.isListening ? const Color(0xFFFF5252) : _getTealAccent(context),
                            side: BorderSide(
                              color: provider.isListening 
                                  ? const Color(0xFFFF5252).withAlpha(100) 
                                  : _getTealAccent(context).withAlpha(100),
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
                    color: isSelected ? const Color(0xFF090D1A) : _getBodyTextColor(context),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                selected: isSelected,
                selectedColor: _getTealAccent(context),
                backgroundColor: _getCardColor(context),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isSelected ? _getTealAccent(context) : _getBorderColor(context),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF161E33), const Color(0xFF121625)]
              : [const Color(0xFFFFFFFF), const Color(0xFFF0F2F5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _getBorderColor(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 35 : 12),
            blurRadius: 15,
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
              Text(
                'LOCAL LEDGER BALANCE',
                style: TextStyle(
                  color: _getSecondaryTextColor(context),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.5,
                ),
              ),
              Icon(Icons.account_balance_rounded, color: _getSecondaryTextColor(context), size: 20),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '₹${provider.balance.toStringAsFixed(2)}',
            style: TextStyle(
              color: _getPrimaryTextColor(context),
              fontSize: 38,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  // Fix 3: Add Today row above This Week in Transaction Summary
  Widget _buildSummarySection(PaymentProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF14192A), const Color(0xFF111421)]
              : [const Color(0xFFFFFFFF), const Color(0xFFECEFF1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _getBorderColor(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 30 : 10),
            blurRadius: 15,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TRANSACTION SUMMARY',
            style: TextStyle(
              color: _getSecondaryTextColor(context),
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
          Divider(color: _getDividerColor(context), height: 1),
          const SizedBox(height: 14),
          _buildSummaryRow(
            label: 'This Week',
            received: provider.totalReceivedThisWeek,
            sent: provider.totalSentThisWeek,
          ),
          const SizedBox(height: 14),
          Divider(color: _getDividerColor(context), height: 1),
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
          style: TextStyle(color: _getBodyTextColor(context), fontSize: 13, fontWeight: FontWeight.bold),
        ),
        Row(
          children: [
            Text(
              '+₹${received.toStringAsFixed(0)}',
              style: TextStyle(color: _getTealAccent(context), fontSize: 13, fontWeight: FontWeight.w900),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _getCardColor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _getBorderColor(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 30 : 10),
            blurRadius: 15,
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
              Text(
                'VOICE CUSTOMIZATION',
                style: TextStyle(
                  color: _getSecondaryTextColor(context),
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Audio Confirmation Alerts', style: TextStyle(color: _getPrimaryTextColor(context), fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text('Speak out incoming/outgoing payments', style: TextStyle(color: _getSecondaryTextColor(context), fontSize: 11)),
                  ],
                ),
              ),
              Switch(
                value: provider.isVoiceAlertEnabled,
                onChanged: (val) => provider.toggleVoiceAlert(val),
                activeColor: _getTealAccent(context),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Divider(color: _getDividerColor(context), height: 1),
          const SizedBox(height: 18),

          // Speech Language Selector
          Text('Voice Alert Language', style: TextStyle(color: _getPrimaryTextColor(context), fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF090D1A) : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _getBorderColor(context)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: provider.language,
                dropdownColor: _getCardColor(context),
                isExpanded: true,
                style: TextStyle(color: _getPrimaryTextColor(context), fontSize: 13),
                items: provider.supportedLanguages.entries.map((e) {
                  return DropdownMenuItem(
                    value: e.key,
                    child: Text(
                      e.value,
                      style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1F2937)),
                    ),
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
              Text('Voice Speed Rate', style: TextStyle(color: _getPrimaryTextColor(context), fontWeight: FontWeight.bold, fontSize: 13)),
              Text('${(provider.speechRate * 100).toInt()}%', style: TextStyle(color: _getTealAccent(context), fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
          Slider(
            value: provider.speechRate,
            min: 0.3,
            max: 0.8,
            divisions: 5,
            activeColor: _getTealAccent(context),
            inactiveColor: isDark ? Colors.white12 : Colors.black12,
            onChanged: (rate) => provider.setSpeechRate(rate),
          ),
          const SizedBox(height: 14),
          Divider(color: _getDividerColor(context), height: 1),
          const SizedBox(height: 18),

          // Night Mode Quiet Hours
          Text('Night Mode (Quiet Hours)', style: TextStyle(color: _getPrimaryTextColor(context), fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Start Hour', style: TextStyle(color: _getSecondaryTextColor(context), fontSize: 11)),
                    const SizedBox(height: 4),
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF090D1A) : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _getBorderColor(context)),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () async {
                            final selectedTime = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay(
                                hour: provider.nightModeStartHour,
                                minute: provider.nightModeStartMinute,
                              ),
                            );
                            if (selectedTime != null) {
                              provider.setNightModeStartTime(selectedTime.hour, selectedTime.minute);
                            }
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 12.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "${provider.nightModeStartHour}:${provider.nightModeStartMinute.toString().padLeft(2, '0')}",
                                  style: TextStyle(
                                    color: isDark ? Colors.white : const Color(0xFF1F2937),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                Icon(
                                  Icons.access_time_rounded,
                                  size: 18,
                                  color: isDark ? Colors.white70 : const Color(0xFF6B7280),
                                ),
                              ],
                            ),
                          ),
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
                    Text('End Hour', style: TextStyle(color: _getSecondaryTextColor(context), fontSize: 11)),
                    const SizedBox(height: 4),
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF090D1A) : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _getBorderColor(context)),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () async {
                            final selectedTime = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay(
                                hour: provider.nightModeEndHour,
                                minute: provider.nightModeEndMinute,
                              ),
                            );
                            if (selectedTime != null) {
                              provider.setNightModeEndTime(selectedTime.hour, selectedTime.minute);
                            }
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 12.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "${provider.nightModeEndHour}:${provider.nightModeEndMinute.toString().padLeft(2, '0')}",
                                  style: TextStyle(
                                    color: isDark ? Colors.white : const Color(0xFF1F2937),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                Icon(
                                  Icons.access_time_rounded,
                                  size: 18,
                                  color: isDark ? Colors.white70 : const Color(0xFF6B7280),
                                ),
                              ],
                            ),
                          ),
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
                foregroundColor: _getTealAccent(context),
                side: BorderSide(color: _getTealAccent(context).withAlpha(51)),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _getCardColor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _getBorderColor(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 30 : 10),
            blurRadius: 15,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fix 1: Restore Manual Wallet Balance section on Home with label and helpers
          Text(
            'BALANCE CONFIGURATION',
            style: TextStyle(
              color: _getSecondaryTextColor(context),
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
                  style: TextStyle(color: _getPrimaryTextColor(context), fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Manual Wallet Balance',
                    labelStyle: TextStyle(color: _getSecondaryTextColor(context), fontSize: 12),
                    hintText: 'Enter custom balance',
                    hintStyle: TextStyle(color: _getSecondaryTextColor(context).withAlpha(100)),
                    prefixText: '₹ ',
                    prefixStyle: TextStyle(color: _getTealAccent(context)),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF090D1A) : const Color(0xFFF3F4F6),
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
                  backgroundColor: _getTealAccent(context),
                  foregroundColor: isDark ? const Color(0xFF090D1A) : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
                ),
                child: const Text('Update', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Set your initial balance. Incoming payments will be added, and outgoing payments will be subtracted.',
            style: TextStyle(
              color: _getBodyTextColor(context),
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
    final primaryColor = isSent ? const Color(0xFFFF5252) : _getTealAccent(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (payment == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
        decoration: BoxDecoration(
          color: _getCardColor(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _getBorderColor(context)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(isDark ? 30 : 10),
              blurRadius: 15,
              offset: const Offset(0, 8),
            )
          ],
        ),
        child: Column(
          children: [
            Icon(Icons.payment_rounded, color: _getSecondaryTextColor(context).withAlpha(40), size: 36),
            const SizedBox(height: 12),
            Text(
              'No payments recorded yet',
              style: TextStyle(color: _getSecondaryTextColor(context), fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _getCardColor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primaryColor.withAlpha(40), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 30 : 10),
            blurRadius: 15,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            provider.speakPaymentAmount(payment.amount, payment.isSent);
          },
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'LAST CAPTURED PAYMENT',
                      style: TextStyle(
                        color: _getSecondaryTextColor(context),
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
                            style: TextStyle(color: _getPrimaryTextColor(context), fontWeight: FontWeight.bold, fontSize: 16),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_formatDate(payment.timestamp)} at ${_formatTime(payment.timestamp)}',
                            style: TextStyle(color: _getSecondaryTextColor(context), fontSize: 12),
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
                            style: TextStyle(color: _getSecondaryTextColor(context), fontSize: 10),
                          ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHistorySection(PaymentProvider provider, {required bool isSent}) {
    final fullList = isSent ? provider.sentHistory : provider.receivedHistory;
    final list = fullList.take(15).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TRANSACTION HISTORY',
          style: TextStyle(
            color: _getSecondaryTextColor(context),
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
            child: Text('No records found matching criteria', style: TextStyle(color: _getSecondaryTextColor(context), fontSize: 12)),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: list.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = list[index];
              final itemColor = item.isSent ? const Color(0xFFFF5252) : _getTealAccent(context);

              return Container(
                decoration: BoxDecoration(
                  color: _getCardColor(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _getBorderColor(context)),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      provider.speakPaymentAmount(item.amount, item.isSent);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                                  style: TextStyle(color: _getPrimaryTextColor(context), fontWeight: FontWeight.bold, fontSize: 14),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_formatDate(item.timestamp)} • ${_formatTime(item.timestamp)}',
                                  style: TextStyle(color: _getSecondaryTextColor(context), fontSize: 11),
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
                                  style: TextStyle(color: _getSecondaryTextColor(context), fontSize: 9),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildBankBreakdownCard(PaymentProvider provider) {
    final receivedTxns = provider.receivedHistory;

    final Map<String, double> breakdown = {};
    for (var txn in receivedTxns) {
      final acc = (txn.accountNumber != null && txn.accountNumber!.isNotEmpty)
          ? txn.accountNumber!
          : 'Unknown';
      breakdown[acc] = (breakdown[acc] ?? 0.0) + txn.amount;
    }

    final List<String> voiceFilterOptions = ['All Accounts'];
    final detectedAccounts = provider.paymentHistory
        .map((p) => p.accountNumber)
        .where((acc) => acc != null && acc.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();
    detectedAccounts.sort();
    voiceFilterOptions.addAll(detectedAccounts);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _getCardColor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _getBorderColor(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 30 : 10),
            blurRadius: 15,
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
              Text(
                'RECEIVED BY BANK ACCOUNT',
                style: TextStyle(
                  color: _getSecondaryTextColor(context),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                ),
              ),
              Icon(Icons.account_balance_wallet_rounded, color: _getSecondaryTextColor(context), size: 20),
            ],
          ),
          const SizedBox(height: 18),
          if (breakdown.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24.0),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.account_balance_outlined,
                      color: _getSecondaryTextColor(context).withAlpha(80),
                      size: 32,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'No bank data yet',
                      style: TextStyle(color: _getSecondaryTextColor(context), fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            )
          else
            ...breakdown.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.account_balance_rounded, color: _getTealAccent(context), size: 16),
                        const SizedBox(width: 10),
                        Text(
                          entry.key == 'Unknown' ? 'Unknown VPA/Account' : 'A/C ...${entry.key}',
                          style: TextStyle(color: _getBodyTextColor(context), fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Text(
                      '₹${entry.value.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: _getTealAccent(context),
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              );
            }),
          const SizedBox(height: 14),
          Divider(color: _getDividerColor(context)),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.volume_up_rounded, color: _getTealAccent(context), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Voice Alert Filter',
                    style: TextStyle(
                      color: _getBodyTextColor(context),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF090D1A) : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _getBorderColor(context)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: voiceFilterOptions.contains(provider.voiceFilterAccount)
                        ? provider.voiceFilterAccount
                        : 'All Accounts',
                    dropdownColor: _getCardColor(context),
                    icon: Icon(Icons.arrow_drop_down, color: _getTealAccent(context)),
                    style: TextStyle(
                      color: _getTealAccent(context),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    items: voiceFilterOptions.map((opt) {
                      return DropdownMenuItem<String>(
                        value: opt,
                        child: Text(
                          opt,
                          style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1F2937)),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        provider.setVoiceFilterAccount(val);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
