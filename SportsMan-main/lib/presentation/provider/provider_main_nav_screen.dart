import 'package:flutter/material.dart';
import 'package:flutter_structure/core/theme/app_typography.dart';
import '../../core/theme/app_colors.dart';
import './view/provider_dashboard_screen.dart';
import './view/provider_listings_screen.dart';
import './view/provider_schedule_screen.dart';
import './view/provider_chat_screen.dart';
import './view/provider_profile_screen.dart';
import '../widgets/common_widgets.dart';

class ProviderMainNavScreen extends StatefulWidget {
  const ProviderMainNavScreen({super.key});

  @override
  State<ProviderMainNavScreen> createState() => _ProviderMainNavScreenState();
}

class _ProviderMainNavScreenState extends State<ProviderMainNavScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const ProviderDashboardScreen(),
    const ProviderListingsScreen(),
    const ProviderScheduleScreen(),
    const ProviderChatScreen(),
    const ProviderProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: Container(
        height: 100,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: const BoxDecoration(
          color: AppColors.ink,
          border: Border(top: BorderSide(color: AppColors.hairline, width: 0.5)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildNavItem(0, Icons.grid_view_rounded, 'DASHBOARD'),
            _buildNavItem(1, Icons.list_alt_rounded, 'LISTINGS'),
            _buildNavItem(2, Icons.calendar_today_outlined, 'SCHEDULE'),
            _buildNavItem(3, Icons.chat_bubble_outline, 'CHAT'),
            _buildNavItem(4, Icons.person_outline, 'PROFILE'),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    bool isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(
              icon,
              color: isSelected ? AppColors.slateText : AppColors.textTertiary,
              size: 24,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTypography.font(
              color: isSelected ? AppColors.slateText : AppColors.textTertiary,
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
