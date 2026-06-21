import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/sport_colors.dart';
import '../controllers/provider_controller.dart';
import '../widgets/create_listing_bottom_sheet.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/sporve_button.dart';
import '../../widgets/sporve_image.dart';
import 'program_detail_screen.dart';

class ProviderListingsScreen extends StatefulWidget {
  const ProviderListingsScreen({super.key});

  @override
  State<ProviderListingsScreen> createState() => _ProviderListingsScreenState();
}

class _ProviderListingsScreenState extends State<ProviderListingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProviderController>().fetchMyPrograms();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ProviderController>();
    final listings = controller.listings;

    return GradientScaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Listings',
                        style: AppTypography.font(
                          color: AppColors.textPrimary,
                          fontSize: 26,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${listings.length} TOTAL LISTINGS',
                        style: AppTypography.font(
                          color: AppColors.textGrey,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                  SporveButton(
                    'Create listing',
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => const CreateListingBottomSheet(),
                      ).then((_) {
                        // Refresh after creating a listing
                        if (mounted) context.read<ProviderController>().fetchMyPrograms();
                      });
                    },
                    variant: SporveButtonVariant.primary,
                    size: SporveButtonSize.compact,
                    fullWidth: false,
                  ),
                ],
              ),
            ),

            // Listings List
            Expanded(
              child: controller.isLoading && !controller.listingsLoaded
                  // ── Loading shimmer ──────────────────────────────────────
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: AppColors.slateText, strokeWidth: 2),
                          SizedBox(height: 16),
                          Text('Loading listings...', style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                        ],
                      ),
                    )
                  : listings.isEmpty
                      // ── Empty state ──────────────────────────────────────
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.inbox_outlined, color: AppColors.textTertiary, size: 56),
                              const SizedBox(height: 12),
                              Text(
                                'No listings yet.',
                                style: AppTypography.font(color: AppColors.textSecondary, fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Tap "Create Listing" to add your first program.',
                                textAlign: TextAlign.center,
                                style: AppTypography.font(color: AppColors.textTertiary, fontSize: 12),
                              ),
                              const SizedBox(height: 24),
                              // Manual refresh button in empty state
                              SporveButton(
                                'Refresh',
                                onPressed: () => controller.fetchMyPrograms(),
                                variant: SporveButtonVariant.dark,
                                size: SporveButtonSize.compact,
                                fullWidth: false,
                                icon: Icons.refresh,
                              ),
                            ],
                          ),
                        )
                      // ── Data list ────────────────────────────────────────
                      : RefreshIndicator(
                          color: AppColors.slateText,
                          backgroundColor: AppColors.surface,
                          onRefresh: () => controller.fetchMyPrograms(),
                          child: ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            itemCount: listings.length,
                            itemBuilder: (context, index) {
                              final listing = listings[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16.0),
                                child: _buildListingCard(
                                  index: index,
                                  listing: listing,
                                  context: context,
                                ),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildListingCard({
    required int index,
    required ProviderListing listing,
    required BuildContext context,
  }) {
    final sportColor = SportColors.of(listing.sportType);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(AppRadii.tile),
                  border: Border.all(color: AppColors.hairline),
                ),
                child: listing.image.isNotEmpty
                    ? SporveImage(
                        listing.image,
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                        radius: AppRadii.tile,
                      )
                    : const Icon(
                        Icons.image_outlined,
                        color: AppColors.textTertiary,
                        size: 24,
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          SportColors.iconOf(listing.sportType),
                          color: sportColor,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            listing.title,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.font(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      listing.pricingModel.toUpperCase().replaceAll('_', ' '),
                      style: AppTypography.font(
                        color: AppColors.textGrey,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.star, color: AppColors.textPrimary, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          listing.rating,
                          style: AppTypography.mono(
                            size: 11,
                            weight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '\$${listing.price.toStringAsFixed(0)}',
                          style: AppTypography.mono(
                            size: 11,
                            weight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          listing.availability,
                          style: AppTypography.font(
                            color: listing.availabilityColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (listing.sessions.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Hairline(),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined, color: AppColors.textTertiary, size: 12),
                const SizedBox(width: 6),
                Text(
                  'SESSIONS',
                  style: AppTypography.font(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...listing.sessions.take(2).map((session) {
              final startDateStr = session['startDate'] ?? '';
              final startTime = session['startTime'] ?? '';
              final endTime = session['endTime'] ?? '';
              DateTime? startDate;
              try {
                startDate = DateTime.parse(startDateStr);
              } catch (_) {}
              
              final dateLabel = startDate != null
                  ? '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}'
                  : 'Unknown Date';

              return Padding(
                padding: const EdgeInsets.only(bottom: 6.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '$dateLabel  •  $startTime - $endTime',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.font(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    if (session['instructor'] != null && session['instructor'].toString().isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          session['instructor'].toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: AppTypography.font(
                            color: AppColors.slateText,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),
            if (listing.sessions.length > 2)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(top: 2.0),
                  child: Row(
                    children: [
                      OutlinePill('+${listing.sessions.length - 2} more'),
                    ],
                  ),
                ),
              ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: SporveButton(
                  'View details',
                  onPressed: () async {
                    // Refresh details on demand, then navigate to screen
                    if (listing.id.isNotEmpty) {
                      await context.read<ProviderController>().fetchProgramDetails(listing.id);
                    }
                    if (!mounted) return;
                    final editIndex = await Navigator.push<int>(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProgramDetailScreen(listing: listing),
                      ),
                    );
                    if (!mounted) return;
                    if (editIndex != null && editIndex >= 0) {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => CreateListingBottomSheet(editIndex: editIndex),
                      );
                    }
                  },
                  variant: SporveButtonVariant.secondary,
                  size: SporveButtonSize.compact,
                  onDark: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SporveButton(
                  'Edit',
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => CreateListingBottomSheet(editIndex: index),
                    );
                  },
                  variant: SporveButtonVariant.primary,
                  size: SporveButtonSize.compact,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SporveButton(
                  'Delete',
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (dialogCtx) => AlertDialog(
                        backgroundColor: AppColors.surface,
                        title: const Text('Delete Listing', style: TextStyle(color: AppColors.textPrimary)),
                        content: Text('Are you sure you want to delete "${listing.title}"?', style: const TextStyle(color: AppColors.textSecondary)),
                        actions: [
                          SporveButton(
                            'Cancel',
                            onPressed: () => Navigator.pop(dialogCtx),
                            variant: SporveButtonVariant.tertiary,
                            size: SporveButtonSize.compact,
                            fullWidth: false,
                            onDark: true,
                          ),
                          SporveButton(
                            'Delete',
                            onPressed: () {
                              Navigator.pop(dialogCtx);
                              context.read<ProviderController>().deleteListing(index);
                            },
                            variant: SporveButtonVariant.destructive,
                            size: SporveButtonSize.compact,
                            fullWidth: false,
                          ),
                        ],
                      ),
                    );
                  },
                  variant: SporveButtonVariant.destructive,
                  size: SporveButtonSize.compact,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
