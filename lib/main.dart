import 'dart:math';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';

/// false = black/dark  ·  true = white/light
final ValueNotifier<bool> themeNotifier = ValueNotifier(false);

/// Global key used by [toggleTheme] to trigger the circular reveal.
final _appKey = GlobalKey<_CricketAppState>();

/// Call with the tap's global screen position for an accurate reveal origin.
void toggleTheme({Offset origin = Offset.zero}) =>
    _appKey.currentState?.triggerReveal(origin);

Future<void> _loadTheme() async {
  final prefs = await SharedPreferences.getInstance();
  themeNotifier.value = prefs.getBool('lightTheme') ?? false;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await _loadTheme();
  runApp(CricketApp(key: _appKey));
}

// ── App ───────────────────────────────────────────────────────────────────────

class CricketApp extends StatefulWidget {
  const CricketApp({super.key});

  @override
  State<CricketApp> createState() => _CricketAppState();
}

class _CricketAppState extends State<CricketApp>
    with SingleTickerProviderStateMixin {
  // ── Circular reveal state ──────────────────────────────────────────────────
  bool _showReveal = false;
  Offset _revealCenter = Offset.zero;
  bool _revealToLight = false;
  late final AnimationController _revealCtrl;
  late final Animation<double> _revealAnim;

  // ── Black (dark) theme ─────────────────────────────────────────────────────
  static final _kDark = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    fontFamily: 'Roboto',
    scaffoldBackgroundColor: Colors.black,
    colorScheme: const ColorScheme.dark(
      primary: Colors.white,
      onPrimary: Colors.black,
      secondary: Color(0xFFCCCCCC),
      onSecondary: Colors.black,
      surface: Color(0xFF161616),
      onSurface: Colors.white,
      surfaceContainerHighest: Color(0xFF222222),
      outline: Color(0x3DFFFFFF),   // white 24%
      outlineVariant: Color(0x1FFFFFFF), // white 12%
      error: Color(0xFFCF6679),
      onError: Colors.black,
    ),
    cardColor: const Color(0xFF161616),
    dividerColor: const Color(0x1FFFFFFF),
    iconTheme: const IconThemeData(color: Colors.white),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF0A0A0A),
      foregroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      iconTheme: IconThemeData(color: Colors.white),
      titleTextStyle: TextStyle(
          color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        disabledBackgroundColor: const Color(0xFF333333),
        disabledForegroundColor: Colors.white38,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.bold),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: Color(0x3DFFFFFF)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: const Color(0x0AFFFFFF),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: Colors.white70),
    ),
    inputDecorationTheme: InputDecorationTheme(
      hintStyle: const TextStyle(color: Color(0x61FFFFFF)),
      labelStyle: const TextStyle(color: Colors.white54),
      prefixIconColor: Colors.white54,
      suffixIconColor: Colors.white38,
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Color(0x3DFFFFFF)),
        borderRadius: BorderRadius.circular(10),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.white, width: 1.5),
        borderRadius: BorderRadius.circular(10),
      ),
      filled: true,
      fillColor: const Color(0xFF161616),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: Colors.white,
      unselectedLabelColor: Colors.white38,
      indicatorColor: Colors.white,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: const Color(0xFF222222),
      labelStyle: const TextStyle(color: Colors.white),
      side: const BorderSide(color: Color(0x1FFFFFFF)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: Colors.white70,
      textColor: Colors.white,
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFF161616),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0x1FFFFFFF)),
      ),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: Color(0xFF1A1A1A),
      titleTextStyle: TextStyle(
          color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
      contentTextStyle: TextStyle(color: Colors.white70, fontSize: 14),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Color(0xFF161616),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: Color(0xFF2A2A2A),
      contentTextStyle: TextStyle(color: Colors.white),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
    ),
    popupMenuTheme: const PopupMenuThemeData(
      color: Color(0xFF1A1A1A),
      textStyle: TextStyle(color: Colors.white),
    ),
    dropdownMenuTheme: const DropdownMenuThemeData(
      menuStyle: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(Color(0xFF1A1A1A)),
      ),
    ),
    pageTransitionsTheme: _kTransitions,
  );

  // ── White (light) theme ────────────────────────────────────────────────────
  static final _kLight = ThemeData(
    brightness: Brightness.light,
    useMaterial3: true,
    fontFamily: 'Roboto',
    scaffoldBackgroundColor: Colors.white,
    colorScheme: const ColorScheme.light(
      primary: Colors.black,
      onPrimary: Colors.white,
      secondary: Color(0xFF555555),
      onSecondary: Colors.white,
      surface: Color(0xFFF0F0F0),
      onSurface: Colors.black87,
      surfaceContainerHighest: Color(0xFFE5E5E5),
      outline: Color(0x3D000000),   // black 24%
      outlineVariant: Color(0x1F000000), // black 12%
      error: Color(0xFFB00020),
      onError: Colors.white,
    ),
    cardColor: const Color(0xFFF0F0F0),
    dividerColor: const Color(0x1F000000),
    iconTheme: const IconThemeData(color: Colors.black87),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      iconTheme: IconThemeData(color: Colors.black87),
      titleTextStyle: TextStyle(
          color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        disabledBackgroundColor: const Color(0xFFCCCCCC),
        disabledForegroundColor: Colors.black38,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.bold),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.black87,
        side: const BorderSide(color: Color(0x3D000000)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: const Color(0x0A000000),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: Colors.black54),
    ),
    inputDecorationTheme: InputDecorationTheme(
      hintStyle: const TextStyle(color: Color(0x61000000)),
      labelStyle: const TextStyle(color: Colors.black54),
      prefixIconColor: Colors.black54,
      suffixIconColor: Colors.black38,
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Color(0x3D000000)),
        borderRadius: BorderRadius.circular(10),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.black, width: 1.5),
        borderRadius: BorderRadius.circular(10),
      ),
      filled: true,
      fillColor: const Color(0xFFF0F0F0),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: Colors.black,
      unselectedLabelColor: Colors.black38,
      indicatorColor: Colors.black,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: const Color(0xFFE8E8E8),
      labelStyle: const TextStyle(color: Colors.black87),
      side: const BorderSide(color: Color(0x1F000000)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: Colors.black54,
      textColor: Colors.black87,
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFFF0F0F0),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0x1F000000)),
      ),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: Colors.white,
      titleTextStyle: TextStyle(
          color: Colors.black87, fontSize: 18, fontWeight: FontWeight.bold),
      contentTextStyle: TextStyle(color: Colors.black54, fontSize: 14),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: Color(0xFF222222),
      contentTextStyle: TextStyle(color: Colors.white),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
    ),
    popupMenuTheme: const PopupMenuThemeData(
      color: Colors.white,
      textStyle: TextStyle(color: Colors.black87),
    ),
    dropdownMenuTheme: const DropdownMenuThemeData(
      menuStyle: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(Colors.white),
      ),
    ),
    pageTransitionsTheme: _kTransitions,
  );

  static const _kTransitions = PageTransitionsTheme(
    builders: {
      TargetPlatform.android: _CricketTransitionsBuilder(),
      TargetPlatform.iOS: _CricketTransitionsBuilder(),
      TargetPlatform.windows: _CricketTransitionsBuilder(),
      TargetPlatform.linux: _CricketTransitionsBuilder(),
      TargetPlatform.macOS: _CricketTransitionsBuilder(),
      TargetPlatform.fuchsia: _CricketTransitionsBuilder(),
    },
  );

  @override
  void initState() {
    super.initState();
    _revealCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );
    _revealAnim = CurvedAnimation(
      parent: _revealCtrl,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _revealCtrl.dispose();
    super.dispose();
  }

  /// Called by the global [toggleTheme] with the button's screen position.
  void triggerReveal(Offset origin) {
    if (_showReveal) return; // ignore while animating
    final toLight = !themeNotifier.value;
    setState(() {
      _revealCenter = origin;
      _revealToLight = toLight;
      _showReveal = true;
    });
    _revealCtrl.forward(from: 0.0).then((_) {
      themeNotifier.value = toLight;
      SharedPreferences.getInstance()
          .then((p) => p.setBool('lightTheme', toLight));
      if (mounted) setState(() => _showReveal = false);
    });
  }

  static double _maxRadius(Size size, Offset center) {
    final dx = max(center.dx, size.width - center.dx);
    final dy = max(center.dy, size.height - center.dy);
    return sqrt(dx * dx + dy * dy);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: themeNotifier,
      builder: (_, isLight, __) => MaterialApp(
        title: 'Cricket Scoreboard',
        debugShowCheckedModeBanner: false,
        theme: isLight ? _kLight : _kDark,
        home: const SplashScreen(),
        builder: (ctx, child) => Stack(
          children: [
            child!,
            if (_showReveal)
              AnimatedBuilder(
                animation: _revealAnim,
                builder: (buildCtx, _) {
                  final size = MediaQuery.of(buildCtx).size;
                  return CustomPaint(
                    size: size,
                    painter: _RevealPainter(
                      center: _revealCenter,
                      radius: _revealAnim.value *
                          _maxRadius(size, _revealCenter),
                      color: _revealToLight ? Colors.white : Colors.black,
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

// ── Circular reveal painter ───────────────────────────────────────────────────

class _RevealPainter extends CustomPainter {
  final Offset center;
  final double radius;
  final Color color;

  const _RevealPainter({
    required this.center,
    required this.radius,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(center, radius, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_RevealPainter old) =>
      old.radius != radius || old.color != color;
}

// ── Page transition ───────────────────────────────────────────────────────────

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
        .chain(CurveTween(
            curve: const Interval(0.0, 0.65, curve: Curves.easeOut)))
        .animate(animation);

    return SlideTransition(
      position: slide,
      child: FadeTransition(opacity: fade, child: child),
    );
  }
}
