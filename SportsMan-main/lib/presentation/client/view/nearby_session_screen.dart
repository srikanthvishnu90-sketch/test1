import 'package:flutter/material.dart';
import 'package:flutter_structure/core/theme/app_typography.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/sporve_button.dart';

class TravelDetails {
  final String duration;
  final String arrivalTime;
  final String trafficStatus;
  final String checkInDistance;
  final Color trafficColor;
  final Color trafficBgColor;

  const TravelDetails({
    required this.duration,
    required this.arrivalTime,
    required this.trafficStatus,
    required this.checkInDistance,
    required this.trafficColor,
    required this.trafficBgColor,
  });
}

class NearbyField {
  final int id;
  final String name;
  final String address;
  final String sessionTime;
  final String coachName;
  final String entranceHint;
  final double top;
  final double? left;
  final double? right;
  final double? bottom;
  final Map<String, TravelDetails> travelModes;

  const NearbyField({
    required this.id,
    required this.name,
    required this.address,
    required this.sessionTime,
    required this.coachName,
    required this.entranceHint,
    required this.top,
    this.left,
    this.right,
    this.bottom,
    required this.travelModes,
  });
}

class NearbySessionScreen extends StatefulWidget {
  const NearbySessionScreen({super.key});

  @override
  State<NearbySessionScreen> createState() => _NearbySessionScreenState();
}

class _NearbySessionScreenState extends State<NearbySessionScreen> {
  bool _smartCheckIn = true;
  String _selectedMode = 'car'; // 'car', 'walk', 'transit'
  int _selectedFieldIndex = 0; // Default to 'Lab A'

  final List<NearbyField> _nearbyFields = const [
    NearbyField(
      id: 0,
      name: 'Lab A',
      address: '123 MICHIGAN AVE • COURT 2',
      sessionTime: '4:30 PM',
      coachName: 'COACH MARCUS',
      entranceHint: 'Use North Entrance next to Parking Lot A',
      top: 260,
      left: 60,
      travelModes: {
        'car': TravelDetails(
          duration: '12 min',
          arrivalTime: 'ARRIVE 4:18 PM',
          trafficStatus: 'Low Traffic',
          checkInDistance: 'Auto at 150ft',
          trafficColor: AppColors.slateText,
          trafficBgColor: AppColors.slateTint,
        ),
        'walk': TravelDetails(
          duration: '42 min',
          arrivalTime: 'ARRIVE 4:48 PM',
          trafficStatus: 'No Traffic',
          checkInDistance: 'Auto at 150ft',
          trafficColor: AppColors.textSecondary,
          trafficBgColor: AppColors.surface2,
        ),
        'transit': TravelDetails(
          duration: '24 min',
          arrivalTime: 'ARRIVE 4:30 PM',
          trafficStatus: 'On Time',
          checkInDistance: 'Auto at 150ft',
          trafficColor: AppColors.textSecondary,
          trafficBgColor: AppColors.surface2,
        ),
      },
    ),
    NearbyField(
      id: 1,
      name: 'Courtside Arena',
      address: '456 BROADWAY ST • COURT 5',
      sessionTime: '6:00 PM',
      coachName: 'COACH CARTER',
      entranceHint: 'Enter through the East Gate next to the Cafe',
      top: 360,
      right: 50,
      travelModes: {
        'car': TravelDetails(
          duration: '18 min',
          arrivalTime: 'ARRIVE 5:48 PM',
          trafficStatus: 'Moderate Traffic',
          checkInDistance: 'Auto at 200ft',
          trafficColor: AppColors.warning,
          trafficBgColor: AppColors.warningTint,
        ),
        'walk': TravelDetails(
          duration: '65 min',
          arrivalTime: 'ARRIVE 6:35 PM',
          trafficStatus: 'Clear Walkway',
          checkInDistance: 'Auto at 200ft',
          trafficColor: AppColors.textSecondary,
          trafficBgColor: AppColors.surface2,
        ),
        'transit': TravelDetails(
          duration: '35 min',
          arrivalTime: 'ARRIVE 6:05 PM',
          trafficStatus: 'Delayed 5m',
          checkInDistance: 'Auto at 200ft',
          trafficColor: AppColors.negative,
          trafficBgColor: AppColors.negativeTint,
        ),
      },
    ),
    NearbyField(
      id: 2,
      name: 'Downtown Gym',
      address: '789 GRAND AVE • MAIN COURT',
      sessionTime: '7:30 PM',
      coachName: 'COACH JORDAN',
      entranceHint: 'Use basement entrance near elevator B',
      top: 480,
      left: 120,
      travelModes: {
        'car': TravelDetails(
          duration: '8 min',
          arrivalTime: 'ARRIVE 7:08 PM',
          trafficStatus: 'Heavy Traffic',
          checkInDistance: 'Auto at 100ft',
          trafficColor: AppColors.negative,
          trafficBgColor: AppColors.negativeTint,
        ),
        'walk': TravelDetails(
          duration: '28 min',
          arrivalTime: 'ARRIVE 7:28 PM',
          trafficStatus: 'Clear Path',
          checkInDistance: 'Auto at 100ft',
          trafficColor: AppColors.slateText,
          trafficBgColor: AppColors.slateTint,
        ),
        'transit': TravelDetails(
          duration: '15 min',
          arrivalTime: 'ARRIVE 7:15 PM',
          trafficStatus: 'On Time',
          checkInDistance: 'Auto at 100ft',
          trafficColor: AppColors.textSecondary,
          trafficBgColor: AppColors.surface2,
        ),
      },
    ),
    NearbyField(
      id: 3,
      name: 'Apex Sports Complex',
      address: '101 STADIUM WAY • FIELD 3',
      sessionTime: '8:00 PM',
      coachName: 'COACH AMARA',
      entranceHint: 'Gate 4 next to the ticketing office',
      top: 560,
      right: 120,
      travelModes: {
        'car': TravelDetails(
          duration: '25 min',
          arrivalTime: 'ARRIVE 7:55 PM',
          trafficStatus: 'Light Traffic',
          checkInDistance: 'Auto at 300ft',
          trafficColor: AppColors.slateText,
          trafficBgColor: AppColors.slateTint,
        ),
        'walk': TravelDetails(
          duration: '95 min',
          arrivalTime: 'ARRIVE 9:05 PM',
          trafficStatus: 'Clear Road',
          checkInDistance: 'Auto at 300ft',
          trafficColor: AppColors.textSecondary,
          trafficBgColor: AppColors.surface2,
        ),
        'transit': TravelDetails(
          duration: '45 min',
          arrivalTime: 'ARRIVE 8:15 PM',
          trafficStatus: 'On Time',
          checkInDistance: 'Auto at 300ft',
          trafficColor: AppColors.textSecondary,
          trafficBgColor: AppColors.surface2,
        ),
      },
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final currentField = _nearbyFields[_selectedFieldIndex];
    final travel = currentField.travelModes[_selectedMode]!;

    return Scaffold(
      backgroundColor: AppColors.navyDark,
      body: Stack(
        children: [
          // 1. Simulated Stylized Map Background containing all interactive markers
          _buildMapArea(),

          // 2. Custom Safe Area for Top Header (Title & Address Card)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // App Bar Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SporveIconButton(
                        Icons.arrow_back,
                        onTap: () => Get.back(),
                        iconSize: 20,
                      ),
                      Text(
                        currentField.name,
                        style: AppTypography.font(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 38), // Spacer to balance back arrow
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Address line centered/aligned below title
                  Align(
                    alignment: Alignment.center,
                    child: Text(
                      currentField.address,
                      style: AppTypography.font(
                        color: AppColors.textGrey,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Capsule Session Badge
                  Align(
                    alignment: Alignment.center,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadii.chip),
                        border: Border.all(color: AppColors.hairline),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.circle, color: AppColors.accentBlue, size: 8),
                          const SizedBox(width: 8),
                          Text(
                            '${currentField.sessionTime} • ${currentField.coachName}',
                            style: AppTypography.font(
                              color: AppColors.textPrimary,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Entrance Hint Card
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
                          'ENTRANCE HINT',
                          style: AppTypography.font(
                            color: AppColors.slateText,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          currentField.entranceHint,
                          style: AppTypography.font(
                            color: Colors.white,
                            fontSize: 14,
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

          // 3. Bottom Sheet Card (Travel info and Check-in toggle)
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.card)),
                border: Border(top: BorderSide(color: AppColors.hairline)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 30,
                    offset: Offset(0, -10),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(28, 12, 28, 36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag handle indicator
                  Container(
                    width: 38,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.hairline,
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Row for: [Time & Traffic] and [Smart Check-in Card]
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left Section: Duration & Arrival details
                      Expanded(
                        flex: 11,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              travel.duration,
                              style: AppTypography.font(
                                color: AppColors.textPrimary,
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                height: 1.0,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              travel.arrivalTime,
                              style: AppTypography.font(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 10),
                            // Traffic status badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: travel.trafficBgColor,
                                borderRadius: BorderRadius.circular(AppRadii.chip),
                              ),
                              child: Text(
                                travel.trafficStatus,
                                style: AppTypography.font(
                                  color: travel.trafficColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Right Section: Smart Check-In Card
                      Expanded(
                        flex: 12,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surface2,
                            borderRadius: BorderRadius.circular(AppRadii.card),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'SMART CHECK-IN',
                                style: AppTypography.font(
                                  color: AppColors.textTertiary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      travel.checkInDistance,
                                      style: AppTypography.font(
                                        color: AppColors.textPrimary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Transform.scale(
                                    scale: 0.8,
                                    child: Switch(
                                      value: _smartCheckIn,
                                      activeThumbColor: AppColors.slateText,
                                      activeTrackColor: AppColors.slateTint,
                                      inactiveThumbColor: AppColors.textSecondary,
                                      inactiveTrackColor: AppColors.hairline,
                                      onChanged: (val) {
                                        setState(() {
                                          _smartCheckIn = val;
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 28),
                  
                  // Row for Travel Modes Selection Buttons
                  Row(
                    children: [
                      _buildModeButton(
                        mode: 'car',
                        icon: Icons.directions_car,
                        activeIconColor: AppColors.onSlate,
                        inactiveIconColor: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 12),
                      _buildModeButton(
                        mode: 'walk',
                        icon: Icons.directions_walk,
                        activeIconColor: AppColors.onSlate,
                        inactiveIconColor: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 12),
                      _buildModeButton(
                        mode: 'transit',
                        icon: Icons.directions_bus,
                        activeIconColor: AppColors.onSlate,
                        inactiveIconColor: AppColors.textSecondary,
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 28),
                  
                  // Row for Action Buttons
                  Row(
                    children: [
                      // START NAVIGATION (Blue)
                      Expanded(
                        flex: 13,
                        child: SporveButton(
                          'Start navigation',
                          onPressed: () {
                            Get.snackbar(
                              'Navigation',
                              'Starting navigation to ${currentField.name} via $_selectedMode...',
                              snackPosition: SnackPosition.TOP,
                              backgroundColor: AppColors.accentBlue,
                              colorText: Colors.white,
                              borderRadius: 16,
                              margin: const EdgeInsets.all(16),
                            );
                          },
                          variant: SporveButtonVariant.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // SHARE ETA (Dark Black)
                      Expanded(
                        flex: 9,
                        child: SporveButton(
                          'Share ETA',
                          onPressed: () {
                            Get.snackbar(
                              'Share',
                              'ETA ${travel.duration} shared successfully!',
                              snackPosition: SnackPosition.TOP,
                              backgroundColor: AppColors.surface2,
                              colorText: AppColors.textPrimary,
                              borderRadius: 10,
                              margin: const EdgeInsets.all(16),
                            );
                          },
                          variant: SporveButtonVariant.dark,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapArea() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: AppColors.ink, // stylized map canvas
      child: Stack(
        children: [
          // Styled Subtle Grid Overlay (Simulated Gridlines)
          Positioned.fill(
            child: Opacity(
              opacity: 0.03,
              child: GridPaper(
                color: Colors.white,
                divisions: 1,
                subdivisions: 1,
                interval: 80,
              ),
            ),
          ),
          
          // Stylized Map Roads/Shapes in Map background
          Positioned(
            top: 250,
            left: -50,
            child: Container(
              width: 500,
              height: 12,
              transform: Matrix4.rotationZ(0.2),
              color: Colors.white.withOpacity(0.03),
            ),
          ),
          Positioned(
            top: 380,
            left: -100,
            child: Container(
              width: 600,
              height: 20,
              transform: Matrix4.rotationZ(-0.4),
              color: Colors.white.withOpacity(0.025),
            ),
          ),
          Positioned(
            top: 180,
            right: -50,
            child: Container(
              width: 12,
              height: 500,
              color: Colors.white.withOpacity(0.03),
            ),
          ),

          // Render all nearby fields dynamically as interactive markers
          ..._nearbyFields.map((field) {
            final bool isSelected = _selectedFieldIndex == field.id;
            final travel = field.travelModes[_selectedMode]!;
            
            return Positioned(
              top: field.top,
              left: field.left,
              right: field.right,
              bottom: field.bottom,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedFieldIndex = field.id;
                  });
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Dynamic tooltip overlay above selected pin
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 250),
                      opacity: isSelected ? 1.0 : 0.0,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadii.chip),
                          border: Border.all(color: AppColors.hairline),
                          boxShadow: const [
                            BoxShadow(color: Colors.black38, blurRadius: 8, offset: Offset(0, 4)),
                          ],
                        ),
                        child: Text(
                          '${field.name} • ${travel.duration}',
                          style: AppTypography.font(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    
                    // Styled Location Marker Pin (Dynamic scaling & glow)
                    AnimatedScale(
                      scale: isSelected ? 1.25 : 1.0,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.slateTint : AppColors.surface,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? AppColors.slateText : AppColors.hairline,
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.slateText : AppColors.surface2,
                            shape: BoxShape.circle,
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: AppColors.slateText.withOpacity(0.6),
                                      blurRadius: 16,
                                      spreadRadius: 2,
                                    )
                                  ]
                                : [],
                          ),
                          child: Icon(
                            Icons.location_on,
                            color: isSelected ? AppColors.onSlate : AppColors.textSecondary,
                            size: isSelected ? 20 : 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildModeButton({
    required String mode,
    required IconData icon,
    required Color activeIconColor,
    required Color inactiveIconColor,
  }) {
    final bool isSelected = _selectedMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedMode = mode;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 56,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.slateText : AppColors.surface2,
            borderRadius: BorderRadius.circular(AppRadii.tile),
            border: Border.all(
              color: isSelected ? Colors.transparent : AppColors.hairline,
              width: 1.5,
            ),
          ),
          child: Icon(
            icon,
            color: isSelected ? activeIconColor : inactiveIconColor,
            size: 24,
          ),
        ),
      ),
    );
  }
}
