import 'dart:io';
import 'package:flutter_structure/core/theme/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:animate_do/animate_do.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/sport_colors.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/sporve_button.dart';
import '../../widgets/sporve_image.dart';

import '../../../core/mock/mock_data.dart';

class ServiceProfileScreen extends StatefulWidget {
  const ServiceProfileScreen({super.key});

  @override
  State<ServiceProfileScreen> createState() => _ServiceProfileScreenState();
}

class _ServiceProfileScreenState extends State<ServiceProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _businessNameController = TextEditingController();

  // Selected Sports list
  final List<String> _availableSports = ['Soccer', 'Basketball', 'Tennis', 'Football', 'Swimming', 'Martial Arts', 'Baseball'];
  final List<String> _selectedSports = [];

  // Pricing Options state
  bool _perSessionActive = false;
  final TextEditingController _perSessionRate = TextEditingController();
  final TextEditingController _perSessionDuration = TextEditingController();

  bool _perHourActive = false;
  final TextEditingController _perHourRate = TextEditingController();
  final TextEditingController _perHourDuration = TextEditingController();

  bool _perSeasonActive = false;
  final TextEditingController _perSeasonRate = TextEditingController();
  final TextEditingController _perSeasonDuration = TextEditingController();

  bool _isLoading = false;
  bool _isFetching = true;

  // Selected files/URLs
  String? _logoUrl;
  String? _coverUrl;
  String? _localLogoPath;
  String? _localCoverPath;

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
      await Future.delayed(const Duration(milliseconds: 300));
      final data = MockData.providerProfile;
      if (data.isNotEmpty) {
        _businessNameController.text = data['businessName'] ?? '';
        
        if (data['supportedSports'] != null) {
          _selectedSports.clear();
          for (var sport in data['supportedSports']) {
            _selectedSports.add(sport.toString());
          }
        }

        _logoUrl = data['logo'];
        _coverUrl = data['coverImage'];

        final pricing = data['pricingOptions'];
        if (pricing != null) {
          final perSession = pricing['perSession'];
          if (perSession != null) {
            _perSessionActive = perSession['active'] ?? false;
            _perSessionRate.text = perSession['rate']?.toString() ?? '';
            _perSessionDuration.text = perSession['duration']?.toString() ?? '';
          }

          final perHour = pricing['perHour'];
          if (perHour != null) {
            _perHourActive = perHour['active'] ?? false;
            _perHourRate.text = perHour['rate']?.toString() ?? '';
            _perHourDuration.text = perHour['duration']?.toString() ?? '';
          }

          final perSeason = pricing['perSeason'];
          if (perSeason != null) {
            _perSeasonActive = perSeason['active'] ?? false;
            _perSeasonRate.text = perSeason['rate']?.toString() ?? '';
            
            final dur = perSeason['duration'];
            if (dur != null) {
              final numOnly = dur.toString().replaceAll(RegExp(r'[^0-9]'), '');
              _perSeasonDuration.text = numOnly.isNotEmpty ? numOnly : dur.toString();
            }
          }
        }
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
    _businessNameController.dispose();
    _perSessionRate.dispose();
    _perSessionDuration.dispose();
    _perHourRate.dispose();
    _perHourDuration.dispose();
    _perSeasonRate.dispose();
    _perSeasonDuration.dispose();
    super.dispose();
  }

  void _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSports.isEmpty) {
      Get.snackbar(
        'Error',
        'Please select at least one sport.',
        backgroundColor: AppColors.negative,
        colorText: AppColors.textPrimary,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final Map<String, dynamic> body = {
      'businessName': _businessNameController.text.trim(),
      'supportedSports': _selectedSports,
      'pricingOptions': {
        'perSession': {
          'active': _perSessionActive,
          'rate': double.tryParse(_perSessionRate.text) ?? 0.0,
          'duration': int.tryParse(_perSessionDuration.text) ?? 0,
        },
        'perHour': {
          'active': _perHourActive,
          'rate': double.tryParse(_perHourRate.text) ?? 0.0,
          'duration': int.tryParse(_perHourDuration.text) ?? 0,
        },
        'perSeason': {
          'active': _perSeasonActive,
          'rate': double.tryParse(_perSeasonRate.text) ?? 0.0,
          'duration': _perSeasonDuration.text.contains('Month') 
              ? _perSeasonDuration.text 
              : '${_perSeasonDuration.text} Months',
        }
      }
    };

    try {
      await Future.delayed(const Duration(milliseconds: 300));
      final prof = MockData.providerProfile;
      prof.addAll(body);
      if (_localLogoPath != null) prof['logo'] = _localLogoPath;
      if (_localCoverPath != null) prof['coverImage'] = _localCoverPath;
      MockData.providerProfile = prof;

      Get.snackbar(
        'Success',
        'Service profile updated successfully!',
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
          'Service Profile',
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
                // 1. Business Name Card
                FadeInUp(
                  duration: const Duration(milliseconds: 500),
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
                          'BUSINESS DETAILS',
                          style: AppTypography.font(
                            color: AppColors.textGrey,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _businessNameController,
                          label: 'Business / Academy Name',
                          validator: (v) => v!.isEmpty ? 'Business name is required' : null,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // 2. Supported Sports Card
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
                          'SUPPORTED SPORTS',
                          style: AppTypography.font(
                            color: AppColors.textGrey,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _availableSports.map((sport) {
                            final isSelected = _selectedSports.any((s) => s.toUpperCase() == sport.toUpperCase());
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  if (isSelected) {
                                    _selectedSports.removeWhere((s) => s.toUpperCase() == sport.toUpperCase());
                                  } else {
                                    _selectedSports.add(sport);
                                  }
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isSelected ? AppColors.slateTint : AppColors.surface,
                                  borderRadius: BorderRadius.circular(AppRadii.tile),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.slateBorder
                                        : AppColors.hairline,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      SportColors.iconOf(sport),
                                      size: 16,
                                      color: isSelected ? AppColors.slateText : AppColors.textSecondary,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      sport,
                                      style: AppTypography.font(
                                        color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                                        fontSize: 13,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // 3. Pricing Configuration Card
                FadeInUp(
                  duration: const Duration(milliseconds: 700),
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
                          'PRICING OPTIONS',
                          style: AppTypography.font(
                            color: AppColors.textGrey,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Per Session
                        _buildPricingToggleRow(
                          title: 'Per Session Pricing',
                          value: _perSessionActive,
                          onChanged: (val) => setState(() => _perSessionActive = val),
                        ),
                        if (_perSessionActive) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  controller: _perSessionRate,
                                  label: 'Rate (\$)',
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildTextField(
                                  controller: _perSessionDuration,
                                  label: 'Duration (Min)',
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const Divider(color: AppColors.hairline, height: 32),

                        // Per Hour
                        _buildPricingToggleRow(
                          title: 'Per Hour Pricing',
                          value: _perHourActive,
                          onChanged: (val) => setState(() => _perHourActive = val),
                        ),
                        if (_perHourActive) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  controller: _perHourRate,
                                  label: 'Rate (\$)',
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildTextField(
                                  controller: _perHourDuration,
                                  label: 'Duration (Min)',
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const Divider(color: AppColors.hairline, height: 32),

                        // Per Season
                        _buildPricingToggleRow(
                          title: 'Per Season Pricing',
                          value: _perSeasonActive,
                          onChanged: (val) => setState(() => _perSeasonActive = val),
                        ),
                        if (_perSeasonActive) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  controller: _perSeasonRate,
                                  label: 'Rate (\$)',
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildTextField(
                                  controller: _perSeasonDuration,
                                  label: 'Duration (Months)',
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // 4. Logo and Cover Photo Selection
                FadeInUp(
                  duration: const Duration(milliseconds: 800),
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
                          'MEDIA & BRANDING',
                          style: AppTypography.font(
                            color: AppColors.textGrey,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Logo Row
                        Row(
                          children: [
                            Container(
                              height: 64,
                              width: 64,
                              decoration: BoxDecoration(
                                color: AppColors.surface2,
                                borderRadius: BorderRadius.circular(AppRadii.tile),
                                border: Border.all(color: AppColors.hairline),
                              ),
                              child: _localLogoPath != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(AppRadii.tile),
                                      child: Image.file(File(_localLogoPath!), fit: BoxFit.cover),
                                    )
                                  : (_logoUrl != null
                                      ? SporveImage(
                                          _logoUrl,
                                          width: 64,
                                          height: 64,
                                          fit: BoxFit.cover,
                                          radius: AppRadii.tile,
                                          fallbackIcon: Icons.business,
                                        )
                                      : const Icon(Icons.business, color: AppColors.textSecondary)),
                            ),
                            const SizedBox(width: 16),
                            SporveButton(
                              'Change logo',
                              onPressed: () async {
                                final picker = ImagePicker();
                                final image = await picker.pickImage(source: ImageSource.gallery);
                                if (image != null) {
                                  setState(() {
                                    _localLogoPath = image.path;
                                  });
                                }
                              },
                              variant: SporveButtonVariant.secondary,
                              onDark: true,
                              size: SporveButtonSize.compact,
                              fullWidth: false,
                            ),
                          ],
                        ),
                        const Divider(color: AppColors.hairline, height: 32),
                        // Cover Photo Row
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'COVER PHOTO',
                              style: AppTypography.font(
                                color: AppColors.textTertiary,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              height: 120,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: AppColors.surface2,
                                borderRadius: BorderRadius.circular(AppRadii.tile),
                                border: Border.all(color: AppColors.hairline),
                              ),
                              child: _localCoverPath != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(AppRadii.tile),
                                      child: Image.file(File(_localCoverPath!), fit: BoxFit.cover),
                                    )
                                  : (_coverUrl != null
                                      ? SporveImage(
                                          _coverUrl,
                                          width: double.infinity,
                                          height: 120,
                                          fit: BoxFit.cover,
                                          radius: AppRadii.tile,
                                        )
                                      : const Center(
                                          child: Icon(Icons.image, color: AppColors.textSecondary),
                                        )),
                            ),
                            const SizedBox(height: 12),
                            SporveButton(
                              'Change cover photo',
                              onPressed: () async {
                                final picker = ImagePicker();
                                final image = await picker.pickImage(source: ImageSource.gallery);
                                if (image != null) {
                                  setState(() {
                                    _localCoverPath = image.path;
                                  });
                                }
                              },
                              variant: SporveButtonVariant.secondary,
                              onDark: true,
                              size: SporveButtonSize.compact,
                              fullWidth: false,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
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

  Widget _buildPricingToggleRow({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: AppTypography.font(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: AppColors.slateText,
          activeTrackColor: AppColors.slateTint,
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
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
          style: AppTypography.font(color: AppColors.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surface2,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.tile),
              borderSide: const BorderSide(color: AppColors.hairline),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.tile),
              borderSide: const BorderSide(color: AppColors.slateText, width: 1.5),
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
