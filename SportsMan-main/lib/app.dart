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
        // Transparent so the app-wide ambient glow backdrop (builder below)
        // shows behind every screen.
        scaffoldBackgroundColor: Colors.transparent,
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
        // Ambient "lit-from-center" glow behind EVERY screen — transparent
        // scaffolds reveal it, so the whole app shares one emissive feel.
        final glow = DecoratedBox(
          decoration: const BoxDecoration(gradient: AppColors.canvasGlow),
          child: child ?? const SizedBox.shrink(),
        );
        if (media.size.width <= 480 || child == null) {
          return glow;
        }
        return ColoredBox(
          color: AppColors.frame,
          child: Center(
            child: SizedBox(
              width: frameWidth,
              child: MediaQuery(
                data: media.copyWith(size: Size(frameWidth, media.size.height)),
                child: glow,
              ),
            ),
          ),
        );
      },
      // Near-instant page motion (Uber/Airbnb feel): a single fast fade, no
      // slide — slides read as lag on web. Sub-150ms keeps switches crisp.
      defaultTransition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 120),
      initialRoute: AppPages.initial,
      getPages: AppPages.routes,
    );
  }
}
