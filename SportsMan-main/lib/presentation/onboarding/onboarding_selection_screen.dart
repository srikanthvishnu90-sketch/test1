import 'package:flutter/material.dart';
import 'package:flutter_structure/core/theme/app_typography.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import './controllers/onboarding_controller.dart';

class OnboardingSelectionScreen extends StatelessWidget {
  const OnboardingSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<OnboardingProvider>();

    return Scaffold(
      backgroundColor: AppColors.navyDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Get.back(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Text(
                'How will you use Sporve?',
                style: AppTypography.font(
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Choose your account type to get started.',
                style: AppTypography.font(
                  color: AppColors.textSecondary,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 32),
              _buildOptionCard(
                title: 'Athlete & Family',
                subtitle: 'Find coaches, book sessions, and manage your entire athletic schedule in one place.',
                icon: Icons.directions_run,
                accent: AppColors.slateText,
                tint: AppColors.slateTint,
                onTap: () {
                  provider.setServiceProvider(false);
                  Get.toNamed(AppRoutes.selectSports);
                },
              ),
              const SizedBox(height: 20),
              _buildOptionCard(
                title: 'Coach or program',
                subtitle: 'Manage your program — bookings, athletes, payments, and more.',
                icon: Icons.person_search,
                accent: AppColors.blueText,
                tint: AppColors.blueTint,
                onTap: () {
                  provider.setServiceProvider(true);
                  Get.toNamed(AppRoutes.providerIdentity);
                },
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Already have an account? ',
                    style: AppTypography.font(color: AppColors.textSecondary),
                  ),
                  GestureDetector(
                    onTap: () => Get.toNamed(
                      context.read<OnboardingProvider>().isServiceProvider
                          ? AppRoutes.providerLogin
                          : AppRoutes.login,
                    ),
                    child: Text(
                      'Log in',
                      style: AppTypography.font(
                        color: AppColors.slateText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accent,
    required Color tint,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: AppColors.hairline),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: tint,
                borderRadius: BorderRadius.circular(AppRadii.tile),
              ),
              child: Icon(icon, color: accent, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.font(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: AppTypography.font(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward, color: accent, size: 20),
          ],
        ),
      ),
    );
  }
}
