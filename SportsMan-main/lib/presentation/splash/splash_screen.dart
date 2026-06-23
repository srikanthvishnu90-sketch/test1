import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:animate_do/animate_do.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
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
    return Container(
      // Radial "lit-from-center" field — the screen emits light (Kalshi/Whoop
      // register) instead of a flat slate fill.
      decoration: const BoxDecoration(gradient: AppColors.slateGlowWall),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: FadeIn(
            duration: const Duration(milliseconds: 1500),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // White mark with a soft slate BLOOM behind it (drop-shadow
                // halo) so it reads as glowing, not painted.
                Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: AppColors.glowHalo, blurRadius: 56, spreadRadius: 8),
                      BoxShadow(color: AppColors.glowHalo, blurRadius: 18, spreadRadius: 2),
                    ],
                  ),
                  child: ColorFiltered(
                    colorFilter: const ColorFilter.mode(
                      Colors.white,
                      BlendMode.srcIn,
                    ),
                    child: Image.asset(AppAssets.appLogo, width: 72, height: 72),
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
