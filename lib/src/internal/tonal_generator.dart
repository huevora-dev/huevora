import 'package:huevora/src/internal/color_converter.dart';
import 'package:huevora/src/models/color_role.dart';
import 'package:huevora/src/models/core_palette.dart';
import 'package:huevora/src/models/huevora_color.dart';
import 'package:huevora/src/models/tonal_palette_result.dart';
import 'package:material_color_utilities/material_color_utilities.dart' hide CorePalette;

/// Generates tonal palettes from a validated Huevora core palette.
///
/// Core responsibility and abstraction boundary:
/// - Convert each role seed color into an MCU tonal palette.
/// - Materialize configured tone steps as [HuevoraColor] values.
/// - Return a [TonalPaletteResult] without exposing MCU types.
///
/// Key decisions:
/// - HCT extraction uses [Hct.fromInt] because MCU owns HCT conversion.
/// - [TonalPalette.fromHct] keeps hue/chroma derivation inside MCU.
/// - Neutral roles use a denser tone array than chromatic roles.
/// - Duplicate custom names fail fast to avoid silent tone-map loss.
///
/// Limitations:
/// - Does not derive seed colors.
/// - Does not generate on-color roles.
/// - Does not perform contrast validation.
abstract final class TonalGenerator {
  /// Standard 18-step tone array for chromatic roles.
  static const List<int> _standardTones = <int>[0, 5, 10, 15, 20, 25, 30, 35, 40, 50, 60, 70, 80, 90, 95, 98, 99, 100];

  /// Neutral 28-step tone array for neutral and neutralVariant roles.
  static const List<int> _neutralTones = <int>[
    0,
    4,
    5,
    6,
    10,
    12,
    15,
    17,
    20,
    22,
    24,
    25,
    30,
    35,
    40,
    50,
    60,
    70,
    80,
    87,
    90,
    92,
    94,
    95,
    96,
    98,
    99,
    100,
  ];

  /// Generates tonal palettes for all standard and custom colors in [palette].
  static TonalPaletteResult generate(CorePalette palette) {
    return TonalPaletteResult(tones: _buildStandardToneMaps(palette), customTones: _buildCustomToneMaps(palette));
  }

  static Map<ColorRole, Map<int, HuevoraColor>> _buildStandardToneMaps(CorePalette palette) {
    final tones = <ColorRole, Map<int, HuevoraColor>>{};

    for (final entry in palette.asMap().entries) {
      tones[entry.key] = _buildToneMap(entry.value, _toneStepsForRole(entry.key));
    }

    return Map<ColorRole, Map<int, HuevoraColor>>.unmodifiable(tones);
  }

  static Map<String, Map<int, HuevoraColor>> _buildCustomToneMaps(CorePalette palette) {
    if (palette.custom.isEmpty) {
      return const <String, Map<int, HuevoraColor>>{};
    }

    final tones = <String, Map<int, HuevoraColor>>{};

    for (final custom in palette.custom) {
      if (tones.containsKey(custom.name)) {
        throw ArgumentError.value(
          custom.name,
          'palette.custom',
          'Duplicate custom color names cannot be represented as tone maps.',
        );
      }

      tones[custom.name] = _buildToneMap(custom.color, _standardTones);
    }

    return Map<String, Map<int, HuevoraColor>>.unmodifiable(tones);
  }

  static List<int> _toneStepsForRole(ColorRole role) {
    return switch (role) {
      ColorRole.neutral || ColorRole.neutralVariant => _neutralTones,
      ColorRole.primary ||
      ColorRole.secondary ||
      ColorRole.tertiary ||
      ColorRole.success ||
      ColorRole.error ||
      ColorRole.warning ||
      ColorRole.info => _standardTones,
      ColorRole.custom => throw ArgumentError.value(
        role,
        'role',
        'Custom colors are generated from CorePalette.custom.',
      ),
    };
  }

  static Map<int, HuevoraColor> _buildToneMap(HuevoraColor base, List<int> toneSteps) {
    final hct = Hct.fromInt(base.argb);
    final tonalPalette = TonalPalette.fromHct(hct);
    final tones = <int, HuevoraColor>{};

    for (final tone in toneSteps) {
      tones[tone] = ColorConverter.fromArgb(tonalPalette.get(tone));
    }

    return Map<int, HuevoraColor>.unmodifiable(tones);
  }
}
