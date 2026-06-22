import 'package:flutter/material.dart';
import 'package:flutter_structure/core/theme/app_typography.dart';
import '../widgets/common_widgets.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/mock/mock_data.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  // Push Notification toggles
  bool _pushMessages = true;
  bool _pushBookings = true;
  bool _pushPromotions = false;
  bool _pushReminders = true;

  // Email toggles
  bool _emailMessages = false;
  bool _emailBookings = true;
  bool _emailPromotions = false;
  bool _emailWeeklyDigest = true;

  // SMS toggles
  bool _smsBookings = true;
  bool _smsReminders = true;
  bool _smsPromotions = false;

  @override
  void initState() {
    super.initState();
    final p = MockData.notificationPrefs;
    if (p.isNotEmpty) {
      _pushMessages = p['pushMessages'] ?? _pushMessages;
      _pushBookings = p['pushBookings'] ?? _pushBookings;
      _pushPromotions = p['pushPromotions'] ?? _pushPromotions;
      _pushReminders = p['pushReminders'] ?? _pushReminders;
      _emailMessages = p['emailMessages'] ?? _emailMessages;
      _emailBookings = p['emailBookings'] ?? _emailBookings;
      _emailPromotions = p['emailPromotions'] ?? _emailPromotions;
      _emailWeeklyDigest = p['emailWeeklyDigest'] ?? _emailWeeklyDigest;
      _smsBookings = p['smsBookings'] ?? _smsBookings;
      _smsReminders = p['smsReminders'] ?? _smsReminders;
      _smsPromotions = p['smsPromotions'] ?? _smsPromotions;
    }
  }

  /// Update a toggle and persist all preferences immediately.
  void _setPref(VoidCallback change) {
    setState(change);
    MockData.notificationPrefs = {
      'pushMessages': _pushMessages,
      'pushBookings': _pushBookings,
      'pushPromotions': _pushPromotions,
      'pushReminders': _pushReminders,
      'emailMessages': _emailMessages,
      'emailBookings': _emailBookings,
      'emailPromotions': _emailPromotions,
      'emailWeeklyDigest': _emailWeeklyDigest,
      'smsBookings': _smsBookings,
      'smsReminders': _smsReminders,
      'smsPromotions': _smsPromotions,
    };
  }

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
                      decoration: BoxDecoration(
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
            const SizedBox(height: 24),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // PUSH NOTIFICATIONS
                    _buildSectionLabel('PUSH NOTIFICATIONS'),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadii.card),
                        border: Border.all(color: AppColors.hairline),
                      ),
                      child: Column(
                        children: [
                          _buildToggleRow(
                            icon: Icons.chat_bubble_outline,
                            title: 'Messages',
                            subtitle: 'New messages from athletes or coaches',
                            value: _pushMessages,
                            onChanged: (v) => _setPref(() => _pushMessages = v),
                          ),
                          const Divider(color: AppColors.hairline, height: 1),
                          _buildToggleRow(
                            icon: Icons.calendar_today_outlined,
                            title: 'Bookings',
                            subtitle: 'New, cancelled, or updated bookings',
                            value: _pushBookings,
                            onChanged: (v) => _setPref(() => _pushBookings = v),
                          ),
                          const Divider(color: AppColors.hairline, height: 1),
                          _buildToggleRow(
                            icon: Icons.local_offer_outlined,
                            title: 'Promotions',
                            subtitle: 'Deals, offers, and special events',
                            value: _pushPromotions,
                            onChanged: (v) => _setPref(() => _pushPromotions = v),
                          ),
                          const Divider(color: AppColors.hairline, height: 1),
                          _buildToggleRow(
                            icon: Icons.alarm_outlined,
                            title: 'Reminders',
                            subtitle: 'Upcoming session reminders',
                            value: _pushReminders,
                            onChanged: (v) => _setPref(() => _pushReminders = v),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // EMAIL NOTIFICATIONS
                    _buildSectionLabel('EMAIL NOTIFICATIONS'),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadii.card),
                        border: Border.all(color: AppColors.hairline),
                      ),
                      child: Column(
                        children: [
                          _buildToggleRow(
                            icon: Icons.chat_bubble_outline,
                            title: 'Messages',
                            subtitle: 'Email copies of new messages',
                            value: _emailMessages,
                            onChanged: (v) => _setPref(() => _emailMessages = v),
                          ),
                          const Divider(color: AppColors.hairline, height: 1),
                          _buildToggleRow(
                            icon: Icons.calendar_today_outlined,
                            title: 'Bookings',
                            subtitle: 'Booking confirmations and receipts',
                            value: _emailBookings,
                            onChanged: (v) => _setPref(() => _emailBookings = v),
                          ),
                          const Divider(color: AppColors.hairline, height: 1),
                          _buildToggleRow(
                            icon: Icons.local_offer_outlined,
                            title: 'Promotions',
                            subtitle: 'Marketing emails and newsletters',
                            value: _emailPromotions,
                            onChanged: (v) => _setPref(() => _emailPromotions = v),
                          ),
                          const Divider(color: AppColors.hairline, height: 1),
                          _buildToggleRow(
                            icon: Icons.summarize_outlined,
                            title: 'Weekly Digest',
                            subtitle: 'Weekly summary of your activity',
                            value: _emailWeeklyDigest,
                            onChanged: (v) => _setPref(() => _emailWeeklyDigest = v),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // SMS NOTIFICATIONS
                    _buildSectionLabel('SMS NOTIFICATIONS'),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadii.card),
                        border: Border.all(color: AppColors.hairline),
                      ),
                      child: Column(
                        children: [
                          _buildToggleRow(
                            icon: Icons.calendar_today_outlined,
                            title: 'Bookings',
                            subtitle: 'SMS alerts for booking changes',
                            value: _smsBookings,
                            onChanged: (v) => _setPref(() => _smsBookings = v),
                          ),
                          const Divider(color: AppColors.hairline, height: 1),
                          _buildToggleRow(
                            icon: Icons.alarm_outlined,
                            title: 'Reminders',
                            subtitle: 'Text reminders before sessions',
                            value: _smsReminders,
                            onChanged: (v) => _setPref(() => _smsReminders = v),
                          ),
                          const Divider(color: AppColors.hairline, height: 1),
                          _buildToggleRow(
                            icon: Icons.local_offer_outlined,
                            title: 'Promotions',
                            subtitle: 'Promotional text messages',
                            value: _smsPromotions,
                            onChanged: (v) => _setPref(() => _smsPromotions = v),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Info disclaimer
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.hairlineSoft,
                        borderRadius: BorderRadius.circular(AppRadii.card),
                        border: Border.all(color: AppColors.hairline),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: AppColors.textTertiary, size: 20),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              "You can change these preferences at any time. We'll never share your contact information with third parties.",
                              style: AppTypography.font(
                                color: AppColors.textTertiary,
                                fontSize: 11,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: AppTypography.font(
        color: AppColors.textTertiary,
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.0,
      ),
    );
  }

  Widget _buildToggleRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 20),
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
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTypography.font(
                    color: AppColors.textTertiary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            height: 28,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: AppColors.slateText,
              activeTrackColor: AppColors.slateTint,
              inactiveThumbColor: AppColors.textTertiary,
              inactiveTrackColor: AppColors.surface2,
            ),
          ),
        ],
      ),
    );
  }
}
