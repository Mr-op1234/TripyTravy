import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'di/mobile_di_container.dart';
import 'ui/mobile_dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Obtain persistent local storage directory for the mobile application
  final appDocDir = await getApplicationDocumentsDirectory();
  final di = MobileDiContainer.persistent(appDocDir);

  runApp(TripyTravyMobileApp(di: di));
}

class TripyTravyMobileApp extends StatelessWidget {
  final MobileDiContainer di;

  const TripyTravyMobileApp({super.key, required this.di});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tripy Travy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0D2356),
          primary: const Color(0xFF0D2356),
          surface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF0D2356),
          elevation: 0,
        ),
      ),
      home: MobileDashboardScreen(di: di),
    );
  }
}
