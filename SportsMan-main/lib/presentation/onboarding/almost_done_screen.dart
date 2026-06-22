import 'package:flutter/material.dart';
import 'package:flutter_structure/core/theme/app_typography.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import './controllers/onboarding_controller.dart';
import '../widgets/sporve_button.dart';

class AlmostDoneScreen extends StatelessWidget {
  const AlmostDoneScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OnboardingProvider>();

    return Scaffold(
      backgroundColor: AppColors.navyDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Text(
                'STEP 4 OF 4',
                style: AppTypography.font(color: AppColors.textTertiary, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Almost done',
              style: AppTypography.font(
                fontSize: 26,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadii.card),
                border: Border.all(color: AppColors.hairline),
              ),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 50,
                    backgroundImage: NetworkImage(
                        'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=500&auto=format&fit=crop&q=60'),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    provider.fullName.isEmpty ? 'Your Name' : provider.fullName,
                    style: AppTypography.font(fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    'AGE: ${provider.selectedAgeRange}',
                    style: AppTypography.font(
                        fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.slateText, letterSpacing: 2),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: provider.selectedSports.map((sport) => _buildMiniChip(sport)).toList(),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: BorderRadius.circular(AppRadii.tile),
                      border: Border.all(color: AppColors.hairline),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MISSION',
                          style: AppTypography.font(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 1),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          provider.selectedMission,
                          style: AppTypography.font(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Across ${provider.selectedSports.length} sports',
                          style: AppTypography.font(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadii.card),
                border: Border.all(color: AppColors.hairline),
              ),
              child: Text(
                'Your goal applies across all ${provider.selectedSports.length} sports you selected. We\'ll tailor your recommendations accordingly.',
                style: AppTypography.font(color: AppColors.textSecondary, fontSize: 11),
              ),
            ),
            const Spacer(),
            SporveButton(
              'Create my profile',
              onPressed: provider.isLoading
                  ? null
                  : () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final success = await provider.submitAthleteProfile();
                      if (success) {
                        Get.offAllNamed(AppRoutes.mainNav);
                      } else {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Failed to create profile. Please try again.'),
                            backgroundColor: AppColors.negative,
                          ),
                        );
                      }
                    },
              loading: provider.isLoading,
              variant: SporveButtonVariant.primary,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(AppRadii.chip),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Text(
        label,
        style: AppTypography.font(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
      ),
    );
  }
}
