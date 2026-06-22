import 'package:flutter/material.dart';
import 'package:flutter_structure/core/theme/app_typography.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../controllers/provider_controller.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/sporve_button.dart';
import '../../widgets/sporve_image.dart';

class ProviderScheduleScreen extends StatefulWidget {
  const ProviderScheduleScreen({super.key});

  @override
  State<ProviderScheduleScreen> createState() => _ProviderScheduleScreenState();
}

class _ProviderScheduleScreenState extends State<ProviderScheduleScreen> {
  String _selectedView = 'MONTH';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ProviderController>().fetchProviderBookings();
      }
    });
  }

  int _getDaysInMonth(int year, int month) {
    if (month == 2) {
      if (((year % 4 == 0) && (year % 100 != 0)) || (year % 400 == 0)) {
        return 29;
      }
      return 28;
    }
    const days = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    return days[month - 1];
  }

  String _formatFullDate(DateTime date) {
    final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    
    // Manual mapping to handle index properly
    final weekdayStr = weekdays[date.weekday - 1];
    final String monthStr;
    switch (date.month) {
      case 1: monthStr = 'January'; break;
      case 2: monthStr = 'February'; break;
      case 3: monthStr = 'March'; break;
      case 4: monthStr = 'April'; break;
      case 5: monthStr = 'May'; break;
      case 6: monthStr = 'June'; break;
      case 7: monthStr = 'July'; break;
      case 8: monthStr = 'August'; break;
      case 9: monthStr = 'September'; break;
      case 10: monthStr = 'October'; break;
      case 11: monthStr = 'November'; break;
      case 12: monthStr = 'December'; break;
      default: monthStr = '';
    }
    
    return '$weekdayStr, $monthStr ${date.day}, ${date.year}';
  }

  String _formatMonthHeader(DateTime date) {
    final String monthStr;
    switch (date.month) {
      case 1: monthStr = 'January'; break;
      case 2: monthStr = 'February'; break;
      case 3: monthStr = 'March'; break;
      case 4: monthStr = 'April'; break;
      case 5: monthStr = 'May'; break;
      case 6: monthStr = 'June'; break;
      case 7: monthStr = 'July'; break;
      case 8: monthStr = 'August'; break;
      case 9: monthStr = 'September'; break;
      case 10: monthStr = 'October'; break;
      case 11: monthStr = 'November'; break;
      case 12: monthStr = 'December'; break;
      default: monthStr = '';
    }
    return '$monthStr ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ProviderController>();
    final currentMonth = controller.currentMonth;
    final selectedDate = controller.selectedDate;

    // Calculate calendar parameters
    int daysInMonth = _getDaysInMonth(currentMonth.year, currentMonth.month);
    // weekday is 1 (Monday) to 7 (Sunday). Let's convert to 0 (Sunday) to 6 (Saturday).
    int firstWeekday = DateTime(currentMonth.year, currentMonth.month, 1).weekday;
    int offset = firstWeekday == 7 ? 0 : firstWeekday; // Sunday is 0, Monday is 1, etc.
    int totalCells = daysInMonth + offset;

    final daySessions = controller.getSessionsForDate(selectedDate);
    final pendingRequests = daySessions.where((s) => !s.isConfirmed).toList();
    final confirmedSessions = daySessions.where((s) => s.isConfirmed).toList();

    return Scaffold(
      backgroundColor: AppColors.navyDark,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Schedule',
                      style: AppTypography.font(
                        color: AppColors.textPrimary,
                        fontSize: 26,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'UPCOMING & PAST SESSIONS',
                      style: AppTypography.font(
                        color: AppColors.textGrey,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

              // View Toggle Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SporveSegmented(
                  segments: const ['MONTH', 'WEEK', 'DAY'],
                  selected: const ['MONTH', 'WEEK', 'DAY'].indexOf(_selectedView),
                  onChanged: (i) {
                    setState(() {
                      _selectedView = const ['MONTH', 'WEEK', 'DAY'][i];
                    });
                  },
                ),
              ),
              const SizedBox(height: 24),

              // White Calendar Card
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadii.card),
                ),
                child: Column(
                  children: [
                    // Month/Week/Day Navigation Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        SporveIconButton(
                          Icons.arrow_back,
                          circle: true,
                          size: 40,
                          iconSize: 16,
                          onTap: () {
                            if (_selectedView == 'MONTH') {
                              controller.prevMonth();
                            } else if (_selectedView == 'WEEK') {
                              final newDate = selectedDate.subtract(const Duration(days: 7));
                              controller.selectDate(newDate);
                            } else if (_selectedView == 'DAY') {
                              final newDate = selectedDate.subtract(const Duration(days: 1));
                              controller.selectDate(newDate);
                            }
                          },
                        ),
                        Text(
                          _formatMonthHeader(_selectedView == 'MONTH' ? currentMonth : selectedDate),
                          style: AppTypography.font(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SporveIconButton(
                          Icons.arrow_forward,
                          circle: true,
                          size: 40,
                          iconSize: 16,
                          onTap: () {
                            if (_selectedView == 'MONTH') {
                              controller.nextMonth();
                            } else if (_selectedView == 'WEEK') {
                              final newDate = selectedDate.add(const Duration(days: 7));
                              controller.selectDate(newDate);
                            } else if (_selectedView == 'DAY') {
                              final newDate = selectedDate.add(const Duration(days: 1));
                              controller.selectDate(newDate);
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    if (_selectedView == 'MONTH') ...[
                      // Weekdays Label Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'].map((day) {
                          return Expanded(
                            child: Center(
                              child: Text(
                                day,
                                style: AppTypography.font(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),

                      // Days Grid
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 8,
                          childAspectRatio: 0.85,
                        ),
                        itemCount: totalCells,
                        itemBuilder: (context, index) {
                          if (index < offset) {
                            return const SizedBox.shrink();
                          }
                          final dayNum = index - offset + 1;
                          final cellDate = DateTime(currentMonth.year, currentMonth.month, dayNum);
                          final isSelected = selectedDate.year == cellDate.year &&
                              selectedDate.month == cellDate.month &&
                              selectedDate.day == cellDate.day;
                          final hasSessions = controller.hasSessionsOnDate(cellDate);

                          return GestureDetector(
                            onTap: () => controller.selectDate(cellDate),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: isSelected ? AppColors.slateText : Colors.transparent,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    '$dayNum',
                                    style: AppTypography.font(
                                      color: isSelected ? AppColors.onSlate : AppColors.textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  width: 4,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.slateText
                                        : (hasSessions ? AppColors.slateText : Colors.transparent),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ] else if (_selectedView == 'WEEK') ...[
                      _buildWeeklyView(selectedDate, controller),
                    ] else if (_selectedView == 'DAY') ...[
                      _buildDailyView(selectedDate, controller),
                    ],
                    const SizedBox(height: 24),

                    // Selected Date Panel
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        color: AppColors.surface2,
                        borderRadius: BorderRadius.circular(AppRadii.tile),
                      ),
                      width: double.infinity,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SELECTED DATE',
                            style: AppTypography.font(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatFullDate(selectedDate),
                            style: AppTypography.font(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Pending Requests Section
              if (pendingRequests.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Text(
                    'SESSION REQUESTS (${pendingRequests.length})',
                    style: AppTypography.font(
                      color: AppColors.textGrey,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: pendingRequests.length,
                  itemBuilder: (context, index) {
                    final session = pendingRequests[index];
                    return _buildPendingRequestCard(context, session);
                  },
                ),
                const SizedBox(height: 16),
              ],

              // Confirmed Sessions Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Text(
                  'CONFIRMED SESSIONS (${confirmedSessions.length})',
                  style: AppTypography.font(
                    color: AppColors.textGrey,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              confirmedSessions.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      child: Center(
                        child: Text(
                          'No confirmed sessions for this date.',
                          style: AppTypography.font(color: AppColors.textGrey, fontSize: 13),
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: confirmedSessions.length,
                      itemBuilder: (context, index) {
                        final session = confirmedSessions[index];
                        return _buildConfirmedSessionCard(session);
                      },
                    ),

              const SizedBox(height: 120), // Spacing for bottom nav bar overlay
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPendingRequestCard(BuildContext context, ScheduledSession session) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.hairlineSoft),
      ),
      child: Column(
        children: [
          Row(
            children: [
              ClipOval(
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: SporveImage(
                    session.userAvatar,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    fallbackIcon: Icons.person,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.userName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.font(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      session.serviceTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.font(
                        color: AppColors.textGrey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Date & Time display container
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(AppRadii.tile),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DATE & TIME',
                  style: AppTypography.font(
                    color: AppColors.textGrey,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${session.sessionDate.year}-${session.sessionDate.month.toString().padLeft(2, '0')}-${session.sessionDate.day.toString().padLeft(2, '0')} • ${session.timeStr}',
                  style: AppTypography.font(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: SporveButton(
                  'Confirm',
                  onPressed: () {
                    context.read<ProviderController>().confirmSession(session.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Confirmed session for ${session.userName}')),
                    );
                  },
                  variant: SporveButtonVariant.primary,
                  size: SporveButtonSize.compact,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SporveButton(
                  'Decline',
                  onPressed: () {
                    context.read<ProviderController>().declineSession(session.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Declined request from ${session.userName}')),
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

  Widget _buildConfirmedSessionCard(ScheduledSession session) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Column(
        children: [
          Row(
            children: [
              ClipOval(
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: SporveImage(
                    session.userAvatar,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    fallbackIcon: Icons.person,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.userName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.font(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      session.serviceTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.font(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.slateTint,
                  borderRadius: BorderRadius.circular(AppRadii.chip),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check, color: AppColors.slateDeep, size: 10),
                    const SizedBox(width: 4),
                    Text(
                      'CONFIRMED',
                      style: AppTypography.font(
                        color: AppColors.slateDeep,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Date & Time display container
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(AppRadii.tile),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DATE & TIME',
                  style: AppTypography.font(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${session.sessionDate.year}-${session.sessionDate.month.toString().padLeft(2, '0')}-${session.sessionDate.day.toString().padLeft(2, '0')} • ${session.timeStr}',
                  style: AppTypography.font(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<DateTime> _getDaysInWeek(DateTime date) {
    int daysFromSunday = date.weekday == 7 ? 0 : date.weekday;
    DateTime sunday = date.subtract(Duration(days: daysFromSunday));
    return List.generate(7, (index) => sunday.add(Duration(days: index)));
  }

  List<DateTime> _getDaysAround(DateTime date) {
    return List.generate(5, (index) => date.add(Duration(days: index - 2)));
  }

  Widget _buildWeeklyView(DateTime selectedDate, ProviderController controller) {
    final daysOfWeek = _getDaysInWeek(selectedDate);
    final shortWeekdays = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];
    
    return Column(
      children: [
        // Weekday labels
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(7, (index) {
            return Expanded(
              child: Center(
                child: Text(
                  shortWeekdays[index],
                  style: AppTypography.font(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 16),
        // Day numbers
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: daysOfWeek.map((cellDate) {
            final isSelected = selectedDate.year == cellDate.year &&
                selectedDate.month == cellDate.month &&
                selectedDate.day == cellDate.day;
            final hasSessions = controller.hasSessionsOnDate(cellDate);
            final dayNum = cellDate.day;
            
            return Expanded(
              child: GestureDetector(
                onTap: () => controller.selectDate(cellDate),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.slateText : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$dayNum',
                        style: AppTypography.font(
                          color: isSelected ? AppColors.onSlate : AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.slateText
                            : (hasSessions ? AppColors.slateText : Colors.transparent),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDailyView(DateTime selectedDate, ProviderController controller) {
    final daysAround = _getDaysAround(selectedDate);
    final shortWeekdays = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: daysAround.map((cellDate) {
        final isSelected = selectedDate.year == cellDate.year &&
            selectedDate.month == cellDate.month &&
            selectedDate.day == cellDate.day;
        final hasSessions = controller.hasSessionsOnDate(cellDate);
        final dayNum = cellDate.day;
        final weekdayStr = shortWeekdays[cellDate.weekday == 7 ? 0 : cellDate.weekday];

        return Expanded(
          child: GestureDetector(
            onTap: () => controller.selectDate(cellDate),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  weekdayStr,
                  style: AppTypography.font(
                    color: isSelected ? AppColors.slateText : AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.slateText : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$dayNum',
                    style: AppTypography.font(
                      color: isSelected ? AppColors.onSlate : AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.slateText
                        : (hasSessions ? AppColors.slateText : Colors.transparent),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
