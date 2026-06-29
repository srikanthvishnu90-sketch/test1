import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_structure/core/theme/app_typography.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../onboarding/controllers/onboarding_controller.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_assets.dart';
import '../widgets/sporve_button.dart';

/// Apple Sign In is gated OFF until the Apple Developer account + Supabase
/// provider exist (a button that errors is worse than none — audit #14).
const bool kAppleSignInEnabled = false;

class AuthEntryScreen extends StatelessWidget {
  const AuthEntryScreen({super.key});

  /// Code-half of OAuth (#12): kicks off Supabase Google OAuth. Functions once
  /// the Google provider is enabled in the Supabase dashboard + a Google Cloud
  /// OAuth client is configured; until then it surfaces a clear message.
  Future<void> _continueWithGoogle() async {
    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? Uri.base.origin : null,
      );
    } catch (e) {
      debugPrint('Google OAuth failed: $e');
      Get.snackbar(
        'Google sign-in',
        'Google sign-in isn\'t available yet. Use email for now.',
        backgroundColor: AppColors.surface,
        colorText: AppColors.textPrimary,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isServiceProvider = context
        .watch<OnboardingProvider>()
        .isServiceProvider;

    const ink = Colors.white; // slate wall → white logo/text/accents
    return Container(
      color: AppColors.slate,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              children: [
                const Spacer(flex: 2),
                // Logo rendered as a solid dark mark on the slate wall.
                Center(
                  child: ColorFiltered(
                    colorFilter: const ColorFilter.mode(ink, BlendMode.srcIn),
                    child: Image.asset(
                      AppAssets.appLogo,
                      width: 80,
                      height: 80,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Sporve',
                  style: AppTypography.font(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 10),
                // Portal switch pill — translucent ink on slate.
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: ink.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isServiceProvider
                            ? 'Coach or program'
                            : 'Athlete & family',
                        style: AppTypography.font(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: ink.withValues(alpha: 0.7),
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          context.read<OnboardingProvider>().setServiceProvider(
                            !isServiceProvider,
                          );
                        },
                        child: Text(
                          'Switch',
                          style: AppTypography.font(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(flex: 3),
                // Buttons — white social pills, translucent-ink get-started.
                Text(
                  'LAST USED',
                  style: AppTypography.font(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    color: ink.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 8),
                SporveButton(
                  'Continue with Google',
                  leadingWidget: SvgPicture.asset(
                    'assets/icons/google.svg',
                    width: 20,
                    height: 20,
                  ),
                  onPressed: _continueWithGoogle,
                  variant: SporveButtonVariant.white,
                ),
                // Apple is hidden until kAppleSignInEnabled (audit #14).
                if (kAppleSignInEnabled) ...[
                  const SizedBox(height: 14),
                  SporveButton(
                    'Continue with Apple',
                    leadingWidget: SvgPicture.asset(
                      'assets/icons/apple.svg',
                      width: 20,
                      height: 20,
                    ),
                    onPressed: () {},
                    variant: SporveButtonVariant.white,
                  ),
                ],
                const SizedBox(height: 14),
                SporveButton(
                  'Continue with email',
                  icon: Icons.arrow_forward,
                  onPressed: () => Get.toNamed(AppRoutes.onboarding),
                  variant: SporveButtonVariant.secondary,
                  onDark: true,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Already have an account? ',
                      style: AppTypography.font(
                        color: ink.withValues(alpha: 0.7),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Get.toNamed(
                        isServiceProvider
                            ? AppRoutes.providerLogin
                            : AppRoutes.login,
                      ),
                      child: Text(
                        'Log in',
                        style: AppTypography.font(
                          color: ink,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'By continuing, you acknowledge and agree to Sporve\'s Terms of Service and Privacy Policy.',
                  textAlign: TextAlign.center,
                  style: AppTypography.font(
                    color: ink.withValues(alpha: 0.5),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
