import 'package:flutter/material.dart';

/// Sporve color system — black canvas + slate brand + contained sport metadata.
///
/// The register is Kalshi/Robinhood: a true-black product canvas, white/gray
/// type, hairline structure, and the brand slate `#536878` used for all chrome
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
  static const Color inkOnSlate = Color(0xFF04121F); // dark text on light fills (value unchanged; renamed in 1b)

  // ── Brand ───────────────────────────────────────────────────────────────
  // The single accent is SLATE (#536878) — used for ALL chrome.
  static const Color slate = Color(0xFF536878); // PRIMARY accent (slate)
  static const Color slateDeep = Color(0xFF3E4F5C); // pressed
  static const Color slateText = Color(0xFF536878); // slate accent for text/icons (active/selected use textPrimary)
  static const Color slateTint = Color(0x2E536878); // ~18% slate fill
  static const Color slateBorder = Color(0x80536878); // ~50% slate border
  static const Color slateBrand = Color(0xFF536878); // folded into slate (splash is flat slate)
  static const Color onSlate = Color(0xFFFFFFFF); // text/icons ON a slate fill
  // AI / social were a distinct blue; folded into slate (single accent).
  static const Color blue = Color(0xFF536878);
  static const Color blueText = Color(0xFF536878);
  static const Color blueTint = Color(0x2E536878); // ~18% slate fill

  // ── Glow (brand "lit" moments only: splash / hero / brand) ───────────────
  // Perceived glow = high LUMINANCE + CHROMA + a soft BLOOM against a dark
  // field. The muted brand slate (#536878, lum ~0.13, sat ~18%) is matte BY
  // DESIGN and cannot glow — so these brighter, more saturated tokens carry the
  // emissive look. Use ONLY for brand moments, never for product chrome.
  static const Color glowCore = Color(0xFFAFC6D8); // luminous slate — the lit mark
  static const Color glowSlate = Color(0xFF7D9FBE); // mid glow / glowing accents
  static const Color glowHalo = Color(0x8C7DA0BE); // ~55% slate — bloom shadow color

  /// Radial "lit-from-center" field for brand moments (splash / entry wall). A
  /// brighter slate core falls off to deep slate then the near-black canvas, so
  /// the screen reads as emitting light instead of a flat painted slate fill.
  static const RadialGradient slateGlowWall = RadialGradient(
    center: Alignment(0, -0.08),
    radius: 0.95,
    colors: [Color(0xFF6E93B5), slateDeep, ink],
    stops: [0.0, 0.5, 1.0],
  );

  /// SUBTLE ambient glow painted behind EVERY product screen (transparent
  /// scaffolds reveal it). A faint slate-tinted lift toward the upper-center
  /// falls off to the near-black canvas — enough to give the whole app a
  /// cohesive "lit from within" depth while keeping text fully legible. This is
  /// the restrained product-layer cousin of [slateGlowWall].
  static const RadialGradient canvasGlow = RadialGradient(
    center: Alignment(0, -0.35),
    radius: 1.15,
    colors: [Color(0xFF18222D), ink],
    stops: [0.0, 0.9],
  );

  // ── Semantic ─────────────────────────────────────────────────────────────
  static const Color positive = slateText; // up / confirmed (slate, no green)
  // Non-destructive "negative" (down/error states) is MUTED — never red.
  static const Color negative = Color(0xFF647079);
  static const Color negativeTint = Color(0x24647079); // ~14% muted fill
  // Folded into slate (status pills); rating stars use textPrimary instead.
  static const Color warning = Color(0xFF536878);
  static const Color warningTint = Color(0x2E536878);
  // RED IS DESTRUCTIVE ONLY (Sign out, Delete).
  static const Color destructiveRed = Color(0xFFEF4444);

  /// Off-canvas letterbox behind the phone frame on desktop web.
  static const Color frame = Color(0xFF05080F);

  // ── Entry-wall gradient (Layer 1 only: splash + auth) ───────────────────
  static const LinearGradient slateWall = LinearGradient(
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
  static const Color accentBlue = slate; // was #3B82F6 blue → brand slate
  static const Color textGrey = textSecondary; // subtitles / hints
  static const Color inputFill = surface; // was light #F1F5F9 → dark surface

  /// Legacy "background gradient" — now a flat black canvas (no navy).
  static const LinearGradient bgGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [ink, ink],
  );
}
