import 'package:flutter/animation.dart';

/// Sporve motion system — the SINGLE source of truth for every micro-animation
/// in the app. No screen or widget should hardcode its own durations, curves, or
/// scales: pull them from here so the whole app shares one motion language
/// (Uber/Kalshi register — subtle, fast, consistent).
class Motion {
  Motion._();

  // ── Durations ────────────────────────────────────────────────────────────
  /// Press feedback, tiny state flips, page pushes.
  static const Duration fast = Duration(milliseconds: 120);

  /// Default for nav selection, tab indicator, most transitions.
  static const Duration base = Duration(milliseconds: 200);

  /// Larger reveals (skeleton→content, sheets).
  static const Duration slow = Duration(milliseconds: 300);

  // ── Curves ───────────────────────────────────────────────────────────────
  /// The default easing for almost everything.
  static const Curve standard = Curves.easeOutCubic;

  /// Subtle overshoot for selection/active accents (kept restrained).
  static const Curve emphasized = Curves.easeOutBack;

  // ── Scales ───────────────────────────────────────────────────────────────
  /// Tap-down scale for pressable surfaces.
  static const double pressScale = 0.97;

  /// Selected bottom-nav icon scale.
  static const double iconActiveScale = 1.12;
}
