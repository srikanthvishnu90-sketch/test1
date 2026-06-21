import 'package:flutter/material.dart';

/// Sport-identity layer (Layer 3) — per-sport color answers "what sport?" at a
/// glance and does nothing else. It is metadata, never chrome. Containment is
/// strict: a glyph color, a ~16% tint behind that glyph, a small tag/pill, a 3px
/// accent bar, or a category dot — nothing larger, one sport color per card max.
///
/// Cool colors belong to the brand (slate/blue), so sports skew warm + green +
/// jewel on purpose. Color is never the sole carrier of meaning — always paired
/// with the sport icon and/or label.
class SportColors {
  // Tier-1 curated, perceptually distinct, tuned to sit on black.
  static const Map<String, Color> _core = {
    'basketball': Color(0xFFF2824F), // warm burnt orange
    'soccer': Color(0xFF3FC585), // clean emerald
    'football (soccer)': Color(0xFF3FC585),
    'golf': Color(0xFFA6C46F), // sage / olive (yellower than soccer)
    'tennis': Color(0xFFC2DE4A), // volt / chartreuse
    'baseball': Color(0xFFE06A6A), // brick red
    'softball': Color(0xFFE06A6A),
    'swimming': Color(0xFF5BAAD0), // muted cerulean
    'diving': Color(0xFF5BAAD0),
    'football': Color(0xFFD29A66), // pigskin bronze/tan (American)
    'track': Color(0xFFE8A33A), // amber gold
    'track & field': Color(0xFFE8A33A),
    'running': Color(0xFFE8A33A),
    'volleyball': Color(0xFFE8B86A), // warm sand-gold
    'hockey': Color(0xFF8FB8D9), // steel / ice slate
    'ice hockey': Color(0xFF8FB8D9),
    'lacrosse': Color(0xFFC76B98), // rose
    'wrestling': Color(0xFFC25A4D), // rust
  };

  // Tier-2 family fallbacks — color carried by family, icon+label disambiguate.
  static const Map<String, String> _toFamily = {
    'pickleball': 'racket', 'badminton': 'racket', 'table tennis': 'racket',
    'squash': 'racket',
    'boxing': 'combat', 'mma': 'combat', 'karate': 'combat', 'judo': 'combat',
    'fencing': 'combat', 'taekwondo': 'combat',
    'skiing': 'winter', 'snowboarding': 'winter', 'figure skating': 'winter',
    'skating': 'winter',
    'water polo': 'water', 'surfing': 'water', 'rowing': 'water',
    'sailing': 'water',
    'gymnastics': 'movement', 'cheer': 'movement', 'cheerleading': 'movement',
    'dance': 'movement',
    'cross country': 'endurance', 'triathlon': 'endurance', 'cycling': 'endurance',
  };

  static const Map<String, Color> _family = {
    'racket': Color(0xFFC2DE4A),
    'combat': Color(0xFFC25A4D),
    'winter': Color(0xFF8FB8D9),
    'water': Color(0xFF5BAAD0),
    'movement': Color(0xFFC76B98),
    'endurance': Color(0xFFE8A33A),
  };

  static const Color fallback = Color(0xFF9A9AA1); // neutral when unmapped

  static String _key(String? sport) => (sport ?? '').toLowerCase().trim();

  /// The full-saturation sport color (glyph / text / 3px bar only).
  static Color of(String? sport) {
    final k = _key(sport);
    if (_core.containsKey(k)) return _core[k]!;
    final fam = _toFamily[k];
    if (fam != null) return _family[fam]!;
    return fallback;
  }

  /// Low-opacity tint for sport tags (~20%).
  static Color tintOf(String? sport) => of(sport).withOpacity(0.20);

  /// Stronger tint for icon-tile bases (~25%) — the bolder, more colorful look.
  static Color tileTintOf(String? sport) => of(sport).withOpacity(0.25);

  /// Faint header-zone wash for cards (~12%).
  static Color washOf(String? sport) => of(sport).withOpacity(0.12);

  /// Heavier scrim for gradient overlays on cover images (~60%).
  static Color scrimOf(String? sport) => of(sport).withOpacity(0.60);

  /// Sport → line/duotone icon. Replaces every emoji in the product.
  static IconData iconOf(String? sport) {
    switch (_key(sport)) {
      case 'basketball':
        return Icons.sports_basketball;
      case 'soccer':
      case 'football (soccer)':
        return Icons.sports_soccer;
      case 'tennis':
      case 'pickleball':
      case 'badminton':
      case 'table tennis':
      case 'squash':
        return Icons.sports_tennis;
      case 'golf':
        return Icons.sports_golf;
      case 'baseball':
      case 'softball':
        return Icons.sports_baseball;
      case 'swimming':
      case 'diving':
      case 'water polo':
        return Icons.pool;
      case 'football':
        return Icons.sports_football;
      case 'volleyball':
        return Icons.sports_volleyball;
      case 'hockey':
      case 'ice hockey':
        return Icons.sports_hockey;
      case 'wrestling':
      case 'boxing':
      case 'mma':
      case 'karate':
      case 'judo':
        return Icons.sports_mma;
      case 'track':
      case 'track & field':
      case 'running':
      case 'cross country':
      case 'triathlon':
        return Icons.directions_run;
      case 'cycling':
        return Icons.directions_bike;
      case 'skiing':
      case 'snowboarding':
        return Icons.downhill_skiing;
      case 'gymnastics':
      case 'cheer':
      case 'cheerleading':
      case 'dance':
        return Icons.sports_gymnastics;
      default:
        return Icons.sports;
    }
  }

  /// Maps a legacy sport emoji (still present in data/widgets) to a line icon,
  /// so any code passing an emoji string renders a refined glyph instead.
  static IconData iconForEmoji(String? emoji) {
    switch ((emoji ?? '').trim()) {
      case '🏀':
        return Icons.sports_basketball;
      case '⚽':
        return Icons.sports_soccer;
      case '🏈':
        return Icons.sports_football;
      case '🎾':
        return Icons.sports_tennis;
      case '⚾':
      case '🥎':
        return Icons.sports_baseball;
      case '🏐':
        return Icons.sports_volleyball;
      case '🏊':
      case '🏊‍♂️':
        return Icons.pool;
      case '⛳':
      case '🏌️':
        return Icons.sports_golf;
      case '🏒':
        return Icons.sports_hockey;
      case '🥍':
        return Icons.sports_hockey;
      case '🤼':
      case '🥊':
        return Icons.sports_mma;
      case '🏃':
      case '🏃‍♂️':
        return Icons.directions_run;
      case '🚴':
        return Icons.directions_bike;
      case '⛷️':
      case '🏂':
        return Icons.downhill_skiing;
      case '🤸':
        return Icons.sports_gymnastics;
      default:
        // Maybe a sport *name* was passed rather than an emoji.
        return iconOf(emoji);
    }
  }
}
