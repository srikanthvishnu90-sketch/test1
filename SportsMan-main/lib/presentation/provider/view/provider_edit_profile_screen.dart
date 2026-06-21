import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_structure/core/theme/app_typography.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/mock/mock_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/sporve_button.dart';
import '../../widgets/sporve_image.dart';

class ProviderEditProfileScreen extends StatefulWidget {
  const ProviderEditProfileScreen({super.key});

  @override
  State<ProviderEditProfileScreen> createState() => _ProviderEditProfileScreenState();
}

class _ProviderEditProfileScreenState extends State<ProviderEditProfileScreen> {
  final TextEditingController _firstNameController = TextEditingController(text: 'Vishnu');
  final TextEditingController _lastNameController = TextEditingController(text: 'S.');
  final TextEditingController _bioController = TextEditingController(
    text: 'Professional basketball coach with 10+ years of experience training elite athletes. Specializing in guard development, shooting mechanics, and mental performance.',
  );
  final TextEditingController _locationController = TextEditingController(text: 'Chicago, IL');
  final TextEditingController _phoneController = TextEditingController(text: '+1 (312) 555-0147');
  final TextEditingController _emailController = TextEditingController(text: 'vishnu.s@sporve.com');

  String _selectedSport = 'Basketball';
  final List<String> _sports = ['Basketball', 'Football', 'Soccer', 'Tennis', 'Baseball', 'Swimming', 'Golf', 'Track & Field'];

  // Locally-picked avatar (demo): blob URL on web, file path on mobile.
  String? _avatarPath;

  Future<void> _pickAvatar() async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image != null) setState(() => _avatarPath = image.path);
  }

  void _save() {
    final user = Map<String, dynamic>.from(MockData.userProfile);
    user['firstName'] = _firstNameController.text.trim();
    user['lastName'] = _lastNameController.text.trim();
    user['email'] = _emailController.text.trim();
    user['phoneNumber'] = _phoneController.text.trim();
    MockData.userProfile = user;

    final prov = Map<String, dynamic>.from(MockData.providerProfile);
    prov['bio'] = _bioController.text.trim();
    prov['location'] = _locationController.text.trim();
    prov['sports'] = [_selectedSport];
    MockData.providerProfile = prov;

    Get.snackbar(
      'Saved',
      'Your profile has been updated.',
      backgroundColor: AppColors.surface,
      colorText: AppColors.textPrimary,
    );
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _bioController.dispose();
    _locationController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
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
                  SporveIconButton(
                    Icons.arrow_back,
                    circle: true,
                    iconSize: 20,
                    onTap: () => Navigator.pop(context),
                  ),
                  Text(
                    'Edit Profile',
                    style: AppTypography.font(
                      color: AppColors.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Photo section
                    Center(
                      child: Column(
                        children: [
                          Stack(
                            children: [
                              Container(
                                height: 100,
                                width: 100,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.hairline, width: 3),
                                ),
                                child: _avatarPath != null
                                    ? (kIsWeb
                                        ? SporveImage(_avatarPath, width: 100, height: 100, fit: BoxFit.cover, radius: 50)
                                        : ClipRRect(
                                            borderRadius: BorderRadius.circular(50),
                                            child: Image.file(File(_avatarPath!), width: 100, height: 100, fit: BoxFit.cover),
                                          ))
                                    : SporveImage(
                                        'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=200&auto=format&fit=crop&q=80',
                                        width: 100,
                                        height: 100,
                                        fit: BoxFit.cover,
                                        radius: 50,
                                      ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: SporveIconButton(
                                  Icons.camera_alt,
                                  filled: true,
                                  circle: true,
                                  size: 32,
                                  iconSize: 16,
                                  onTap: _pickAvatar,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Tap to change photo',
                            style: AppTypography.font(
                              color: AppColors.textTertiary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // PERSONAL INFORMATION
                    _buildSectionLabel('PERSONAL INFORMATION'),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildInputField(
                            label: 'First name',
                            controller: _firstNameController,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildInputField(
                            label: 'Last name',
                            controller: _lastNameController,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildInputField(
                      label: 'Email',
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    _buildInputField(
                      label: 'Phone number',
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    _buildInputField(
                      label: 'Location',
                      controller: _locationController,
                    ),
                    const SizedBox(height: 32),

                    // SPORT & SPECIALIZATION
                    _buildSectionLabel('SPORT & SPECIALIZATION'),
                    const SizedBox(height: 16),

                    // Sport dropdown
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Primary sport',
                          style: AppTypography.font(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          height: 56,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: AppColors.surface2,
                            borderRadius: BorderRadius.circular(AppRadii.tile),
                            border: Border.all(color: AppColors.hairline),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedSport,
                              isExpanded: true,
                              dropdownColor: AppColors.surface2,
                              style: AppTypography.font(color: AppColors.textPrimary, fontSize: 13),
                              icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textTertiary),
                              items: _sports.map((sport) {
                                return DropdownMenuItem<String>(
                                  value: sport,
                                  child: Text(sport),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedSport = value!;
                                });
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // BIO
                    _buildSectionLabel('BIO'),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface2,
                        borderRadius: BorderRadius.circular(AppRadii.tile),
                        border: Border.all(color: AppColors.hairline),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        controller: _bioController,
                        maxLines: 5,
                        maxLength: 300,
                        style: AppTypography.font(color: AppColors.textPrimary, fontSize: 13, height: 1.5),
                        decoration: InputDecoration(
                          hintText: 'Tell athletes about yourself...',
                          hintStyle: AppTypography.font(color: AppColors.textTertiary, fontSize: 13),
                          border: InputBorder.none,
                          counterStyle: AppTypography.font(color: AppColors.textTertiary, fontSize: 11),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Save Button
                    SporveButton(
                      'Save changes',
                      onPressed: _save,
                      variant: SporveButtonVariant.primary,
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

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.font(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.surface2,
            borderRadius: BorderRadius.circular(AppRadii.tile),
            border: Border.all(color: AppColors.hairline),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: AppTypography.font(color: AppColors.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: label,
              hintStyle: AppTypography.font(color: AppColors.textTertiary, fontSize: 13),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }
}
