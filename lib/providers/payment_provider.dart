import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:home_widget/home_widget.dart';
import '../models/payment_record.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

enum TtsStatus { initializing, initialized, speaking, failed }

const ttsAnnouncementDelay = Duration(milliseconds: 1000);

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
  final String? upiRef;

  ParsedPayment({required this.type, required this.amount, this.accountNumber, this.upiRef});

  dynamic operator [](String key) {
    if (key == 'type') return type;
    if (key == 'amount') return amount;
    if (key == 'accountNumber') return accountNumber;
    if (key == 'upiRef') return upiRef;
    return null;
  }

  @override
  String toString() => "ParsedPayment(type: $type, amount: $amount, account: $accountNumber, upiRef: $upiRef)";
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

  match ??= RegExp(
    r'^\s*([0-9,]+(?:\.[0-9]+)?)\s+was\s+(?:credited|debited)',
    caseSensitive: false,
  ).firstMatch(message);

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

  String? upiRef;
  final refMatch = RegExp(
    r'(?:upi\s*ref|ref\s*no|reference\s*no|ref|txn\s*id|transaction\s*id)[^\d]*(\d{8,18})',
    caseSensitive: false,
  ).firstMatch(message);
  if (refMatch != null) {
    upiRef = refMatch.group(1);
  }

  return ParsedPayment(type: type, amount: amount, accountNumber: accountNumber, upiRef: upiRef);
}

class PaymentProvider with ChangeNotifier {
  static const MethodChannel _channel = MethodChannel('com.upi.payment.alert/notification_listener');

  final FlutterTts _flutterTts = FlutterTts();
  FlutterTts get flutterTts => _flutterTts;
  late SharedPreferences _prefs;

  bool _isInitialized = false;
  bool _isListening = false;
  bool _isVoiceAlertEnabled = true;
  double _speechRate = 0.3;
  String _language = "en-IN";
  bool _hasAcceptedPrivacyNotice = false;
  bool _isCheckingPermissions = false;
  double _ttsVolume = 0.5;
  
  int _nightModeStartHour = 0;
  int _nightModeStartMinute = 0;
  int _nightModeEndHour = 0;
  int _nightModeEndMinute = 0;
  
  bool _isNotificationPermissionGranted = false;
  bool _isListenerPermissionGranted = false;
  bool _isBatteryOptimizationDisabled = true;
  bool _batteryOptimizationSkipped = false;
  PaymentRecord? _lastPayment;
  List<PaymentRecord> _paymentHistory = [];
  double _balance = 0.0;
  String? _selectedAccount;
  String _voiceFilterAccount = 'All Accounts';
  final Map<String, DateTime> _seenFingerprints = {};
  final Map<String, String> _seenNotificationKeys = {};
  final Set<String> _seenUpiRefs = {};
  bool _isLightMode = true;

  // Caching layer for performance optimization
  List<PaymentRecord> _filteredHistoryCache = [];
  List<PaymentRecord> _receivedHistoryCache = [];
  List<PaymentRecord> _sentHistoryCache = [];
  PaymentRecord? _lastReceivedPaymentCache;
  PaymentRecord? _lastSentPaymentCache;

  double _totalReceivedTodayCache = 0.0;
  int _totalReceivedTransactionsTodayCache = 0;
  double _highestReceivedPaymentCache = 0.0;

  double _totalSentTodayCache = 0.0;
  int _totalSentTransactionsTodayCache = 0;
  double _highestSentPaymentCache = 0.0;

  double _totalReceivedThisWeekCache = 0.0;
  double _totalSentThisWeekCache = 0.0;
  double _totalReceivedThisMonthCache = 0.0;
  double _totalSentThisMonthCache = 0.0;




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
    _updateCache();
    notifyListeners();
  }

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isListening => _isListening;
  bool get hasAcceptedPrivacyNotice => _hasAcceptedPrivacyNotice;
  bool get isVoiceAlertEnabled => _isVoiceAlertEnabled;
  double get speechRate => _speechRate;
  double get ttsVolume => _ttsVolume;
  String get language => _language;
  int get nightModeStartHour => _nightModeStartHour;
  int get nightModeStartMinute => _nightModeStartMinute;
  int get nightModeEndHour => _nightModeEndHour;
  int get nightModeEndMinute => _nightModeEndMinute;
  
  bool get isNightModeActive {
    if (_nightModeStartHour == _nightModeEndHour && _nightModeStartMinute == _nightModeEndMinute) {
      return false;
    }
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;
    final startMinutes = _nightModeStartHour * 60 + _nightModeStartMinute;
    final endMinutes = _nightModeEndHour * 60 + _nightModeEndMinute;

    if (startMinutes <= endMinutes) {
      return currentMinutes >= startMinutes && currentMinutes < endMinutes;
    } else {
      return currentMinutes >= startMinutes || currentMinutes < endMinutes;
    }
  }

  Map<String, String> get supportedLanguages => _supportedLanguages;
  bool get isNotificationPermissionGranted => _isNotificationPermissionGranted;
  bool get isListenerPermissionGranted => _isListenerPermissionGranted;
  bool get isBatteryOptimizationDisabled => _isBatteryOptimizationDisabled;
  bool get batteryOptimizationSkipped => _batteryOptimizationSkipped;
  
  List<RawNotification> get rawFeed => _rawFeed;
  bool get isMethodChannelWorking => _isMethodChannelWorking;
  TtsStatus get ttsStatus => _ttsStatus;
   double get balance => _balance;
  String get voiceFilterAccount => _voiceFilterAccount;
  bool get isLightMode => _isLightMode;

  Future<void> toggleThemeMode(bool isLight) async {
    _isLightMode = isLight;
    try {
      await _prefs.setBool('isLightMode', isLight);
    } catch (e) {
      debugPrint("[PaymentProvider] Saving theme mode failed: $e");
    }
    notifyListeners();
  }

  Future<void> setVoiceFilterAccount(String account) async {
    _voiceFilterAccount = account;
    try {
      await _prefs.setString('voiceFilterAccount', account);
    } catch (e) {
      debugPrint("[PaymentProvider] Saving voice filter account failed: $e");
    }
    notifyListeners();
  }

  PaymentRecord? get lastPayment => _lastPayment;
  

  PaymentRecord? get lastReceivedPayment => _lastReceivedPaymentCache;
  PaymentRecord? get lastSentPayment => _lastSentPaymentCache;

  List<PaymentRecord> get paymentHistory => _filteredHistoryCache;
  List<PaymentRecord> get receivedHistory => _receivedHistoryCache;
  List<PaymentRecord> get sentHistory => _sentHistoryCache;

  // Statistics Getters - Received
  double get totalReceivedToday => _totalReceivedTodayCache;
  int get totalReceivedTransactionsToday => _totalReceivedTransactionsTodayCache;
  double get highestReceivedPayment => _highestReceivedPaymentCache;

  // Statistics Getters - Sent
  double get totalSentToday => _totalSentTodayCache;
  int get totalSentTransactionsToday => _totalSentTransactionsTodayCache;
  double get highestSentPayment => _highestSentPaymentCache;

  double get totalReceivedThisWeek => _totalReceivedThisWeekCache;
  double get totalSentThisWeek => _totalSentThisWeekCache;
  double get totalReceivedThisMonth => _totalReceivedThisMonthCache;
  double get totalSentThisMonth => _totalSentThisMonthCache;

  PaymentProvider({SharedPreferences? prefs}) {
    debugPrint("[PaymentProvider] Constructor called. Initiating safe async startup...");
    if (prefs != null) {
      _prefs = prefs;
      _isListening = _prefs.getBool('isListening') ?? false;
      _isVoiceAlertEnabled = _prefs.getBool('isVoiceAlertEnabled') ?? true;
      _speechRate = _prefs.getDouble('speechRate') ?? 0.3;
      _language = _prefs.getString('language') ?? 'en-IN';
      _nightModeStartHour = _prefs.getInt('nightModeStartHour') ?? 0;
      _nightModeStartMinute = _prefs.getInt('nightModeStartMinute') ?? 0;
      _nightModeEndHour = _prefs.getInt('nightModeEndHour') ?? 0;
      _nightModeEndMinute = _prefs.getInt('nightModeEndMinute') ?? 0;
      _voiceFilterAccount = _prefs.getString('voiceFilterAccount') ?? 'All Accounts';
      _isLightMode = _prefs.getBool('isLightMode') ?? true;
      _batteryOptimizationSkipped = _prefs.getBool('battery_optimization_skipped') ?? false;
      _hasAcceptedPrivacyNotice = _prefs.getBool('hasAcceptedPrivacyNotice') ?? false;
      if (_prefs.containsKey('ttsVolume')) {
        _ttsVolume = _prefs.getDouble('ttsVolume')!;
      } else {
        final isExisting = _prefs.containsKey('isVoiceAlertEnabled') || _prefs.containsKey('speechRate');
        _ttsVolume = isExisting ? 0.75 : 0.5;
      }
    }
    Future.microtask(() => _safeInit(preloaded: prefs != null));
  }

  Future<void> _safeInit({bool preloaded = false}) async {
    debugPrint("[PaymentProvider] _safeInit started. Preloaded: $preloaded");
    try {
      // 1. SharedPreferences (load settings)
      try {
        if (!preloaded) {
          debugPrint("[PaymentProvider] Initializing SharedPreferences...");
          _prefs = await SharedPreferences.getInstance();
          _isListening = _prefs.getBool('isListening') ?? false;
          _isVoiceAlertEnabled = _prefs.getBool('isVoiceAlertEnabled') ?? true;
          _speechRate = _prefs.getDouble('speechRate') ?? 0.3;
          _language = _prefs.getString('language') ?? 'en-IN';
          
          _nightModeStartHour = _prefs.getInt('nightModeStartHour') ?? 0;
          _nightModeStartMinute = _prefs.getInt('nightModeStartMinute') ?? 0;
          _nightModeEndHour = _prefs.getInt('nightModeEndHour') ?? 0;
          _nightModeEndMinute = _prefs.getInt('nightModeEndMinute') ?? 0;
          _voiceFilterAccount = _prefs.getString('voiceFilterAccount') ?? 'All Accounts';
          _isLightMode = _prefs.getBool('isLightMode') ?? true;
          _batteryOptimizationSkipped = _prefs.getBool('battery_optimization_skipped') ?? false;
          _hasAcceptedPrivacyNotice = _prefs.getBool('hasAcceptedPrivacyNotice') ?? false;
          if (_prefs.containsKey('ttsVolume')) {
            _ttsVolume = _prefs.getDouble('ttsVolume')!;
          } else {
            final isExisting = _prefs.containsKey('isVoiceAlertEnabled') || _prefs.containsKey('speechRate');
            _ttsVolume = isExisting ? 0.75 : 0.5;
          }
        }

        debugPrint("[PaymentProvider] Initializing Hive History...");
        final Box box = Hive.box('payments');
        final List<dynamic> list = box.get('history', defaultValue: []) as List<dynamic>;
        _paymentHistory = list
            .map((item) => PaymentRecord.fromMap(Map<String, dynamic>.from(item)))
            .toList();
        if (_paymentHistory.isNotEmpty) {
          _lastPayment = _paymentHistory.first;
        }
        _updateCache();
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
              debugPrint("[PaymentProvider] MethodChannel onPaymentNotification arguments: $args");
              final double amount = (args['amount'] as num).toDouble();
              final String sender = args['sender'] as String? ?? 'Notification';
              final String appName = args['appName'] as String? ?? 'UPI App';
              final String rawText = args['rawText'] as String? ?? '';
              final String packageName = args['packageName'] as String? ?? '';
              final String title = args['title'] as String? ?? '';
              final String body = args['body'] as String? ?? '';
              final bool isSent = args['isSent'] as bool? ?? false;
              final String? notificationKey = args['notificationKey'] as String?;

              await handleNewPayment(
                amount: amount,
                sender: sender,
                appName: appName,
                rawText: rawText,
                packageName: packageName,
                title: title,
                body: body,
                isSent: isSent,
                notificationKey: notificationKey,
              );
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

      // 3. Initialize TTS asynchronously in the background
      _initTtsAsync();

      // 4. Check permissions asynchronously in the background
      _checkPermissionsAsync();

      // 5. Test MethodChannel Verification
      _verifyMethodChannel();


      
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
      await _flutterTts.setVolume(_ttsVolume).timeout(const Duration(seconds: 2));
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
    if (_isCheckingPermissions) {
      debugPrint("[PaymentProvider] _checkPermissionsAsync already in progress. Skipping.");
      return;
    }
    _isCheckingPermissions = true;
    try {
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
    } finally {
      _isCheckingPermissions = false;
    }
  }

  Future<void> checkPermissions() async {
    if (_isCheckingPermissions) {
      debugPrint("[PaymentProvider] checkPermissions already in progress. Skipping.");
      return;
    }
    _isCheckingPermissions = true;
    debugPrint("[PaymentProvider] Explicit checkPermissions requested.");
    try {
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
    } finally {
      _isCheckingPermissions = false;
    }
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

  Future<void> openBatteryOptimizationSettings() async {
    try {
      await _channel.invokeMethod('openBatteryOptimizationSettings');
    } on PlatformException catch (e) {
      debugPrint('Failed to open battery optimization settings: ${e.message}');
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

  Future<void> acceptPrivacyNotice() async {
    _hasAcceptedPrivacyNotice = true;
    try {
      await _prefs.setBool('hasAcceptedPrivacyNotice', true);
    } catch (e) {
      debugPrint("[PaymentProvider] Saving privacy notice state failed: $e");
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

  Future<void> setTtsVolume(double volume) async {
    _ttsVolume = volume;
    try {
      await _prefs.setDouble('ttsVolume', volume);
      await _flutterTts.setVolume(volume);
    } catch (e) {
      debugPrint("[PaymentProvider] Applying TTS volume failed: $e");
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

  Future<void> setNightModeStartTime(int hour, int minute) async {
    _nightModeStartHour = hour;
    _nightModeStartMinute = minute;
    try {
      await _prefs.setInt('nightModeStartHour', hour);
      await _prefs.setInt('nightModeStartMinute', minute);
    } catch (e) {
      debugPrint("[PaymentProvider] Applying night mode start time failed: $e");
    }
    notifyListeners();
  }

  Future<void> setNightModeEndTime(int hour, int minute) async {
    _nightModeEndHour = hour;
    _nightModeEndMinute = minute;
    try {
      await _prefs.setInt('nightModeEndHour', hour);
      await _prefs.setInt('nightModeEndMinute', minute);
    } catch (e) {
      debugPrint("[PaymentProvider] Applying night mode end time failed: $e");
    }
    notifyListeners();
  }


  Future<void> handleNewPayment({
    required double amount,
    required String sender,
    required String appName,
    required String rawText,
    required String packageName,
    required String title,
    required String body,
    required bool isSent,
    String? notificationKey,
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

    var parsed = parsePayment(body);
    if (parsed == null) {
      if (amount > 0.0) {
        parsed = ParsedPayment(
          type: isSent ? 'outgoing' : 'incoming',
          amount: amount,
          accountNumber: null,
          upiRef: null,
        );
      } else {
        _restoreVolume();
        return;
      }
    }

    final actualAmount = parsed.amount > 0.0 ? parsed.amount : amount;
    final resolvedSender = (sender == 'Notification' || sender.isEmpty) ? (title.isNotEmpty ? title : 'UPI User') : sender;
    final finalAppName = appName == 'UPI App' ? 'UPI' : appName;

    final now = DateTime.now();

    final String typeStr = isSent ? 'debited' : 'credited';
    String accSuffix = '';
    if (parsed.accountNumber != null && parsed.accountNumber!.isNotEmpty) {
      final acc = parsed.accountNumber!;
      accSuffix = acc.length > 4 ? acc.substring(acc.length - 4) : acc;
    }
    final fingerprint = "${actualAmount}_${typeStr}_$accSuffix";

    // Deduplication check (history + balance + TTS)
    bool isDuplicate = false;
    if (parsed.upiRef != null && parsed.upiRef!.isNotEmpty && _seenUpiRefs.contains(parsed.upiRef)) {
      isDuplicate = true;
      debugPrint("Duplicate suppressed (history+balance+TTS): ref=${parsed.upiRef}");
    }

    if (!isDuplicate && notificationKey != null && _seenNotificationKeys.containsKey(notificationKey)) {
      if (_seenNotificationKeys[notificationKey] == fingerprint) {
        isDuplicate = true;
        debugPrint("Duplicate suppressed (history+balance+TTS): acct=$accSuffix, amount=${actualAmount.toStringAsFixed(0)}");
      }
    }

    if (!isDuplicate && _seenFingerprints.containsKey(fingerprint)) {
      final lastSeen = _seenFingerprints[fingerprint]!;
      if (now.difference(lastSeen).inSeconds <= 15) {
        isDuplicate = true;
        debugPrint("Duplicate suppressed (history+balance+TTS): acct=$accSuffix, amount=${actualAmount.toStringAsFixed(0)}");
      }
    }

    if (isDuplicate) {
      _restoreVolume();
      return;
    }

    // Record deduplication context for future notifications
    _seenFingerprints[fingerprint] = now;
    if (notificationKey != null) {
      _seenNotificationKeys[notificationKey] = fingerprint;
    }
    if (parsed.upiRef != null && parsed.upiRef!.isNotEmpty) {
      _seenUpiRefs.add(parsed.upiRef!);
    }

    final speech = _getSpeechString(actualAmount, isSent ? 'outgoing' : 'incoming', finalAppName, resolvedSender);
    
    bool shouldSpeak = true;
    if (!isSent && _voiceFilterAccount != 'All Accounts') {
      final paymentAcc = parsed.accountNumber ?? 'Unknown';
      if (paymentAcc != _voiceFilterAccount) {
        shouldSpeak = false;
        debugPrint("[PaymentProvider] Voice filter matches specific account ($_voiceFilterAccount), but payment is from ($paymentAcc). Silently ignoring TTS.");
      }
    }

    if (isNightModeActive) {
      debugPrint("[PaymentProvider] Night mode is active. Skipping TTS.");
    } else if (_isVoiceAlertEnabled && shouldSpeak) {
      Future.delayed(ttsAnnouncementDelay, () async {
        debugPrint("[PaymentProvider] TTS triggered: source=notification_listener, fingerprint=$fingerprint, speech='$speech'");
        _boostVolume();
        await _flutterTts.speak(speech);
      });
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
    _updateCache();
    notifyListeners();
  }

  Future<void> replayLastPayment() async {
    if (_lastPayment != null) {
      debugPrint("[PaymentProvider] Replaying last payment...");
      debugPrint("[PaymentProvider] TTS triggered: source=replay_last_payment, text='${_lastPayment!.rawText}'");
      _boostVolume();
      await _flutterTts.speak(_lastPayment!.rawText);
    } else {
      debugPrint("[PaymentProvider] No payment to replay.");
      debugPrint("[PaymentProvider] TTS triggered: source=replay_last_payment_failed");
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
            ? "आपको $formattedAmount रुपये मिले"
            : "आपने $formattedAmount रुपये भेजे";
      case 'ta-IN':
        return isIncoming
            ? "உங்களுக்கு $formattedAmount ரூபாய் கிடைத்தது"
            : "நீங்கள் $formattedAmount ரூபாய் அனுப்பினீர்கள்";
      case 'te-IN':
        return isIncoming
            ? "మీకు $formattedAmount రూపాయలు వచ్చాయి"
            : "మీరు $formattedAmount రూపాయలు పంపారు";
      case 'kn-IN':
        return isIncoming
            ? "ನಿಮಗೆ $formattedAmount ರೂಪಾಯಿ ಬಂದಿದೆ"
            : "ನೀವು $formattedAmount ರೂಪಾಯಿ ಕಳಿಸಿದ್ದೀರಿ";
      case 'ml-IN':
        return isIncoming
            ? "നിങ്ങൾക്ക് $formattedAmount രൂപ ലഭിച്ചു"
            : "നിങ്ങൾ $formattedAmount രൂപ അയച്ചു";
      case 'bn-IN':
        return isIncoming
            ? "আপনি $formattedAmount টাকা পেয়েছেন"
            : "আপনি $formattedAmount টাকা পাঠিয়েছেন";
      case 'en-IN':
      default:
        final word = amount == 1.0 ? "rupee" : "rupees";
        return isIncoming
            ? "You received $formattedAmount $word"
            : "You sent $formattedAmount $word";
    }
  }

  Future<void> testSpeak({bool isSent = false}) async {
    final speech = _getSpeechString(100.0, isSent ? 'outgoing' : 'incoming', 'GPay', 'Test User');
    _boostVolume();
    _flutterTts.speak(speech);
  }

  Future<void> speakPaymentAmount(double amount, bool isSent) async {
    if (isNightModeActive) {
      debugPrint("[PaymentProvider] Night mode is active. Skipping manual/tap-to-speak TTS.");
      return;
    }
    final speech = _getSpeechString(amount, isSent ? 'outgoing' : 'incoming', 'UPI', 'User');
    _boostVolume();
    await _flutterTts.speak(speech);
  }

  Future<void> testTTS(bool isSent) async {
    final speech = _getSpeechString(100.0, isSent ? 'outgoing' : 'incoming', 'GPay', 'Tester');
    debugPrint("[PaymentProvider] TTS triggered: source=test_tts, speech='$speech'");
    _boostVolume();
    _flutterTts.speak(speech);
  }

  Future<void> testVoice() async {
    final speech = _getSpeechString(100.0, 'incoming', 'GPay', 'Tester');
    debugPrint("[PaymentProvider] TTS triggered: source=test_voice, speech='$speech'");
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

  Future<void> skipBatteryOptimization() async {
    _batteryOptimizationSkipped = true;
    try {
      await _prefs.setBool('battery_optimization_skipped', true);
    } catch (e) {
      debugPrint("[PaymentProvider] Saving battery optimization skip failed: $e");
    }
    notifyListeners();
  }

  Future<void> _boostVolume() async {
    // No-op: Do NOT modify phone's system volume or boost media volume.
  }

  Future<void> _restoreVolume() async {
    // No-op: Do NOT modify phone's system volume or boost media volume.
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
    _updateCache();
    notifyListeners();
  }

  void _updateCache() {
    final now = DateTime.now();
    
    // 1. Filtered history list
    if (_selectedAccount == null || _selectedAccount == 'All Accounts') {
      _filteredHistoryCache = List.from(_paymentHistory);
    } else {
      _filteredHistoryCache = _paymentHistory.where((p) => p.accountNumber == _selectedAccount).toList();
    }

    // 2. Received and Sent history caches
    _receivedHistoryCache = _filteredHistoryCache.where((p) => !p.isSent).toList();
    _sentHistoryCache = _filteredHistoryCache.where((p) => p.isSent).toList();

    // 3. Last payment cache
    _lastReceivedPaymentCache = _receivedHistoryCache.isEmpty ? null : _receivedHistoryCache.first;
    _lastSentPaymentCache = _sentHistoryCache.isEmpty ? null : _sentHistoryCache.first;

    // 4. Statistics - Received
    final todayReceived = _receivedHistoryCache.where((p) => p.timestamp.year == now.year && p.timestamp.month == now.month && p.timestamp.day == now.day).toList();
    _totalReceivedTodayCache = todayReceived.fold(0.0, (sum, p) => sum + p.amount);
    _totalReceivedTransactionsTodayCache = todayReceived.length;
    _highestReceivedPaymentCache = _receivedHistoryCache.isEmpty ? 0.0 : _receivedHistoryCache.map((p) => p.amount).reduce((curr, next) => curr > next ? curr : next);

    // 5. Statistics - Sent
    final todaySent = _sentHistoryCache.where((p) => p.timestamp.year == now.year && p.timestamp.month == now.month && p.timestamp.day == now.day).toList();
    _totalSentTodayCache = todaySent.fold(0.0, (sum, p) => sum + p.amount);
    _totalSentTransactionsTodayCache = todaySent.length;
    _highestSentPaymentCache = _sentHistoryCache.isEmpty ? 0.0 : _sentHistoryCache.map((p) => p.amount).reduce((curr, next) => curr > next ? curr : next);

    // 6. Statistics - Weekly
    final startOfWeek = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    _totalReceivedThisWeekCache = _receivedHistoryCache.where((p) => p.timestamp.isAfter(startOfWeek)).fold(0.0, (sum, p) => sum + p.amount);
    _totalSentThisWeekCache = _sentHistoryCache.where((p) => p.timestamp.isAfter(startOfWeek)).fold(0.0, (sum, p) => sum + p.amount);

    // 7. Statistics - Monthly
    _totalReceivedThisMonthCache = _receivedHistoryCache.where((p) => p.timestamp.year == now.year && p.timestamp.month == now.month).fold(0.0, (sum, p) => sum + p.amount);
    _totalSentThisMonthCache = _sentHistoryCache.where((p) => p.timestamp.year == now.year && p.timestamp.month == now.month).fold(0.0, (sum, p) => sum + p.amount);
  }
}
