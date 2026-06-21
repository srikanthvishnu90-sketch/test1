import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_typography.dart';
import '../../onboarding/controllers/onboarding_controller.dart';
import '../widgets/create_listing_bottom_sheet.dart';
import '../controllers/provider_controller.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/sporve_button.dart';
import '../../widgets/sporve_image.dart';


class ProviderDashboardScreen extends StatefulWidget {
  const ProviderDashboardScreen({super.key});

  @override
  State<ProviderDashboardScreen> createState() => _ProviderDashboardScreenState();
}

class _ProviderDashboardScreenState extends State<ProviderDashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Fetch real programs and bookings from API on first load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = context.read<ProviderController>();
      controller.fetchMyPrograms();
      controller.fetchProviderBookings();
    });
  }

  void _showCreateListing(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const CreateListingBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final onboardingProvider = context.watch<OnboardingProvider>();
    final providerController = context.watch<ProviderController>();
    final listings = providerController.listings;

    return GradientScaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.slateText,
          backgroundColor: AppColors.surface,
          onRefresh: () => Future.wait([
            providerController.fetchMyPrograms(),
            providerController.fetchProviderBookings(),
          ]),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Good morning',
                        style: AppTypography.font(
                          color: AppColors.textGrey,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        onboardingProvider.institutionName.isNotEmpty
                            ? onboardingProvider.institutionName
                            : 'Apex Performance Academy',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.font(
                          color: AppColors.textPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.6,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.slateText,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Active • 2 sessions today',
                            style: AppTypography.font(
                              color: AppColors.slateText,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  ),
                  const SizedBox(width: 12),
                  ClipOval(
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: SporveImage(
                        'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=100',
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        fallbackIcon: Icons.person,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              if (!onboardingProvider.profileCompleted)
                _buildFinishProfileCard(context, onboardingProvider),

              // Summary Cards
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      label: 'THIS WEEK',
                      value: '\$8,420',
                      trend: '+8%',
                      trendColor: AppColors.slateText,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSummaryCard(
                      label: 'BOOKING RATE',
                      value: '92%',
                      trend: 'PEAK',
                      trendColor: AppColors.slateText,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSummaryCard(
                      label: 'CONVERSION',
                      value: '18%',
                      trend: '+3%',
                      trendColor: AppColors.slateText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Insight Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadii.card),
                  border: Border.all(color: AppColors.hairline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TODAY\'S INSIGHT',
                      style: AppTypography.font(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '"Providers with 5+ photos in their listing earn 2× more views per week."',
                            style: AppTypography.font(
                              color: AppColors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              height: 1.4,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Icon(Icons.lightbulb_outline, color: AppColors.slateText, size: 32),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Today's Sessions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'TODAY\'S SESSIONS',
                    style: AppTypography.font(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SeeAll(label: 'View all'),
                ],
              ),
              const SizedBox(height: 16),
              if (providerController.sessions.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'No sessions scheduled.',
                      style: AppTypography.font(color: AppColors.textTertiary, fontSize: 12),
                    ),
                  ),
                )
              else ...[
                for (final session in providerController.sessions.take(2)) ...[
                  Builder(
                    builder: (context) {
                      final timeParts = session.timeStr.split(' ');
                      final timeVal = timeParts[0];
                      final periodVal = timeParts.length > 1 ? timeParts[1] : 'PM';
                      return _buildSessionCard(
                        time: timeVal,
                        period: periodVal,
                        title: session.serviceTitle,
                        subtitle: session.userName.toUpperCase(),
                        status: session.isConfirmed ? 'CONFIRMED' : 'PENDING',
                        statusColor: session.isConfirmed ? AppColors.slateText : AppColors.warning,
                      );
                    }
                  ),
                  const SizedBox(height: 12),
                ],
              ],
              const SizedBox(height: 20),

              // Active Listings
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'ACTIVE LISTINGS',
                    style: AppTypography.font(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SeeAll(label: 'Manage'),
                ],
              ),
              if (providerController.isLoading && !providerController.listingsLoaded)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator(color: AppColors.slateText, strokeWidth: 2)),
                )
              else if (listings.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    children: [
                      const Icon(Icons.inbox_outlined, color: AppColors.textTertiary, size: 40),
                      const SizedBox(height: 8),
                      Text(
                        'No active listings yet.\nTap below to create your first program.',
                        textAlign: TextAlign.center,
                        style: AppTypography.font(color: AppColors.textTertiary, fontSize: 12, height: 1.6),
                      ),
                    ],
                  ),
                )
              else ...[
                for (int i = 0; i < listings.length && i < 2; i++) ...[
                  _buildActiveListingCard(
                    index: i,
                    image: listings[i].image,
                    title: listings[i].title,
                    rating: listings[i].rating,
                    spots: listings[i].availability,
                    context: context,
                  ),
                  const SizedBox(height: 12),
                ],
              ],


              // Create New Listing Button
              SporveButton(
                'Create new listing',
                onPressed: () => _showCreateListing(context),
                variant: SporveButtonVariant.secondary,
                icon: Icons.add,
                onDark: true,
              ),
              const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard({
    required String label,
    required String value,
    required String trend,
    required Color trendColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.font(
              color: AppColors.textTertiary,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTypography.mono(
              size: 20,
              weight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.arrow_upward, size: 8, color: trendColor),
              const SizedBox(width: 2),
              Text(
                trend,
                style: AppTypography.font(
                  color: trendColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSessionCard({
    required String time,
    required String period,
    required String title,
    required String subtitle,
    required String status,
    required Color statusColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'STARTS',
                style: AppTypography.font(color: AppColors.textTertiary, fontSize: 11, fontWeight: FontWeight.bold),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    time,
                    style: AppTypography.mono(size: 20, weight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    period,
                    style: AppTypography.mono(size: 11, weight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.font(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.font(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          OutlinePill(status, color: statusColor),
          const SizedBox(width: 8),
          const Icon(Icons.arrow_forward_ios, size: 10, color: AppColors.textTertiary),
        ],
      ),
    );
  }

  Widget _buildActiveListingCard({
    required int index,
    required String image,
    required String title,
    required String rating,
    required String spots,
    required BuildContext context,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        children: [
          SporveImage(
            image,
            width: 48,
            height: 48,
            fit: BoxFit.cover,
            radius: AppRadii.tile,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.font(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.star, color: AppColors.textPrimary, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      rating,
                      style: AppTypography.mono(size: 11, weight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      spots,
                      style: AppTypography.font(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SporveButton(
            'Edit',
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => CreateListingBottomSheet(editIndex: index),
              );
            },
            variant: SporveButtonVariant.secondary,
            size: SporveButtonSize.compact,
            fullWidth: false,
          ),
        ],
      ),
    );
  }

  void _showFinishProfileModal(BuildContext context, OnboardingProvider provider) {
    int localCapacity = provider.maxAthletes;
    String localLogo = provider.logoPath ?? '';
    List<String> localGallery = List.from(provider.galleryPaths);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: SingleChildScrollView(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadii.card),
                    border: Border.all(color: AppColors.hairline),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Complete Profile",
                            style: AppTypography.font(
                              color: AppColors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SporveIconButton(
                            Icons.close,
                            color: AppColors.negative,
                            iconSize: 20,
                            onTap: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        '1. MAX ATHLETES PER SESSION',
                        style: AppTypography.font(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: AppColors.slateText,
                                inactiveTrackColor: AppColors.hairline,
                                thumbColor: AppColors.slateText,
                                trackHeight: 6,
                              ),
                              child: Slider(
                                value: localCapacity.toDouble(),
                                min: 1,
                                max: 100,
                                onChanged: (val) {
                                  setModalState(() {
                                    localCapacity = val.round();
                                  });
                                },
                              ),
                            ),
                          ),
                          Text(
                            '$localCapacity',
                            style: AppTypography.mono(size: 20, weight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        '2. UPLOAD BRAND LOGO',
                        style: AppTypography.font(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () {
                          setModalState(() {
                            localLogo = 'logo_mock.png';
                          });
                        },
                        child: Container(
                          height: 56,
                          decoration: BoxDecoration(
                            color: AppColors.surface2,
                            borderRadius: BorderRadius.circular(AppRadii.tile),
                            border: Border.all(color: AppColors.hairline),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(localLogo.isNotEmpty ? Icons.check_circle : Icons.upload,
                                   color: localLogo.isNotEmpty ? AppColors.slateText : AppColors.textSecondary, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                localLogo.isNotEmpty ? 'logo_mock.png uploaded!' : 'Upload Logo File',
                                style: AppTypography.font(color: localLogo.isNotEmpty ? AppColors.textPrimary : AppColors.textSecondary, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        '3. MEDIA GALLERY (ADD MOCK PHOTOS)',
                        style: AppTypography.font(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () {
                          if (localGallery.length < 4) {
                            setModalState(() {
                              localGallery.add('gallery_${localGallery.length + 1}.png');
                            });
                          }
                        },
                        child: Container(
                          height: 56,
                          decoration: BoxDecoration(
                            color: AppColors.surface2,
                            borderRadius: BorderRadius.circular(AppRadii.tile),
                            border: Border.all(color: AppColors.hairline),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.add_photo_alternate, color: AppColors.textSecondary, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'Add Photo (${localGallery.length}/4)',
                                style: AppTypography.font(color: AppColors.textSecondary, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (localGallery.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          children: localGallery.map((p) => Chip(
                            backgroundColor: AppColors.surface2,
                            label: Text(p, style: AppTypography.font(color: AppColors.textPrimary, fontSize: 11)),
                            onDeleted: () {
                              setModalState(() {
                                localGallery.remove(p);
                              });
                            },
                            deleteIconColor: AppColors.textSecondary,
                          )).toList(),
                        ),
                      ],
                      const SizedBox(height: 32),
                      SporveButton(
                        'Save & finish',
                        onPressed: () {
                          provider.setMaxAthletes(localCapacity);
                          if (localLogo.isNotEmpty) {
                            provider.setLogo(localLogo);
                          }
                          for (var path in localGallery) {
                            if (!provider.galleryPaths.contains(path)) {
                              provider.addGalleryPhoto(path);
                            }
                          }
                          provider.setProfileCompleted(true);
                          Navigator.pop(context);
                          Get.snackbar(
                            'Profile Completed!',
                            'Your coach profile is now 100% complete!',
                            backgroundColor: AppColors.surface,
                            colorText: AppColors.textPrimary,
                          );
                        },
                        variant: SporveButtonVariant.primary,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFinishProfileCard(BuildContext context, OnboardingProvider provider) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.slateBorder, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: AppColors.slateText,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.star, color: AppColors.onSlate, size: 16),
              ),
              const SizedBox(width: 12),
              Text(
                'Finish Your Profile',
                style: AppTypography.font(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Complete your capacity limits and media files so athletes can discover your program services.',
            style: AppTypography.font(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    height: 6,
                    width: 80,
                    decoration: BoxDecoration(
                      color: AppColors.hairline,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    alignment: Alignment.centerLeft,
                    child: Container(
                      height: 6,
                      width: 40,
                      decoration: BoxDecoration(
                        color: AppColors.slateText,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '3 of 6 completed',
                    style: AppTypography.font(color: AppColors.slateText, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              SporveButton(
                'Complete Now',
                onPressed: () => _showFinishProfileModal(context, provider),
                variant: SporveButtonVariant.primary,
                size: SporveButtonSize.compact,
                fullWidth: false,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
