import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'features/auth/login_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'core/services/local_database.dart';
import 'core/services/sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  await LocalDatabase.init();
  SyncService().startAutoSync();
  
  final prefs = await SharedPreferences.getInstance();
  final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

  runApp(MainApp(isLoggedIn: isLoggedIn));
}

class MainApp extends StatelessWidget {
  final bool isLoggedIn;
  const MainApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DR-Check AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: isLoggedIn ? const DashboardScreen() : const LoginScreen(),
    );
  }
}
