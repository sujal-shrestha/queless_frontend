import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:queless_app/views/booking/booking_screen.dart';

import 'views/auth/auth_screen.dart';
import 'views/auth/signup_screen.dart';
import 'views/home/home_screen.dart';
import 'viewmodels/venue_viewmodel.dart';

void main() {
  runApp(const QueueLessApp());
}

class QueueLessApp extends StatelessWidget {
  const QueueLessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => VenueViewModel()),
      ],
      child: MaterialApp(
        title: 'QueueLess',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          fontFamily: 'Roboto',
          primaryColor: const Color(0xFF16C25A),
          scaffoldBackgroundColor: const Color(0xFFF5F7FB),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF16C25A),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: const Color(0xFFF3F4F6),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        initialRoute: '/auth',
        routes: {
          '/auth': (context) => const AuthScreen(),
          '/signup': (context) => const SignupScreen(),
          '/home': (context) => const HomeScreen(),

          '/select-service': (context) => const SelectServiceScreen(),
        },
      ),
    );
  }
}
