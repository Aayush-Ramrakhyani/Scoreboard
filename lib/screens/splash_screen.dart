import 'package:flutter/material.dart';
import 'mode_select_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Controllers
  late final AnimationController _iconCtrl;
  late final AnimationController _textCtrl;
  late final AnimationController _pulseCtrl;
  late final AnimationController _exitCtrl;

  // Icon
  late final Animation<double> _iconY;
  late final Animation<double> _iconScale;
  late final Animation<double> _iconOpacity;
  late final Animation<double> _glowOpacity;

  // Text
  late final Animation<double> _titleX;
  late final Animation<double> _titleOpacity;
  late final Animation<double> _subtitleX;
  late final Animation<double> _subtitleOpacity;
  late final Animation<double> _dividerW;
  late final Animation<double> _taglineOpacity;

  // Pulse ring
  late final Animation<double> _pulseScale;
  late final Animation<double> _pulseOpacity;

  // Exit
  late final Animation<double> _exitOpacity;
  late final Animation<double> _exitScale;

  @override
  void initState() {
    super.initState();

    _iconCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _textCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100));
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1300))
      ..repeat(reverse: true);
    _exitCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));

    // ── Icon: drops from above with bounce
    _iconY = Tween(begin: -300.0, end: 0.0)
        .chain(CurveTween(curve: Curves.bounceOut))
        .animate(_iconCtrl);
    _iconScale = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween(begin: 0.3, end: 1.12)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 65),
      TweenSequenceItem(
          tween: Tween(begin: 1.12, end: 1.0), weight: 35),
    ]).animate(_iconCtrl);
    _iconOpacity = Tween(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _iconCtrl, curve: const Interval(0.0, 0.18)));
    _glowOpacity = Tween(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _iconCtrl, curve: const Interval(0.55, 1.0)));

    // ── Text: staggered slide-in from opposite sides
    _titleX = Tween(begin: -70.0, end: 0.0)
        .chain(CurveTween(curve: Curves.easeOutCubic))
        .animate(CurvedAnimation(
            parent: _textCtrl, curve: const Interval(0.0, 0.52)));
    _titleOpacity = Tween(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _textCtrl, curve: const Interval(0.0, 0.38)));

    _subtitleX = Tween(begin: 70.0, end: 0.0)
        .chain(CurveTween(curve: Curves.easeOutCubic))
        .animate(CurvedAnimation(
            parent: _textCtrl, curve: const Interval(0.22, 0.68)));
    _subtitleOpacity = Tween(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _textCtrl, curve: const Interval(0.22, 0.55)));

    _dividerW = Tween(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _textCtrl, curve: const Interval(0.38, 0.72)));

    _taglineOpacity = Tween(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _textCtrl, curve: const Interval(0.62, 1.0)));

    // ── Pulsing ring
    _pulseScale = Tween(begin: 1.0, end: 1.45)
        .chain(CurveTween(curve: Curves.easeInOut))
        .animate(_pulseCtrl);
    _pulseOpacity = Tween(begin: 0.55, end: 0.0)
        .chain(CurveTween(curve: Curves.easeInOut))
        .animate(_pulseCtrl);

    // ── Exit: scale-down + fade (feels like going "into" the screen)
    _exitOpacity = Tween(begin: 1.0, end: 0.0).animate(
        CurvedAnimation(parent: _exitCtrl, curve: Curves.easeInCubic));
    _exitScale = Tween(begin: 1.0, end: 0.9).animate(
        CurvedAnimation(parent: _exitCtrl, curve: Curves.easeInCubic));

    _runSequence();
  }

  Future<void> _runSequence() async {
    await Future.delayed(const Duration(milliseconds: 180));
    await _iconCtrl.forward();           // icon drops (900ms)
    _textCtrl.forward();                 // text reveals overlap with hold
    await Future.delayed(const Duration(milliseconds: 1350));
    await _exitCtrl.forward();           // exit fade (700ms)
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const ModeSelectScreen(),
        transitionDuration: const Duration(milliseconds: 550),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
          child: child,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _iconCtrl.dispose();
    _textCtrl.dispose();
    _pulseCtrl.dispose();
    _exitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF061410),
      body: AnimatedBuilder(
        animation: Listenable.merge(
            [_iconCtrl, _textCtrl, _pulseCtrl, _exitCtrl]),
        builder: (_, __) {
          return Opacity(
            opacity: _exitOpacity.value.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: _exitScale.value,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // ── Background radial gradient
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment(0, -0.15),
                        radius: 1.15,
                        colors: [Color(0xFF1B4A2F), Color(0xFF061410)],
                        stops: [0.0, 1.0],
                      ),
                    ),
                  ),

                  // ── Subtle concentric ring decoration
                  CustomPaint(painter: _RingsPainter()),

                  // ── Main content
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Icon + pulse ring
                        SizedBox(
                          width: 180,
                          height: 180,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Outer pulse ring
                              Transform.scale(
                                scale: _pulseScale.value,
                                child: Container(
                                  width: 150,
                                  height: 150,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.greenAccent.withOpacity(
                                          _pulseOpacity.value),
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                              // Second pulse ring (phase-shifted)
                              Transform.scale(
                                scale: 1.0 +
                                    (_pulseScale.value - 1.0) * 0.6,
                                child: Container(
                                  width: 150,
                                  height: 150,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.greenAccent.withOpacity(
                                          _pulseOpacity.value * 0.5),
                                      width: 1,
                                    ),
                                  ),
                                ),
                              ),
                              // Glow halo
                              Opacity(
                                opacity: _glowOpacity.value,
                                child: Container(
                                  width: 130,
                                  height: 130,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.greenAccent
                                            .withOpacity(0.35),
                                        blurRadius: 48,
                                        spreadRadius: 12,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              // The cricket icon — drops in with bounce
                              Transform.translate(
                                offset: Offset(0, _iconY.value),
                                child: Opacity(
                                  opacity:
                                      _iconOpacity.value.clamp(0.0, 1.0),
                                  child: Transform.scale(
                                    scale: _iconScale.value,
                                    child: Container(
                                      width: 118,
                                      height: 118,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            Colors.green.shade500,
                                            Colors.green.shade900,
                                          ],
                                        ),
                                        border: Border.all(
                                          color: Colors.greenAccent
                                              .withOpacity(0.6),
                                          width: 1.5,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.green
                                                .withOpacity(0.6),
                                            blurRadius: 28,
                                            spreadRadius: 3,
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.sports_cricket,
                                        size: 62,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 38),

                        // "CRICKET" — slides from left
                        Transform.translate(
                          offset: Offset(_titleX.value, 0),
                          child: Opacity(
                            opacity: _titleOpacity.value.clamp(0.0, 1.0),
                            child: const Text(
                              'CRICKET',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 56,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 15,
                                height: 1.0,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 10),

                        // Animated wipe divider
                        SizedBox(
                          width: 270 * _dividerW.value,
                          height: 1.5,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [
                                Colors.greenAccent.withOpacity(0),
                                Colors.greenAccent,
                                Colors.greenAccent.withOpacity(0),
                              ]),
                            ),
                          ),
                        ),

                        const SizedBox(height: 10),

                        // "SCOREBOARD" — slides from right
                        Transform.translate(
                          offset: Offset(_subtitleX.value, 0),
                          child: Opacity(
                            opacity: _subtitleOpacity.value.clamp(0.0, 1.0),
                            child: Text(
                              'SCOREBOARD',
                              style: TextStyle(
                                color: Colors.greenAccent.withOpacity(0.9),
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 9,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 30),

                        // Tagline
                        Opacity(
                          opacity: _taglineOpacity.value.clamp(0.0, 1.0),
                          child: const Text(
                            'Your Digital Cricket Scorer',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 13,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Bottom pulsing dots
                  Positioned(
                    bottom: 54,
                    left: 0,
                    right: 0,
                    child: Opacity(
                      opacity: _taglineOpacity.value.clamp(0.0, 1.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(3, (i) {
                          final phase = (_pulseCtrl.value + i / 3.0) % 1.0;
                          final bright =
                              phase < 0.5 ? phase * 2.0 : (1.0 - phase) * 2.0;
                          return Container(
                            margin:
                                const EdgeInsets.symmetric(horizontal: 5),
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.greenAccent
                                  .withOpacity(0.2 + 0.8 * bright),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RingsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.green.withOpacity(0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    final cx = size.width / 2;
    final cy = size.height / 2;
    for (final r in [
      size.width * 0.55,
      size.width * 0.78,
      size.width * 1.05,
    ]) {
      canvas.drawCircle(Offset(cx, cy), r, paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
