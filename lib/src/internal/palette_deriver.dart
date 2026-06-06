import 'package:huevora/src/internal/color_converter.dart';
import 'package:huevora/src/internal/gamut_guard.dart';
import 'package:huevora/src/models/color_role.dart';
import 'package:huevora/src/models/core_palette.dart';
import 'package:huevora/src/models/derivation_config.dart';
import 'package:huevora/src/models/huevora_color.dart';

/// Derives Huevora's core palette roles in OKLCH space.
///
/// Core responsibility and abstraction boundary:
/// - Accept one validated primary color plus derivation configuration.
/// - Compute standard role seed colors using OKLCH arithmetic.
/// - Return a gamut-safe [CorePalette].
///
/// Derivation contracts:
/// - Secondary: analogous to primary (hue offset via config, reduced chroma).
/// - Tertiary: complementary to primary (+180°, reduced chroma).
/// - Neutrals: branded — primary hue at very low chroma, preserving primary lightness.
/// - Semantics: branded — fixed L/C anchors, hue harmonized toward primary
///   via shortest-arc interpolation. Error is hardcoded at 0.05 strength.
///
/// Limitations:
/// - Does not generate tonal palettes.
/// - Does not parse or append custom colors.
abstract final class PaletteDeriver {
  static const double _secondaryChromaScale = 0.65;
  static const double _tertiaryChromaScale = 0.70;
  static const double _neutralChromaScale = 0.08;
  static const double _neutralVariantChromaScale = 0.18;
  static const double _complementaryHueOffset = 180.0;

  // ─── Semantic role definitions: fixed L/C anchors, configurable strength ───
  static const _semanticDefinitions = <ColorRole, _SemanticAnchor>{
    ColorRole.success: _SemanticAnchor(
      baseHue: 145.0,
      lightness: 0.60,
      chroma: 0.14,
      fixedHarmonizeStrength: 0.20, // was: config.semanticBrandingWeight
    ),
    ColorRole.info: _SemanticAnchor(
      baseHue: 230.0,
      lightness: 0.62,
      chroma: 0.14,
      fixedHarmonizeStrength: 0.20,
    ),
    ColorRole.warning: _SemanticAnchor(
      baseHue: 80.0,
      lightness: 0.72,
      chroma: 0.16,
      fixedHarmonizeStrength: 0.12, // lower to prevent red-orange collision
    ),
    ColorRole.error: _SemanticAnchor(
      baseHue: 25.0,
      lightness: 0.58,
      chroma: 0.20,
      fixedHarmonizeStrength: 0.05, // hardcoded low to preserve urgent signal
    ),
  };

  /// Derives a complete [CorePalette] from [primary].
  ///
  /// Custom colors from [config] are intentionally not included here.
  static CorePalette derive(HuevoraColor primary, DerivationConfig config) {
    final primaryComponents = primary.oklch;

    return CorePalette(
      primary: primary,
      secondary: _deriveSecondary(primaryComponents, config),
      tertiary: _deriveTertiary(primaryComponents),
      neutral: _deriveNeutral(primaryComponents, config),
      neutralVariant: _deriveNeutralVariant(primaryComponents, config),
      error: _deriveSemantic(primaryComponents, ColorRole.error),
      info: _deriveSemantic(primaryComponents, ColorRole.info),
      warning: _deriveSemantic(primaryComponents, ColorRole.warning),
      success: _deriveSemantic(primaryComponents, ColorRole.success),
    );
  }

  /// Secondary: analogous to primary.
  ///
  /// Hue is shifted by [config.secondaryHueOffset] (default +30°).
  /// Chroma is reduced to 65% of primary for visual de-emphasis.
  static HuevoraColor _deriveSecondary(
    OklchComponents primary,
    DerivationConfig config,
  ) {
    return _materialize(
      OklchComponents(
        l: primary.l,
        c: primary.c * _secondaryChromaScale,
        h: primary.h + config.secondaryHueOffset,
      ),
    );
  }

  /// Tertiary: complementary to primary (+180°).
  ///
  /// Full hue inversion provides maximum contrast while maintaining
  /// the same lightness and slightly reduced chroma (70%).
  static HuevoraColor _deriveTertiary(OklchComponents primary) {
    return _materialize(
      OklchComponents(
        l: primary.l,
        c: primary.c * _tertiaryChromaScale,
        h: primary.h + _complementaryHueOffset,
      ),
    );
  }

  /// Neutral: branded — primary hue, very low chroma, preserving primary lightness.
  static HuevoraColor _deriveNeutral(
    OklchComponents primary,
    DerivationConfig config,
  ) {
    return _materialize(
      OklchComponents(
        l: primary.l,
        c: _clamp(
          primary.c * _neutralChromaScale,
          config.neutralMinChroma,
          config.neutralMaxChroma,
        ),
        h: primary.h,
      ),
    );
  }

  /// Neutral Variant: branded — slightly more chroma than neutral for outlines/containers.
  static HuevoraColor _deriveNeutralVariant(
    OklchComponents primary,
    DerivationConfig config,
  ) {
    return _materialize(
      OklchComponents(
        l: primary.l,
        c: _clamp(
          primary.c * _neutralVariantChromaScale,
          config.neutralVariantMinChroma,
          config.neutralVariantMaxChroma,
        ),
        h: primary.h,
      ),
    );
  }

  /// Semantic: branded — fixed L/C perceptual anchor, hue harmonized toward primary.
  ///
  /// Harmonization strength:
  /// - Success, info, warning: [DerivationConfig.semanticBrandingWeight].
  /// - Error: hardcoded at 0.05 (preserves urgent red signal).
  ///
  /// Shortest-arc interpolation prevents hue flips when primary and
  /// semantic base straddle the 0°/360° boundary.
  static HuevoraColor _deriveSemantic(OklchComponents primary, ColorRole role) {
    final anchor = _semanticDefinitions[role]!;
    return _materialize(
      OklchComponents(
        l: anchor.lightness,
        c: anchor.chroma,
        h: _blendHue(anchor.baseHue, primary.h, anchor.fixedHarmonizeStrength!),
      ),
    );
  }

  static HuevoraColor _materialize(OklchComponents components) {
    return ColorConverter.fromOklchComponents(
      GamutGuard.clipComponents(components),
    );
  }

  /// Shortest-arc hue blending.
  ///
  /// Blends [base] toward [target] by [weight] along the shorter path
  /// around the 360° wheel.
  static double _blendHue(double base, double target, double weight) {
    var delta = target - base;
    if (delta > 180.0) delta -= 360.0;
    if (delta < -180.0) delta += 360.0;
    final blended = base + delta * weight;
    return ((blended % 360.0) + 360.0) % 360.0;
  }

  static double _clamp(double value, double min, double max) {
    return value < min ? min : (value > max ? max : value);
  }
}

/// Immutable perceptual anchor for a semantic signal color.
///
/// Abstraction boundary: Private strategy constant. Each semantic role
/// carries a fixed OKLCH lightness and chroma (calibrated for perceptual
/// consistency) plus an optional override harmonization strength.
final class _SemanticAnchor {
  final double baseHue;
  final double lightness;
  final double chroma;
  final double? fixedHarmonizeStrength;

  const _SemanticAnchor({
    required this.baseHue,
    required this.lightness,
    required this.chroma,
    this.fixedHarmonizeStrength,
  });
}
