import 'package:flutter/material.dart';

import 'screens/login/login_screen.dart';
import 'screens/login/register_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/send/send_screen.dart';
import 'screens/receive/receive_screen.dart';
import 'screens/history/history_screen.dart';
import 'screens/goals/goals_screen.dart';
import 'screens/qr/scan_qr_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/earn/earn_screen.dart';


Map<String, WidgetBuilder> appRoutes = {
  '/login': (context) => const LoginScreen(),
  '/register': (context) => const RegisterScreen(),
  '/home': (context) => const HomeScreen(),
  '/send': (context) => const SendScreen(),
  '/receive': (context) => const ReceiveScreen(),
  '/history': (context) => const HistoryScreen(),
  '/goals': (context) => const GoalsScreen(),
  '/scan-qr': (_) => const ScanQrScreen(),
  '/profile': (_) => const ProfileScreen(),
  '/earn': (_) => const EarnScreen(),
};
