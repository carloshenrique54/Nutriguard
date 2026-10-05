import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'auth/login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _shimmerController;
  
  late Animation<double> _outlineOpacity;
  late Animation<double> _fillOpacity;
  late Animation<double> _scalePulse;
  
  late Animation<double> _textFade;
  late Animation<Offset> _textSlide;
  late Animation<double> _letterSpacing;

  @override
  void initState() {
    super.initState();
    
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    // 1. Apple Outline (0 - 800ms)
    _outlineOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.36, curve: Curves.easeIn), // 800ms
      ),
    );

    // 2. Apple Fill (800ms - 1200ms)
    _fillOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.36, 0.54, curve: Curves.easeIn),
      ),
    );

    // 3. Apple Pulse (800ms - 1400ms)
    _scalePulse = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.1).chain(CurveTween(curve: Curves.easeOut)), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.1, end: 1.0).chain(CurveTween(curve: Curves.easeIn)), weight: 50),
    ]).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.36, 0.63), // 800ms to ~1400ms
      ),
    );

    // 4. Text Fade & Slide (1000ms - 1800ms)
    _textFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.45, 0.8, curve: Curves.easeOut),
      ),
    );
    _textSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.45, 0.8, curve: Curves.easeOutCubic),
      ),
    );
    
    // 5. Letter Spacing (1000ms - 2200ms)
    _letterSpacing = Tween<double>(begin: 0.0, end: 2.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.45, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _mainController.addListener(() {
      if (_mainController.value >= 0.36 && _mainController.value <= 0.38) {
        HapticFeedback.lightImpact(); // Início do pulso
      }
      if (_mainController.value >= 0.50 && _mainController.value <= 0.52) {
        HapticFeedback.heavyImpact(); // Pico do pulso
      }
      if (_mainController.value >= 0.99) {
        if (!_shimmerController.isAnimating) {
          _shimmerController.forward();
        }
      }
    });

    _mainController.forward();

    Future.delayed(const Duration(milliseconds: 3000), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const LoginScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 800),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _mainController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF2E0),
      body: Center(
        child: AnimatedBuilder(
          animation: Listenable.merge([_mainController, _shimmerController]),
          builder: (context, child) {
            return ShaderMask(
              shaderCallback: (bounds) {
                if (!_shimmerController.isAnimating && _shimmerController.value == 0) {
                  return const LinearGradient(colors: [Colors.white, Colors.white]).createShader(bounds);
                }
                final value = _shimmerController.value;
                return LinearGradient(
                  colors: [
                    Colors.white,
                    Colors.white,
                    Colors.white.withValues(alpha: 0.4),
                    Colors.white,
                    Colors.white,
                  ],
                  stops: [0.0, value - 0.2, value, value + 0.2, 1.0],
                  begin: const Alignment(-1.0, -0.3),
                  end: const Alignment(1.0, 0.3),
                ).createShader(bounds);
              },
              blendMode: BlendMode.srcATop,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Ícone da Maçã
                  ScaleTransition(
                    scale: _scalePulse,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Outline
                        Opacity(
                          opacity: _outlineOpacity.value,
                          child: Image.asset(
                            'web/icons/1.png',
                            width: 120,
                            height: 120,
                            color: const Color(0xFFC23147).withOpacity(0.5),
                            colorBlendMode: BlendMode.srcATop,
                          ),
                        ),
                        // Fill
                        Opacity(
                          opacity: _fillOpacity.value,
                          child: Image.asset(
                            'web/icons/1.png',
                            width: 120,
                            height: 120,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Texto NutriGuard
                  SlideTransition(
                    position: _textSlide,
                    child: Opacity(
                      opacity: _textFade.value,
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.w800,
                            letterSpacing: _letterSpacing.value,
                          ),
                          children: const [
                            TextSpan(
                              text: 'Nutri',
                              style: TextStyle(color: Color(0xFF8DB600)),
                            ),
                            TextSpan(
                              text: 'Guard',
                              style: TextStyle(color: Color(0xFFC23147)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
