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

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  // Continuous gentle up/down float for the logo.
  late final AnimationController _float;

  @override
  void initState() {
    super.initState();
    _float = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    _navigateToNext();
  }

  @override
  void dispose() {
    _float.dispose();
    super.dispose();
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
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.slateWall),
        child: Center(
          child: FadeIn(
            duration: const Duration(milliseconds: 900),
            child: AnimatedBuilder(
              animation: _float,
              builder: (context, child) {
                // Ease the value so the float feels soft at the turns.
                final t = Curves.easeInOut.transform(_float.value);
                return Transform.translate(
                  offset: Offset(0, -9 + 18 * t), // floats ~±9px
                  child: child,
                );
              },
              child: ColorFiltered(
                colorFilter: const ColorFilter.mode(
                  Colors.white,
                  BlendMode.srcIn,
                ),
                child: Image.asset(AppAssets.appLogo, width: 84, height: 84),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
