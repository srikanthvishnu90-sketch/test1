import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_typography.dart';
import '../../widgets/sporve_button.dart';
import '../controllers/home_controller.dart';

/// Opens the "Add a child" sheet. Returns true if a child was added.
Future<bool> showAddChildSheet(BuildContext context) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
      ),
      child: const _AddChildSheet(),
    ),
  );
  return result ?? false;
}

class _AddChildSheet extends StatefulWidget {
  const _AddChildSheet();

  @override
  State<_AddChildSheet> createState() => _AddChildSheetState();
}

class _AddChildSheetState extends State<_AddChildSheet> {
  final _first = TextEditingController();
  final _last = TextEditingController();
  DateTime? _dob;
  String? _gender;
  bool _saving = false;

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    super.dispose();
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(m), backgroundColor: AppColors.negative),
  );

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 10, now.month, now.day),
      firstDate: DateTime(now.year - 25),
      lastDate: now,
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _submit() async {
    final f = _first.text.trim();
    final l = _last.text.trim();
    if (f.isEmpty || l.isEmpty) {
      _snack("Enter the child's first and last name.");
      return;
    }
    setState(() => _saving = true);
    final id = await context.read<HomeProvider>().addAthlete(
      firstName: f,
      lastName: l,
      dateOfBirth: _dob?.toIso8601String(),
      gender: _gender,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (id == null) {
      _snack("Couldn't add the child. Please try again.");
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadii.card),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
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
          const SizedBox(height: 18),
          Text(
            'Add a child',
            style: AppTypography.font(
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "We'll use this to book and track their sessions.",
            style: AppTypography.font(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 20),
          _field('FIRST NAME', _first, 'Jordan'),
          const SizedBox(height: 16),
          _field('LAST NAME', _last, 'Mercer'),
          const SizedBox(height: 16),
          _label('DATE OF BIRTH (OPTIONAL)'),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _pickDob,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(AppRadii.tile),
                border: Border.all(color: AppColors.hairline),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _dob == null
                        ? 'Select date of birth'
                        : '${_dob!.year}-${_dob!.month.toString().padLeft(2, '0')}-${_dob!.day.toString().padLeft(2, '0')}',
                    style: AppTypography.font(
                      color: _dob == null
                          ? AppColors.textTertiary
                          : AppColors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                  const Icon(
                    Icons.calendar_today_outlined,
                    color: AppColors.textTertiary,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _label('GENDER (OPTIONAL)'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            children: [
              for (final g in const ['male', 'female', 'other']) _genderChip(g),
            ],
          ),
          const SizedBox(height: 24),
          SporveButton(
            _saving ? 'Adding…' : 'Add child',
            onPressed: _saving ? null : _submit,
            loading: _saving,
            variant: SporveButtonVariant.primary,
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Text(
    text,
    style: AppTypography.font(
      color: AppColors.textTertiary,
      fontSize: 11,
      fontWeight: FontWeight.bold,
      letterSpacing: 1.0,
    ),
  );

  Widget _field(String label, TextEditingController c, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        const SizedBox(height: 8),
        TextField(
          controller: c,
          style: AppTypography.font(color: AppColors.textPrimary, fontSize: 14),
          cursorColor: AppColors.slateText,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTypography.font(
              color: AppColors.textTertiary,
              fontSize: 14,
            ),
            filled: true,
            fillColor: AppColors.surface2,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.tile),
              borderSide: const BorderSide(color: AppColors.hairline),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.tile),
              borderSide: const BorderSide(color: AppColors.hairline),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.tile),
              borderSide: const BorderSide(
                color: AppColors.slateBorder,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _genderChip(String g) {
    final selected = _gender == g;
    return GestureDetector(
      onTap: () => setState(() => _gender = selected ? null : g),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.slateText : AppColors.surface2,
          borderRadius: BorderRadius.circular(AppRadii.tile),
          border: Border.all(
            color: selected ? Colors.transparent : AppColors.hairline,
          ),
        ),
        child: Text(
          g[0].toUpperCase() + g.substring(1),
          style: AppTypography.font(
            color: selected ? AppColors.onSlate : AppColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
