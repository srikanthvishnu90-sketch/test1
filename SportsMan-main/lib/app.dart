import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'core/routes/app_pages.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_typography.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData(
      useMaterial3: true,
      fontFamily: AppTypography.fontFamily,
    );
    return GetMaterialApp(
      title: 'Sporve',
      debugShowCheckedModeBanner: false,
      theme: base.copyWith(
        // Solid near-black canvas behind every screen.
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
        // Any Material route (Navigator.push) also swaps instantly — no native
        // slide/zoom — so it matches the GetX no-transition behaviour below.
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: _NoTransitionsBuilder(),
            TargetPlatform.iOS: _NoTransitionsBuilder(),
            TargetPlatform.macOS: _NoTransitionsBuilder(),
            TargetPlatform.windows: _NoTransitionsBuilder(),
            TargetPlatform.linux: _NoTransitionsBuilder(),
            TargetPlatform.fuchsia: _NoTransitionsBuilder(),
          },
        ),
      ),
      // On wide screens (desktop web), render inside a centered phone-width
      // frame so the mobile app keeps its intended proportions instead of being
      // stretched across the whole window.
      builder: (context, child) {
        final media = MediaQuery.of(context);
        const frameWidth = 440.0;
        // Solid near-black canvas behind EVERY screen.
        final canvas = ColoredBox(
          color: AppColors.ink,
          child: child ?? const SizedBox.shrink(),
        );
        if (media.size.width <= 480 || child == null) {
          return canvas;
        }
        return ColoredBox(
          color: AppColors.frame,
          child: Center(
            child: SizedBox(
              width: frameWidth,
              child: MediaQuery(
                data: media.copyWith(size: Size(frameWidth, media.size.height)),
                child: canvas,
              ),
            ),
          ),
        );
      },
      // Instant, direct page swaps — no fade/slide to "see". Tab content already
      // switches instantly via IndexedStack; this makes route pushes match.
      defaultTransition: Transition.noTransition,
      transitionDuration: Duration.zero,
      initialRoute: AppPages.initial,
      getPages: AppPages.routes,
    );
  }
}

/// A page-transition builder that performs NO animation — the new page appears
/// immediately. Applied to every platform so Material routes match the GetX
/// no-transition behaviour for a clean, direct page-to-page swap.
class _NoTransitionsBuilder extends PageTransitionsBuilder {
  const _NoTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}
