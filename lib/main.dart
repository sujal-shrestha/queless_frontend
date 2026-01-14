import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'viewmodels/home_viewmodel.dart';
import 'viewmodels/venue_viewmodel.dart';
import 'viewmodels/profile_viewmodel.dart';

import 'views/auth/auth_screen.dart';
import 'views/auth/signup_screen.dart';
import 'views/home/home_screen.dart';
import 'views/queue/live_queue_view.dart';


// ✅ Single-screen booking flow (kept)
import 'views/booking/select_service_screen.dart';

void main() {
  runApp(const QueueLessApp());
}

class QueueLessApp extends StatelessWidget {
  const QueueLessApp({super.key});

  static const kGreen = Color(0xFF65BF61);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => HomeViewModel()),
        ChangeNotifierProvider(create: (_) => VenueViewModel()),
        ChangeNotifierProvider(create: (_) => ProfileViewModel()),
      ],
      child: MaterialApp(
        title: 'QueueLess',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          fontFamily: 'Roboto',
          primaryColor: kGreen,
          scaffoldBackgroundColor: const Color(0xFFF5F7FB),
          colorScheme: ColorScheme.fromSeed(seedColor: kGreen),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: const Color(0xFFF3F4F6),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),

        // ✅ Start here
        initialRoute: '/auth',

        // ✅ Only the routes you still use
        routes: {
          '/auth': (_) => const AuthScreen(),
          '/signup': (_) => const SignupScreen(),
          '/home': (_) => const HomeScreen(),
          '/queue': (_) => const LiveQueueView(),

          // ✅ Optional: keep ONLY if somewhere you still do Navigator.pushNamed('/select-service')
          '/select-service': (_) => const SelectServiceScreen(),
        },
      ),
    );
  }
}
