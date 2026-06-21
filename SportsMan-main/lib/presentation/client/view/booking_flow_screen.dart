import 'package:flutter/material.dart';
import 'package:flutter_structure/core/theme/app_typography.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/sport_colors.dart';
import '../controllers/home_controller.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/sporve_button.dart';

class BookingFlowScreen extends StatefulWidget {
  const BookingFlowScreen({super.key});

  @override
  State<BookingFlowScreen> createState() => _BookingFlowScreenState();
}

class _BookingFlowScreenState extends State<BookingFlowScreen> {
  int _currentStep = 1; // Step 1: Book Slot, Step 2: Review & Pay, Step 3: Getting Ready, Step 4: Confirmed
  int _selectedDay = 4;
  String _selectedTime = '10:30 AM';
  // Demo payment methods (local screen state only — no real Stripe).
  final List<Map<String, String>> _cards = [
    {'brand': 'Visa', 'last4': '4242'},
  ];
  int _selectedCardIndex = 0;
  bool _bookingSaved = false; // guard against double-persist

  // Calendar shows the real current month.
  late int _calYear;
  late int _calMonth;

  static const List<String> _monthNames = [
    'JANUARY', 'FEBRUARY', 'MARCH', 'APRIL', 'MAY', 'JUNE',
    'JULY', 'AUGUST', 'SEPTEMBER', 'OCTOBER', 'NOVEMBER', 'DECEMBER',
  ];
  static const List<String> _weekdayNames = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
  ];

  int get _daysInMonth => DateTime(_calYear, _calMonth + 1, 0).day;
  // Sunday-first offset: how many blank cells before day 1.
  int get _leadingBlanks => DateTime(_calYear, _calMonth, 1).weekday % 7;

  // e.g. "Wednesday, Jun 18" for the selected date.
  String get _selectedDateLabel {
    final d = DateTime(_calYear, _calMonth, _selectedDay);
    final weekday = _weekdayNames[d.weekday - 1];
    final month = _monthNames[_calMonth - 1];
    final monthShort = (month[0] + month.substring(1).toLowerCase()).substring(0, 3);
    return '$weekday, $monthShort $_selectedDay';
  }

  // The full weekday name of the currently selected booking date.
  String get _selectedWeekday =>
      _weekdayNames[DateTime(_calYear, _calMonth, _selectedDay).weekday - 1];

  // ── Month navigation ────────────────────────────────────────────────────
  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _calYear == now.year && _calMonth == now.month;
  }

  void _prevMonth() {
    if (_isCurrentMonth) return; // never go before this month
    setState(() {
      if (_calMonth == 1) {
        _calMonth = 12;
        _calYear--;
      } else {
        _calMonth--;
      }
      _clampSelectedDay();
    });
  }

  void _nextMonth() {
    setState(() {
      if (_calMonth == 12) {
        _calMonth = 1;
        _calYear++;
      } else {
        _calMonth++;
      }
      _clampSelectedDay();
    });
  }

  // Keep _selectedDay valid for the visible month: not before today in the
  // current month, and not past the month's last day.
  void _clampSelectedDay() {
    final now = DateTime.now();
    final firstSelectable = _isCurrentMonth ? now.day : 1;
    final lastDay = _daysInMonth;
    if (_selectedDay < firstSelectable) _selectedDay = firstSelectable;
    if (_selectedDay > lastDay) _selectedDay = lastDay;
  }

  // Booking context passed from the session-details screen.
  Map<String, dynamic>? _program;
  String _sessionTitle = 'Training Session';
  String _coach = 'Academy';
  String _tier = 'STANDARD';

  // Sport identity of the booked program — themes the primary CTAs + selections.
  String get _sport => (_program?['sportType'] ?? 'basketball').toString();
  Color get _sportColor => SportColors.of(_sport);

  // Pricing — provider-set price from the selected tier (falls back to 75).
  late double _sessionPrice;
  double get _serviceFee => _sessionPrice * 0.05;
  double get _total => _sessionPrice + _serviceFee;
  String _money(double v) => '\$${v.toStringAsFixed(2)}';

  // The booked start as a real DateTime (selected date + parsed 12h time).
  DateTime _bookingStart() {
    final m = RegExp(r'(\d{1,2}):(\d{2})\s*([AaPp][Mm])?').firstMatch(_selectedTime);
    int hour = 9, minute = 0;
    if (m != null) {
      hour = int.tryParse(m.group(1)!) ?? 9;
      minute = int.tryParse(m.group(2)!) ?? 0;
      final period = m.group(3)?.toUpperCase();
      if (period == 'PM' && hour != 12) hour += 12;
      if (period == 'AM' && hour == 12) hour = 0;
    }
    return DateTime(_calYear, _calMonth, _selectedDay, hour, minute);
  }

  // Opens a Google Calendar event template (HTTPS — no platform scheme config).
  Future<void> _addToCalendar() async {
    final start = _bookingStart();
    final end = start.add(const Duration(hours: 1));
    String fmt(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}${d.month.toString().padLeft(2, '0')}'
        '${d.day.toString().padLeft(2, '0')}T${d.hour.toString().padLeft(2, '0')}'
        '${d.minute.toString().padLeft(2, '0')}00';

    String location = '';
    final address = _program?['address'];
    if (address is Map) {
      location = [address['line1'], address['city'], address['state']]
          .where((p) => p != null && p.toString().trim().isNotEmpty)
          .join(', ');
    }

    final url = Uri.parse(
      'https://calendar.google.com/calendar/render?action=TEMPLATE'
      '&text=${Uri.encodeComponent(_sessionTitle)}'
      '&dates=${fmt(start)}/${fmt(end)}'
      '&details=${Uri.encodeComponent('Booked via Sporve')}'
      '${location.isNotEmpty ? '&location=${Uri.encodeComponent(location)}' : ''}',
    );
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  // Styled input matching the Step 1 notes field (surface2 fill inside the sheet).
  Widget _cardField({
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    bool obscure = false,
    void Function(String)? onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      onChanged: onChanged,
      style: AppTypography.font(color: AppColors.textPrimary, fontSize: 14),
      cursorColor: AppColors.slateText,
      decoration: InputDecoration(
        hintText: hint,
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
    );
  }

  // Demo "add card" sheet — collects a number/expiry/CVC, stores a masked card.
  // No Stripe, no real validation (expiry/CVC are cosmetic).
  Future<void> _openAddCardSheet() async {
    final numberCtrl = TextEditingController();
    final expiryCtrl = TextEditingController();
    final cvcCtrl = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheet) {
            final digits = numberCtrl.text.replaceAll(RegExp(r'\D'), '');
            final canAdd = digits.length >= 4;
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
                      'Add card',
                      style: AppTypography.font(
                        color: AppColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _cardField(
                      controller: numberCtrl,
                      hint: 'Card number',
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setSheet(() {}),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _cardField(
                            controller: expiryCtrl,
                            hint: 'MM/YY',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _cardField(
                            controller: cvcCtrl,
                            hint: 'CVC',
                            keyboardType: TextInputType.number,
                            obscure: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SporveButton(
                      'Add card',
                      onPressed: canAdd
                          ? () {
                              final d = numberCtrl.text.replaceAll(RegExp(r'\D'), '');
                              final last4 = d.length >= 4 ? d.substring(d.length - 4) : d;
                              final brand = d.isEmpty
                                  ? 'Card'
                                  : d[0] == '4'
                                      ? 'Visa'
                                      : d[0] == '5'
                                          ? 'Mastercard'
                                          : d[0] == '3'
                                              ? 'Amex'
                                              : 'Card';
                              setState(() {
                                _cards.add({'brand': brand, 'last4': last4});
                                _selectedCardIndex = _cards.length - 1;
                              });
                              Navigator.pop(sheetCtx);
                            }
                          : null,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    numberCtrl.dispose();
    expiryCtrl.dispose();
    cvcCtrl.dispose();
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _calYear = now.year;
    _calMonth = now.month;
    _selectedDay = now.day;

    final args = Get.arguments;
    if (args is Map) {
      _program = args['program'] is Map
          ? Map<String, dynamic>.from(args['program'])
          : null;
      _sessionTitle = (args['title'] ?? _program?['title'] ?? _sessionTitle).toString();
      _coach = (args['coach'] ?? _coach).toString();
      _tier = (args['tier'] ?? _tier).toString();
      _sessionPrice = (args['price'] is num) ? (args['price'] as num).toDouble() : 75.0;
    } else {
      _sessionPrice = 75.0;
    }
  }

  // Build a booking from the user's selections and persist it so it appears on
  // Home "Coming Up" and the Schedule calendar.
  void _persistBooking() {
    if (_bookingSaved) return;
    _bookingSaved = true;

    final now = DateTime.now();
    // The calendar shows the real current month, so use the selected date directly.
    final isoDate =
        '${_calYear.toString().padLeft(4, '0')}-${_calMonth.toString().padLeft(2, '0')}-${_selectedDay.toString().padLeft(2, '0')}T00:00:00.000Z';

    final session = {
      '_id': 'sess_${now.millisecondsSinceEpoch}',
      'title': _sessionTitle,
      'startDate': isoDate,
      'date': isoDate,
      'startTime': _selectedTime,
      'programId': _program?['_id'],
    };

    final booking = <String, dynamic>{
      '_id': 'book_${now.millisecondsSinceEpoch}',
      'searcherId': 'user_123',
      'programId': _program, // full object so Home/Schedule resolve sport + coach
      'sessionId': session,
      'selectedTier': _tier,
      'originalPrice': _sessionPrice,
      'finalPrice': _total,
      'currency': 'USD',
      'status': 'confirmed',
      'paymentStatus': 'paid',
      'createdAt': now.toIso8601String(),
    };

    context.read<HomeProvider>().addBooking(booking);
  }

  final List<String> _timeSlots = [
    '09:00 AM',
    '10:30 AM',
    '11:30 AM',
    '12:00 PM',
    '01:00 PM',
    '02:30 PM',
    '04:00 PM',
    '05:30 PM'
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      appBar: _buildAppBar(),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _buildCurrentStepView(),
      ),
    );
  }

  PreferredSizeWidget? _buildAppBar() {
    if (_currentStep == 3) {
      // Step 3 has custom close button / back button
      return AppBar(
        backgroundColor: AppColors.ink,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: SporveIconButton(
            Icons.arrow_back,
            onTap: () {
              setState(() {
                _currentStep = 2;
              });
            },
          ),
        ),
      );
    }
    if (_currentStep == 4) {
      // Step 4 has close button on right
      return AppBar(
        backgroundColor: AppColors.ink,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          SporveIconButton(
            Icons.close,
            onTap: () => Get.offAllNamed(AppRoutes.mainNav),
            color: AppColors.negative,
          ),
          const SizedBox(width: 16),
        ],
      );
    }

    // Step 1 and Step 2 AppBar
    return AppBar(
      backgroundColor: AppColors.ink,
      elevation: 0,
      leading: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: SporveIconButton(
          Icons.arrow_back,
          onTap: () {
            if (_currentStep == 2) {
              setState(() {
                _currentStep = 1;
              });
            } else {
              Get.back();
            }
          },
        ),
      ),
      title: Text(
        'STEP $_currentStep OF 2',
        style: AppTypography.font(
          color: AppColors.textTertiary,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
      centerTitle: true,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          color: AppColors.hairline,
          height: 1,
        ),
      ),
    );
  }

  Widget _buildCurrentStepView() {
    switch (_currentStep) {
      case 1:
        return _buildStep1BookSlot();
      case 2:
        return _buildStep2ReviewAndPay();
      case 3:
        return _buildStep3GettingReady();
      case 4:
        return _buildStep4Confirmed();
      default:
        return const SizedBox.shrink();
    }
  }

  // --- STEP 1: BOOK SLOT ---
  Widget _buildStep1BookSlot() {
    return Column(
      key: const ValueKey(1),
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Book Slot',
                  style: AppTypography.font(
                    color: AppColors.textPrimary,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                // Month header with prev/next navigation. Prev is disabled +
                // dimmed in the current month so users can't book in the past.
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SporveIconButton(
                      Icons.arrow_back,
                      iconSize: 16,
                      onTap: _isCurrentMonth ? null : _prevMonth,
                      color: _isCurrentMonth ? AppColors.textTertiary : AppColors.textPrimary,
                    ),
                    Text(
                      '${_monthNames[_calMonth - 1]} $_calYear',
                      style: AppTypography.font(
                        color: AppColors.textTertiary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    SporveIconButton(
                      Icons.arrow_forward,
                      iconSize: 16,
                      onTap: _nextMonth,
                      color: AppColors.textPrimary,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Calendar Weekday Headers
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: ['S', 'M', 'T', 'W', 'T', 'F', 'S'].map((day) {
                    return SizedBox(
                      width: 40,
                      child: Text(
                        day,
                        textAlign: TextAlign.center,
                        style: AppTypography.font(
                          color: AppColors.textTertiary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                
                // Calendar Days Grid
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                  ),
                  itemCount: _leadingBlanks + _daysInMonth,
                  itemBuilder: (context, index) {
                    // Leading blank cells to align day 1 to the right weekday.
                    if (index < _leadingBlanks) return const SizedBox.shrink();
                    final day = index - _leadingBlanks + 1;
                    final now = DateTime.now();
                    final isPast = _calYear == now.year &&
                        _calMonth == now.month &&
                        day < now.day;
                    final isSelected = _selectedDay == day;
                    return GestureDetector(
                      onTap: isPast
                          ? null
                          : () {
                              setState(() {
                                _selectedDay = day;
                              });
                            },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        decoration: BoxDecoration(
                          color: isSelected ? _sportColor : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$day',
                          style: AppTypography.font(
                            color: isPast
                                ? AppColors.textTertiary
                                : (isSelected ? AppColors.onSlate : AppColors.textPrimary),
                            fontSize: 14,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                
                const SizedBox(height: 32),
                
                Text(
                  'AVAILABLE TIMES',
                  style: AppTypography.font(
                    color: AppColors.textTertiary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Time slots grid
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 2.2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                  ),
                  itemCount: _timeSlots.length,
                  itemBuilder: (context, index) {
                    final slot = _timeSlots[index];
                    final isSelected = _selectedTime == slot;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedTime = slot;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        decoration: BoxDecoration(
                          color: isSelected ? _sportColor : AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadii.tile),
                          border: Border.all(color: isSelected ? Colors.transparent : AppColors.hairline),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          slot,
                          style: AppTypography.font(
                            color: isSelected ? AppColors.onSlate : AppColors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                
                const SizedBox(height: 32),
                
                Text(
                  'NOTES (OPTIONAL)',
                  style: AppTypography.font(
                    color: AppColors.textTertiary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 12),

                // Notes Input Box
                TextField(
                  maxLines: 3,
                  style: AppTypography.font(color: AppColors.textPrimary, fontSize: 13),
                  cursorColor: AppColors.slateText,
                  decoration: InputDecoration(
                    hintText: 'Any goals, injuries, or special requests...',
                    hintStyle: AppTypography.font(color: AppColors.textTertiary, fontSize: 13),
                    filled: true,
                    fillColor: AppColors.surface,
                    contentPadding: const EdgeInsets.all(16),
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
              ],
            ),
          ),
        ),
        
        // Step 1 Footer Row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: const BoxDecoration(
            color: AppColors.ink,
            border: Border(
              top: BorderSide(color: AppColors.hairline, width: 1),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _money(_sessionPrice),
                      style: AppTypography.font(
                        color: AppColors.textPrimary,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '60 MIN',
                      style: AppTypography.font(
                        color: AppColors.textTertiary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: SporveButton(
                    'Continue',
                    variant: SporveButtonVariant.primary,
                    color: _sportColor,
                    onPressed: () {
                      setState(() {
                        _currentStep = 2;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- STEP 2: REVIEW & PAY ---
  Widget _buildStep2ReviewAndPay() {
    return Column(
      key: const ValueKey(2),
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Review & Pay',
                  style: AppTypography.font(
                    color: AppColors.textPrimary,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),

                // Details Card
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadii.card),
                    border: Border.all(color: AppColors.hairline),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Date & Time Row
                      Row(
                        children: [
                          Container(
                            height: 44,
                            width: 44,
                            decoration: BoxDecoration(
                              color: AppColors.surface2,
                              borderRadius: BorderRadius.circular(AppRadii.tile),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(Icons.calendar_today, color: AppColors.slateText, size: 20),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'DATE & TIME',
                                  style: AppTypography.font(
                                    color: AppColors.textTertiary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$_selectedDateLabel at $_selectedTime',
                                  style: AppTypography.font(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Divider(color: AppColors.hairline, height: 1),
                      ),
                      
                      // Session Row
                      Row(
                        children: [
                          Container(
                            height: 44,
                            width: 44,
                            decoration: BoxDecoration(
                              color: AppColors.surface2,
                              borderRadius: BorderRadius.circular(AppRadii.tile),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(Icons.emoji_events, color: AppColors.slateText, size: 20),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'SESSION',
                                  style: AppTypography.font(
                                    color: AppColors.textTertiary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _sessionTitle,
                                  style: AppTypography.font(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                
                Text(
                  'SELECT PAYMENT METHOD',
                  style: AppTypography.font(
                    color: AppColors.textTertiary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 16),

                // Saved cards (real list — tap to select)
                ...List.generate(_cards.length, (i) {
                  final card = _cards[i];
                  final selected = _selectedCardIndex == i;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedCardIndex = i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadii.card),
                          border: Border.all(
                            color: selected ? _sportColor : AppColors.hairline,
                            width: 2,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.credit_card, color: AppColors.slateText, size: 24),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '•••• ${card['last4']}',
                                    style: AppTypography.font(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    card['brand'] ?? 'Card',
                                    style: AppTypography.font(
                                      color: AppColors.textTertiary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (selected)
                              Container(
                                height: 18,
                                width: 18,
                                decoration: BoxDecoration(
                                  color: _sportColor,
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: const Icon(Icons.check, color: AppColors.onSlate, size: 10),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),

                // Add New Payment Option — opens the add-card sheet
                GestureDetector(
                  onTap: _openAddCardSheet,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadii.card),
                      border: Border.all(color: AppColors.hairline, width: 2),
                    ),
                    child: Row(
                      children: [
                        Container(
                          height: 24,
                          width: 24,
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.hairline, width: 1.5),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: const Icon(Icons.add, color: AppColors.textSecondary, size: 14),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            'Add new payment method',
                            style: AppTypography.font(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: AppColors.textTertiary, size: 16),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),
                
                // Secured by Stripe pad banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.slateTint,
                    borderRadius: BorderRadius.circular(AppRadii.tile),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lock, color: AppColors.slateText, size: 18),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Price guaranteed — what you see is what you pay. Secured by Stripe.',
                          style: AppTypography.font(
                            color: AppColors.slateText,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // Step 2 Footer button
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: const BoxDecoration(
            color: AppColors.ink,
            border: Border(
              top: BorderSide(color: AppColors.hairline, width: 1),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SporveButton(
              'Confirm & Pay ${_money(_total)}',
              variant: SporveButtonVariant.primary,
              color: _sportColor,
              icon: Icons.lock_outline,
              onPressed: () {
                _persistBooking();
                setState(() {
                  _currentStep = 3;
                });
                // Automatically transition to step 4 after 3 seconds for beautiful demo effect!
                Future.delayed(const Duration(seconds: 3), () {
                  if (mounted && _currentStep == 3) {
                    setState(() {
                      _currentStep = 4;
                    });
                  }
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  // --- STEP 3: GETTING READY LOADER ---
  Widget _buildStep3GettingReady() {
    return Container(
      key: const ValueKey(3),
      width: double.infinity,
      color: AppColors.ink,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Circular progress ring spinner
          const SizedBox(
            height: 60,
            width: 60,
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.slateText),
              strokeWidth: 4.5,
            ),
          ),
          const SizedBox(height: 32),

          Text(
            'GETTING YOU READY',
            style: AppTypography.font(
              color: AppColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),

          Text(
            'PERSONALIZING YOUR SESSION',
            style: AppTypography.font(
              color: AppColors.textTertiary,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 48),

          // Coach message box card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadii.card),
              border: Border.all(color: AppColors.hairline),
            ),
            child: Text(
              '"Arrive 10 minutes early to warm up and prepare mentally."',
              textAlign: TextAlign.center,
              style: AppTypography.font(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.bold,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- STEP 4: CONFIRMED SCREEN ---
  Widget _buildStep4Confirmed() {
    return Container(
      key: const ValueKey(4),
      width: double.infinity,
      color: AppColors.ink,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const Spacer(),

          // Large Check Icon
          Container(
            height: 72,
            width: 72,
            decoration: const BoxDecoration(
              color: AppColors.slateText,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.check, color: AppColors.onSlate, size: 36),
          ),
          const SizedBox(height: 32),

          Text(
            'Confirmed.',
            style: AppTypography.font(
              color: AppColors.textPrimary,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // Locked Info Text
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: AppTypography.font(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.4,
              ),
              children: [
                const TextSpan(text: 'Your slot is locked for '),
                TextSpan(
                  text: _selectedWeekday,
                  style: AppTypography.font(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const TextSpan(text: ' at '),
                TextSpan(
                  text: _selectedTime,
                  style: AppTypography.font(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const TextSpan(text: '.'),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Charged Card Info
          Text(
            '${_money(_total)} charged to •••• ${_cards[_selectedCardIndex]['last4']}',
            style: AppTypography.font(
              color: AppColors.slateText,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),

          const Spacer(),

          // Confirmed Page Buttons
          SporveButton(
            'Back to Home',
            variant: SporveButtonVariant.primary,
            onPressed: () => Get.offAllNamed(AppRoutes.mainNav),
          ),
          const SizedBox(height: 12),
          SporveButton(
            'Add to Calendar',
            variant: SporveButtonVariant.secondary,
            icon: Icons.calendar_today_outlined,
            onPressed: _addToCalendar,
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }
}
