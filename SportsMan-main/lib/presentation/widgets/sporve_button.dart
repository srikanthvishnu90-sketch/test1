import 'package:flutter/material.dart';
import 'package:flutter_structure/core/theme/app_typography.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';

/// Visual role of a button. Color encodes importance consistently app-wide.
enum SporveButtonVariant {
  /// Main action — solid deep-slate (or sport color), white text. One per screen.
  primary,

  /// Secondary on the dark canvas — transparent + hairline border.
  dark,

  /// White pill with dark text — entry-wall social/login buttons.
  white,

  /// Lower-emphasis filled — subtle surface fill.
  secondary,

  /// Lowest-emphasis — text only.
  tertiary,

  /// Destructive — ghost (muted-red text, no fill).
  destructive,
}

enum SporveButtonSize { large, compact }

/// The single button used across Sporve — Uber/Kalshi register: tall, tight
/// radius (8), restrained 15px/600 label, flat (no shadow), with a subtle
/// press-scale for a premium tactile feel. Route EVERY CTA through this so the
/// whole app's buttons look and feel identical.
class SporveButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final SporveButtonVariant variant;
  final SporveButtonSize size;
  final IconData? icon;

  /// Custom leading widget (e.g. a brand SVG logo). Takes priority over [icon].
  final Widget? leadingWidget;

  final bool loading;
  final bool fullWidth;

  /// For [secondary]/[tertiary] on dark backgrounds — picks light text/border.
  final bool onDark;

  /// Optional accent override for the [primary] variant — pass a sport color to
  /// theme the CTA to the current sport's content (text color auto-contrasts).
  final Color? color;

  const SporveButton(
    this.label, {
    super.key,
    required this.onPressed,
    this.variant = SporveButtonVariant.primary,
    this.size = SporveButtonSize.large,
    this.icon,
    this.leadingWidget,
    this.loading = false,
    this.fullWidth = true,
    this.onDark = false,
    this.color,
  });

  @override
  State<SporveButton> createState() => _SporveButtonState();
}

class _SporveButtonState extends State<SporveButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final bool isLarge = widget.size == SporveButtonSize.large;
    final double height = isLarge ? 52 : 44;
    final double fontSize = isLarge ? 15 : 14;
    final EdgeInsets pad = EdgeInsets.symmetric(horizontal: isLarge ? 20 : 16);
    final bool disabled = widget.onPressed == null || widget.loading;

    // Tight tile radius everywhere except the entry-wall white pill (999).
    final double radius =
        widget.variant == SporveButtonVariant.white ? AppRadii.pill : AppRadii.tile;

    Color bg;
    Color fg;
    BorderSide side = BorderSide.none;
    switch (widget.variant) {
      case SporveButtonVariant.primary:
        bg = widget.color ?? AppColors.slate;
        // White on the deep slate / dark sports; dark ink on light sports.
        fg = bg.computeLuminance() < 0.28 ? AppColors.onSlate : AppColors.inkOnSlate;
        break;
      case SporveButtonVariant.dark:
        bg = Colors.transparent;
        fg = AppColors.textPrimary;
        side = const BorderSide(color: AppColors.hairline, width: 1);
        break;
      case SporveButtonVariant.white:
        bg = Colors.white;
        fg = AppColors.inkOnSlate;
        break;
      case SporveButtonVariant.destructive:
        // Destructive (Sign out / Delete / Remove) is the ONLY red in the app.
        bg = Colors.transparent;
        fg = AppColors.destructiveRed;
        break;
      case SporveButtonVariant.secondary:
        bg = widget.onDark
            ? AppColors.surface2
            : AppColors.inkOnSlate.withOpacity(0.16);
        fg = widget.onDark ? AppColors.textPrimary : AppColors.inkOnSlate;
        break;
      case SporveButtonVariant.tertiary:
        bg = Colors.transparent;
        fg = widget.onDark ? AppColors.slateText : AppColors.inkOnSlate;
        break;
    }

    final textStyle = AppTypography.font(
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.1,
      color: fg,
    );

    final Widget child = widget.loading
        ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(fg),
            ),
          )
        : Row(
            mainAxisSize: widget.fullWidth ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.leadingWidget != null) ...[
                widget.leadingWidget!,
                const SizedBox(width: 10),
              ] else if (widget.icon != null) ...[
                Icon(widget.icon, size: 18, color: fg),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  widget.label,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: textStyle,
                ),
              ),
            ],
          );

    final style = ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled) ? bg.withOpacity(0.45) : bg,
      ),
      foregroundColor: WidgetStateProperty.all(fg),
      overlayColor: WidgetStateProperty.all(fg.withOpacity(0.10)),
      side: side == BorderSide.none
          ? null
          : WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.disabled)
                  ? side.copyWith(color: side.color.withOpacity(0.4))
                  : side,
            ),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
      ),
      elevation: WidgetStateProperty.all(0),
      padding: WidgetStateProperty.all(pad),
      minimumSize: WidgetStateProperty.all(Size(widget.fullWidth ? double.infinity : 0, height)),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );

    final button = TextButton(
      onPressed: disabled ? null : widget.onPressed,
      style: style,
      child: child,
    );

    // Subtle press-scale (Uber-style) layered over the Material ripple.
    return Listener(
      onPointerDown: disabled ? null : (_) => setState(() => _pressed = true),
      onPointerUp: disabled ? null : (_) => setState(() => _pressed = false),
      onPointerCancel: disabled ? null : (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: SizedBox(
          width: widget.fullWidth ? double.infinity : null,
          height: height,
          child: button,
        ),
      ),
    );
  }
}
