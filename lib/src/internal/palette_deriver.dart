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
/// Key decisions:
/// - Role derivation stays as private functions so each role's color
///   relationship remains explicit.
/// - Gamut clipping is applied before color materialization.
/// - Semantic hue blending uses shortest-path angular interpolation because
///   hue is circular, not linear scalar data.
///
/// Limitations:
/// - Does not generate tonal palettes.
/// - Does not parse or append custom colors.
abstract final class PaletteDeriver {
  static const double _successBaseHue = 145.0;
  static const double _errorBaseHue = 25.0;
  static const double _infoBaseHue = 240.0;
  static const double _warningBaseHue = 80.0;

  static const double _secondaryChromaScale = 0.65;
  static const double _tertiaryChromaScale = 0.70;
  static const double _neutralChromaScale = 0.08;
  static const double _neutralVariantChromaScale = 0.18;

  static const double _complementaryHueOffset = 60.0;

  // ─── Semantic role definitions: fixed L/C anchors, configurable strength ───
  static const _semanticDefinitions = <ColorRole, _SemanticAnchor>{
    ColorRole.success: _SemanticAnchor(
      baseHue: 145.0,
      lightness: 0.60,
      chroma: 0.14,
    ),
    ColorRole.info: _SemanticAnchor(
      baseHue: 230.0,
      lightness: 0.62,
      chroma: 0.14,
    ),
    ColorRole.warning: _SemanticAnchor(
      baseHue: 80.0,
      lightness: 0.72,
      chroma: 0.16,
    ),
    ColorRole.error: _SemanticAnchor(
      baseHue: 25.0,
      lightness: 0.58,
      chroma: 0.20,
      // Error is hardcoded at 0.05 regardless of config to preserve
      // its urgent red-family signal meaning.
      fixedHarmonizeStrength: 0.05,
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
      error: _deriveSemantic(
        primaryComponents,
        config,
        _errorBaseHue,
        ColorRole.error,
      ),
      info: _deriveSemantic(
        primaryComponents,
        config,
        _infoBaseHue,
        ColorRole.info,
      ),
      warning: _deriveSemantic(
        primaryComponents,
        config,
        _warningBaseHue,
        ColorRole.warning,
      ),
      success: _deriveSemantic(
        primaryComponents,
        config,
        _successBaseHue,
        ColorRole.success,
      ),
    );
  }

  static HuevoraColor _deriveSecondary(
    OklchComponents primary,
    DerivationConfig config,
  ) {
    return _materialize(
      OklchComponents(
        l: primary.l,
        c: primary.c * _secondaryChromaScale,
        h: primary.h,
      ),
    );
  }

  static HuevoraColor _deriveTertiary(OklchComponents primary) {
    return _materialize(
      OklchComponents(
        l: primary.l,
        c: primary.c * _tertiaryChromaScale,
        h: primary.h + _complementaryHueOffset,
      ),
    );
  }

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

  static HuevoraColor _deriveSemantic(
    OklchComponents primary,
    DerivationConfig config,
    double baseHue,
    ColorRole role,
  ) {
    final anchor = _semanticDefinitions[role]!;
    final strength =
        anchor.fixedHarmonizeStrength ?? config.semanticBrandingWeight;
    return _materialize(
      OklchComponents(
        l: anchor.lightness,
        c: anchor.chroma,
        h: _blendHue(baseHue, primary.h, strength),
      ),
    );
  }

  static HuevoraColor _materialize(OklchComponents components) {
    return ColorConverter.fromOklchComponents(
      GamutGuard.clipComponents(components),
    );
  }

  /// Blends from [base] toward [target] using linear interpolation.
  ///
  /// Follows the architecture formula:
  ///   derivedHue = semanticBaseHue + (primaryHue - semanticBaseHue) * brandingWeight
  ///
  /// The result is normalized to [0, 360) by [OklchComponents].
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
    double? fixedHarmonizeStrength,
  }) : fixedHarmonizeStrength = fixedHarmonizeStrength;
}
