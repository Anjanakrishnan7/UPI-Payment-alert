import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/payment_provider.dart';
import 'screens/splash_screen.dart';

import 'package:hive_flutter/hive_flutter.dart';

void main() async {
  debugPrint("[Main] main() function called. Starting application startup tracing...");
  SharedPreferences? prefs;
  try {
    WidgetsFlutterBinding.ensureInitialized();
    debugPrint("[Main] WidgetsFlutterBinding.ensureInitialized() succeeded.");
    await Hive.initFlutter();
    await Hive.openBox('payments');
    debugPrint("[Main] Hive initialized and payments box opened.");
    prefs = await SharedPreferences.getInstance();
    debugPrint("[Main] SharedPreferences preloaded successfully.");
  } catch (e) {
    debugPrint("[Main] Fatal: Initialization failed: $e");
  }

  try {
    debugPrint("[Main] Launching runApp with MultiProvider...");
    runApp( multiProvider(prefs) );
    debugPrint("[Main] runApp successfully executed.");
  } catch (e) {
    debugPrint("[Main] Fatal: runApp execution crashed: $e");
  }
}

Widget multiProvider(SharedPreferences? prefs) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => PaymentProvider(prefs: prefs)),
    ],
    child: const MyApp(),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    debugPrint("[MyApp] build() method triggered. Setting up MaterialApp and theme...");
    final isLightMode = context.select<PaymentProvider, bool>((p) => p.isLightMode);
    return MaterialApp(
      title: 'UPI Payment Alert',
      debugShowCheckedModeBanner: false,
      themeMode: isLightMode ? ThemeMode.light : ThemeMode.dark,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF00B894),
          secondary: Color(0xFF00E5FF),
          surface: Color(0xFFFFFFFF),
          error: Color(0xFFFF5252),
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F8FA),
        fontFamily: 'Inter',
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00FFC2),
          secondary: Color(0xFF00E5FF),
          surface: Color(0xFF121625),
          error: Color(0xFFFF5252),
        ),
        scaffoldBackgroundColor: const Color(0xFF0A0E1A),
        fontFamily: 'Inter',
      ),
      home: const SplashScreen(),
    );
  }
}
