import 'package:huevora/src/internal/color_converter.dart';
import 'package:huevora/src/models/exceptions.dart';
import 'package:huevora/src/models/huevora_color.dart';
import 'package:prism/prism.dart';

/// Enforces Huevora's sRGB gamut boundary.
///
/// Core responsibility and abstraction boundary:
/// - Decide whether OKLCH colors are representable in sRGB.
/// - Reduce chroma when needed while preserving lightness and hue.
/// - Hide Prism gamut APIs and RGB conversion details from callers.
///
/// Key decisions:
/// - Gamut checks use Prism's OKLCH boundary calculation as a fast path.
/// - A round-trip fallback (OKLCH→RGB8→OKLCH) catches false positives from
///   the linear cusp approximation, which is conservative near the true
///   curved sRGB boundary (common for saturated reds, oranges, and magentas).
/// - Clipping uses binary search with the round-trip predicate to find the
///   true in-gamut boundary, because the approximation can also be liberal
///   (overestimate the boundary) for some hue/lightness combinations.
///
/// Limitations:
/// - Targets sRGB only.
/// - Does not model HCT gamut behavior; material_color_utilities owns that.
abstract final class GamutGuard {
  /// Returns a guaranteed in-gamut [HuevoraColor].
  ///
  /// Returns [color] unchanged when already in gamut. Otherwise, returns a
  /// same-lightness, same-hue color with chroma reduced to the sRGB boundary.
  static HuevoraColor clip(HuevoraColor color) {
    final clipped = _clipComponentsToSrgb(color.oklch);

    if (identical(clipped, color.oklch)) {
      return color;
    }

    return ColorConverter.fromOklchComponents(clipped);
  }

  /// Returns in-gamut OKLCH components.
  ///
  /// Avoids materializing a [HuevoraColor] when callers are still deriving raw
  /// palette channels.
  static OklchComponents clipComponents(OklchComponents components) {
    return _clipComponentsToSrgb(components);
  }

  /// Clips every color in [colors].
  static List<HuevoraColor> clipAll(List<HuevoraColor> colors) {
    return List<HuevoraColor>.generate(
      colors.length,
      (index) => clip(colors[index]),
      growable: false,
    );
  }

  /// Throws [OutOfGamutException] when [color] is outside sRGB.
  static void assertInSrgb(HuevoraColor color) {
    if (_isInSrgbGamut(color.oklch)) {
      return;
    }

    final clipped = ColorConverter.fromOklchComponents(
      _clipComponentsToSrgb(color.oklch),
    );

    throw OutOfGamutException(sourceHex: color.hex, clampedHex: clipped.hex);
  }

  /// Returns true when [color] is representable in sRGB.
  static bool isInGamut(HuevoraColor color) {
    return _isInSrgbGamut(color.oklch);
  }

  static OklchComponents _clipComponentsToSrgb(OklchComponents components) {
    _validateComponents(components);

    // Fast path: already in gamut per round-trip verification.
    if (_isInSrgbGamut(components)) {
      return components;
    }

    // The linear cusp approximation from RayOklab.getMaxValidChroma can be
    // liberal for some hue/lightness combinations, overestimating the true
    // sRGB boundary. Binary search for the highest chroma that passes
    // round-trip verification.
    double low = 0.0;
    double high = components.c;
    double best = 0.0;

    for (var iteration = 0; iteration < 24; iteration++) {
      final mid = (low + high) * 0.5;
      final candidate = components.withC(mid);

      if (_isInSrgbGamut(candidate)) {
        best = mid;
        low = mid;
      } else {
        high = mid;
      }
    }

    return components.withC(best);
  }

  static bool _isInSrgbGamut(OklchComponents components) {
    final maxChroma = _maxValidChroma(components);

    // Fast path: well inside the approximate boundary.
    if (components.c <= maxChroma + _chromaTolerance) {
      return true;
    }

    // Fallback: getMaxValidChroma uses a linear cusp approximation that can be
    // conservative near the true sRGB boundary. Verify with an OKLCH→RGB8→OKLCH
    // round-trip. In-gamut colors survive round-trip with negligible drift;
    // out-of-gamut colors are altered by RGB8 clamping.
    final rayOklch = RayOklch.fromComponents(
      components.l,
      components.c,
      components.h,
    );
    final rayRgb = rayOklch.toRgb8();
    final roundTrip = rayRgb.toOklch();

    const lTolerance = 0.001;
    const cTolerance = 0.005;
    const hTolerance = 1.0;
    const achromaticThreshold = 1e-9;

    final lDiff = (components.l - roundTrip.lightness).abs();
    final cDiff = (components.c - roundTrip.chroma).abs();

    if (lDiff > lTolerance || cDiff > cTolerance) {
      return false;
    }

    // Hue is unstable near zero chroma; skip angular check for achromatic colors.
    final isAchromatic =
        components.c <= achromaticThreshold ||
        roundTrip.chroma <= achromaticThreshold;

    if (isAchromatic) {
      return true;
    }

    final hDiff = _angularDiff(components.h, roundTrip.hue);
    return hDiff <= hTolerance;
  }

  /// Shortest angular distance on the hue circle [0, 360).
  static double _angularDiff(double a, double b) {
    final diff = (a - b).abs() % 360.0;
    return diff > 180.0 ? 360.0 - diff : diff;
  }

  static double _maxValidChroma(OklchComponents components) {
    final maxChroma = RayOklab.getMaxValidChroma(components.l, components.h);

    if (!maxChroma.isFinite || maxChroma <= 0.0) {
      return 0.0;
    }

    return maxChroma;
  }

  static void _validateComponents(OklchComponents components) {
    if (!components.l.isFinite || components.l < 0.0 || components.l > 1.0) {
      throw InvalidChannelValueException(
        channel: 'lightness',
        value: components.l,
        min: 0.0,
        max: 1.0,
      );
    }

    if (!components.c.isFinite || components.c < 0.0) {
      throw InvalidChannelValueException(
        channel: 'chroma',
        value: components.c,
        min: 0.0,
        max: double.infinity,
      );
    }

    if (!components.h.isFinite || components.h < 0.0 || components.h >= 360.0) {
      throw InvalidChannelValueException(
        channel: 'hue',
        value: components.h,
        min: 0.0,
        max: 360.0,
      );
    }
  }

  static const double _chromaTolerance = 1e-7;
}
