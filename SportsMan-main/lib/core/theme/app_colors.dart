import 'package:flutter/material.dart';

/// Sporve color system — black canvas + teal brand + contained sport metadata.
///
/// The register is Kalshi/Robinhood: a true-black product canvas, white/gray
/// type, hairline structure, and the brand teal (`#01F1F1`) sprinkled liberally
/// but ALWAYS as a small accent on top of black/white — never as a surface fill
/// in the product layer.
///
/// The old navy palette (`navyDark`/`navyCard`/`accentBlue`/`bgGradient`...) is
/// kept ONLY as backward-compatible aliases that now point at the new system, so
/// the entire app re-skins at once. New code must use the named tokens below.
class AppColors {
  // ── Core neutrals (the 90%) ─────────────────────────────────────────────
  // Canvas is a near-black (not pure #000) to kill neon halation and soften
  // every edge — the single highest-impact "calm" change.
  static const Color ink = Color(0xFF0B0F14); // product canvas (near-black, slate-tinted)
  static const Color surface = Color(0xFF12181F); // raised surface 1
  static const Color surface2 = Color(0xFF1A222B); // raised surface 2 / pressed
  static const Color hairline = Color(0xFF283039); // divider / border (slate)
  static const Color hairlineSoft = Color(0xFF1E252D); // faint divider
  static const Color textPrimary = Color(0xFFF3F6F8); // near-white
  static const Color textSecondary = Color(0xFF9AA7B2);
  static const Color textTertiary = Color(0xFF647079); // muted
  static const Color inkOnTeal = Color(0xFF04121F); // dark text on light fills (value unchanged; renamed in 1b)

  // ── Brand ───────────────────────────────────────────────────────────────
  // The single accent is SLATE (#536878) — used for ALL chrome. (Token names
  // still teal* here; the 1b rename makes them slate*.)
  static const Color teal = Color(0xFF536878); // PRIMARY accent (slate)
  static const Color tealDeep = Color(0xFF3E4F5C); // pressed
  static const Color tealText = Color(0xFF536878); // slate accent for text/icons (active/selected use textPrimary)
  static const Color tealTint = Color(0x2E536878); // ~18% slate fill
  static const Color tealBorder = Color(0x80536878); // ~50% slate border
  static const Color tealBrand = Color(0xFF536878); // folded into slate (splash is flat slate)
  static const Color onTeal = Color(0xFFFFFFFF); // text/icons ON a slate fill
  static const Color blue = Color(0xFF2E7BFF); // secondary: AI / social only
  static const Color blueText = Color(0xFF6AA6FF); // blue text/link on black
  static const Color blueTint = Color(0x292E7BFF); // ~0.16 blue fill

  // ── Semantic (rare, always icon-paired) ─────────────────────────────────
  static const Color positive = tealText; // up / confirmed (legible on dark)
  static const Color negative = Color(0xFFD2645C); // down / error (muted red)
  static const Color warning = Color(0xFFE8A33A);
  static const Color warningTint = Color(0x24E8A33A); // ~14% amber fill
  static const Color negativeTint = Color(0x24D2645C); // ~14% muted-red fill

  /// Off-canvas letterbox behind the phone frame on desktop web.
  static const Color frame = Color(0xFF05080F);

  // ── Entry-wall gradient (Layer 1 only: splash + auth) ───────────────────
  static const LinearGradient tealWall = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF536878), Color(0xFF536878), Color(0xFF536878)],
    stops: [0.0, 0.55, 1.0],
  );

  // ── Brand gradient (logo + rare brand moments only) ─────────────────────
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF536878), Color(0xFF3E4F5C)],
  );

  // ── Backward-compatible aliases (legacy names → new system) ─────────────
  // These exist so existing screens compile and re-skin automatically. Do NOT
  // use them in new code — reach for the named tokens above instead.
  static const Color navyDark = ink; // was #0A1020 navy → true black canvas
  static const Color navyCard = surface; // was #111827 → raised dark surface
  static const Color accentBlue = teal; // was #3B82F6 blue → brand teal
  static const Color textGrey = textSecondary; // subtitles / hints
  static const Color inputFill = surface; // was light #F1F5F9 → dark surface

  /// Legacy "background gradient" — now a flat black canvas (no navy).
  static const LinearGradient bgGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [ink, ink],
  );
}
