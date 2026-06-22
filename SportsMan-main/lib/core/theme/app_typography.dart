import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Sporve type system — **serif headers (Fraunces) + sans body (Geist)**.
/// Headers/display/titles (≥18px) render in Fraunces for editorial warmth;
/// body, labels, and numbers stay in Geist. Hierarchy comes from size + the
/// gray ramp + ONE weight step, not from making everything bold.
///
/// Geist is a bundled variable font; we drive its weight axis with
/// [FontVariation]. Fraunces is loaded via google_fonts.
class AppTypography {
  static const String fontFamily = 'Geist';

  static TextStyle _geist({
    required double size,
    required FontWeight weight,
    required double tracking,
    double height = 1.3,
    Color? color,
  }) =>
      TextStyle(
        fontFamily: fontFamily,
        fontSize: size,
        fontWeight: weight,
        fontVariations: [FontVariation('wght', weight.value.toDouble())],
        letterSpacing: tracking,
        height: height,
        color: color,
      );

  // HEADERS use Fraunces (a serif) — family only; sizes/weights/tracking match
  // the scale they replaced. Body / labels / numbers stay Geist (sans).
  static TextStyle _serifHeader({
    required double size,
    required FontWeight weight,
    required double tracking,
    double height = 1.3,
    Color? color,
  }) =>
      GoogleFonts.fraunces(
        fontSize: size,
        fontWeight: weight,
        letterSpacing: tracking,
        height: height,
        color: color,
      );

  // ── Display & headlines (serif: Fraunces) ────────────────────────────────
  /// Splash / brand-scale numbers.
  static TextStyle get displayLarge =>
      _serifHeader(size: 30, weight: FontWeight.w600, tracking: -0.6, height: 1.05);

  /// Big screen headers / auth hero.
  static TextStyle get display =>
      _serifHeader(size: 26, weight: FontWeight.w600, tracking: -0.5, height: 1.1);

  /// Screen titles, the user's name on Home.
  static TextStyle get h1 =>
      _serifHeader(size: 22, weight: FontWeight.w600, tracking: -0.4, height: 1.15);
  static TextStyle get heading => h1; // backwards-compatible alias

  /// Card titles / section headers that need weight.
  static TextStyle get h2 =>
      _serifHeader(size: 18, weight: FontWeight.w600, tracking: -0.3, height: 1.2);

  // ── Body: regular weight does the work ───────────────────────────────────
  /// List-item titles / emphasised body.
  static TextStyle get titleMedium =>
      _geist(size: 15, weight: FontWeight.w500, tracking: -0.1, height: 1.3);

  static TextStyle get bodyLarge =>
      _geist(size: 15, weight: FontWeight.w400, tracking: 0, height: 1.5);

  static TextStyle get bodyMedium =>
      _geist(size: 13.5, weight: FontWeight.w400, tracking: 0, height: 1.5);

  static TextStyle get bodySmall =>
      _geist(size: 12.5, weight: FontWeight.w400, tracking: 0, height: 1.45);

  // ── Labels & captions: caps with a WHISPER of tracking (not airy) ────────
  /// ALL-CAPS micro labels / eyebrows.
  static TextStyle get label =>
      _geist(size: 11, weight: FontWeight.w500, tracking: 0.4, height: 1.3);

  static TextStyle get caption =>
      _geist(size: 11, weight: FontWeight.w400, tracking: 0.1, height: 1.4);

  // ── Emphasis: the ONE place bold lives ───────────────────────────────────
  static TextStyle get valueBold =>
      _geist(size: 16, weight: FontWeight.w700, tracking: -0.3, height: 1.2);

  /// Drop-in replacement for inline `AppTypography.font(...)` call sites — same
  /// named params, but renders **Geist** and enforces the "Kalshi diet"
  /// app-wide: any heavy weight (700/800/900) is capped to 600, and airy
  /// caps tracking (>0.6) is reduced to a whisper. This de-bubbles every
  /// inline text style without touching 565 call sites individually.
  static TextStyle font({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
    FontStyle? fontStyle,
    TextDecoration? decoration,
    Color? decorationColor,
    TextDecorationStyle? decorationStyle,
    double? wordSpacing,
    Color? backgroundColor,
    TextBaseline? textBaseline,
    List<Shadow>? shadows,
  }) {
    final w = _diet(fontWeight ?? FontWeight.w400);
    // Display discipline: cap oversized hardcoded headers and force tight
    // (negative) tracking on large text — the Kalshi/Uber register. Big + loose
    // is what read as "bubbly/unprofessional".
    double? size = fontSize;
    if (size != null && size > 28) size = 28; // clamp 32/36/40/48 → 28
    double? ls;
    if (size != null && size >= 20 && (letterSpacing == null || letterSpacing >= 0)) {
      ls = -0.4; // large text is always tightly tracked
    } else {
      ls = _track(letterSpacing); // collapse airy caps elsewhere
    }
    // Headers (≥18px) render in the serif (Fraunces); body/labels stay Geist.
    if (size != null && size >= 18) {
      return GoogleFonts.fraunces(
        fontSize: size,
        fontWeight: w,
        letterSpacing: ls,
        height: height,
        color: color,
        fontStyle: fontStyle,
        decoration: decoration,
        decorationColor: decorationColor,
        decorationStyle: decorationStyle,
        wordSpacing: wordSpacing,
        backgroundColor: backgroundColor,
        textBaseline: textBaseline,
        shadows: shadows,
      );
    }
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: size,
      fontWeight: w,
      fontVariations: [FontVariation('wght', w.value.toDouble())],
      letterSpacing: ls,
      height: height,
      color: color,
      fontStyle: fontStyle,
      decoration: decoration,
      decorationColor: decorationColor,
      decorationStyle: decorationStyle,
      wordSpacing: wordSpacing,
      backgroundColor: backgroundColor,
      textBaseline: textBaseline,
      shadows: shadows,
    );
  }

  /// Weight diet: 700/800/900 → 600; lighter weights unchanged.
  static FontWeight _diet(FontWeight w) =>
      w.value >= FontWeight.w700.value ? FontWeight.w600 : w;

  /// Tracking diet: collapse airy caps spacing to a whisper.
  static double? _track(double? ls) => (ls != null && ls > 0.6) ? 0.4 : ls;

  // Numbers stay in the BODY font (Geist) — no mono/JetBrains anywhere.
  // (Kept the `mono` name so existing number call-sites need no change.)
  static TextStyle mono({
    double size = 13,
    FontWeight weight = FontWeight.w500,
    Color? color,
    double height = 1.2,
  }) =>
      TextStyle(
        fontFamily: fontFamily,
        fontSize: size,
        fontWeight: weight,
        fontVariations: [FontVariation('wght', weight.value.toDouble())],
        color: color,
        height: height,
        letterSpacing: 0,
      );
}
