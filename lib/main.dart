import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';

void main() {
  runApp(const PMJAYLiveAuditApp());
}

class PMJAYLiveAuditApp extends StatelessWidget {
  const PMJAYLiveAuditApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PMJAY Live Audit',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
    );
  }
}
