import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';

void main() {
  runApp(const CricketApp());
}

class CricketApp extends StatelessWidget {
  const CricketApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cricket Scoreboard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: _CricketTransitionsBuilder(),
            TargetPlatform.iOS: _CricketTransitionsBuilder(),
            TargetPlatform.windows: _CricketTransitionsBuilder(),
            TargetPlatform.linux: _CricketTransitionsBuilder(),
            TargetPlatform.macOS: _CricketTransitionsBuilder(),
            TargetPlatform.fuchsia: _CricketTransitionsBuilder(),
          },
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

class _CricketTransitionsBuilder extends PageTransitionsBuilder {
  const _CricketTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final slide = Tween<Offset>(
      begin: const Offset(0.18, 0),
      end: Offset.zero,
    )
        .chain(CurveTween(curve: Curves.easeOutCubic))
        .animate(animation);

    final fade = Tween<double>(begin: 0.0, end: 1.0)
        .chain(CurveTween(curve: const Interval(0.0, 0.65, curve: Curves.easeOut)))
        .animate(animation);

    return SlideTransition(
      position: slide,
      child: FadeTransition(opacity: fade, child: child),
    );
  }
}
