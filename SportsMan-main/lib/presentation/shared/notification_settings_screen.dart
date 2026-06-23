import 'package:flutter/material.dart';
import 'package:flutter_structure/core/theme/app_typography.dart';
import '../widgets/common_widgets.dart';
import '../../core/theme/app_colors.dart';

// TODO(notifications): This screen previously rendered 11 push/email/SMS toggles
// (pushMessages, pushBookings, pushPromotions, pushReminders, emailMessages,
// emailBookings, emailPromotions, emailWeeklyDigest, smsBookings, smsReminders,
// smsPromotions) wired to MockData.notificationPrefs. They persisted nowhere real
// (no push/email backend, no DB column), so the dead switches were HIDDEN and an
// honest placeholder is shown instead. The preference MODEL
// (MockData.notificationPrefs) is intentionally left intact. Restore the toggle
// UI + per-pref fields here once the email/push backend exists.
class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: AppColors.hairline,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back, color: AppColors.textPrimary, size: 20),
                    ),
                  ),
                  Text(
                    'Notifications',
                    style: AppTypography.font(
                      color: AppColors.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.notifications_none, color: AppColors.textTertiary, size: 40),
                      const SizedBox(height: 16),
                      Text(
                        'Notification settings are coming soon.',
                        textAlign: TextAlign.center,
                        style: AppTypography.font(color: AppColors.textSecondary, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
