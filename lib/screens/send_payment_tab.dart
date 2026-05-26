import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/payment_provider.dart';

class SendPaymentTab extends StatefulWidget {
  const SendPaymentTab({super.key});

  @override
  State<SendPaymentTab> createState() => _SendPaymentTabState();
}

class _SendPaymentTabState extends State<SendPaymentTab> {
  final _formKey = GlobalKey<FormState>();
  final _upiIdController = TextEditingController();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  String? _selectedAppPackage; // null means 'Select Any App' (System Chooser)
  bool _isLoading = false;

  final List<Map<String, dynamic>> _upiApps = [
    {
      'name': 'Any App',
      'package': null,
      'color': const Color(0xFF00FFC2),
      'icon': Icons.apps_rounded,
    },
    {
      'name': 'Google Pay',
      'package': 'com.google.android.apps.nbu.paisa.user',
      'color': const Color(0xFF4285F4),
      'icon': Icons.account_balance_wallet_rounded,
    },
    {
      'name': 'PhonePe',
      'package': 'com.phonepe.app',
      'color': const Color(0xFF5F259F),
      'icon': Icons.payment_rounded,
    },
    {
      'name': 'Paytm',
      'package': 'net.one97.paytm',
      'color': const Color(0xFF00B9F5),
      'icon': Icons.currency_rupee_rounded,
    },
  ];

  @override
  void dispose() {
    _upiIdController.dispose();
    _nameController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  // UPI ID validation regex helper
  bool _isValidUpiId(String val) {
    // Basic check for pattern: user@bank
    final upiRegex = RegExp(r'^[a-zA-Z0-9.\-_]{2,256}@[a-zA-Z]{2,64}$');
    return upiRegex.hasMatch(val);
  }

  Future<void> _processPayment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    final provider = context.read<PaymentProvider>();
    final upiId = _upiIdController.text.trim();
    final name = _nameController.text.trim().isEmpty ? 'Recipient' : _nameController.text.trim();
    final amount = double.parse(_amountController.text.trim());
    final note = _noteController.text.trim().isEmpty ? 'UPI Payment' : _noteController.text.trim();

    final result = await provider.sendUPIPayment(
      upiId: upiId,
      amount: amount,
      note: note,
      name: name,
      appPackage: _selectedAppPackage,
    );

    setState(() {
      _isLoading = false;
    });

    if (result == 'app_not_installed' || result == 'no_upi_app') {
      _showEmulatorSimulationDialog(upiId, name, amount, note);
    } else {
      _showPaymentResultDialog(result);
    }
  }

  void _showEmulatorSimulationDialog(String upiId, String name, double amount, String note) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF14192D),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0x1F00E5FF)),
          ),
          title: const Row(
            children: [
              Icon(Icons.developer_mode_rounded, color: Color(0xFF00E5FF)),
              SizedBox(width: 10),
              Text(
                'Simulator Mode',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Text(
            'The selected UPI application is not installed on this device (common on emulators).\n\nWould you like to simulate a payment result?',
            style: const TextStyle(color: Colors.white70, height: 1.4),
          ),
          actions: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00FFC2),
                    foregroundColor: const Color(0xFF090D1A),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    _showPaymentResultDialog('success');
                  },
                  child: const Text('Simulate SUCCESS', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFF5252),
                    side: const BorderSide(color: Color(0x33FF5252)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    _showPaymentResultDialog('failure');
                  },
                  child: const Text('Simulate FAILURE', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Color(0x1FFFFFFF)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    _showPaymentResultDialog('cancelled');
                  },
                  child: const Text('Simulate CANCELLED', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white38)),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  void _showPaymentResultDialog(String status) {
    IconData icon;
    Color color;
    String title;
    String message;

    switch (status) {
      case 'success':
        icon = Icons.check_circle_rounded;
        color = const Color(0xFF00FFC2);
        title = 'Payment Successful';
        message = 'The transaction was processed successfully by the UPI app.';
        break;
      case 'cancelled':
        icon = Icons.cancel_rounded;
        color = const Color(0xFFFFB300);
        title = 'Payment Cancelled';
        message = 'The transaction was cancelled or backed out by the user.';
        break;
      case 'failure':
      default:
        icon = Icons.error_rounded;
        color = const Color(0xFFFF5252);
        title = 'Payment Failed';
        message = 'The transaction could not be completed or was rejected.';
        break;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF101424),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: color.withAlpha(51), width: 1.5),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withAlpha(20),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 54),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF161B30),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: const BorderSide(color: Color(0x11FFFFFF)),
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Dismiss', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF161B30), Color(0xFF101424)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0x11FFFFFF)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.send_rounded, color: Color(0xFF00FFC2), size: 24),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SEND UPI PAYMENT',
                          style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Send funds securely using installed UPI apps.',
                          style: TextStyle(color: Colors.white30, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Form
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Recipient UPI ID
                  const Text(
                    'RECIPIENT UPI ID',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _upiIdController,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    keyboardType: TextInputType.emailAddress,
                    decoration: _buildInputDecoration(
                      hintText: 'e.g. user@okhdfcbank',
                      prefixIcon: Icons.alternate_email_rounded,
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'UPI ID is required';
                      }
                      if (!_isValidUpiId(val.trim())) {
                        return 'Enter a valid UPI ID (e.g. name@bank)';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),

                  // Recipient Name (Optional)
                  const Text(
                    'RECIPIENT NAME (OPTIONAL)',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _nameController,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    keyboardType: TextInputType.name,
                    decoration: _buildInputDecoration(
                      hintText: 'e.g. John Doe',
                      prefixIcon: Icons.person_outline_rounded,
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Amount & Note Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Amount
                      Expanded(
                        flex: 5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'AMOUNT (₹)',
                              style: TextStyle(
                                color: Colors.white38,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _amountController,
                              style: const TextStyle(
                                color: Color(0xFF00FFC2),
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                              ],
                              decoration: _buildInputDecoration(
                                hintText: '0.00',
                                prefixIcon: Icons.currency_rupee_rounded,
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Required';
                                }
                                final amt = double.tryParse(val.trim());
                                if (amt == null || amt <= 0) {
                                  return 'Invalid amount';
                                }
                                if (amt > 100000) {
                                  return 'Max ₹1,00,000';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Note
                      Expanded(
                        flex: 7,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'NOTE / MEMO',
                              style: TextStyle(
                                color: Colors.white38,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _noteController,
                              style: const TextStyle(color: Colors.white, fontSize: 15),
                              keyboardType: TextInputType.text,
                              decoration: _buildInputDecoration(
                                hintText: 'e.g. Dinner split',
                                prefixIcon: Icons.sticky_note_2_outlined,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // UPI App Selector
                  const Text(
                    'SELECT UPI APP',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 96,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: _upiApps.length,
                      separatorBuilder: (context, index) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final app = _upiApps[index];
                        final isSelected = _selectedAppPackage == app['package'];
                        final appColor = app['color'] as Color;

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedAppPackage = app['package'];
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            width: 90,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? appColor.withAlpha(20)
                                  : const Color(0xFF101424),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? appColor
                                    : const Color(0x11FFFFFF),
                                width: isSelected ? 1.8 : 1.0,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  app['icon'] as IconData,
                                  color: isSelected ? appColor : Colors.white54,
                                  size: 24,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  app['name'] as String,
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : Colors.white38,
                                    fontSize: 11,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Send Payment Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _processPayment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00FFC2),
                        foregroundColor: const Color(0xFF090D1A),
                        disabledBackgroundColor: const Color(0xFF1E2830),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 4,
                        shadowColor: const Color(0x6000FFC2),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(
                              color: Color(0xFF090D1A),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.flash_on_rounded, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Send Payment',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    required String hintText,
    required IconData prefixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: Colors.white24, fontSize: 14),
      prefixIcon: Icon(prefixIcon, color: Colors.white30, size: 20),
      filled: true,
      fillColor: const Color(0xFF101424),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0x11FFFFFF)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0x11FFFFFF)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF00FFC2), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFFF5252), width: 1.0),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFFF5252), width: 1.5),
      ),
      errorStyle: const TextStyle(color: Color(0xFFFF5252), fontSize: 11),
    );
  }
}
