import 'package:flutter/material.dart';
import 'package:flutter_structure/core/theme/app_typography.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get/get.dart';
import 'package:animate_do/animate_do.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/sporve_button.dart';
import '../../widgets/sporve_image.dart';
import '../../../core/mock/mock_data.dart';

class PersonalProfileScreen extends StatefulWidget {
  const PersonalProfileScreen({super.key});

  @override
  State<PersonalProfileScreen> createState() => _PersonalProfileScreenState();
}

class _PersonalProfileScreenState extends State<PersonalProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  // Settings State
  bool _pushEnabled = false;
  bool _emailEnabled = false;
  bool _inAppEnabled = false;
  bool _bookingReminderEnabled = false;
  bool _smsAlertsEnabled = false;

  bool _listingVisibility = false;
  bool _activityStatusEnabled = false;
  bool _shareUsageDataEnabled = false;

  bool _isLoading = false;
  bool _isFetching = true;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    setState(() {
      _isFetching = true;
    });

    try {
      final data = MockData.userProfile;
      if (data.isNotEmpty) {
        _firstNameController.text = data['firstName'] ?? '';
        _lastNameController.text = data['lastName'] ?? '';
        _emailController.text = data['email'] ?? '';

        _pushEnabled = data['pushEnabled'] ?? false;
        _emailEnabled = data['emailEnabled'] ?? false;
        _inAppEnabled = data['inAppEnabled'] ?? false;
        _bookingReminderEnabled = data['bookingReminderEnabled'] ?? false;
        _smsAlertsEnabled = data['smsAlertsEnabled'] ?? false;

        _listingVisibility = data['listingVisibility'] ?? false;
        _activityStatusEnabled = data['activityStatusEnabled'] ?? false;
        _shareUsageDataEnabled = data['shareUsageDataEnabled'] ?? false;
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'An error occurred: $e',
        backgroundColor: AppColors.negative,
        colorText: AppColors.textPrimary,
      );
    } finally {
      setState(() {
        _isFetching = false;
      });
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    final Map<String, dynamic> body = {
      ...MockData.userProfile,
      'firstName': _firstNameController.text.trim(),
      'lastName': _lastNameController.text.trim(),
      'pushEnabled': _pushEnabled,
      'emailEnabled': _emailEnabled,
      'inAppEnabled': _inAppEnabled,
      'bookingReminderEnabled': _bookingReminderEnabled,
      'smsAlertsEnabled': _smsAlertsEnabled,
      'listingVisibility': _listingVisibility,
      'activityStatusEnabled': _activityStatusEnabled,
      'shareUsageDataEnabled': _shareUsageDataEnabled,
    };

    try {
      MockData.userProfile = body;
      Get.snackbar(
        'Success',
        'Personal profile updated successfully!',
        backgroundColor: AppColors.slateText,
        colorText: AppColors.onSlate,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'An error occurred: $e',
        backgroundColor: AppColors.negative,
        colorText: AppColors.textPrimary,
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'Personal Profile',
          style: AppTypography.font(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _isFetching
            ? const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Profile Image
                      FadeInDown(
                        duration: const Duration(milliseconds: 500),
                        child: Center(
                          child: Stack(
                            children: [
                              Container(
                                height: 100,
                                width: 100,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.hairline, width: 3),
                                ),
                                child: ClipOval(
                                  child: SizedBox(
                                    width: 100,
                                    height: 100,
                                    child: SporveImage(
                                      'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=200&auto=format&fit=crop&q=80',
                                      width: 100,
                                      height: 100,
                                      fit: BoxFit.cover,
                                      fallbackIcon: Icons.person,
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: AppColors.slateText,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.camera_alt, color: AppColors.onSlate, size: 16),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Basic Info Section
                      FadeInUp(
                        duration: const Duration(milliseconds: 600),
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(AppRadii.card),
                            border: Border.all(color: AppColors.hairlineSoft, width: 1),
                          ),
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'BASIC INFORMATION',
                                style: AppTypography.font(
                                  color: AppColors.textGrey,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(
                                controller: _firstNameController,
                                label: 'First Name',
                                validator: (v) => v!.isEmpty ? 'First name is required' : null,
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(
                                controller: _lastNameController,
                                label: 'Last Name',
                                validator: (v) => v!.isEmpty ? 'Last name is required' : null,
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(
                                controller: _emailController,
                                label: 'Email Address',
                                readOnly: true,
                                keyboardType: TextInputType.emailAddress,
                              ),
                            ],
                          ),
                        ),
                      ),
                      /*
                      const SizedBox(height: 20),

                      // Notification Preferences Section
                      FadeInUp(
                        duration: const Duration(milliseconds: 700),
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(AppRadii.card),
                            border: Border.all(color: AppColors.hairline, width: 1),
                          ),
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'NOTIFICATION PREFERENCES',
                                style: AppTypography.font(
                                  color: AppColors.textGrey,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildSwitchRow(
                                title: 'Push Notifications',
                                subtitle: 'Receive alerts on your mobile device',
                                value: _pushEnabled,
                                onChanged: (val) => setState(() => _pushEnabled = val),
                              ),
                              const Divider(color: Colors.white10),
                              _buildSwitchRow(
                                title: 'Email Notifications',
                                subtitle: 'Receive summaries and updates via email',
                                value: _emailEnabled,
                                onChanged: (val) => setState(() => _emailEnabled = val),
                              ),
                              const Divider(color: Colors.white10),
                              _buildSwitchRow(
                                title: 'In-App Alerts',
                                subtitle: 'Get instant notices within the platform',
                                value: _inAppEnabled,
                                onChanged: (val) => setState(() => _inAppEnabled = val),
                              ),
                              const Divider(color: Colors.white10),
                              _buildSwitchRow(
                                title: 'Booking Reminders',
                                subtitle: 'Reminders for upcoming program sessions',
                                value: _bookingReminderEnabled,
                                onChanged: (val) => setState(() => _bookingReminderEnabled = val),
                              ),
                              const Divider(color: Colors.white10),
                              _buildSwitchRow(
                                title: 'SMS Alerts',
                                subtitle: 'Get urgent updates via text messaging',
                                value: _smsAlertsEnabled,
                                onChanged: (val) => setState(() => _smsAlertsEnabled = val),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Privacy Section
                      FadeInUp(
                        duration: const Duration(milliseconds: 800),
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(AppRadii.card),
                            border: Border.all(color: AppColors.hairline, width: 1),
                          ),
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'PRIVACY & DATA',
                                style: AppTypography.font(
                                  color: AppColors.textGrey,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildSwitchRow(
                                title: 'Listing Visibility',
                                subtitle: 'Allow your public pages to be searchable',
                                value: _listingVisibility,
                                onChanged: (val) => setState(() => _listingVisibility = val),
                              ),
                              const Divider(color: Colors.white10),
                              _buildSwitchRow(
                                title: 'Activity Status',
                                subtitle: 'Show when you are active on the platform',
                                value: _activityStatusEnabled,
                                onChanged: (val) => setState(() => _activityStatusEnabled = val),
                              ),
                              const Divider(color: Colors.white10),
                              _buildSwitchRow(
                                title: 'Share Usage Data',
                                subtitle: 'Help us improve by sending anonymous usage stats',
                                value: _shareUsageDataEnabled,
                                onChanged: (val) => setState(() => _shareUsageDataEnabled = val),
                              ),
                            ],
                          ),
                        ),
                      ),
                      */
                      const SizedBox(height: 32),

                      // Save button
                      FadeInUp(
                        duration: const Duration(milliseconds: 900),
                        child: SporveButton(
                          'Save changes',
                          onPressed: _isLoading ? null : _saveProfile,
                          variant: SporveButtonVariant.primary,
                          loading: _isLoading,
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildSwitchRow({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.font(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTypography.font(
                    color: AppColors.textGrey,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.accentBlue,
            activeTrackColor: AppColors.accentBlue.withOpacity(0.3),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    bool readOnly = false,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: AppTypography.font(
            color: AppColors.textTertiary,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          readOnly: readOnly,
          style: AppTypography.font(
            color: readOnly ? AppColors.textSecondary : AppColors.textPrimary,
            fontSize: 14,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surface2,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.tile),
              borderSide: const BorderSide(color: AppColors.hairline),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.tile),
              borderSide: BorderSide(
                color: readOnly ? AppColors.hairline : AppColors.slateText,
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.tile),
              borderSide: const BorderSide(color: AppColors.negative),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.tile),
              borderSide: const BorderSide(color: AppColors.negative, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }
}
