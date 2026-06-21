import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Sport-identity layer (Layer 3) — the per-sport color answers "what sport?"
/// at a glance and does nothing else. It is the ONLY chromatic color in the
/// app (everything else is black / white / slate). Used accent-only: sport tag,
/// icon-tile glyph, the in-context action button, a sport status pill, and
/// calendar session dots — never on chrome, never a card background.
/// Always paired with the sport icon and/or label. Unmapped sport → slate.
class SportColors {
  // Authoritative sport → color map (single source of truth).
  static const Map<String, Color> _core = {
    'basketball': Color(0xFFFF7A30),
    'baseball': Color(0xFF2F6FE0),
    'tennis': Color(0xFFE0DF2E),
    'rowing': Color(0xFF2C56B0),
    'rowing / crew': Color(0xFF2C56B0),
    'crew': Color(0xFF2C56B0),
    'soccer': Color(0xFF34C759),
    'football (soccer)': Color(0xFF34C759),
    'badminton': Color(0xFF5FA8E6),
    'boxing': Color(0xFFA0263A),
    'football': Color(0xFFC56A2E), // American football
    'football (am.)': Color(0xFFC56A2E),
    'swimming': Color(0xFF15C7D6),
    'diving': Color(0xFF15C7D6),
    'track & field': Color(0xFF8B5CF0),
    'track and field': Color(0xFF8B5CF0),
    'track': Color(0xFF8B5CF0),
    'running': Color(0xFF8B5CF0),
    'cross country': Color(0xFF8B5CF0),
    'triathlon': Color(0xFF8B5CF0),
    'water polo': Color(0xFF0F9FBF),
    'surfing': Color(0xFF0F9FBF),
    'gymnastics': Color(0xFFA656E0),
    'ice hockey': Color(0xFF4FB0E6),
    'hockey': Color(0xFF4FB0E6),
    'martial arts': Color(0xFF6A5BE0),
    'mma': Color(0xFF6A5BE0),
    'karate': Color(0xFF6A5BE0),
    'judo': Color(0xFF6A5BE0),
    'taekwondo': Color(0xFF6A5BE0),
    'ski / snowboard': Color(0xFF7FD0E8),
    'skiing': Color(0xFF7FD0E8),
    'snowboarding': Color(0xFF7FD0E8),
    'figure skating': Color(0xFF7FD0E8),
    'skating': Color(0xFF7FD0E8),
    'fencing': Color(0xFF8E86E6),
    'golf': Color(0xFF0E8A5F),
    'volleyball': Color(0xFFFF5C7A),
    'lacrosse': Color(0xFF1FB58A),
    'dance': Color(0xFFFF4FA3),
    'cricket': Color(0xFF1E7A5E),
    'cheer': Color(0xFFE64FC0),
    'cheerleading': Color(0xFFE64FC0),
    'cycling': Color(0xFFB6D636),
    'softball': Color(0xFFE6A92E),
    'climbing': Color(0xFFC2693E),
    'wrestling': Color(0xFFC13A4E),
    // racket family → tennis hue
    'pickleball': Color(0xFFE0DF2E),
    'squash': Color(0xFFE0DF2E),
    'table tennis': Color(0xFFE0DF2E),
    // water family
    'sailing': Color(0xFF2C56B0),
  };

  static const Color fallback = AppColors.slate; // unmapped sport → brand slate

  static String _key(String? sport) => (sport ?? '').toLowerCase().trim();

  /// The full sport color (glyph / text / 3px bar / in-context action only).
  static Color of(String? sport) => _core[_key(sport)] ?? fallback;

  /// Legible text/glyph color to place ON a sport-color fill — a dark shade for
  /// light sports, near-white for the few dark ones (boxing, baseball, etc.).
  static Color onColorOf(String? sport) =>
      of(sport).computeLuminance() < 0.45 ? const Color(0xFFF3F6F8) : const Color(0xFF0B0F14);

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
