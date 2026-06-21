import 'package:flutter/material.dart';
import 'package:flutter_structure/core/theme/app_typography.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import '../controllers/home_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/sport_colors.dart';
import '../../../core/routes/app_routes.dart';
import 'search_screen.dart'; // import Opportunity if defined there

import '../../widgets/common_widgets.dart';
import '../../widgets/sporve_button.dart';
import '../../widgets/sporve_image.dart';

class SessionDetailsScreen extends StatefulWidget {
  const SessionDetailsScreen({super.key});

  @override
  State<SessionDetailsScreen> createState() => _SessionDetailsScreenState();
}

class _SessionDetailsScreenState extends State<SessionDetailsScreen> {
  String _selectedTab = 'OVERVIEW'; // 'OVERVIEW', 'WHAT YOU\'LL LEARN', 'REVIEWS'
  String _selectedTier = 'STANDARD'; // 'STANDARD', 'PRO', 'ELITE'

  double get _basePrice {
    final dynamic args = Get.arguments;
    Map<String, dynamic>? programData;
    if (args is Opportunity) {
      programData = args.rawData;
    } else if (args is Map<String, dynamic>) {
      programData = args;
    }
    if (programData != null && programData['price'] != null) {
      return (programData['price'] as num).toDouble();
    }
    if (args is Opportunity) {
      final clean = args.price.replaceAll(RegExp(r'[^0-9]'), '');
      return double.tryParse(clean) ?? 75.0;
    }
    return 75.0;
  }

  // Dynamic details based on plan selected
  String get _tierPrice {
    final base = _basePrice;
    switch (_selectedTier) {
      case 'PRO':
        return '\$${(base * 1.6).toStringAsFixed(0)}';
      case 'ELITE':
        return '\$${(base * 2.6).toStringAsFixed(0)}';
      case 'STANDARD':
      default:
        return '\$${base.toStringAsFixed(0)}';
    }
  }

  // Numeric version of the selected tier price, passed to the booking flow so
  // checkout charges the provider's actual (tier-adjusted) price.
  double get _tierPriceValue {
    final base = _basePrice;
    switch (_selectedTier) {
      case 'PRO':
        return base * 1.6;
      case 'ELITE':
        return base * 2.6;
      case 'STANDARD':
      default:
        return base;
    }
  }

  String get _tierDescription {
    switch (_selectedTier) {
      case 'PRO':
        return 'Advanced pro-level coaching session with specialized drills.';
      case 'ELITE':
        return 'Private 1-on-1 intensive masterclass tailored directly for you.';
      case 'STANDARD':
      default:
        return 'Baseline training with associate coaching.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final dynamic args = Get.arguments;
    Opportunity? opportunity;
    Map<String, dynamic>? programData;
    
    if (args is Opportunity) {
      opportunity = args;
      programData = args.rawData;
    } else if (args is Map<String, dynamic>) {
      programData = args;
    }
    
    if (opportunity == null && programData != null) {
      final gallery = programData['gallery'];
      final image = (gallery != null && (gallery as List).isNotEmpty)
          ? gallery[0].toString()
          : 'https://images.unsplash.com/photo-1546519638-68e109498ffc?w=500&auto=format&fit=crop&q=60';
          
      opportunity = Opportunity(
        id: 0,
        title: programData['title'] ?? 'Program',
        coach: programData['providerId']?['businessName'] ?? 'Academy',
        price: '\$${programData['price'] ?? 0}',
        rating: programData['averageRating']?.toString() ?? '5.0',
        image: image,
        spotsLeft: 'AVAILABLE',
        isVerified: true,
        bookingTrend: 'Trending',
        top: 0,
        team: programData['providerId']?['businessName'] ?? 'Academy',
        rawData: programData,
      );
    }
    
    final String title = programData?['title'] ?? opportunity?.title ?? 'Elite Point Guard Training';

    // Sport identity for this session — drives the per-sport CTA, tag, scrim.
    final String sport = (programData?['sportType'] ?? 'basketball').toString();

    final String image = programData?['coverImage'] ?? 
        ((programData != null && programData['gallery'] != null && (programData['gallery'] as List).isNotEmpty) 
            ? programData['gallery'][0].toString() 
            : null) ?? 
        opportunity?.image ?? 
        'https://images.unsplash.com/photo-1546519638-68e109498ffc?w=500&auto=format&fit=crop&q=60';
        
    final String coach = programData?['providerId']?['businessName'] ?? 
        opportunity?.coach ?? 
        'Coach Marcus Johnson';
        
    final double averageRatingVal = (programData?['averageRating'] as num?)?.toDouble() ?? 
        double.tryParse(opportunity?.rating.split(' ')[0] ?? '4.9') ?? 4.9;
    final int reviewsCountVal = (programData?['totalReviews'] as num?)?.toInt() ?? 124;
    final String rating = '${averageRatingVal.toStringAsFixed(1)} ($reviewsCountVal)';
    
    String locationText = 'Downtown Athletic Club';
    if (programData != null) {
      final addr = programData['address'];
      if (addr is Map) {
        final parts = [
          addr['line1'] ?? addr['addressLine1'],
          addr['city'],
          addr['state']
        ].where((s) => s != null && s.toString().trim().isNotEmpty).toList();
        if (parts.isNotEmpty) {
          locationText = parts.join(', ');
        }
      } else if (addr is String && addr.isNotEmpty) {
        locationText = addr;
      } else if (programData['location'] is String && (programData['location'] as String).isNotEmpty) {
        locationText = programData['location'];
      }
    }

    return GradientScaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 1. TOP HEADER WITH IMAGE, CLOSE BUTTON AND TITLE
            Stack(
              children: [
                // Top Cover Image with bottom gradient fade
                Container(
                  height: 380,
                  width: double.infinity,
                  foregroundDecoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.4),
                        Colors.transparent,
                        AppColors.ink,
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                  child: SporveImage(
                    image,
                    width: double.infinity,
                    height: 380,
                    fit: BoxFit.cover,
                  ),
                ),

                // Sport-color scrim at the bottom of the cover (identity wash).
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: Container(
                      height: 200,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            SportColors.scrimOf(sport),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Top Action Row (Back Button)
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: () => Get.back(),
                          child: Container(
                            height: 44,
                            width: 44,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.45),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white24),
                            ),
                            child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                          ),
                        ),
                        Consumer<HomeProvider>(
                          builder: (context, homeProvider, child) {
                            if (opportunity == null) return const SizedBox.shrink();
                            final isFav = homeProvider.isOpportunityFavorited(opportunity.id);
                            return GestureDetector(
                              onTap: () {
                                if (opportunity != null) {
                                  homeProvider.toggleFavorite(opportunity.id);
                                }
                              },
                              child: Container(
                                height: 44,
                                width: 44,
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.45),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white24),
                                ),
                                child: Icon(
                                  isFav ? Icons.favorite : Icons.favorite_border,
                                  color: isFav ? AppColors.slateText : AppColors.textPrimary,
                                  size: 18,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                // Floating Title & Details block overlayed on bottom of cover image
                Positioned(
                  bottom: 20,
                  left: 24,
                  right: 24,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Training & Chat Tag Row
                      Row(
                        children: [
                          SportTag(sport),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              Get.snackbar(
                                'Chat',
                                'Opening chat with $coach...',
                                backgroundColor: AppColors.surface,
                                colorText: AppColors.textPrimary,
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.slateText,
                                borderRadius: BorderRadius.circular(AppRadii.chip),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.chat_bubble_outline, color: AppColors.onSlate, size: 12),
                                  const SizedBox(width: 6),
                                  Text(
                                    'CHAT',
                                    style: AppTypography.font(
                                      color: AppColors.onSlate,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      // Title Text
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.font(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Rating & Reviews & Address Row
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.white38),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.star, color: Colors.white, size: 12),
                                const SizedBox(width: 4),
                                Text(
                                  rating.split(' ')[0],
                                  style: AppTypography.font(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '$reviewsCountVal REVIEWS',
                            style: AppTypography.font(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Icon(Icons.location_on, color: AppColors.slateText, size: 14),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              locationText,
                              style: AppTypography.font(
                                color: Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // 2. TAB MENU (OVERVIEW, WHAT YOU'LL LEARN, REVIEWS)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildTabItem('OVERVIEW'),
                  _buildTabItem('WHAT YOU\'LL LEARN'),
                  _buildTabItem('REVIEWS'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 3. MAIN DYNAMIC BODY AREA (Based on Figma Designs)
            _buildDynamicBodyContent(coach),

            const SizedBox(height: 20),

            // 4. FOOTER CARD FOR SESSION PRICE & PLAN BOOKING (WHITE BACKGROUND)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadii.card),
                border: Border.all(color: AppColors.hairline),
              ),
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tier selector pills
                  Builder(
                    builder: (context) {
                      const tiers = ['STANDARD', 'PRO', 'ELITE'];
                      return SporveSegmented(
                        segments: tiers,
                        selected: tiers.indexOf(_selectedTier),
                        onChanged: (i) => setState(() => _selectedTier = tiers[i]),
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // Selected Tier Info
                  Text(
                    'SESSION PRICE',
                    style: AppTypography.font(
                      color: AppColors.textTertiary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _tierPrice,
                    style: AppTypography.font(
                      color: AppColors.textPrimary,
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.9,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _tierDescription,
                    style: AppTypography.font(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Action buttons
                  SporveButton(
                    'Book session',
                    onPressed: () {
                      Get.toNamed(AppRoutes.bookingFlow, arguments: {
                        'program': programData,
                        'title': title,
                        'coach': coach,
                        'tier': _selectedTier,
                        'price': _tierPriceValue,
                      });
                    },
                    variant: SporveButtonVariant.primary,
                    color: SportColors.of(sport),
                  ),
                  const SizedBox(height: 12),
                  SporveButton(
                    'Message coach',
                    onPressed: () {
                      Get.snackbar(
                        'Message',
                        'Messaging $coach...',
                        snackPosition: SnackPosition.TOP,
                        backgroundColor: AppColors.surface,
                        colorText: AppColors.textPrimary,
                      );
                    },
                    variant: SporveButtonVariant.secondary,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildTabItem(String title) {
    final bool isSelected = _selectedTab == title;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTab = title;
        });
      },
      child: Column(
        children: [
          Text(
            title,
            style: AppTypography.font(
              color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 2,
            width: isSelected ? 40 : 0,
            color: AppColors.slateText,
          ),
        ],
      ),
    );
  }

  Widget _buildDynamicBodyContent(String coach) {
    if (_selectedTab == 'REVIEWS') {
      // Figma Reviews view is a series of stacked white cards
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            _buildRatingSummary(),
            const SizedBox(height: 16),
            _buildIndividualReview(
              name: 'Jordan M.',
              date: 'FEB 2026',
              rating: 5,
              comment: 'Coach Marcus transformed my son\'s game in 6 weeks. Incredibly detail-oriented and motivating.',
              avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=100&auto=format&fit=crop&q=80',
            ),
            const SizedBox(height: 16),
            _buildIndividualReview(
              name: 'Taylor R.',
              date: 'JAN 2026',
              rating: 5,
              comment: 'Best investment we\'ve made. My daughter went from JV to Varsity after 2 months of sessions.',
              avatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100&auto=format&fit=crop&q=80',
            ),
            const SizedBox(height: 16),
            _buildIndividualReview(
              name: 'Alex B.',
              date: 'DEC 2025',
              rating: 4,
              comment: 'Great drills and coaching philosophy. Would recommend for serious athletes.',
              avatarUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=100&auto=format&fit=crop&q=80',
            ),
          ],
        ),
      );
    }

    // OVERVIEW and WHAT YOU'LL LEARN share the same giant white card box container style
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.hairline),
      ),
      padding: const EdgeInsets.all(28),
      child: _selectedTab == 'WHAT YOU\'LL LEARN'
          ? _buildWhatYoullLearn()
          : _buildOverviewContent(),
    );
  }

  // FIGMA WHAT YOU'LL LEARN LAYOUT
  Widget _buildWhatYoullLearn() {
    final dynamic args = Get.arguments;
    Map<String, dynamic>? programData;
    if (args is Opportunity) {
      programData = args.rawData;
    } else if (args is Map<String, dynamic>) {
      programData = args;
    }

    final String sportType = programData?['sportType'] ?? '';
    
    // Choose dynamic breakdown steps based on sportType
    String step1Title = 'Warm-Up Protocol';
    String step1Desc = 'Dynamic stretching, light cardio, and sport-specific warm-up.';
    String step2Title = 'Skill Drills';
    String step2Desc = 'Core skill development and technical drill progression.';
    String step3Title = 'Live Application';
    String step3Desc = 'Game-speed scenarios applying drill concepts in real-time.';
    String step4Title = 'Cool Down & Review';
    String step4Desc = 'Recovery stretches and tactical review of the session.';
    
    if (sportType.toLowerCase() == 'soccer') {
      step1Desc = 'Dynamic stretching, light footwork, and dribbling warm-up.';
      step2Title = 'Tactical Drills';
      step2Desc = 'Passing accuracy, ball control, and shooting practice.';
      step3Title = 'Match Simulation';
      step3Desc = 'Small-sided game application to test positioning and teamwork.';
      step4Title = 'Cool Down & Feedback';
      step4Desc = 'Recovery stretch session and strategic feedback from the coach.';
    } else if (sportType.toLowerCase() == 'basketball') {
      step1Desc = 'Dynamic stretching, dribbling drills, and shooting warm-up.';
      step2Desc = 'Finishing at the rim, pick & roll execution, and defensive positioning.';
      step3Title = 'Scrimmage';
      step3Desc = 'Half-court game simulation applying concepts learned under pressure.';
      step4Title = 'Cool Down & Feedback';
      step4Desc = 'Free-throw shooting and individual performance review.';
    }

    // Inclusions
    final List<dynamic>? inclusionsRaw = programData?['whatsIncluded'];
    final List<String> inclusions = (inclusionsRaw != null && inclusionsRaw.isNotEmpty)
        ? inclusionsRaw.map((e) => e.toString()).toList()
        : ['Video analysis included', '1-on-1 focus', 'Customized drills'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SESSION BREAKDOWN',
          style: AppTypography.font(
            color: AppColors.textTertiary,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 24),

        // Steps
        _buildLearnStep(
          step: '1',
          title: step1Title,
          duration: '10 MIN',
          description: step1Desc,
        ),
        const SizedBox(height: 24),
        _buildLearnStep(
          step: '2',
          title: step2Title,
          duration: '25 MIN',
          description: step2Desc,
        ),
        const SizedBox(height: 24),
        _buildLearnStep(
          step: '3',
          title: step3Title,
          duration: '15 MIN',
          description: step3Desc,
        ),
        const SizedBox(height: 24),
        _buildLearnStep(
          step: '4',
          title: step4Title,
          duration: '10 MIN',
          description: step4Desc,
        ),
        
        const SizedBox(height: 28),
        
        // What's Included Green Box Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.slateTint,
            borderRadius: BorderRadius.circular(AppRadii.tile),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'WHAT\'S INCLUDED',
                style: AppTypography.font(
                  color: AppColors.slateText,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              ...inclusions.asMap().entries.map((entry) {
                final idx = entry.key;
                final item = entry.value;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildIncludedItem(item),
                    if (idx < inclusions.length - 1) const SizedBox(height: 10),
                  ],
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLearnStep({
    required String step,
    required String title,
    required String duration,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Number badge circle
        Container(
          height: 38,
          width: 38,
          decoration: const BoxDecoration(
            color: AppColors.slateTint,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            step,
            style: AppTypography.font(
              color: AppColors.slateText,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Content
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: AppTypography.font(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    duration,
                    style: AppTypography.font(
                      color: AppColors.textTertiary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: AppTypography.font(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIncludedItem(String text) {
    return Row(
      children: [
        const Icon(Icons.check, color: AppColors.slateText, size: 16),
        const SizedBox(width: 8),
        Text(
          text,
          style: AppTypography.font(
            color: AppColors.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // DEFAULT OVERVIEW TAB CONTENT
  Widget _buildOverviewContent() {
    final dynamic args = Get.arguments;
    Map<String, dynamic>? programData;
    if (args is Opportunity) {
      programData = args.rawData;
    } else if (args is Map<String, dynamic>) {
      programData = args;
    }

    final String overviewDescription = programData?['description'] ?? 
        (args is Opportunity ? args.title : 'Focused session on ball handling, court vision, and finishing under pressure.');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ABOUT THIS SESSION',
          style: AppTypography.font(
            color: AppColors.textTertiary,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          overviewDescription,
          style: AppTypography.font(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 20),

        // Views count tag
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.slateTint,
            borderRadius: BorderRadius.circular(AppRadii.chip),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.local_fire_department, color: AppColors.slateText, size: 14),
              const SizedBox(width: 8),
              Text(
                '94 people viewed this week',
                style: AppTypography.font(
                  color: AppColors.slateText,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Booking count tag
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.slateTint,
            borderRadius: BorderRadius.circular(AppRadii.chip),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.event_available, color: AppColors.slateText, size: 14),
              const SizedBox(width: 8),
              Text(
                'Booked 3 times today',
                style: AppTypography.font(
                  color: AppColors.slateText,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Sporve verified badge bar
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface2,
            borderRadius: BorderRadius.circular(AppRadii.tile),
          ),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.verified_user, color: AppColors.slateText, size: 16),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Background checked',
                            style: AppTypography.font(
                              color: AppColors.textPrimary,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Identity verified by Sporve',
                            style: AppTypography.font(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.bolt, color: AppColors.slateText, size: 16),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '98% response rate',
                            style: AppTypography.font(
                              color: AppColors.textPrimary,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Typically replies under 1 hr',
                            style: AppTypography.font(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Grid Properties (Sport, Distance, Age, Response)
        Row(
          children: [
            _buildGridBox('SPORT', Icons.emoji_events, '${programData?['sportType'] ?? (args is Opportunity ? 'Basketball' : 'General')}'),
            const SizedBox(width: 12),
            _buildGridBox('DISTANCE', Icons.place, '${programData?['distance']?.toString() ?? '0.8'} miles'),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildGridBox('AGE RANGE', Icons.person, '${programData != null ? ('${programData['minimumAge'] ?? 10}-${programData['maximumAge'] ?? 17}') : '10-17'} years'),
            const SizedBox(width: 12),
            _buildGridBox('CANCELLATION', Icons.shield, '${programData?['cancellationPolicy'] ?? 'flexible'}'),
          ],
        ),
      ],
    );
  }

  Widget _buildGridBox(String label, IconData icon, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(AppRadii.tile),
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
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(icon, color: AppColors.slateText, size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    value,
                    style: AppTypography.font(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // FIGMA REVIEWS SUMMARY CARD
  Widget _buildRatingSummary() {
    final dynamic args = Get.arguments;
    Map<String, dynamic>? programData;
    if (args is Opportunity) {
      programData = args.rawData;
    } else if (args is Map<String, dynamic>) {
      programData = args;
    }

    final double avgRating = (programData?['averageRating'] as num?)?.toDouble() ?? 
        double.tryParse(args is Opportunity ? args.rating.split(' ')[0] : '4.9') ?? 4.9;
    final int reviewsCount = (programData?['totalReviews'] as num?)?.toInt() ?? 124;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.hairline),
      ),
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left: Large Rating
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                avgRating.toStringAsFixed(1),
                style: AppTypography.font(
                  color: AppColors.textPrimary,
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (index) {
                  return Icon(
                    index < avgRating.round() ? Icons.star : Icons.star_border,
                    color: AppColors.warning,
                    size: 16,
                  );
                }),
              ),
              const SizedBox(height: 6),
              Text(
                '$reviewsCount REVIEWS',
                style: AppTypography.font(
                  color: AppColors.textTertiary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(width: 24),
          // Right: Bars
          Expanded(
            child: Column(
              children: [
                _buildRatingBar('5', 0.68, '68%'),
                const SizedBox(height: 4),
                _buildRatingBar('4', 0.22, '22%'),
                const SizedBox(height: 4),
                _buildRatingBar('3', 0.07, '7%'),
                const SizedBox(height: 4),
                _buildRatingBar('2', 0.02, '2%'),
                const SizedBox(height: 4),
                _buildRatingBar('1', 0.01, '1%'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingBar(String star, double percentage, String percentText) {
    return Row(
      children: [
        Text(
          star,
          style: AppTypography.font(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: percentage,
              backgroundColor: AppColors.surface2,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.warning),
              minHeight: 6,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 28,
          child: Text(
            percentText,
            style: AppTypography.font(
              color: AppColors.textTertiary,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  // FIGMA INDIVIDUAL REVIEW CARD
  Widget _buildIndividualReview({
    required String name,
    required String date,
    required double rating,
    required String comment,
    required String avatarUrl,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.hairline),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // User Avatar
              ClipOval(
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: SporveImage(
                    avatarUrl,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    fallbackIcon: Icons.person,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Name and Stars & Date
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.font(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Row(
                          children: List.generate(5, (index) {
                            return Icon(
                              Icons.star,
                              color: index < rating ? AppColors.warning : AppColors.textTertiary,
                              size: 14,
                            );
                          }),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          date,
                          style: AppTypography.font(
                            color: AppColors.textTertiary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            comment,
            style: AppTypography.font(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

}
