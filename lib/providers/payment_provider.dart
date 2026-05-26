import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/payment_record.dart';

class PaymentProvider with ChangeNotifier {
  static const MethodChannel _channel = MethodChannel('com.upi.payment.alert/notification_listener');

  final FlutterTts _flutterTts = FlutterTts();
  late SharedPreferences _prefs;

  bool _isInitialized = false;
  bool _isListening = false;
  bool _isVoiceAlertEnabled = true;
  bool _isNotificationPermissionGranted = false;
  bool _isListenerPermissionGranted = false;
  PaymentRecord? _lastPayment;
  List<PaymentRecord> _paymentHistory = [];

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isListening => _isListening;
  bool get isVoiceAlertEnabled => _isVoiceAlertEnabled;
  bool get isNotificationPermissionGranted => _isNotificationPermissionGranted;
  bool get isListenerPermissionGranted => _isListenerPermissionGranted;
  PaymentRecord? get lastPayment => _lastPayment;
  List<PaymentRecord> get paymentHistory => _paymentHistory;

  PaymentProvider() {
    _init();
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();

    // Load persisted settings
    _isListening = _prefs.getBool('isListening') ?? false;
    _isVoiceAlertEnabled = _prefs.getBool('isVoiceAlertEnabled') ?? true;

    // Load payment history
    final String? historyJson = _prefs.getString('paymentHistory');
    if (historyJson != null) {
      try {
        final List<dynamic> decoded = json.decode(historyJson);
        _paymentHistory = decoded
            .map((item) => PaymentRecord.fromMap(Map<String, dynamic>.from(item)))
            .toList();
        if (_paymentHistory.isNotEmpty) {
          _lastPayment = _paymentHistory.first;
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error parsing payment history: $e');
        }
      }
    }

    // Configure Method Channel Handler to receive notifications from Android
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onPaymentNotification') {
        final Map<dynamic, dynamic> args = call.arguments;
        final double amount = (args['amount'] as num).toDouble();
        final String sender = args['sender'] as String? ?? 'UPI Payment';
        final String appName = args['appName'] as String? ?? 'UPI App';
        final String rawText = args['rawText'] as String? ?? '';
        await handleNewPayment(amount, sender, appName, rawText);
      }
    });

    // Configure TTS
    await _flutterTts.setLanguage("en-IN");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);

    // Initial permissions check
    await checkPermissions();

    _isInitialized = true;
    notifyListeners();
  }

  // Check all permissions
  Future<void> checkPermissions() async {
    // 1. Check standard notification permission (relevant on Android 13+)
    final PermissionStatus status = await Permission.notification.status;
    _isNotificationPermissionGranted = status.isGranted;

    // 2. Check Android Notification Listener permission via Method Channel
    try {
      final bool? listenerGranted = await _channel.invokeMethod<bool>('isListenerPermissionGranted');
      _isListenerPermissionGranted = listenerGranted ?? false;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        print('Failed to check listener permission: ${e.message}');
      }
      _isListenerPermissionGranted = false;
    }

    notifyListeners();
  }

  // Request standard notification permission
  Future<void> requestNotificationPermission() async {
    final PermissionStatus status = await Permission.notification.request();
    _isNotificationPermissionGranted = status.isGranted;
    notifyListeners();
  }

  // Request Notification Listener Permission (Opens Android Settings)
  Future<void> requestListenerPermission() async {
    try {
      await _channel.invokeMethod('openListenerSettings');
    } on PlatformException catch (e) {
      if (kDebugMode) {
        print('Failed to open listener settings: ${e.message}');
      }
    }
    // Check permission again after returning (usually user goes back to app)
    await checkPermissions();
  }

  // Toggle listening state
  Future<void> toggleListening(bool value) async {
    _isListening = value;
    await _prefs.setBool('isListening', _isListening);
    notifyListeners();
  }

  // Toggle Voice Alert
  Future<void> toggleVoiceAlert(bool value) async {
    _isVoiceAlertEnabled = value;
    await _prefs.setBool('isVoiceAlertEnabled', _isVoiceAlertEnabled);
    notifyListeners();
  }

  // Process a new detected payment
  Future<void> handleNewPayment(double amount, String sender, String appName, String rawText) async {
    // If not listening, ignore payments
    if (!_isListening) return;

    final newPayment = PaymentRecord(
      amount: amount,
      sender: sender,
      appName: appName,
      timestamp: DateTime.now(),
      rawText: rawText,
    );

    _lastPayment = newPayment;
    _paymentHistory.insert(0, newPayment);

    // Keep history limited to 50 items
    if (_paymentHistory.length > 50) {
      _paymentHistory = _paymentHistory.sublist(0, 50);
    }

    // Persist history
    final String historyJson = json.encode(_paymentHistory.map((e) => e.toMap()).toList());
    await _prefs.setString('paymentHistory', historyJson);

    notifyListeners();

    // Trigger voice alert if enabled
    if (_isVoiceAlertEnabled) {
      await speakAlert(amount, sender);
    }
  }

  // Speak the payment details using TTS
  Future<void> speakAlert(double amount, String sender) async {
    // Standard alert text: "Received Rupees X from Y"
    final String text = "Received ${amount.toInt()} Rupees from $sender";
    await _flutterTts.speak(text);
  }

  // Clear payment history
  Future<void> clearHistory() async {
    _paymentHistory.clear();
    _lastPayment = null;
    await _prefs.remove('paymentHistory');
    notifyListeners();
  }

  // Mock a payment notification for testing/demo purposes
  Future<void> mockPaymentReceived({required double amount, required String sender, required String appName}) async {
    final String rawText = "Mock: Rs. $amount received from $sender via $appName";
    await handleNewPayment(amount, sender, appName, rawText);
  }

  // Initiate UPI payment sending
  Future<String> sendUPIPayment({
    required String upiId,
    required double amount,
    required String note,
    String? name,
    String? appPackage,
  }) async {
    try {
      final String? result = await _channel.invokeMethod<String>('initiatePayment', {
        'upiId': upiId,
        'amount': amount.toStringAsFixed(2),
        'note': note,
        'name': name ?? 'Recipient',
        'appPackage': appPackage,
      });
      return result ?? 'failure';
    } on PlatformException catch (e) {
      if (e.code == 'APP_NOT_FOUND') {
        return 'app_not_installed';
      }
      if (e.code == 'NO_UPI_APP') {
        return 'no_upi_app';
      }
      return 'failure';
    } catch (e) {
      return 'failure';
    }
  }
}
