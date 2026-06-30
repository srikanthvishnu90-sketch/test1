import 'package:flutter/material.dart';
import 'package:flutter_structure/core/theme/app_typography.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../widgets/common_widgets.dart';
import '../controllers/search_provider.dart';

class FilterScreen extends StatefulWidget {
  const FilterScreen({super.key});

  @override
  State<FilterScreen> createState() => _FilterScreenState();
}

class _FilterScreenState extends State<FilterScreen> {
  double _radius = 25;
  String _selectedSport = 'VOLLEYBALL';
  String _selectedService = 'CAMPS';
  String _selectedSkill = 'INTERMEDIATE';

  // A skill level maps to a soft (ranking-hint) attribute, never a hard filter.
  static const Map<String, String> _skillToSoft = {
    'BEGINNER': 'beginner-friendly',
    'INTERMEDIATE': 'intermediate',
    'ADVANCED': 'advanced',
    'ELITE': 'competitive',
  };

  @override
  void initState() {
    super.initState();
    // Round-trip with the AI constraint chips: seed the controls from whatever
    // the current search already resolved.
    final c = context.read<SearchProvider>().constraints;
    final sport = c['sport']?.toString();
    if (sport != null && sport.isNotEmpty) _selectedSport = sport.toUpperCase();
    final radius = c['radius_miles'];
    if (radius is num) _radius = radius.toDouble().clamp(0, 100);
  }

  void _applyFilters() {
    final search = context.read<SearchProvider>();
    final existing =
        (search.constraints['soft_attributes'] as List?)?.map((e) => '$e') ??
        const <String>[];
    final soft = <String>{...existing};
    final skill = _skillToSoft[_selectedSkill];
    if (skill != null) soft.add(skill);

    search.applyConstraints({
      'sport': _selectedSport.toLowerCase(),
      'radius_miles': _radius,
      'soft_attributes': soft.toList(),
    });
    Get.back();
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'Filters',
          style: AppTypography.font(
            color: AppColors.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: SporveIconButton(
              Icons.close,
              semanticLabel: 'Close filters',
              onTap: () => Get.back(),
              color: AppColors.negative,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('SPORT'),
            const SizedBox(height: 16),
            _buildSportGrid(),
            const SizedBox(height: 32),
            _buildSectionTitle('SERVICE TYPE'),
            const SizedBox(height: 16),
            _buildServiceTypes(),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionTitle('RADIUS'),
                Text(
                  '${_radius.toInt()} mi',
                  style: AppTypography.font(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppColors.slateText,
                inactiveTrackColor: AppColors.hairline,
                thumbColor: AppColors.slateText,
                overlayColor: AppColors.slateTint,
              ),
              child: Slider(
                value: _radius,
                min: 0,
                max: 100,
                onChanged: (v) => setState(() => _radius = v),
              ),
            ),
            const SizedBox(height: 32),
            _buildSectionTitle('SKILL LEVEL'),
            const SizedBox(height: 16),
            _buildSkillLevels(),
            const SizedBox(height: 48),
            Row(
              children: [
                TextButton(
                  onPressed: () => setState(() {
                    _radius = 25;
                    _selectedSport = 'VOLLEYBALL';
                    _selectedService = 'CAMPS';
                    _selectedSkill = 'INTERMEDIATE';
                  }),
                  child: Text(
                    'CLEAR ALL',
                    style: AppTypography.font(
                      color: AppColors.textTertiary,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _applyFilters,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.slateText,
                      foregroundColor: AppColors.onSlate,
                      minimumSize: const Size(double.infinity, 60),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadii.tile),
                      ),
                    ),
                    child: Text(
                      'APPLY FILTERS',
                      style: AppTypography.font(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: AppTypography.font(
        color: AppColors.textTertiary,
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1,
      ),
    );
  }

  Widget _buildSportGrid() {
    final sports = [
      {'icon': Icons.sports_basketball, 'label': 'BASKETBALL'},
      {'icon': Icons.sports_soccer, 'label': 'SOCCER'},
      {'icon': Icons.sports_tennis, 'label': 'TENNIS'},
      {'icon': Icons.sports_football, 'label': 'FOOTBALL'},
      {'icon': Icons.pool, 'label': 'SWIMMING'},
      {'icon': Icons.sports_golf, 'label': 'GOLF'},
      {'icon': Icons.sports_baseball, 'label': 'BASEBALL'},
      {'icon': Icons.sports_volleyball, 'label': 'VOLLEYBALL'},
      {'icon': Icons.accessibility_new, 'label': 'GYMNASTICS'},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.1,
      ),
      itemCount: sports.length,
      itemBuilder: (context, index) {
        final sport = sports[index];
        bool isSelected = _selectedSport == sport['label'];
        return GestureDetector(
          onTap: () =>
              setState(() => _selectedSport = sport['label'] as String),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? AppColors.slateText : AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadii.tile),
              border: Border.all(
                color: isSelected ? Colors.transparent : AppColors.hairline,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  sport['icon'] as IconData,
                  color: isSelected ? AppColors.onSlate : AppColors.textPrimary,
                  size: 24,
                ),
                const SizedBox(height: 8),
                Text(
                  sport['label'] as String,
                  style: AppTypography.font(
                    color: isSelected
                        ? AppColors.onSlate
                        : AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildServiceTypes() {
    final types = ['TRAINING', 'PROGRAMS', 'FACILITIES', 'CAMPS', 'GEAR'];
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: types.map((type) {
        bool isSelected = _selectedService == type;
        return GestureDetector(
          onTap: () => setState(() => _selectedService = type),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.slateText : AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadii.tile),
              border: Border.all(
                color: isSelected ? Colors.transparent : AppColors.hairline,
              ),
            ),
            child: Text(
              type,
              style: AppTypography.font(
                color: isSelected ? AppColors.onSlate : AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSkillLevels() {
    final levels = ['BEGINNER', 'INTERMEDIATE', 'ADVANCED', 'ELITE'];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 2.8,
      ),
      itemCount: levels.length,
      itemBuilder: (context, index) {
        final level = levels[index];
        bool isSelected = _selectedSkill == level;
        return GestureDetector(
          onTap: () => setState(() => _selectedSkill = level),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected ? AppColors.slateText : AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadii.tile),
              border: Border.all(
                color: isSelected ? Colors.transparent : AppColors.hairline,
              ),
            ),
            child: Text(
              level,
              style: AppTypography.font(
                color: isSelected ? AppColors.onSlate : AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }
}
