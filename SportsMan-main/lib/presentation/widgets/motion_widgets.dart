import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_structure/core/theme/app_typography.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/motion.dart';

/// Wraps any tappable child: scales to [Motion.pressScale] on tap-down, springs
/// back on release over [Motion.fast], and fires a selection haptic on tap. Use
/// for ALL tappable surfaces (buttons, nav items, cards, list rows) so every tap
/// in the app feels identical.
class PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;
  final bool haptics;
  final HitTestBehavior behavior;

  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.pressedScale = Motion.pressScale,
    this.haptics = true,
    this.behavior = HitTestBehavior.opaque,
  });

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _down = false;
  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: enabled ? (_) => _set(true) : null,
      onTapUp: enabled ? (_) => _set(false) : null,
      onTapCancel: enabled ? () => _set(false) : null,
      onTap: enabled
          ? () {
              if (widget.haptics) HapticFeedback.selectionClick();
              widget.onTap!();
            }
          : null,
      child: AnimatedScale(
        scale: _down ? widget.pressedScale : 1.0,
        duration: Motion.fast,
        curve: Motion.standard,
        child: widget.child,
      ),
    );
  }
}

/// A single bottom-nav item. When selected, the icon tweens up to
/// [Motion.iconActiveScale] and to the active color (near-white textPrimary),
/// the label tweens to active color + weight; unselected items are muted
/// (textTertiary). Animates over [Motion.base]. Tapping presses + haptics via
/// [PressableScale]. Designed to sit directly in a Row (returns Expanded).
class AnimatedNavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const AnimatedNavItem({
    super.key,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: PressableScale(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: TweenAnimationBuilder<double>(
            duration: Motion.base,
            curve: Motion.standard,
            tween: Tween<double>(begin: 0, end: selected ? 1 : 0),
            builder: (context, t, _) {
              final color =
                  Color.lerp(AppColors.textTertiary, AppColors.textPrimary, t)!;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Transform.scale(
                    scale: 1 + (Motion.iconActiveScale - 1) * t,
                    child: Icon(selected ? activeIcon : icon, color: color, size: 22),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    label,
                    style: AppTypography.font(
                      color: color,
                      fontSize: 10,
                      fontWeight: t > 0.5 ? FontWeight.w600 : FontWeight.w400,
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

/// An indicator (pill/underline) that ANIMATES its position between equal-width
/// tabs over [Motion.base] — never an instant jump (Kalshi category-bar feel).
/// Place it spanning the full width of a [count]-tab row; it slides to [index].
class SlidingTabIndicator extends StatelessWidget {
  final int count;
  final int index;
  final double height;
  final Color color;

  /// Horizontal inset applied inside each tab slot (controls the pill width).
  final EdgeInsets slotPadding;
  final BorderRadius? radius;

  const SlidingTabIndicator({
    super.key,
    required this.count,
    required this.index,
    required this.color,
    this.height = 3,
    this.slotPadding = EdgeInsets.zero,
    this.radius,
  });

  @override
  Widget build(BuildContext context) {
    // Map index → alignment.x in [-1, 1] for an equal-width slot layout.
    final x = count <= 1 ? 0.0 : (index / (count - 1)) * 2 - 1;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: AnimatedAlign(
        duration: Motion.base,
        curve: Motion.standard,
        alignment: Alignment(x, 0),
        child: FractionallySizedBox(
          widthFactor: 1 / count,
          child: Padding(
            padding: slotPadding,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: color,
                borderRadius: radius ?? BorderRadius.circular(height),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A lightweight pulsing placeholder block for loading states — shows instead of
/// a blank screen or an error flash until the first data load resolves.
class Skeleton extends StatefulWidget {
  final double? width;
  final double height;
  final BorderRadius? radius;
  final EdgeInsets margin;

  const Skeleton({
    super.key,
    this.width,
    required this.height,
    this.radius,
    this.margin = EdgeInsets.zero,
  });

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Motion.slow,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: widget.margin,
      child: FadeTransition(
        opacity: Tween<double>(begin: 0.45, end: 0.9).animate(
          CurvedAnimation(parent: _c, curve: Motion.standard),
        ),
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: AppColors.surface2,
            borderRadius: widget.radius ?? BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}
