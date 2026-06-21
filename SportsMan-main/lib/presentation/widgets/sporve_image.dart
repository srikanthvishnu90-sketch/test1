import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Network image that fades in smoothly once decoded, shows a clean neutral
/// placeholder while loading, and a graceful fallback on error.
///
/// Replaces raw `Image.network` (which pops in abruptly and shows broken-image
/// glyphs) so imagery feels polished rather than janky.
class SporveImage extends StatelessWidget {
  final String? url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double radius;

  /// Glyph shown on load failure / empty url. Defaults to a neutral
  /// image-placeholder; pass `Icons.person` for avatars so a missing photo
  /// never reads as "broken".
  final IconData fallbackIcon;

  const SporveImage(
    this.url, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.radius = 0,
    this.fallbackIcon = Icons.image_not_supported_outlined,
  });

  Widget _placeholder({bool broken = false}) {
    return Container(
      width: width,
      height: height,
      color: AppColors.surface2,
      alignment: Alignment.center,
      child: broken
          ? Icon(fallbackIcon, color: AppColors.textTertiary, size: 22)
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (url == null || url!.trim().isEmpty) {
      content = _placeholder(broken: true);
    } else {
      content = Image.network(
        url!,
        width: width,
        height: height,
        fit: fit,
        // Fade the decoded image in for a soft, premium reveal.
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded) return child;
          return AnimatedOpacity(
            opacity: frame == null ? 0 : 1,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOut,
            child: child,
          );
        },
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return _placeholder();
        },
        errorBuilder: (context, error, stackTrace) => _placeholder(broken: true),
      );
    }

    if (radius > 0) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: SizedBox(width: width, height: height, child: content),
      );
    }
    return content;
  }
}
