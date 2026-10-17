import 'package:flutter/material.dart';
import 'data/itinerary_database.dart';
import 'ui/dashboard_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  ItineraryDatabase.initializeFfi();
  runApp(const TripyTravyDesktopApp());
}

class TripyTravyDesktopApp extends StatelessWidget {
  const TripyTravyDesktopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TripyTravy — Travel Itinerary Creator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0066FF),
          primary: const Color(0xFF0066FF),
        ),
        fontFamily: 'Segoe UI',
      ),
      home: const DashboardScreen(),
    );
  }
}
