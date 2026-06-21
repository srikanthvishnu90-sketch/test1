import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'core/routes/app_pages.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_typography.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData(useMaterial3: true, fontFamily: AppTypography.fontFamily);
    return GetMaterialApp(
      title: 'Sporve',
      debugShowCheckedModeBanner: false,
      theme: base.copyWith(
        scaffoldBackgroundColor: AppColors.ink,
        primaryColor: AppColors.slate,
        colorScheme: base.colorScheme.copyWith(
          brightness: Brightness.dark,
          primary: AppColors.slate,
          onPrimary: AppColors.onSlate,
          surface: AppColors.surface,
          onSurface: AppColors.textPrimary,
        ),
        // Standardise the whole app on Geist (the neutral grotesque), with soft
        // white as the default text color on the near-black canvas.
        textTheme: base.textTheme.apply(
          bodyColor: AppColors.textPrimary,
          displayColor: AppColors.textPrimary,
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        dividerColor: AppColors.hairline,
      ),
      // On wide screens (desktop web), render inside a centered phone-width
      // frame so the mobile app keeps its intended proportions instead of being
      // stretched across the whole window.
      builder: (context, child) {
        final media = MediaQuery.of(context);
        const frameWidth = 440.0;
        if (media.size.width <= 480 || child == null) {
          return child ?? const SizedBox.shrink();
        }
        return ColoredBox(
          color: AppColors.frame,
          child: Center(
            child: SizedBox(
              width: frameWidth,
              child: MediaQuery(
                data: media.copyWith(size: Size(frameWidth, media.size.height)),
                child: child,
              ),
            ),
          ),
        );
      },
      // Uber-like route motion: a soft fade-through with a small upward slide.
      customTransition: _FadeThroughTransition(),
      transitionDuration: const Duration(milliseconds: 260),
      initialRoute: AppPages.initial,
      getPages: AppPages.routes,
    );
  }
}

/// Fade-through + soft slide page transition (incoming fades up & in).
class _FadeThroughTransition extends CustomTransition {
  @override
  Widget buildTransition(
    BuildContext context,
    Curve? curve,
    Alignment? alignment,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.015),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}
