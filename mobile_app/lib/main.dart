import 'package:flutter/material.dart';
import 'theme/theme.dart';
import 'screens/main_navigation_screen.dart';

void main() {
  runApp(const SteplightApp());
}

class SteplightApp extends StatelessWidget {
  const SteplightApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Steplight',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: MediaQuery.textScalerOf(
              context,
            ).clamp(minScaleFactor: 1.0, maxScaleFactor: 2.5),
          ),
          child: child!,
        );
      },
      home: const MainNavigationScreen(),
    );
  }
}
