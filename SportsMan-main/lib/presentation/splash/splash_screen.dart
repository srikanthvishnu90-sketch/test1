import 'package:flutter/material.dart';
import 'package:flutter_structure/core/theme/app_typography.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_assets.dart';
import '../../core/auth/auth_controller.dart';
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
    final token = AuthController.accessToken;

    if (token != null && token.isNotEmpty) {
      // Token exists — navigate directly to the correct screen.
      // If it's expired, the NetworkCaller interceptor will silently call
      // POST /auth/refresh-token (with the cookie) and retry automatically.
      if (mounted) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final nextRoute = await authProvider.determineNextRoute();
        Get.offAllNamed(nextRoute);
      }
    } else {
      // No stored session — go to login
      Get.offAllNamed(AppRoutes.authEntry);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.slateWall),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: FadeIn(
            duration: const Duration(milliseconds: 1500),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo rendered as a solid WHITE mark on the deep-slate wall.
                ColorFiltered(
                  colorFilter: const ColorFilter.mode(
                    Colors.white,
                    BlendMode.srcIn,
                  ),
                  child: Image.asset(AppAssets.appLogo, width: 72, height: 72),
                ),
                const SizedBox(height: 18),
                Text(
                  'SPORVE',
                  style: AppTypography.font(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.white.withOpacity(0.6),
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
