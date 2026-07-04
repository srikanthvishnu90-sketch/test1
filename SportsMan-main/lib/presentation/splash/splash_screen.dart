import 'package:flutter/material.dart';
import 'package:get/get.dart';
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
    // Brief hold so the auth/session check resolves — no visual animation.
    await Future.delayed(const Duration(milliseconds: 1600));
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
    // Static logo only — no float, no fade, no spinner.
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.slateWall),
        child: Center(
          // Transparent S figure, rendered BLACK on the slate wall — matches
          // the source mark (black S on slate). Static — no motion.
          child: ColorFiltered(
            colorFilter: const ColorFilter.mode(Colors.black, BlendMode.srcIn),
            child: Image.asset(AppAssets.appLogo, width: 104, height: 104),
          ),
        ),
      ),
    );
  }
}
