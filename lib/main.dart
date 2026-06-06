import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/payment_provider.dart';
import 'screens/splash_screen.dart';

import 'package:hive_flutter/hive_flutter.dart';

void main() async {
  debugPrint("[Main] main() function called. Starting application startup tracing...");
  try {
    WidgetsFlutterBinding.ensureInitialized();
    debugPrint("[Main] WidgetsFlutterBinding.ensureInitialized() succeeded.");
    await Hive.initFlutter();
    await Hive.openBox('payments');
    debugPrint("[Main] Hive initialized and payments box opened.");
  } catch (e) {
    debugPrint("[Main] Fatal: Initialization failed: $e");
  }

  try {
    debugPrint("[Main] Launching runApp with MultiProvider...");
    runApp( multiProvider() );
    debugPrint("[Main] runApp successfully executed.");
  } catch (e) {
    debugPrint("[Main] Fatal: runApp execution crashed: $e");
  }
}

Widget multiProvider() {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => PaymentProvider()),
    ],
    child: const MyApp(),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    debugPrint("[MyApp] build() method triggered. Setting up MaterialApp and theme...");
    return MaterialApp(
      title: 'UPI Payment Alert',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00FFC2),
          secondary: Color(0xFF00E5FF),
          surface: Color(0xFF101424),
          error: Color(0xFFFF5252),
        ),
        scaffoldBackgroundColor: const Color(0xFF090D1A),
        fontFamily: 'Inter',
      ),
      home: const SplashScreen(),
    );
  }
}
