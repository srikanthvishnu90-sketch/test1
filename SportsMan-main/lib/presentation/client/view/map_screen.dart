import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/sport_colors.dart';
import '../../../core/routes/app_routes.dart';
import '../../widgets/common_widgets.dart';
import '../controllers/home_controller.dart';
import 'search_screen.dart' show Opportunity;

/// Real map of nearby companies/coaches — each published program is a
/// sport-colored pin at its real lat/lng (OpenStreetMap dark tiles, no API key).
/// Tapping a pin surfaces a card that opens the listing.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _map = MapController();
  Map<String, dynamic>? _selected;

  static const LatLng _chicago = LatLng(41.8781, -87.6298);

  List<_Pin> _pins(List<dynamic> programs) {
    final pins = <_Pin>[];
    for (final p in programs) {
      if (p is! Map) continue;
      final coords = p['location']?['coordinates'];
      if (coords is! List || coords.length < 2) continue;
      final lng = (coords[0] as num?)?.toDouble();
      final lat = (coords[1] as num?)?.toDouble();
      if (lat == null || lng == null || (lat == 0 && lng == 0)) continue;
      pins.add(_Pin(LatLng(lat, lng), Map<String, dynamic>.from(p)));
    }
    return pins;
  }

  @override
  Widget build(BuildContext context) {
    final programs = context.watch<HomeProvider>().programs;
    final pins = _pins(programs);
    final center = pins.isNotEmpty ? pins.first.pos : _chicago;

    return GradientScaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 11.5,
              onTap: (_, _) => setState(() => _selected = null),
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://a.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.sporve.app',
              ),
              MarkerLayer(
                markers: [
                  for (final pin in pins)
                    Marker(
                      point: pin.pos,
                      width: 44,
                      height: 44,
                      child: GestureDetector(
                        onTap: () => setState(() => _selected = pin.data),
                        child: _MarkerPin(
                          sport: pin.data['sportType']?.toString(),
                          selected: identical(_selected, pin.data),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),

          // Header
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  SporveIconButton(
                    Icons.arrow_back,
                    semanticLabel: 'Back',
                    onTap: () => Get.back(),
                    filled: true,
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadii.tile),
                      border: Border.all(color: AppColors.hairline),
                    ),
                    child: Text(
                      '${pins.length} ${pins.length == 1 ? 'coach' : 'coaches'} on the map',
                      style: AppTypography.font(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_selected != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: _ListingCard(program: _selected!),
            ),
        ],
      ),
    );
  }
}

class _Pin {
  final LatLng pos;
  final Map<String, dynamic> data;
  _Pin(this.pos, this.data);
}

class _MarkerPin extends StatelessWidget {
  final String? sport;
  final bool selected;
  const _MarkerPin({required this.sport, required this.selected});

  @override
  Widget build(BuildContext context) {
    final c = SportColors.of(sport);
    final size = selected ? 42.0 : 34.0;
    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: c,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: SportColors.glowOf(sport, intensity: selected ? 1.2 : 0.9),
        ),
        child: Icon(
          SportColors.iconOf(sport),
          color: SportColors.onColorOf(sport),
          size: size * 0.55,
        ),
      ),
    );
  }
}

class _ListingCard extends StatelessWidget {
  final Map<String, dynamic> program;
  const _ListingCard({required this.program});

  @override
  Widget build(BuildContext context) {
    final sport = program['sportType']?.toString();
    final title = program['title']?.toString() ?? 'Program';
    final coach =
        (program['providerId'] is Map
                ? program['providerId']['businessName']
                : null)
            ?.toString() ??
        'Academy';
    final price = program['price'];
    final rating = program['averageRating']?.toString() ?? '0.0';

    return GestureDetector(
      onTap: () => Get.toNamed(
        AppRoutes.sessionDetails,
        arguments: _opportunity(program),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border(
            left: BorderSide(color: SportColors.of(sport), width: 3),
            top: const BorderSide(color: AppColors.hairline),
            right: const BorderSide(color: AppColors.hairline),
            bottom: const BorderSide(color: AppColors.hairline),
          ),
        ),
        child: Row(
          children: [
            SportIconTile(sport ?? '', size: 46),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.font(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    coach,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.font(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.star,
                        color: AppColors.textPrimary,
                        size: 12,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        rating,
                        style: AppTypography.font(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '\$${price is num ? price.round() : (price ?? 0)}',
                        style: AppTypography.font(
                          color: SportColors.of(sport),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AppColors.textTertiary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Opportunity _opportunity(Map<String, dynamic> p) => Opportunity(
    id: 0,
    programId: p['_id']?.toString(),
    title: p['title']?.toString() ?? 'Program',
    coach:
        (p['providerId'] is Map ? p['providerId']['businessName'] : null)
            ?.toString() ??
        'Academy',
    price: '\$${p['price'] is num ? (p['price'] as num).round() : (p['price'] ?? 0)}',
    rating: p['averageRating']?.toString() ?? '0.0',
    image: '',
    spotsLeft: '',
    isVerified: false,
    bookingTrend: '',
    top: 0,
    team: '',
    rawData: p,
  );
}
