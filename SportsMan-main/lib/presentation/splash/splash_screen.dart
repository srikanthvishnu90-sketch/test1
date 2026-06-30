import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:animate_do/animate_do.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/constants/app_assets.dart';
import 'package:provider/provider.dart';
import '../authentication/controllers/auth_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToNext();
  }

  void _navigateToNext() async {
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;

    // Route guard (#18): Supabase persists the session, so a returning user is
    // already logged in here. Send them to their role's home; otherwise to the
    // auth entry screen.
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.isLoggedIn) {
      final nextRoute = await authProvider.determineNextRoute();
      Get.offAllNamed(nextRoute);
    } else {
      Get.offAllNamed(AppRoutes.authEntry);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Flat slate brand fill.
      // Depth: the slate wall gradient instead of a flat fill.
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.slateWall),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo zooms in, then breathes (infinite pulse) while loading.
              Pulse(
                infinite: true,
                duration: const Duration(milliseconds: 1800),
                child: ZoomIn(
                  duration: const Duration(milliseconds: 800),
                  child: ColorFiltered(
                    colorFilter: const ColorFilter.mode(
                      Colors.white,
                      BlendMode.srcIn,
                    ),
                    child: Image.asset(
                      AppAssets.appLogo,
                      width: 76,
                      height: 76,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              FadeInUp(
                delay: const Duration(milliseconds: 350),
                from: 12,
                child: Text(
                  'Sporve',
                  style: AppTypography.displayLarge.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.white.withValues(alpha: 0.65),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
