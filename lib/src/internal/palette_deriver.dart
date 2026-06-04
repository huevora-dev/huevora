import 'package:huevora/src/internal/color_converter.dart';
import 'package:huevora/src/internal/gamut_guard.dart';
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
  static const double _warningBaseHue = 75.0;

  static const double _secondaryChromaScale = 0.85;
  static const double _tertiaryChromaScale = 0.90;
  static const double _neutralChromaScale = 0.06;
  static const double _neutralVariantChromaScale = 0.10;
  static const double _semanticChromaScale = 0.75;

  static const double _neutralSeedLightness = 0.50;
  static const double _complementaryHueOffset = 180.0;

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
      error: _deriveSemantic(primaryComponents, config, _errorBaseHue),
      info: _deriveSemantic(primaryComponents, config, _infoBaseHue),
      warning: _deriveSemantic(primaryComponents, config, _warningBaseHue),
      success: _deriveSemantic(primaryComponents, config, _successBaseHue),
    );
  }

  static HuevoraColor _deriveSecondary(OklchComponents primary, DerivationConfig config) {
    return _materialize(
      OklchComponents(l: primary.l, c: primary.c * _secondaryChromaScale, h: primary.h + config.secondaryHueOffset),
    );
  }

  static HuevoraColor _deriveTertiary(OklchComponents primary) {
    return _materialize(
      OklchComponents(l: primary.l, c: primary.c * _tertiaryChromaScale, h: primary.h + _complementaryHueOffset),
    );
  }

  static HuevoraColor _deriveNeutral(OklchComponents primary, DerivationConfig config) {
    return _materialize(
      OklchComponents(
        l: _neutralSeedLightness,
        c: _clamp(primary.c * _neutralChromaScale, config.neutralMinChroma, config.neutralMaxChroma),
        h: primary.h,
      ),
    );
  }

  static HuevoraColor _deriveNeutralVariant(OklchComponents primary, DerivationConfig config) {
    return _materialize(
      OklchComponents(
        l: _neutralSeedLightness,
        c: _clamp(
          primary.c * _neutralVariantChromaScale,
          config.neutralVariantMinChroma,
          config.neutralVariantMaxChroma,
        ),
        h: primary.h,
      ),
    );
  }

  static HuevoraColor _deriveSemantic(OklchComponents primary, DerivationConfig config, double baseHue) {
    return _materialize(
      OklchComponents(
        l: primary.l,
        c: _clamp(primary.c * _semanticChromaScale, config.semanticMinChroma, config.semanticMaxChroma),
        h: _blendHue(baseHue, primary.h, config.semanticBrandingWeight),
      ),
    );
  }

  static HuevoraColor _materialize(OklchComponents components) {
    return ColorConverter.fromOklchComponents(GamutGuard.clipComponents(components));
  }

  /// Blends from [base] toward [target] using linear interpolation.
  ///
  /// Follows the architecture formula:
  ///   derivedHue = semanticBaseHue + (primaryHue - semanticBaseHue) * brandingWeight
  ///
  /// The result is normalized to [0, 360) by [OklchComponents].
  static double _blendHue(double base, double target, double weight) {
    return base + (target - base) * weight;
  }

  static double _clamp(double value, double min, double max) {
    return value < min ? min : (value > max ? max : value);
  }
}
