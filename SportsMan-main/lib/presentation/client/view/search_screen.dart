import 'package:flutter/material.dart';
import 'package:flutter_structure/core/theme/app_typography.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import '../controllers/home_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/routes/app_routes.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/sporve_button.dart';
import '../../widgets/sporve_image.dart';

class Opportunity {
  final int id;
  /// The REAL program id (Supabase uuid) this card represents. Used for
  /// favorites + carried into the booking flow. Null only for non-program cards.
  final String? programId;
  final String title;
  final String coach;
  final String price;
  final String rating;
  final String image;
  final String spotsLeft;
  final bool isVerified;
  final String bookingTrend;
  final double top;
  final String team;
  final double? left;
  final double? right;
  final double? bottom;
  final Map<String, dynamic>? rawData;

  const Opportunity({
    required this.id,
    this.programId,
    required this.title,
    required this.coach,
    required this.price,
    required this.rating,
    required this.image,
    required this.spotsLeft,
    required this.isVerified,
    required this.bookingTrend,
    required this.top,
    required this.team,
    this.left,
    this.right,
    this.bottom,
    this.rawData,
  });
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  int? _selectedOpportunityIndex;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final homeProvider = context.watch<HomeProvider>();
    final String query = _searchController.text.trim().toLowerCase();

    // 1. Map dynamic programs to Opportunity objects for the map view
    final List<Opportunity> dynamicOpportunities = homeProvider.programs.asMap().entries.map((entry) {
      final index = entry.key;
      final program = entry.value;
      final gallery = program['gallery'];
      final image = (gallery != null && (gallery as List).isNotEmpty)
          ? gallery[0].toString()
          : '';

      return Opportunity(
        id: index,
        programId: program['_id']?.toString(),
        title: program['title'] ?? 'Program',
        coach: program['providerId']?['businessName'] ?? 'Academy',
        price: '\$${program['price'] ?? 0}',
        rating: '${program['averageRating']?.toString() ?? '5.0'} (0)',
        image: image,
        spotsLeft: 'AVAILABLE',
        isVerified: program['providerId']?['verificationStatus'] == 'verified',
        bookingTrend: 'Trending now',
        top: 200.0 + (index * 100), // map pin layout positions
        left: index % 2 == 0 ? 100.0 : null,
        right: index % 2 != 0 ? 80.0 : null,
        team: program['providerId']?['businessName'] ?? 'Academy',
        rawData: program,
      );
    }).toList();

    // 2. Filter opportunities based on search bar text
    final List<Opportunity> filteredOpportunities = dynamicOpportunities.where((opp) {
      if (query.isEmpty) return true;
      return opp.title.toLowerCase().contains(query) ||
             opp.coach.toLowerCase().contains(query) ||
             opp.team.toLowerCase().contains(query);
    }).toList();

    // 2. Select display items based on selected map pin or overall list
    final displayedItems = _selectedOpportunityIndex == null
        ? filteredOpportunities
        : filteredOpportunities.where((opp) => opp.id == _selectedOpportunityIndex).toList();

    return GradientScaffold(
      body: Stack(
        children: [
          // Simulated Map Background (markers from real programs)
          _buildSimulatedMap(filteredOpportunities),

          // Floating Top Search Bar & Recent Searches row
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Back Button
                      SporveIconButton(
                        Icons.arrow_back_ios_new,
                        onTap: () => Get.back(),
                        size: 56,
                        iconSize: 20,
                        circle: true,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          height: 56,
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(AppRadii.tile),
                            border: Border.all(color: AppColors.hairline),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.search, color: AppColors.textTertiary),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  style: const TextStyle(color: AppColors.textPrimary),
                                  cursorColor: AppColors.slateText,
                                  onChanged: (val) => setState(() {}),
                                  onSubmitted: (val) {
                                    if (val.trim().isNotEmpty) {
                                      context.read<HomeProvider>().addPastSearch(val);
                                      setState(() {});
                                    }
                                  },
                                  decoration: InputDecoration(
                                    hintText: 'Search sessions, coaches, sports...',
                                    hintStyle: AppTypography.font(color: AppColors.textTertiary, fontSize: 14),
                                    border: InputBorder.none,
                                  ),
                                ),
                              ),
                              if (_searchController.text.isNotEmpty)
                                GestureDetector(
                                  onTap: () {
                                    _searchController.clear();
                                    setState(() {});
                                  },
                                  child: const Icon(Icons.close, color: AppColors.textSecondary, size: 18),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SporveIconButton(
                        Icons.tune,
                        onTap: () => Get.toNamed(AppRoutes.filters),
                        size: 56,
                        iconSize: 24,
                        circle: true,
                      ),
                    ],
                  ),

                  // Dynamic "Recent Searches" scrolling tag bar
                  Consumer<HomeProvider>(
                    builder: (context, homeProvider, child) {
                      if (homeProvider.pastSearches.isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 12, left: 4),
                        child: SizedBox(
                          height: 36,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: homeProvider.pastSearches.length + 1,
                            itemBuilder: (context, index) {
                              if (index == 0) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8, top: 8),
                                  child: Text(
                                    'Recents:',
                                    style: AppTypography.font(
                                      color: AppColors.textTertiary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                );
                              }
                              final search = homeProvider.pastSearches[index - 1];
                              return GestureDetector(
                                onTap: () {
                                  _searchController.text = search;
                                  homeProvider.addPastSearch(search);
                                  setState(() {});
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(AppRadii.chip),
                                    border: Border.all(color: AppColors.hairline),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.history, color: AppColors.textTertiary, size: 11),
                                      const SizedBox(width: 6),
                                      Text(
                                        search,
                                        style: AppTypography.font(
                                          color: AppColors.textSecondary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // Draggable Bottom Sheet
          DraggableScrollableSheet(
            initialChildSize: 0.35,
            minChildSize: 0.15,
            maxChildSize: 0.9,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.card)),
                  border: Border(top: BorderSide(color: AppColors.hairline)),
                  boxShadow: [
                    BoxShadow(color: Colors.black54, blurRadius: 20, offset: Offset(0, -5)),
                  ],
                ),
                child: Consumer<HomeProvider>(
                  builder: (context, homeProvider, child) {
                    final recommendations = homeProvider.getRecommendations(dynamicOpportunities);
                    final hasQuery = _searchController.text.trim().isNotEmpty;

                    return ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.only(bottom: 40),
                      children: [
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.topCenter,
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(color: AppColors.hairline, borderRadius: BorderRadius.circular(2)),
                          ),
                        ),

                        // 1. Recommended Carousel Section (When no active query and no pin details selected)
                        if (!hasQuery && _selectedOpportunityIndex == null && recommendations.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Row(
                              children: [
                                Text(
                                  'Recommended for You',
                                  style: AppTypography.font(
                                    color: AppColors.textPrimary,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const AIBadge(label: 'AI Recommend'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 190,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              itemCount: recommendations.length,
                              itemBuilder: (context, index) {
                                return _buildRecommendedCard(recommendations[index], homeProvider);
                              },
                            ),
                          ),
                        ],

                        // 2. Main List Title Section
                        const SizedBox(height: 28),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _selectedOpportunityIndex == null
                                    ? (hasQuery ? 'Search Results' : 'Top Opportunities')
                                    : 'Selected Session',
                                style: AppTypography.font(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                              if (_selectedOpportunityIndex != null)
                                SporveButton(
                                  'Show all',
                                  onPressed: () => setState(() => _selectedOpportunityIndex = null),
                                  variant: SporveButtonVariant.tertiary,
                                  size: SporveButtonSize.compact,
                                  fullWidth: false,
                                  onDark: true,
                                )
                              else
                                const Icon(Icons.sort, color: AppColors.slateText),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 3. Main Opportunities List (or empty state)
                        if (displayedItems.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                            child: Center(
                              child: Text(
                                'No matches — try adjusting your filters.',
                                textAlign: TextAlign.center,
                                style: AppTypography.font(color: AppColors.textSecondary, fontSize: 13),
                              ),
                            ),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: displayedItems.length,
                              itemBuilder: (context, index) {
                                return _buildOpportunityCard(displayedItems[index]);
                              },
                            ),
                          ),
                      ],
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendedCard(Opportunity opp, HomeProvider homeProvider) {
    final bool isTeamMatch = opp.team.toLowerCase() == homeProvider.athleteTeam.toLowerCase();

    return GestureDetector(
      onTap: () => Get.toNamed(AppRoutes.sessionDetails, arguments: opp),
      child: Container(
        width: 290,
        margin: const EdgeInsets.only(right: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(
            color: isTeamMatch ? AppColors.blue.withValues(alpha: 0.5) : AppColors.hairline,
            width: isTeamMatch ? 1.5 : 1,
          ),
          boxShadow: isTeamMatch
              ? [
                  BoxShadow(
                    color: AppColors.blue.withValues(alpha: 0.15),
                    blurRadius: 8,
                    spreadRadius: 1,
                  )
                ]
              : [],
        ),
        child: Row(
          children: [
            // Left image thumbnail
            Stack(
              children: [
                SporveImage(
                  opp.image,
                  width: 90,
                  height: 166,
                  fit: BoxFit.cover,
                  radius: AppRadii.tile,
                ),
                if (isTeamMatch)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.blueTint,
                        borderRadius: BorderRadius.circular(AppRadii.chip),
                        border: Border.all(color: AppColors.blue.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        'TEAM',
                        style: AppTypography.font(
                          color: AppColors.blueText,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            // Right info section
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.negative.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppRadii.chip),
                        ),
                        child: Text(
                          opp.spotsLeft.split(' ')[0], // shows e.g. "2" or "FILLS"
                          style: AppTypography.font(
                            color: AppColors.negative,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.star, color: AppColors.textPrimary, size: 10),
                          const SizedBox(width: 2),
                          Text(
                            opp.rating.split(' ')[0],
                            style: AppTypography.font(color: AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    opp.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.font(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    opp.coach,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.font(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  if (isTeamMatch) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.people, color: AppColors.blueText, size: 10),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Same Team',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.font(
                              color: AppColors.blueText,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        opp.price.split('/')[0],
                        style: AppTypography.font(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppColors.slateText,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_forward,
                          color: AppColors.onSlate,
                          size: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimulatedMap(List<Opportunity> opps) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: AppColors.ink,
      child: Stack(
        children: opps.map((opp) {
          return Positioned(
            top: opp.top,
            left: opp.left,
            right: opp.right,
            child: _buildMapMarker(opp),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMapMarker(Opportunity opp) {
    final bool isSelected = _selectedOpportunityIndex == opp.id;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedOpportunityIndex = opp.id;
        });
      },
      child: AnimatedScale(
        scale: isSelected ? 1.15 : 1.0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.slateText : AppColors.ink,
                borderRadius: BorderRadius.circular(AppRadii.chip),
                border: Border.all(
                  color: isSelected ? AppColors.slateText : AppColors.hairline,
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.slateText.withValues(alpha: 0.4),
                          blurRadius: 12,
                          spreadRadius: 2,
                        )
                      ]
                    : [],
              ),
              child: Text(
                opp.price,
                style: AppTypography.font(
                  color: isSelected ? AppColors.onSlate : AppColors.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Icon(
              Icons.location_on,
              color: isSelected ? AppColors.slateText : AppColors.textSecondary,
              size: isSelected ? 28 : 24,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOpportunityCard(Opportunity opp) {
    return GestureDetector(
      onTap: () => Get.toNamed(AppRoutes.sessionDetails, arguments: opp),
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: AppColors.hairline),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                SporveImage(
                  opp.image,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  radius: AppRadii.card,
                ),
                Positioned(
                  top: 16,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: AppColors.negative, borderRadius: BorderRadius.circular(AppRadii.chip)),
                    child: Text(
                      opp.spotsLeft,
                      style: AppTypography.font(color: AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                 Positioned(
                  top: 16,
                  right: 16,
                  child: Consumer<HomeProvider>(
                    builder: (context, homeProvider, child) {
                      final isFav = homeProvider.isFavorite(opp.programId);
                      return GestureDetector(
                        onTap: () {
                          homeProvider.toggleFavorite(opp.programId);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isFav ? Icons.favorite : Icons.favorite_border,
                            color: isFav ? AppColors.slateText : AppColors.textPrimary,
                            size: 24,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        opp.price.startsWith('\$1') ? opp.price : '${opp.price}+',
                        style: AppTypography.font(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: AppColors.textPrimary),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.star, color: AppColors.textPrimary, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            opp.rating,
                            style: AppTypography.font(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    opp.title,
                    style: AppTypography.font(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  Text(
                    opp.coach,
                    style: AppTypography.font(color: AppColors.textSecondary, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      if (opp.isVerified) ...[
                        _buildTag(Icons.verified, 'Verified', AppColors.slateText),
                        const SizedBox(width: 8),
                      ],
                      _buildTag(Icons.calendar_today, opp.bookingTrend, AppColors.slateText),
                      const Spacer(),
                      SporveButton(
                        'Details',
                        onPressed: () => Get.toNamed(AppRoutes.sessionDetails, arguments: opp),
                        variant: SporveButtonVariant.primary,
                        size: SporveButtonSize.compact,
                        icon: Icons.arrow_forward_ios,
                        fullWidth: false,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.chip),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTypography.font(color: color, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
