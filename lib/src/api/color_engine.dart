/// Primary public API for palette derivation and color-space conversion.
///
/// Core responsibility and abstraction boundary:
/// - Derive a [CorePalette] from one primary hex string.
/// - Validate and promote a [CorePaletteInput].
/// - Expose hex and OKLCH conversion helpers.
/// - Keep Prism, MCU, and internal conversion details hidden.
///
/// Key decisions:
/// - Public methods delegate color conversion, gamut policy, and derivation to
///   internal modules.
/// - Derivation clips custom colors to match derived-role behavior.
/// - Strict validation asserts custom colors are already inside sRGB.
/// - Custom color name validation is centralized so both paths enforce the
///   same naming rule.
///
/// Limitations:
/// - Does not generate tonal palettes.
/// - Does not perform contrast validation.
import 'package:huevora/huevora.dart';
import 'package:huevora/src/internal/color_converter.dart';
import 'package:huevora/src/internal/gamut_guard.dart';
import 'package:huevora/src/internal/palette_deriver.dart';
import 'package:huevora/src/internal/tonal_generator.dart';
import 'package:huevora/src/models/core_palette.dart';
import 'package:huevora/src/models/core_palette_input.dart';
import 'package:huevora/src/models/derivation_config.dart';
import 'package:huevora/src/models/huevora_color.dart';

typedef _GamutPolicy = HuevoraColor Function(HuevoraColor color);

final class ColorEngine {
  /// Creates a stateless color engine.
  const ColorEngine();

  /// Derives a complete [CorePalette] from [primaryHex].
  ///
  /// Custom colors from [config] are parsed, clipped to sRGB, and appended to
  /// the resulting palette.
  CorePalette deriveCorePalette(String primaryHex, [DerivationConfig? config]) {
    final newConfig = config ?? DerivationConfig.standard();
    final primary = ColorConverter.fromHex(primaryHex);
    final palette = PaletteDeriver.derive(primary, newConfig);
    final custom = _parseCustomColors(newConfig.customColors, _clipToSrgb);

    return _copyPaletteWithCustomColors(palette, custom);
  }

  // ---------------------------------------------------------------------------
  // Tonal palette generation
  // ---------------------------------------------------------------------------

  /// Generates tonal palettes for every role in [palette].
  ///
  /// When to use:
  /// After obtaining a [CorePalette] from [deriveCorePalette] or
  /// [validateCorePalette].
  ///
  /// Returns:
  /// A [TonalPaletteResult] with:
  /// - Standard roles: 18 tone steps (0–100).
  /// - Neutral / neutral-variant: 27 tone steps, denser at extremes.
  /// - Custom colors: 18 tone steps each.
  ///
  /// Side effects: none.
  TonalPaletteResult generateTonalPalettes(CorePalette palette) {
    return TonalGenerator.generate(palette);
  }

  /// Validates and promotes [input] to a [CorePalette].
  ///
  /// Every color is parsed and asserted to be inside sRGB.
  CorePalette validateCorePalette(CorePaletteInput input) {
    final custom = _parseCustomColors(input.customColors, _assertInSrgb);

    return CorePalette(
      primary: _parseAndAssert(input.primary),
      secondary: _parseAndAssert(input.secondary),
      tertiary: _parseAndAssert(input.tertiary),
      neutral: _parseAndAssert(input.neutral),
      neutralVariant: _parseAndAssert(input.neutralVariant),
      success: _parseAndAssert(input.success),
      error: _parseAndAssert(input.error),
      warning: _parseAndAssert(input.warning),
      info: _parseAndAssert(input.info),
      custom: custom,
    );
  }

  /// Parses [hex] into a [HuevoraColor].
  HuevoraColor fromHex(String hex) {
    return ColorConverter.fromHex(hex);
  }

  /// Constructs a [HuevoraColor] from OKLCH channel values.
  HuevoraColor fromOklch(double l, double c, double h) {
    return ColorConverter.fromOklch(l, c, h);
  }

  /// Returns [color]'s canonical `#RRGGBB` hex string.
  String toHex(HuevoraColor color) {
    return color.hex;
  }

  /// Returns [color]'s OKLCH components.
  OklchComponents toOklch(HuevoraColor color) {
    return color.oklch;
  }

  /// Formats [color]'s OKLCH components as a CSS `oklch()` string.
  String toOklchString(HuevoraColor color) {
    return ColorConverter.toOklchString(color.oklch);
  }

  static CorePalette _copyPaletteWithCustomColors(
    CorePalette palette,
    List<({String name, HuevoraColor color})> custom,
  ) {
    return CorePalette(
      primary: palette.primary,
      secondary: palette.secondary,
      tertiary: palette.tertiary,
      neutral: palette.neutral,
      neutralVariant: palette.neutralVariant,
      success: palette.success,
      error: palette.error,
      warning: palette.warning,
      info: palette.info,
      custom: custom,
    );
  }

  static HuevoraColor _parseAndAssert(String hex) {
    return _assertInSrgb(ColorConverter.fromHex(hex));
  }

  static List<({String name, HuevoraColor color})> _parseCustomColors(
    List<({String name, String hex})> customColors,
    _GamutPolicy applyGamutPolicy,
  ) {
    _validateCustomNames(customColors);

    return List<({String name, HuevoraColor color})>.generate(
      customColors.length,
      (index) {
        final entry = customColors[index];
        final color = applyGamutPolicy(ColorConverter.fromHex(entry.hex));

        return (name: entry.name, color: color);
      },
      growable: false,
    );
  }

  static HuevoraColor _clipToSrgb(HuevoraColor color) {
    return GamutGuard.clip(color);
  }

  static HuevoraColor _assertInSrgb(HuevoraColor color) {
    GamutGuard.assertInSrgb(color);
    return color;
  }

  static void _validateCustomNames(
    List<({String name, String hex})> customColors,
  ) {
    final seen = <String>{};

    for (final entry in customColors) {
      final name = entry.name;

      if (name.trim().isEmpty) {
        throw ArgumentError(
          'Custom color names must be non-empty.',
          'customColors',
        );
      }

      if (!seen.add(name)) {
        throw ArgumentError(
          'Duplicate custom color name: "$name". '
              'Each custom color must have a unique name.',
          'customColors',
        );
      }
    }
  }
}
