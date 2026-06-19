import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:home_widget/home_widget.dart';
import '../models/payment_record.dart';
import 'dart:io';
import 'dart:math';
import 'package:path_provider/path_provider.dart';
import 'package:sensors_plus/sensors_plus.dart';

enum TtsStatus { initializing, initialized, speaking, failed }

class RawNotification {
  final String packageName;
  final String title;
  final String body;
  final DateTime timestamp;
  final String appName;

  RawNotification({
    required this.packageName,
    required this.title,
    required this.body,
    required this.timestamp,
    required this.appName,
  });
}

class ParsedPayment {
  final String type; // "incoming" or "outgoing"
  final double amount;
  final String? accountNumber;

  ParsedPayment({required this.type, required this.amount, this.accountNumber});

  dynamic operator [](String key) {
    if (key == 'type') return type;
    if (key == 'amount') return amount;
    if (key == 'accountNumber') return accountNumber;
    return null;
  }

  @override
  String toString() => "ParsedPayment(type: $type, amount: $amount, account: $accountNumber)";
}

ParsedPayment? parsePayment(String message) {
  final textLower = message.toLowerCase();

  String? type;
  if (textLower.contains("credited") ||
      textLower.contains("received") ||
      textLower.contains("added") ||
      textLower.contains("deposited")) {
    type = "incoming";
  } else if (textLower.contains("debited") ||
      textLower.contains("sent") ||
      textLower.contains("paid") ||
      textLower.contains("deducted") ||
      textLower.contains("transferred") ||
      textLower.contains("linked to vpa")) {
    type = "outgoing";
  }

  if (type == null) return null;

  var match = RegExp(
    r'(?:rs\.?\s*|inr\s*|₹\s*)([0-9,]+(?:\.[0-9]+)?)',
    caseSensitive: false,
  ).firstMatch(message);

  if (match == null) {
    match = RegExp(
      r'^\s*([0-9,]+(?:\.[0-9]+)?)\s+was\s+(?:credited|debited)',
      caseSensitive: false,
    ).firstMatch(message);
  }

  if (match == null) return null;

  final amtStr = match.group(1)?.replaceAll(',', '');
  if (amtStr == null) return null;

  final amount = double.tryParse(amtStr);
  if (amount == null || amount <= 0.0) return null;

  String? accountNumber;
  final accMatch = RegExp(r'(?:a/c|acct|account)[^\d]*([0-9]{3,})|[*xX]+([0-9]{3,})', caseSensitive: false).firstMatch(message);
  if (accMatch != null) {
    accountNumber = accMatch.group(1) ?? accMatch.group(2);
  }

  return ParsedPayment(type: type, amount: amount, accountNumber: accountNumber);
}

class PaymentProvider with ChangeNotifier {
  static const MethodChannel _channel = MethodChannel('com.upi.payment.alert/notification_listener');

  final FlutterTts _flutterTts = FlutterTts();
  FlutterTts get flutterTts => _flutterTts;
  late SharedPreferences _prefs;

  bool _isInitialized = false;
  bool _isListening = false;
  bool _isVoiceAlertEnabled = true;
  double _speechRate = 0.5;
  String _language = "en-IN";
  
  // Fix 1: Default Night Mode hours to 00:00 - 00:00 (disabled)
  int _nightModeStartHour = 0;
  int _nightModeEndHour = 0;
  
  bool _isNotificationPermissionGranted = false;
  bool _isListenerPermissionGranted = false;
  bool _isWakeWordEnabled = false;
  bool _isBatteryOptimizationDisabled = true;
  PaymentRecord? _lastPayment;
  List<PaymentRecord> _paymentHistory = [];
  double _balance = 0.0;
  String? _selectedAccount;

  // Shake / Sensors state
  DateTime? _lastShakeSpeakTime;

  // Live Notification Feed State
  final List<RawNotification> _rawFeed = [];
  bool _isMethodChannelWorking = false;

  TtsStatus _ttsStatus = TtsStatus.initializing;

  // Supported languages map
  final Map<String, String> _supportedLanguages = {
    'en-IN': 'English (India)',
    'hi-IN': 'Hindi (हिन्दी)',
    'ta-IN': 'Tamil (தமிழ்)',
    'te-IN': 'Telugu (తెలుగు)',
    'kn-IN': 'Kannada (ಕನ್ನಡ)',
    'ml-IN': 'Malayalam (മലയാളം)',
    'bn-IN': 'Bengali (বাংলা)',
  };

  String? get selectedAccount => _selectedAccount;
  
  List<String> get availableAccounts {
    final accounts = _paymentHistory
        .map((p) => p.accountNumber)
        .where((acc) => acc != null && acc.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();
    accounts.sort();
    return accounts;
  }

  void setSelectedAccount(String? account) {
    _selectedAccount = account;
    notifyListeners();
  }

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isListening => _isListening;
  bool get isVoiceAlertEnabled => _isVoiceAlertEnabled;
  double get speechRate => _speechRate;
  String get language => _language;
  int get nightModeStartHour => _nightModeStartHour;
  int get nightModeEndHour => _nightModeEndHour;
  
  // Fix 1: Active check logic where 00:00 - 00:00 means disabled (no muting)
  bool get isNightModeActive {
    if (_nightModeStartHour == 0 && _nightModeEndHour == 0) {
      return false;
    }
    final now = DateTime.now();
    final hour = now.hour;
    if (_nightModeStartHour <= _nightModeEndHour) {
      return hour >= _nightModeStartHour && hour < _nightModeEndHour;
    } else {
      return hour >= _nightModeStartHour || hour < _nightModeEndHour;
    }
  }

  Map<String, String> get supportedLanguages => _supportedLanguages;
  bool get isNotificationPermissionGranted => _isNotificationPermissionGranted;
  bool get isListenerPermissionGranted => _isListenerPermissionGranted;
  bool get isWakeWordEnabled => _isWakeWordEnabled;
  bool get isBatteryOptimizationDisabled => _isBatteryOptimizationDisabled;
  
  List<RawNotification> get rawFeed => _rawFeed;
  bool get isMethodChannelWorking => _isMethodChannelWorking;
  TtsStatus get ttsStatus => _ttsStatus;
  double get balance => _balance;

  PaymentRecord? get lastPayment => _lastPayment;
  
  List<PaymentRecord> get _filteredHistory {
    if (_selectedAccount == null) return _paymentHistory;
    return _paymentHistory.where((p) => p.accountNumber == _selectedAccount).toList();
  }

  PaymentRecord? get lastReceivedPayment {
    final rec = _filteredHistory.where((p) => !p.isSent);
    return rec.isEmpty ? null : rec.first;
  }
  PaymentRecord? get lastSentPayment {
    final sent = _filteredHistory.where((p) => p.isSent);
    return sent.isEmpty ? null : sent.first;
  }

  List<PaymentRecord> get paymentHistory => _filteredHistory;
  List<PaymentRecord> get receivedHistory => _filteredHistory.where((p) => !p.isSent).toList();
  List<PaymentRecord> get sentHistory => _filteredHistory.where((p) => p.isSent).toList();

  // Statistics Getters - Received
  double get totalReceivedToday {
    final now = DateTime.now();
    return _filteredHistory
        .where((p) => !p.isSent && p.timestamp.year == now.year && p.timestamp.month == now.month && p.timestamp.day == now.day)
        .fold(0.0, (sum, p) => sum + p.amount);
  }

  int get totalReceivedTransactionsToday {
    final now = DateTime.now();
    return _filteredHistory
        .where((p) => !p.isSent && p.timestamp.year == now.year && p.timestamp.month == now.month && p.timestamp.day == now.day)
        .length;
  }

  double get highestReceivedPayment {
    final rec = _filteredHistory.where((p) => !p.isSent);
    if (rec.isEmpty) return 0.0;
    return rec.map((p) => p.amount).reduce((curr, next) => curr > next ? curr : next);
  }

  // Statistics Getters - Sent
  double get totalSentToday {
    final now = DateTime.now();
    return _filteredHistory
        .where((p) => p.isSent && p.timestamp.year == now.year && p.timestamp.month == now.month && p.timestamp.day == now.day)
        .fold(0.0, (sum, p) => sum + p.amount);
  }

  int get totalSentTransactionsToday {
    final now = DateTime.now();
    return _filteredHistory
        .where((p) => p.isSent && p.timestamp.year == now.year && p.timestamp.month == now.month && p.timestamp.day == now.day)
        .length;
  }

  double get highestSentPayment {
    final sent = _filteredHistory.where((p) => p.isSent);
    if (sent.isEmpty) return 0.0;
    return sent.map((p) => p.amount).reduce((curr, next) => curr > next ? curr : next);
  }

  double get totalReceivedThisWeek {
    final now = DateTime.now();
    final startOfWeek = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    return _filteredHistory
        .where((p) => !p.isSent && p.timestamp.isAfter(startOfWeek))
        .fold(0.0, (sum, p) => sum + p.amount);
  }

  double get totalSentThisWeek {
    final now = DateTime.now();
    final startOfWeek = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    return _filteredHistory
        .where((p) => p.isSent && p.timestamp.isAfter(startOfWeek))
        .fold(0.0, (sum, p) => sum + p.amount);
  }

  double get totalReceivedThisMonth {
    final now = DateTime.now();
    return _filteredHistory
        .where((p) => !p.isSent && p.timestamp.year == now.year && p.timestamp.month == now.month)
        .fold(0.0, (sum, p) => sum + p.amount);
  }

  double get totalSentThisMonth {
    final now = DateTime.now();
    return _filteredHistory
        .where((p) => p.isSent && p.timestamp.year == now.year && p.timestamp.month == now.month)
        .fold(0.0, (sum, p) => sum + p.amount);
  }

  PaymentProvider() {
    debugPrint("[PaymentProvider] Constructor called. Initiating safe async startup...");
    Future.microtask(() => _safeInit());
  }

  Future<void> _safeInit() async {
    debugPrint("[PaymentProvider] _safeInit started.");
    try {
      // 1. SharedPreferences (load settings)
      try {
        debugPrint("[PaymentProvider] Initializing SharedPreferences...");
        _prefs = await SharedPreferences.getInstance();
        _isListening = _prefs.getBool('isListening') ?? false;
        _isVoiceAlertEnabled = _prefs.getBool('isVoiceAlertEnabled') ?? true;
        _speechRate = _prefs.getDouble('speechRate') ?? 0.5;
        _language = _prefs.getString('language') ?? 'en-IN';
        
        // Fix 1: Load night mode settings defaulting to 0
        _nightModeStartHour = _prefs.getInt('nightModeStartHour') ?? 0;
        _nightModeEndHour = _prefs.getInt('nightModeEndHour') ?? 0;
        _isWakeWordEnabled = _prefs.getBool('isWakeWordEnabled') ?? false;

        debugPrint("[PaymentProvider] Initializing Hive History...");
        final Box box = Hive.box('payments');
        final List<dynamic> list = box.get('history', defaultValue: []) as List<dynamic>;
        _paymentHistory = list
            .map((item) => PaymentRecord.fromMap(Map<String, dynamic>.from(item)))
            .toList();
        if (_paymentHistory.isNotEmpty) {
          _lastPayment = _paymentHistory.first;
        }
        _balance = (box.get('balance', defaultValue: 0.0) as num).toDouble();
        debugPrint("[PaymentProvider] Settings, payment history, and balance loaded successfully from Hive. Current Balance: $_balance");
      } catch (e) {
        debugPrint("[PaymentProvider] Initialization failed: $e");
      }

      // 2. Configure Method Channel Handler
      try {
        debugPrint("[PaymentProvider] Setting up MethodChannel call handler...");
        _channel.setMethodCallHandler((call) async {
          _isMethodChannelWorking = true;
          
          debugPrint("[PaymentProvider] Received MethodChannel call: ${call.method}");
          try {
            if (call.method == 'onPaymentNotification') {
              final Map<dynamic, dynamic> args = call.arguments;
              final double amount = (args['amount'] as num).toDouble();
              final String sender = args['sender'] as String? ?? 'Notification';
              final String appName = args['appName'] as String? ?? 'UPI App';
              final String rawText = args['rawText'] as String? ?? '';
              final String packageName = args['packageName'] as String? ?? '';
              final String title = args['title'] as String? ?? '';
              final String body = args['body'] as String? ?? '';
              final bool isSent = args['isSent'] as bool? ?? false;

              await handleNewPayment(
                amount: amount,
                sender: sender,
                appName: appName,
                rawText: rawText,
                packageName: packageName,
                title: title,
                body: body,
                isSent: isSent,
              );
            } else if (call.method == 'onWakeWordDetected') {
              _handleWakeWordDetected();
            } else if (call.method == 'replayLastPayment') {
              replayLastPayment();
            }
          } catch (e) {
            debugPrint("[PaymentProvider] Error processing notification: $e");
          }
        });
        debugPrint("[PaymentProvider] MethodChannel handler registered.");
      } catch (e) {
        debugPrint("[PaymentProvider] MethodChannel setup failed: $e");
      }

      // MARK AS INITIALIZED SO APP RENDERS HOME SCREEN IMMEDIATELY
      _isInitialized = true;
      debugPrint("[PaymentProvider] State set to initialized = true. Rendering will unlock.");
      notifyListeners();

      if (_isWakeWordEnabled) {
        _channel.invokeMethod('startWakeWord').catchError((e) {
          debugPrint("Failed to start wake word: $e");
        });
      }

      // 3. Initialize TTS asynchronously in the background
      _initTtsAsync();

      // 4. Check permissions asynchronously in the background
      _checkPermissionsAsync();

      // 5. Test MethodChannel Verification
      _verifyMethodChannel();

      // 6. Shake gesture initialization
      _initShakeDetection();
      
      // 7. Update Home Screen Widget
      _updateHomeWidget();
    } catch (e) {
      debugPrint("[PaymentProvider] Critical initialization exception caught: $e");
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> _verifyMethodChannel() async {
    try {
      final bool? listenerGranted = await _channel.invokeMethod<bool>('isListenerPermissionGranted');
      _isMethodChannelWorking = listenerGranted != null;
      notifyListeners();
    } catch (e) {
      debugPrint("[PaymentProvider] MethodChannel verification error: $e");
    }
  }

  Future<void> _initTtsAsync() async {
    try {
      _ttsStatus = TtsStatus.initializing;
      notifyListeners();
      debugPrint("[PaymentProvider] Starting background TTS initialization...");
      await _flutterTts.setLanguage(_language).timeout(const Duration(seconds: 2));
      await _flutterTts.setSpeechRate(_speechRate).timeout(const Duration(seconds: 2));
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      
      await _flutterTts.awaitSpeakCompletion(true);

      _flutterTts.setCompletionHandler(() {
        _ttsStatus = TtsStatus.initialized;
        _restoreVolume();
        notifyListeners();
      });
      
      _flutterTts.setCancelHandler(() {
        _ttsStatus = TtsStatus.initialized;
        _restoreVolume();
        notifyListeners();
      });

      _flutterTts.setErrorHandler((msg) {
        _ttsStatus = TtsStatus.failed;
        debugPrint("[PaymentProvider] TTS Error: $msg");
        _restoreVolume();
        notifyListeners();
      });

      _ttsStatus = TtsStatus.initialized;
      notifyListeners();
      debugPrint("[PaymentProvider] Background TTS engine initialized successfully.");
    } catch (e) {
      _ttsStatus = TtsStatus.failed;
      notifyListeners();
      debugPrint("[PaymentProvider] Background TTS initialization failed: $e");
    }
  }

  Future<void> _checkPermissionsAsync() async {
    try {
      debugPrint("[PaymentProvider] Starting background notification permission query...");
      final PermissionStatus status = await Permission.notification.status.timeout(const Duration(seconds: 2));
      _isNotificationPermissionGranted = status.isGranted;
    } catch (e) {
      debugPrint("[PaymentProvider] Background notification permission check failed: $e");
    }

    try {
      debugPrint("[PaymentProvider] Starting background listener permission MethodChannel query...");
      final bool? listenerGranted = await _channel.invokeMethod<bool>('isListenerPermissionGranted').timeout(const Duration(seconds: 2));
      _isListenerPermissionGranted = listenerGranted ?? false;
    } catch (e) {
      debugPrint("[PaymentProvider] Background listener permission check failed: $e");
    }

    try {
      debugPrint("[PaymentProvider] Starting background battery optimization check...");
      final bool? batteryDisabled = await _channel.invokeMethod<bool>('isBatteryOptimizationDisabled').timeout(const Duration(seconds: 2));
      _isBatteryOptimizationDisabled = batteryDisabled ?? true;
    } catch (e) {
      debugPrint("[PaymentProvider] Background battery optimization check failed: $e");
    }
    
    notifyListeners();
  }

  Future<void> checkPermissions() async {
    debugPrint("[PaymentProvider] Explicit checkPermissions requested.");
    try {
      final PermissionStatus status = await Permission.notification.status;
      _isNotificationPermissionGranted = status.isGranted;
    } catch (e) {
      debugPrint("[PaymentProvider] Notification permission check error: $e");
    }

    try {
      final bool? listenerGranted = await _channel.invokeMethod<bool>('isListenerPermissionGranted');
      _isListenerPermissionGranted = listenerGranted ?? false;
      _isMethodChannelWorking = listenerGranted != null;
    } on PlatformException catch (e) {
      debugPrint('Failed to check listener permission: ${e.message}');
      _isListenerPermissionGranted = false;
    }

    try {
      final bool? batteryDisabled = await _channel.invokeMethod<bool>('isBatteryOptimizationDisabled');
      _isBatteryOptimizationDisabled = batteryDisabled ?? true;
    } catch (e) {
      debugPrint('Failed to check battery optimization status: $e');
    }

    notifyListeners();
  }

  Future<void> requestNotificationPermission() async {
    try {
      final PermissionStatus status = await Permission.notification.request();
      _isNotificationPermissionGranted = status.isGranted;
    } catch (e) {
      debugPrint("[PaymentProvider] Request notification permission error: $e");
    }
    notifyListeners();
  }

  Future<void> requestListenerPermission() async {
    try {
      await _channel.invokeMethod('openListenerSettings');
    } on PlatformException catch (e) {
      debugPrint('Failed to open listener settings: ${e.message}');
    }
    await checkPermissions();
  }

  Future<void> requestIgnoreBatteryOptimization() async {
    try {
      await _channel.invokeMethod('requestIgnoreBatteryOptimization');
    } on PlatformException catch (e) {
      debugPrint('Failed to request ignore battery optimizations: ${e.message}');
    }
    await checkPermissions();
  }

  Future<void> toggleListening(bool value) async {
    _isListening = value;
    try {
      await _prefs.setBool('isListening', _isListening);
    } catch (e) {
      debugPrint("[PaymentProvider] Saving listening state failed: $e");
    }
    notifyListeners();
  }

  Future<void> toggleVoiceAlert(bool value) async {
    _isVoiceAlertEnabled = value;
    try {
      await _prefs.setBool('isVoiceAlertEnabled', _isVoiceAlertEnabled);
    } catch (e) {
      debugPrint("[PaymentProvider] Saving voice alert state failed: $e");
    }
    notifyListeners();
  }

  Future<void> toggleWakeWord(bool value) async {
    _isWakeWordEnabled = value;
    try {
      await _prefs.setBool('isWakeWordEnabled', value);
      if (value) {
        await _channel.invokeMethod('startWakeWord');
      } else {
        await _channel.invokeMethod('stopWakeWord');
      }
    } catch (e) {
      debugPrint("[PaymentProvider] Saving wake word state failed: $e");
    }
    notifyListeners();
  }

  Future<void> setSpeechRate(double rate) async {
    _speechRate = rate;
    try {
      await _prefs.setDouble('speechRate', rate);
      await _flutterTts.setSpeechRate(rate);
    } catch (e) {
      debugPrint("[PaymentProvider] Applying speech rate failed: $e");
    }
    notifyListeners();
  }

  Future<void> setLanguage(String langCode) async {
    if (_supportedLanguages.containsKey(langCode)) {
      _language = langCode;
      try {
        await _prefs.setString('language', langCode);
        await _flutterTts.setLanguage(langCode);
      } catch (e) {
        debugPrint("[PaymentProvider] Applying language failed: $e");
      }
      notifyListeners();
    }
  }

  Future<void> setNightModeStartHour(int hour) async {
    _nightModeStartHour = hour;
    try {
      await _prefs.setInt('nightModeStartHour', hour);
    } catch (e) {
      debugPrint("[PaymentProvider] Applying night mode start hour failed: $e");
    }
    notifyListeners();
  }

  Future<void> setNightModeEndHour(int hour) async {
    _nightModeEndHour = hour;
    try {
      await _prefs.setInt('nightModeEndHour', hour);
    } catch (e) {
      debugPrint("[PaymentProvider] Applying night mode end hour failed: $e");
    }
    notifyListeners();
  }

  final Set<String> _seenFingerprints = {};
  String _currentDateStr = "";

  Future<void> handleNewPayment({
    required double amount,
    required String sender,
    required String appName,
    required String rawText,
    required String packageName,
    required String title,
    required String body,
    required bool isSent,
  }) async {
    if (!_isListening) {
      debugPrint("[PaymentProvider] Listening is paused. Ignoring raw notification.");
      _restoreVolume();
      return;
    }

    if (title.isEmpty || body.isEmpty) {
      _restoreVolume();
      return;
    }

    final parsed = parsePayment(body);
    if (parsed == null) {
      _restoreVolume();
      return;
    }

    final actualAmount = parsed.amount > 0.0 ? parsed.amount : amount;
    final resolvedSender = (sender == 'Notification' || sender.isEmpty) ? (title.isNotEmpty ? title : 'UPI User') : sender;
    final finalAppName = appName == 'UPI App' ? 'UPI' : appName;

    final now = DateTime.now();
    final dateStr = now.toIso8601String().substring(0, 10);
    
    if (_currentDateStr != dateStr) {
      _seenFingerprints.clear();
      _currentDateStr = dateStr;
    }

    // High fidelity deduplication fingerprint (amount + party/sender + type + date)
    final fingerprint = "${actualAmount}_${resolvedSender}_${isSent ? 'sent' : 'received'}_$dateStr";
    if (_seenFingerprints.contains(fingerprint)) {
      debugPrint("[PaymentProvider] Duplicate fingerprint for today: $fingerprint. Dropping.");
      _restoreVolume();
      return;
    }
    _seenFingerprints.add(fingerprint);

    final speech = _getSpeechString(actualAmount, isSent ? 'outgoing' : 'incoming', finalAppName, resolvedSender);
    
    if (isNightModeActive) {
      debugPrint("[PaymentProvider] Night mode is active. Skipping TTS.");
    } else if (_isVoiceAlertEnabled) {
      _boostVolume();
      _flutterTts.speak(speech);
    }

    // Live Notification Feed logger
    final rawNotif = RawNotification(
      packageName: packageName,
      title: "UPI Payment",
      body: speech,
      timestamp: now,
      appName: finalAppName,
    );
    _rawFeed.insert(0, rawNotif);
    if (_rawFeed.length > 50) {
      _rawFeed.removeLast();
    }

    // Store in Hive
    try {
      final newPayment = PaymentRecord(
        amount: actualAmount,
        sender: resolvedSender,
        appName: finalAppName,
        timestamp: now,
        rawText: speech,
        packageName: packageName,
        title: "UPI Payment",
        body: speech,
        isSent: isSent,
        accountNumber: parsed.accountNumber,
      );

      _lastPayment = newPayment;
      _paymentHistory.insert(0, newPayment);

      if (_paymentHistory.length > 100) {
        _paymentHistory = _paymentHistory.sublist(0, 100);
      }

      final Box box = Hive.box('payments');
      await box.put('history', _paymentHistory.map((e) => e.toMap()).toList());

      if (isSent) {
        _balance -= actualAmount;
      } else {
        _balance += actualAmount;
      }
      await box.put('balance', _balance);
    } catch (e) {
      debugPrint("[PaymentProvider] Failed to store record or update balance: $e");
    }

    _updateHomeWidget();
    notifyListeners();
  }

  Future<void> replayLastPayment() async {
    if (_lastPayment != null) {
      debugPrint("[PaymentProvider] Replaying last payment...");
      _boostVolume();
      await _flutterTts.speak(_lastPayment!.rawText);
    } else {
      debugPrint("[PaymentProvider] No payment to replay.");
      await _flutterTts.speak("No recent payments detected");
    }
  }

  Future<void> _updateHomeWidget() async {
    try {
      final receivedToday = totalReceivedToday;
      final sentToday = totalSentToday;
      
      await HomeWidget.saveWidgetData<String>('total_received', '₹${receivedToday.toStringAsFixed(0)}');
      await HomeWidget.saveWidgetData<String>('total_sent', '₹${sentToday.toStringAsFixed(0)}');
      
      await HomeWidget.updateWidget(
        name: 'PaymentWidgetProvider',
        androidName: 'PaymentWidgetProvider',
      );
    } catch (e) {
      debugPrint("[PaymentProvider] Failed to update home widget: $e");
    }
  }

  String _getSpeechString(double amount, String type, String appName, String sender) {
    final formattedAmount = amount % 1 == 0 ? amount.toInt() : amount;
    final isIncoming = type == 'incoming';

    switch (_language) {
      case 'hi-IN':
        return isIncoming
            ? "$sender से $appName के माध्यम से $formattedAmount रुपये प्राप्त हुए"
            : "$sender को $appName के माध्यम से $formattedAmount रुपये भेजे गए";
      case 'ta-IN':
        return isIncoming
            ? "$sender இடமிருந்து $appName வழியாக $formattedAmount ரூபாய் கிடைத்தது"
            : "$sender க்கு $appName வழியாக $formattedAmount ரூபாய் அனுப்பினோம்";
      case 'te-IN':
        return isIncoming
            ? "$sender నుండి $appName ద్వారా $formattedAmount రూపాయలు వచ్చాయి"
            : "$sender కి $appName ద్వారా $formattedAmount రూపాయలు పంపబడ్డాయి";
      case 'kn-IN':
        return isIncoming
            ? "$sender ರಿಂದ $appName ಮೂಲಕ $formattedAmount ರೂಪಾಯಿ ಬಂದಿದೆ"
            : "$sender ಗೆ $appName ಮೂಲಕ $formattedAmount ರೂಪಾಯಿ ಕಳಿಸಲಾಗಿದೆ";
      case 'ml-IN':
        return isIncoming
            ? "$sender-ൽ നിന്ന് $appName വഴി $formattedAmount രൂപ ലഭിച്ചു"
            : "$sender-ലേക്ക് $appName വഴി $formattedAmount രൂപ അയച്ചു";
      case 'bn-IN':
        return isIncoming
            ? "$sender এর থেকে $appName এর মাধ্যমে $formattedAmount টাকা পাওয়া গেছে"
            : "$sender কে $appName এর মাধ্যমে $formattedAmount টাকা পাঠানো হয়েছে";
      case 'en-IN':
      default:
        final word = amount == 1.0 ? "rupee" : "rupees";
        return isIncoming
            ? "Received $formattedAmount $word via $appName from $sender"
            : "Sent $formattedAmount $word via $appName to $sender";
    }
  }

  Future<void> testSpeak({bool isSent = false}) async {
    final speech = _getSpeechString(100.0, isSent ? 'outgoing' : 'incoming', 'GPay', 'Test User');
    _boostVolume();
    _flutterTts.speak(speech);
  }

  Future<void> speakPaymentAmount(double amount, bool isSent) async {
    final speech = _getSpeechString(amount, isSent ? 'outgoing' : 'incoming', 'UPI', 'User');
    _boostVolume();
    await _flutterTts.speak(speech);
  }

  Future<void> testTTS(bool isSent) async {
    final speech = _getSpeechString(100.0, 'incoming', 'GPay', 'Tester');
    _boostVolume();
    _flutterTts.speak(speech);
  }

  Future<void> testVoice() async {
    final speech = _getSpeechString(100.0, 'incoming', 'GPay', 'Tester');
    _boostVolume();
    _flutterTts.speak(speech);
  }

  Future<void> updateBalance(double newBalance) async {
    _balance = newBalance;
    try {
      final Box box = Hive.box('payments');
      await box.put('balance', _balance);
    } catch (e) {
      debugPrint("[PaymentProvider] Saving balance failed: $e");
    }
    notifyListeners();
  }

  void _handleWakeWordDetected() {
    debugPrint("[PaymentProvider] Wake word detected!");
    if (_lastPayment != null) {
      _boostVolume();
      _flutterTts.speak(_lastPayment!.rawText);
    } else {
      _flutterTts.speak("No recent transactions found");
    }
  }

  Future<void> _boostVolume() async {
    try {
      await _channel.invokeMethod('boostVolume');
    } catch (e) {
      debugPrint("[PaymentProvider] Failed to boost volume: $e");
    }
  }

  Future<void> _restoreVolume() async {
    try {
      await _channel.invokeMethod('restoreVolume');
    } catch (e) {
      debugPrint("[PaymentProvider] Failed to restore volume: $e");
    }
  }

  void _initShakeDetection() {
    userAccelerometerEventStream().listen((UserAccelerometerEvent event) {
      final double acceleration = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
      if (acceleration > 15.0) {
        _handleShake();
      }
    });
  }

  void _handleShake() {
    if (_lastPayment == null) return;
    final now = DateTime.now();
    if (now.difference(_lastPayment!.timestamp).inMinutes >= 5) return;
    if (_lastShakeSpeakTime != null && now.difference(_lastShakeSpeakTime!).inSeconds < 3) return;
    _lastShakeSpeakTime = now;

    _boostVolume();
    _flutterTts.speak(_lastPayment!.rawText);
  }

  Future<String?> exportHistoryToCsv() async {
    try {
      final history = _paymentHistory;
      if (history.isEmpty) return null;

      final csvContent = StringBuffer();
      csvContent.writeln('Date,Time,Type,Amount,Source');
      for (final record in history) {
        final date = "${record.timestamp.year}-${record.timestamp.month.toString().padLeft(2, '0')}-${record.timestamp.day.toString().padLeft(2, '0')}";
        final time = "${record.timestamp.hour.toString().padLeft(2, '0')}:${record.timestamp.minute.toString().padLeft(2, '0')}:${record.timestamp.second.toString().padLeft(2, '0')}";
        final type = record.isSent ? 'Outgoing' : 'Incoming';
        final amount = record.amount.toStringAsFixed(2);
        final source = record.appName;
        csvContent.writeln('$date,$time,$type,$amount,"$source"');
      }

      Directory? downloadsDir;
      if (Platform.isAndroid) {
        downloadsDir = Directory('/storage/emulated/0/Download');
        if (!await downloadsDir.exists()) {
          downloadsDir = await getDownloadsDirectory();
        }
      } else {
        downloadsDir = await getDownloadsDirectory();
      }
      downloadsDir ??= await getApplicationDocumentsDirectory();

      final file = File('${downloadsDir.path}/upi_history.csv');
      await file.writeAsString(csvContent.toString());
      return file.path;
    } catch (e) {
      debugPrint("[PaymentProvider] Export failed: $e");
      return null;
    }
  }

  Future<void> clearHistory() async {
    _paymentHistory.clear();
    _rawFeed.clear();
    _lastPayment = null;
    try {
      final Box box = Hive.box('payments');
      await box.delete('history');
    } catch (e) {
      debugPrint("[PaymentProvider] Clearing history cache failed: $e");
    }
    notifyListeners();
  }
}
