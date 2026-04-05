import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/constants.dart';

/// Full-screen onboarding overlay shown on first app launch.
/// 3 slides introducing BeautyCita's core flow.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  /// Returns true if onboarding has already been shown.
  static Future<bool> hasBeenShown() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('onboarding_shown') ?? false;
  }

  /// Marks onboarding as shown.
  static Future<void> markShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_shown', true);
  }

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  static const _slides = [
    _SlideData(
      icon: Icons.grid_view_rounded,
      title: 'Elige tu servicio',
      body:
          'Selecciona el servicio que necesitas — corte, color, unas, pestanas, y mas',
    ),
    _SlideData(
      icon: Icons.location_on_outlined,
      title: 'Te encontramos el mejor salon',
      body:
          'Nuestro motor inteligente encuentra los 3 mejores salones cerca de ti en segundos',
    ),
    _SlideData(
      icon: Icons.event_available_rounded,
      title: 'Reserva con un toque',
      body:
          'Confirma tu cita, recibe recordatorios, y administra todo desde la app',
    ),
  ];

  // Brand gradient colors
  static const _gradientColors = [
    [Color(0xFFec4899), Color(0xFF9333ea)], // pink → purple
    [Color(0xFF9333ea), Color(0xFF3b82f6)], // purple → blue
    [Color(0xFF3b82f6), Color(0xFFec4899)], // blue → pink
  ];

  void _next() {
    if (_currentPage < _slides.length - 1) {
      _controller.nextPage(
        duration: AppConstants.mediumAnimation,
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    await OnboardingScreen.markShown();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Page view
          PageView.builder(
            controller: _controller,
            itemCount: _slides.length,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (context, index) {
              final slide = _slides[index];
              final colors = _gradientColors[index];
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: colors,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.paddingXL,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Spacer(flex: 2),
                        // Illustration or icon
                        if (slide.imagePath != null)
                          Container(
                            width: 220,
                            height: 220,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Image.asset(
                              slide.imagePath!,
                              fit: BoxFit.cover,
                            ),
                          )
                        else
                          Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              slide.icon,
                              size: 72,
                              color: Colors.white,
                            ),
                          ),
                        const SizedBox(height: AppConstants.paddingXL),
                        // Title
                        Text(
                          slide.title,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppConstants.paddingMD),
                        // Body
                        Text(
                          slide.body,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w400,
                            color: Colors.white.withValues(alpha: 0.9),
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const Spacer(flex: 3),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          // Skip button — top right
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            right: AppConstants.paddingMD,
            child: TextButton(
              onPressed: _finish,
              child: Text(
                'Saltar',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          // Bottom: dots + button
          Positioned(
            left: 0,
            right: 0,
            bottom: MediaQuery.of(context).padding.bottom + 40,
            child: Column(
              children: [
                // Page dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _slides.length,
                    (i) => AnimatedContainer(
                      duration: AppConstants.shortAnimation,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: i == _currentPage ? 28 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _currentPage
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppConstants.paddingLG),
                // Action button
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.paddingXL,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: AppConstants.minTouchHeight,
                    child: ElevatedButton(
                      onPressed: _next,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF9333ea),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppConstants.radiusLG,
                          ),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: Text(
                        _currentPage == _slides.length - 1
                            ? 'Empezar'
                            : 'Siguiente',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SlideData {
  final IconData icon;
  final String title;
  final String body;
  final String? imagePath;

  const _SlideData({
    required this.icon,
    required this.title,
    required this.body,
    this.imagePath,
  });
}
