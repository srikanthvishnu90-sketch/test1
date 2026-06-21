import 'package:flutter/material.dart';
import 'package:flutter_structure/core/theme/app_typography.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/routes/app_routes.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/sport_glyph.dart';
import '../../widgets/sporve_button.dart';
import '../controllers/home_controller.dart';
import '../../../core/utils/session_time.dart';
import 'search_screen.dart'; // Opportunity model (for Book again navigation)

class AthleteSession {
  final DateTime date;
  final String emoji;
  final String time;
  final String location;
  final String title;
  final String subtitle;
  final String? tip;
  final String? id; // booking _id (identity for rating/reviewed state)
  final Map<String, dynamic>? program; // resolved program (address/coords/etc.)

  const AthleteSession({
    required this.date,
    required this.emoji,
    required this.time,
    required this.location,
    required this.title,
    required this.subtitle,
    this.tip,
    this.id,
    this.program,
  });
}

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  String _selectedView = 'Month'; // Month, Week, Day
  DateTime _currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selectedDate = DateTime.now();

  // Tracks past sessions the user has rated (by booking id).
  final Set<String> _reviewedIds = {};

  // Only dynamic sessions now
  final List<AthleteSession> _athleteSessions = [];
  // Populated each build with athlete + booked sessions; used for calendar dots.
  List<AthleteSession> _allSessions = [];

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
    final weekdays = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    
    // Convert weekday so index 0 = Sunday, 1 = Monday, etc.
    final int dayOfWeekIndex = date.weekday == 7 ? 0 : date.weekday;
    final weekdayStr = weekdays[dayOfWeekIndex];
    
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

  // Returns a sport *name* (not an emoji). SportGlyph maps it to a line icon.
  String _getSportEmoji(String? sportType) {
    if (sportType == null) return 'running';
    return sportType;
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

  void _prevMonth() {
    setState(() {
      int prevMonth = _currentMonth.month - 1;
      int prevYear = _currentMonth.year;
      if (prevMonth == 0) {
        prevMonth = 12;
        prevYear -= 1;
      }
      _currentMonth = DateTime(prevYear, prevMonth);
    });
  }

  void _nextMonth() {
    setState(() {
      int nextMonth = _currentMonth.month + 1;
      int nextYear = _currentMonth.year;
      if (nextMonth == 13) {
        nextMonth = 1;
        nextYear += 1;
      }
      _currentMonth = DateTime(nextYear, nextMonth);
    });
  }

  @override
  Widget build(BuildContext context) {
    final homeProvider = context.watch<HomeProvider>();
    
    // Map backend bookings to AthleteSession objects
    final List<AthleteSession> dynamicSessions = homeProvider.bookings.map((booking) {
      final session = booking['sessionId'] is Map ? booking['sessionId'] : null;

      // programId may be a full object or just an id string (inconsistent mock data).
      // Resolve the full program so we never index a String with a map key.
      final rawBookingProgram = booking['programId'];
      final rawSessionProgram = session?['programId'];
      String? programId;
      if (rawBookingProgram is Map) {
        programId = rawBookingProgram['_id']?.toString();
      } else if (rawBookingProgram is String) {
        programId = rawBookingProgram;
      } else if (rawSessionProgram is Map) {
        programId = rawSessionProgram['_id']?.toString();
      } else if (rawSessionProgram is String) {
        programId = rawSessionProgram;
      }
      Map? program;
      if (programId != null) {
        for (final p in homeProvider.programs) {
          if (p is Map && p['_id']?.toString() == programId) {
            program = p;
            break;
          }
        }
      }
      program ??= rawBookingProgram is Map
          ? rawBookingProgram
          : (rawSessionProgram is Map ? rawSessionProgram : null);

      final startTime = parseSessionStart(session);
      final address = program?['address'];

      return AthleteSession(
        date: startTime,
        emoji: program != null ? _getSportEmoji(program['sportType']?.toString()) : 'running',
        time: formatTime12h(startTime),
        location: (address is Map ? address['city']?.toString() : null) ?? 'Location',
        title: program?['title']?.toString() ?? 'Session',
        subtitle: (program?['providerId'] is Map)
            ? (program!['providerId']['businessName']?.toString() ?? 'COACH')
            : 'COACH',
        id: booking['_id']?.toString(),
        program: program != null ? Map<String, dynamic>.from(program) : null,
      );
    }).toList();

    // Merge with static sessions for demo or use only dynamic
    final allSessions = [..._athleteSessions, ...dynamicSessions];
    // Cache so the calendar builder methods can show day dots for real bookings.
    _allSessions = allSessions;

    // Past sessions for the Archive & Rebook section (real data, newest first).
    final pastSessions = allSessions.where((s) => s.date.isBefore(DateTime.now())).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final daySessions = allSessions.where((s) =>
        s.date.year == _selectedDate.year &&
        s.date.month == _selectedDate.month &&
        s.date.day == _selectedDate.day).toList();

    return GradientScaffold(
      body: SafeArea(
        bottom: false,
        child: homeProvider.isLoadingBookings
            ? const Center(child: CircularProgressIndicator(color: AppColors.slateText))
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. HEADER SECTION
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Schedule',
                            style: AppTypography.font(
                              color: AppColors.textPrimary,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'UPCOMING & PAST SESSIONS',
                            style: AppTypography.font(
                              color: AppColors.textTertiary,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // ... rest of the code

              // 2. TOGGLE BAR
              _buildViewToggle(),

              const SizedBox(height: 16),

              // 3. CALENDAR CONTENT (BASED ON TOGGLE STATE)
              if (_selectedView == 'Month')
                _buildMonthCalendar()
              else if (_selectedView == 'Week')
                _buildWeekCalendar()
              else
                _buildDayHeader(),

              const SizedBox(height: 24),

              // 4. SELECTED DATE SESSIONS HEADER
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'SESSIONS ON THIS DAY (${daySessions.length})',
                  style: AppTypography.font(
                    color: AppColors.textTertiary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Sessions list
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: daySessions.isEmpty
                    ? Container(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        alignment: Alignment.center,
                        child: Text(
                          'No scheduled sessions for this date.',
                          style: AppTypography.font(color: AppColors.textSecondary, fontSize: 13),
                        ),
                      )
                    : Column(
                        children: daySessions.map((session) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _buildUpcomingCard(session),
                          );
                        }).toList(),
                      ),
              ),

              const SizedBox(height: 32),

              // 5. ARCHIVE SECTION (Rate past sessions, static consistent UI)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'ARCHIVE & REBOOK',
                  style: AppTypography.font(
                    color: AppColors.textTertiary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: pastSessions.isEmpty
                    ? Container(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        alignment: Alignment.center,
                        child: Text(
                          'No past sessions yet.',
                          style: AppTypography.font(color: AppColors.textSecondary, fontSize: 13),
                        ),
                      )
                    : Column(
                        children: [
                          _buildRebookBanner(pastSessions.first),
                          const SizedBox(height: 16),
                          ...pastSessions.map(
                            (session) => Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _buildPastSessionCard(
                                emoji: session.emoji,
                                title: session.title,
                                subtext: '${_pastLabel(session.date)} • ${session.subtitle.toUpperCase()}',
                                action: (session.id != null && _reviewedIds.contains(session.id))
                                    ? _reviewedAction()
                                    : _buildRateButton(session),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),

              const SizedBox(height: 120), // bottom space overlay
            ],
          ),
        ),
      ),
    );
  }

  // Segmented Sliding Choice Selector
  Widget _buildViewToggle() {
    const views = ['Month', 'Week', 'Day'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: SporveSegmented(
        segments: const ['MONTH', 'WEEK', 'DAY'],
        selected: views.indexOf(_selectedView),
        onChanged: (i) => setState(() => _selectedView = views[i]),
      ),
    );
  }

  // 1. Month Calendar Component (matches Provider's schedule layout)
  Widget _buildMonthCalendar() {
    int daysInMonth = _getDaysInMonth(_currentMonth.year, _currentMonth.month);
    int firstWeekday = DateTime(_currentMonth.year, _currentMonth.month, 1).weekday;
    int offset = firstWeekday == 7 ? 0 : firstWeekday;
    int totalCells = daysInMonth + offset;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        children: [
          // Navigation
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SporveIconButton(
                Icons.arrow_back,
                onTap: _prevMonth,
                size: 32,
                iconSize: 16,
              ),
              Text(
                _formatMonthHeader(_currentMonth),
                style: AppTypography.font(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SporveIconButton(
                Icons.arrow_forward,
                onTap: _nextMonth,
                size: 32,
                iconSize: 16,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // SUN-SAT weekdays title row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'].map((day) {
              return Expanded(
                child: Center(
                  child: Text(
                    day,
                    style: AppTypography.font(
                      color: AppColors.textTertiary,
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
              final cellDate = DateTime(_currentMonth.year, _currentMonth.month, dayNum);
              final isSelected = _selectedDate.year == cellDate.year &&
                  _selectedDate.month == cellDate.month &&
                  _selectedDate.day == cellDate.day;
              
              final hasSessions = _allSessions.any((s) =>
                  s.date.year == cellDate.year &&
                  s.date.month == cellDate.month &&
                  s.date.day == cellDate.day);

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedDate = cellDate;
                  });
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.slateText : Colors.transparent,
                        borderRadius: BorderRadius.circular(AppRadii.tile),
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
                    const SizedBox(height: 4),
                    if (hasSessions)
                      Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.onSlate : AppColors.slateText,
                          shape: BoxShape.circle,
                        ),
                      )
                    else
                      const SizedBox(height: 4),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          _buildSelectedDatePanel(),
        ],
      ),
    );
  }

  // 2. Week Calendar Component (horizontal single-week day chips)
  Widget _buildWeekCalendar() {
    final int difference = _selectedDate.weekday == 7 ? 0 : _selectedDate.weekday;
    final DateTime sunday = _selectedDate.subtract(Duration(days: difference));
    final List<DateTime> weekDays = List.generate(7, (i) => sunday.add(Duration(days: i)));

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: weekDays.map((date) {
              final List<String> shortDays = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];
              final String dayLabel = shortDays[date.weekday == 7 ? 0 : date.weekday];
              final bool isSelected = date.year == _selectedDate.year &&
                  date.month == _selectedDate.month &&
                  date.day == _selectedDate.day;

              final hasSessions = _allSessions.any((s) =>
                  s.date.year == date.year &&
                  s.date.month == date.month &&
                  s.date.day == date.day);

              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedDate = date;
                      _currentMonth = DateTime(date.year, date.month);
                    });
                  },
                  child: Column(
                    children: [
                      Text(
                        dayLabel,
                        style: AppTypography.font(
                          color: AppColors.textTertiary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.slateText : Colors.transparent,
                          borderRadius: BorderRadius.circular(AppRadii.tile),
                        ),
                        child: Text(
                          '${date.day}',
                          style: AppTypography.font(
                            color: isSelected ? AppColors.onSlate : AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (hasSessions)
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.onSlate : AppColors.slateText,
                            shape: BoxShape.circle,
                          ),
                        )
                      else
                        const SizedBox(height: 4),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          _buildSelectedDatePanel(),
        ],
      ),
    );
  }

  // 3. Collapsed Day View Header (collapses calendar grid entirely)
  Widget _buildDayHeader() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.hairline),
      ),
      child: _buildSelectedDatePanel(),
    );
  }

  Widget _buildSelectedDatePanel() {
    return Container(
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
              color: AppColors.textTertiary,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _formatFullDate(_selectedDate),
            style: AppTypography.font(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // FIGMA UPCOMING SESSION CARD
  Widget _buildUpcomingCard(AthleteSession session) {
    final emoji = session.emoji;
    final time = session.time;
    final location = session.location;
    final title = session.title;
    final subtitle = session.subtitle;
    final tip = session.tip;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.hairline),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row (Sport glyph & Time info)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sport glyph tile
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(AppRadii.tile),
                ),
                alignment: Alignment.center,
                child: SportGlyph(
                  emoji,
                  size: 22,
                  color: AppColors.textPrimary,
                ),
              ),
              // Time & Location
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    time,
                    style: AppTypography.font(
                      color: AppColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    location,
                    style: AppTypography.font(
                      color: AppColors.textTertiary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Session Title
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.font(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          // Coach subtitle
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.font(
              color: AppColors.textTertiary,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),

          // Optional Coach Tip Box (coach = social/relationship → blue)
          if (tip != null) ...[
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.blueTint,
                borderRadius: BorderRadius.circular(AppRadii.tile),
                border: Border.all(color: AppColors.blue.withOpacity(0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'COACH TIP',
                    style: AppTypography.font(
                      color: AppColors.blueText,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '"$tip"',
                    style: AppTypography.font(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Bottom Row (Buttons)
          Row(
            children: [
              // GET DIRECTIONS Button
              Expanded(
                child: SporveButton(
                  'Get directions',
                  onPressed: () => _openDirections(session),
                  variant: SporveButtonVariant.primary,
                ),
              ),
              const SizedBox(width: 12),
              // Message Icon Button — opens the chat with this coach/provider.
              SporveIconButton(
                Icons.chat_bubble_outline,
                onTap: () => Get.toNamed(
                  AppRoutes.chatDetails,
                  arguments: {'contactName': subtitle},
                ),
                size: 50,
                iconSize: 20,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // FIGMA REBOOK BANNER
  Widget _buildRebookBanner(AthleteSession recent) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.hairline, width: 1),
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          // Circular Clock Icon
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: AppColors.slateTint,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.history, color: AppColors.slateText, size: 22),
          ),
          const SizedBox(width: 16),
          // Banner Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ready to rebook?',
                  style: AppTypography.font(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Consistent athletes improve 40% faster. Book your next session.',
                  style: AppTypography.font(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Book Again Button
          SporveButton(
            'Book again',
            onPressed: () => _bookAgain(recent),
            variant: SporveButtonVariant.primary,
            size: SporveButtonSize.compact,
            fullWidth: false,
          ),
        ],
      ),
    );
  }

  // FIGMA PAST SESSION CARD
  // ALL-CAPS relative label for a past session date, matching the subtext style.
  String _pastLabel(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(dt.year, dt.month, dt.day);
    final days = today.difference(d).inDays;
    if (days <= 0) return 'TODAY';
    if (days == 1) return 'YESTERDAY';
    if (days < 7) return '$days DAYS AGO';
    if (days < 14) return 'LAST WEEK';
    const m = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    return '${m[dt.month - 1]} ${dt.day}';
  }

  Widget _buildPastSessionCard({
    required String emoji,
    required String title,
    required String subtext,
    required Widget action,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.hairline, width: 1),
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          // Circular Icon Box
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: AppColors.surface2,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: SportGlyph(
              emoji,
              size: 18,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 16),
          // Text Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.font(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtext,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.font(
                    color: AppColors.textTertiary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Action (button or reviewed label)
          action,
        ],
      ),
    );
  }

  Widget _buildRateButton(AthleteSession session) {
    return SporveButton(
      'Rate session',
      onPressed: () => _openRatingSheet(session),
      variant: SporveButtonVariant.primary,
      size: SporveButtonSize.compact,
      fullWidth: false,
    );
  }

  // The "REVIEWED ★★★★★" block shown once a past session has been rated.
  Widget _reviewedAction() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'REVIEWED',
          style: AppTypography.font(
            color: AppColors.textTertiary,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            5,
            (index) => const Icon(Icons.star, color: AppColors.textPrimary, size: 10),
          ),
        ),
      ],
    );
  }

  // ── Button actions ────────────────────────────────────────────────────────

  // Opens Google Maps directions to the program's address/coords, else the
  // session's location string. HTTPS URL — no platform scheme config needed.
  Future<void> _openDirections(AthleteSession session) async {
    String destination = session.location;
    final program = session.program;
    if (program != null) {
      final address = program['address'];
      if (address is Map) {
        final parts = [address['line1'], address['city'], address['state']]
            .where((p) => p != null && p.toString().trim().isNotEmpty)
            .join(', ');
        if (parts.isNotEmpty) destination = parts;
      }
      // Prefer explicit coordinates when present (GeoJSON [lng, lat]).
      final loc = program['location'];
      if (loc is Map &&
          loc['coordinates'] is List &&
          (loc['coordinates'] as List).length >= 2) {
        final coords = loc['coordinates'] as List;
        destination = '${coords[1]},${coords[0]}'; // lat,lng
      }
    }
    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(destination)}',
    );
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  // Re-book the most recent past program: open its details if we have it,
  // otherwise drop the user into discovery/search.
  void _bookAgain(AthleteSession recent) {
    final program = recent.program;
    if (program != null) {
      Get.toNamed(AppRoutes.sessionDetails, arguments: _oppFromProgram(program));
    } else {
      Get.toNamed(AppRoutes.search);
    }
  }

  Opportunity _oppFromProgram(Map<String, dynamic> program) {
    final gallery = program['gallery'];
    final image = (gallery is List && gallery.isNotEmpty)
        ? gallery.first.toString()
        : 'https://images.unsplash.com/photo-1546519638-68e109498ffc?w=500&auto=format&fit=crop&q=60';
    final provider = program['providerId'];
    final business =
        provider is Map ? (provider['businessName']?.toString() ?? 'Academy') : 'Academy';
    return Opportunity(
      id: 0,
      title: program['title']?.toString() ?? 'Program',
      coach: business,
      price: '\$${program['price'] ?? 0}',
      rating: program['averageRating']?.toString() ?? '5.0',
      image: image,
      spotsLeft: 'AVAILABLE',
      isVerified: true,
      bookingTrend: 'Trending now',
      top: 0,
      team: business,
      rawData: program,
    );
  }

  // Rating sheet: 1–5 stars + optional note. On submit, marks the session
  // reviewed so the card flips to the "REVIEWED" block.
  void _openRatingSheet(AthleteSession session) {
    int rating = 5;
    final noteCtrl = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheet) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  border: Border(top: BorderSide(color: AppColors.hairline)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.hairline,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Rate ${session.title}',
                      style: AppTypography.font(
                        color: AppColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: List.generate(5, (i) {
                        return GestureDetector(
                          onTap: () => setSheet(() => rating = i + 1),
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Icon(
                              i < rating ? Icons.star : Icons.star_border,
                              color: AppColors.textPrimary,
                              size: 36,
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: noteCtrl,
                      maxLines: 3,
                      style: AppTypography.font(color: AppColors.textPrimary, fontSize: 14),
                      cursorColor: AppColors.slateText,
                      decoration: InputDecoration(
                        hintText: 'Add a note (optional)…',
                        hintStyle: AppTypography.font(color: AppColors.textTertiary, fontSize: 14),
                        filled: true,
                        fillColor: AppColors.surface2,
                        contentPadding: const EdgeInsets.all(14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadii.tile),
                          borderSide: const BorderSide(color: AppColors.hairline, width: 1.5),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadii.tile),
                          borderSide: const BorderSide(color: AppColors.hairline, width: 1.5),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadii.tile),
                          borderSide: const BorderSide(color: AppColors.slateBorder, width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SporveButton(
                      'Submit review',
                      onPressed: () {
                        if (session.id != null) {
                          setState(() => _reviewedIds.add(session.id!));
                        }
                        Navigator.pop(sheetCtx);
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(noteCtrl.dispose);
  }
}
