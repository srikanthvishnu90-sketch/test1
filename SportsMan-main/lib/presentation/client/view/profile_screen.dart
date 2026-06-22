import 'package:flutter/material.dart';
import 'package:flutter_structure/core/theme/app_typography.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../controllers/home_controller.dart';
import '../../authentication/controllers/auth_provider.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/sporve_button.dart';
import '../../widgets/sporve_image.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final homeProvider = context.watch<HomeProvider>();
    final userProfile = homeProvider.userProfile;

    return GradientScaffold(
      body: SafeArea(
        bottom: false,
        child: homeProvider.isLoadingProfile
            ? const Center(child: CircularProgressIndicator(color: AppColors.slateText))
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. TOP USER CARD
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left Column (Name and Badges)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (userProfile != null)
                                    ? [
                                        (userProfile['firstName'] ?? 'Athlete').toString(),
                                        if ((userProfile['lastName'] ?? '').toString().isNotEmpty)
                                          '${userProfile['lastName'].toString()[0]}.',
                                      ].join(' ')
                                    : 'Athlete',
                                style: AppTypography.font(
                                  color: AppColors.textPrimary,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  // Rating Badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(AppRadii.chip),
                                      border: Border.all(color: AppColors.hairline),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.star, color: AppColors.textPrimary, size: 11),
                                        const SizedBox(width: 4),
                                        Text(
                                          '4.8',
                                          style: AppTypography.font(
                                            color: AppColors.textPrimary,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  // Verified Badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.transparent,
                                      borderRadius: BorderRadius.circular(AppRadii.chip),
                                      border: Border.all(color: AppColors.slateBorder, width: 1.5),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.check, color: AppColors.slateText, size: 10),
                                        const SizedBox(width: 4),
                                        Text(
                                          'VERIFIED',
                                          style: AppTypography.font(
                                            color: AppColors.slateText,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  // Location Badge
                                  _buildTopBadge(
                                    (userProfile != null &&
                                            userProfile['address'] != null &&
                                            (userProfile['address']['city'] ?? '').toString().isNotEmpty)
                                        ? '${userProfile['address']['city'].toString().toUpperCase()}, ${(userProfile['address']['state'] ?? '').toString().toUpperCase()}'
                                        : 'LOCATION',
                                  ),
                                ],
                              ),
                            ],
                          ),
                          
                          // Right Avatar Photo
                          Container(
                            height: 64,
                            width: 64,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.hairline, width: 2),
                            ),
                            child: ClipOval(
                              child: SizedBox(
                                width: 64,
                                height: 64,
                                child: SporveImage(
                                  (userProfile != null && userProfile['profileImage'] != null)
                                      ? userProfile['profileImage']
                                      : 'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=150&auto=format&fit=crop&q=80',
                                  width: 64,
                                  height: 64,
                                  fit: BoxFit.cover,
                                  fallbackIcon: Icons.person,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

              // 2. PROFILE STRENGTH CARD (72%)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadii.card),
                    border: Border.all(color: AppColors.hairline, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Profile strength',
                            style: AppTypography.font(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '72%',
                            style: AppTypography.font(
                              color: AppColors.slateText,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Custom Linear Progress bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: const LinearProgressIndicator(
                          value: 0.72,
                          backgroundColor: AppColors.hairline,
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.slateText),
                          minHeight: 6,
                        ),
                      ),
                      const SizedBox(height: 12),
                      RichText(
                        text: TextSpan(
                          style: AppTypography.font(color: AppColors.textSecondary, fontSize: 11),
                          children: [
                            const TextSpan(text: 'Add a profile photo to get '),
                            TextSpan(
                              text: '3x more bookings',
                              style: AppTypography.font(
                                color: AppColors.slateText,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 3. AI COACH PURPLE BANNER
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.blueTint,
                    borderRadius: BorderRadius.circular(AppRadii.card),
                    border: Border.all(color: AppColors.blue.withValues(alpha: 0.5)),
                  ),
                  child: Stack(
                    children: [
                      // Subtly blended AI glyph background
                      Positioned(
                        right: 24,
                        bottom: -4,
                        child: Opacity(
                          opacity: 0.12,
                          child: const Icon(
                            Icons.auto_awesome,
                            color: AppColors.blueText,
                            size: 84,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const AIBadge(label: 'AI Coach'),
                            const SizedBox(height: 12),
                            Text(
                              'AI Coach',
                              style: AppTypography.font(
                                color: AppColors.textPrimary,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'YOUR PERSONAL SPORTS ADVISOR, ALWAYS AVAILABLE',
                              style: AppTypography.font(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 18),
                            // ASK A QUESTION Button
                            SporveButton(
                              'Ask a question',
                              onPressed: () {
                                Get.snackbar(
                                  'AI Coach',
                                  'AI Sports Advisor is thinking...',
                                  backgroundColor: AppColors.surface,
                                  colorText: AppColors.textPrimary,
                                );
                              },
                              variant: SporveButtonVariant.primary,
                              size: SporveButtonSize.compact,
                              icon: Icons.arrow_forward,
                              fullWidth: false,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // 4. MAIN LIST OPTIONS (ACCURATE FLOATING WHITE CARD MATCHING FIGMA)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(left: 24, right: 24, top: 12, bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadii.card),
                  border: Border.all(color: AppColors.hairline),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                child: Column(
                  children: [
                    _buildListOption(
                      icon: Icons.edit_outlined,
                      title: 'Edit Profile',
                      subtitle: 'Name, photo, sport, bio',
                    ),
                    _buildListOption(
                      icon: Icons.bookmark_border,
                      title: 'Saved Coaches',
                      subtitle: '5 saved coaches and facilities',
                    ),
                    _buildListOption(
                      icon: Icons.credit_card_outlined,
                      title: 'Payment Methods',
                      subtitle: 'Cards and billing',
                    ),
                    _buildListOption(
                      icon: Icons.notifications_none,
                      title: 'Notifications',
                      subtitle: 'Push, email, and SMS preferences',
                      onTap: () => Get.toNamed(AppRoutes.notificationSettings),
                    ),
                    _buildListOption(
                      icon: Icons.shield_outlined,
                      title: 'Privacy & Security',
                      subtitle: 'Visibility, data, and password',
                    ),
                    _buildListOption(
                      icon: Icons.help_outline,
                      title: 'Help & Support',
                      subtitle: 'FAQs, contact us, report a problem',
                    ),
                    _buildListOption(
                      icon: Icons.gavel_outlined,
                      title: 'Legal',
                      subtitle: 'Terms, privacy policy, licenses',
                    ),
                    
                    const SizedBox(height: 16),

                    // Sign Out Button
                    SporveButton(
                      'Sign out',
                      onPressed: () async {
                        final authProvider = Provider.of<AuthProvider>(context, listen: false);
                        await authProvider.logout();
                        Get.offAllNamed(AppRoutes.authEntry);
                      },
                      variant: SporveButtonVariant.destructive,
                      icon: Icons.exit_to_app,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 100), // spacing for bottom navigation bar
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadii.chip),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Text(
        text,
        style: AppTypography.font(
          color: AppColors.textPrimary,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildListOption({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap ?? () {
        Get.snackbar(
          title,
          'Opening $title settings...',
          backgroundColor: AppColors.surface,
          colorText: AppColors.textPrimary,
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: AppColors.textSecondary, size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.font(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTypography.font(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textTertiary, size: 16),
          ],
        ),
      ),
    );
  }
}
