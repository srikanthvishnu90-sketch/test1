import 'package:flutter/material.dart';
import 'package:flutter_structure/core/theme/app_typography.dart';
import '../client/view/home_screen.dart';
import '../client/view/search_screen.dart';
import '../client/view/schedule_screen.dart';
import '../client/view/messages_screen.dart';
import '../client/view/profile_screen.dart';
import '../../core/theme/app_colors.dart';
import '../widgets/common_widgets.dart';

class MainNavScreen extends StatefulWidget {
  const MainNavScreen({super.key});

  @override
  State<MainNavScreen> createState() => _MainNavScreenState();
}

class _MainNavScreenState extends State<MainNavScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const SearchScreen(),
    const ScheduleScreen(),
    const MessagesScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      // Instant tab switching with every tab kept alive — preserves each tab's
      // state and scroll position (no rebuild/re-fetch on switch).
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.only(top: 8, bottom: 8, left: 8, right: 8),
        decoration: const BoxDecoration(
          color: AppColors.ink,
          border: Border(top: BorderSide(color: AppColors.hairline, width: 0.5)),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildNavItem(0, Icons.home_outlined, Icons.home, 'Home'),
              _buildNavItem(1, Icons.search_outlined, Icons.search, 'Search'),
              _buildNavItem(2, Icons.calendar_today_outlined, Icons.calendar_today, 'Schedule'),
              _buildNavItem(3, Icons.chat_bubble_outline, Icons.chat_bubble, 'Chat'),
              _buildNavItem(4, Icons.person_outline, Icons.person, 'Profile'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon, String label) {
    final bool isSelected = _selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _selectedIndex = index),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          // Animate color (tertiary→slate), a subtle scale-up, and the
          // outline→filled icon swap — the Uber-style active-tab polish.
          child: TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            tween: Tween<double>(begin: 0, end: isSelected ? 1 : 0),
            builder: (context, t, _) {
              final color = Color.lerp(AppColors.textTertiary, AppColors.slateText, t)!;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Transform.scale(
                    scale: 1 + 0.12 * t,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: Icon(
                        isSelected ? activeIcon : icon,
                        key: ValueKey<bool>(isSelected),
                        color: color,
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    label,
                    style: AppTypography.font(
                      color: color,
                      fontSize: 10,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
