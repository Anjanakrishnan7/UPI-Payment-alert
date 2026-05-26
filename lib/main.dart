import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/payment_provider.dart';
import 'screens/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PaymentProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
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
