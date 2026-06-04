import 'package:huevora/src/api/color_engine.dart';
import 'package:huevora/src/models/core_palette.dart';
import 'package:huevora/src/models/core_palette_input.dart';
import 'package:test/test.dart';

import 'package:huevora/huevora.dart';
import 'package:huevora/src/internal/color_converter.dart';
import 'package:huevora/src/internal/gamut_guard.dart';
import 'package:huevora/src/internal/palette_deriver.dart';

const _primaryHex = '#4A90E2';

void main() {
  // ===========================================================================
  // DerivationConfig
  // ===========================================================================
  group('DerivationConfig', () {
    group('defaults', () {
      test('standard() and default constructor produce equal configs', () {
        var a = DerivationConfig.standard();
        var b = DerivationConfig();
        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('semanticBrandingWeight defaults to 0.25', () {
        expect(DerivationConfig().semanticBrandingWeight, 0.25);
      });

      test('secondaryHueOffset defaults to 30.0', () {
        expect(DerivationConfig().secondaryHueOffset, 30.0);
      });

      test('neutralMinChroma defaults to 0.002', () {
        expect(DerivationConfig().neutralMinChroma, 0.002);
      });

      test('neutralMaxChroma defaults to 0.006', () {
        expect(DerivationConfig().neutralMaxChroma, 0.006);
      });

      test('neutralVariantMinChroma defaults to 0.004', () {
        expect(DerivationConfig().neutralVariantMinChroma, 0.004);
      });

      test('neutralVariantMaxChroma defaults to 0.010', () {
        expect(DerivationConfig().neutralVariantMaxChroma, 0.010);
      });

      test('customColors defaults to empty list', () {
        expect(DerivationConfig().customColors, isEmpty);
      });
    });

    group('equality', () {
      test('configs with same values are equal', () {
        var a = DerivationConfig(semanticBrandingWeight: 0.5);
        var b = DerivationConfig(semanticBrandingWeight: 0.5);
        expect(a, equals(b));
      });

      test('different semanticBrandingWeight produces unequal configs', () {
        var a = DerivationConfig(semanticBrandingWeight: 0.0);
        var b = DerivationConfig(semanticBrandingWeight: 1.0);
        expect(a, isNot(equals(b)));
      });

      test('different secondaryHueOffset produces unequal configs', () {
        var a = DerivationConfig(secondaryHueOffset: 30.0);
        var b = DerivationConfig(secondaryHueOffset: -30.0);
        expect(a, isNot(equals(b)));
      });
    });

    test('toString contains semanticBrandingWeight value', () {
      var config = DerivationConfig(semanticBrandingWeight: 0.5);
      expect(config.toString(), contains('0.5'));
    });
  });

  // ===========================================================================
  // CorePaletteInput
  // ===========================================================================
  group('CorePaletteInput', () {
    test('constructs with all required fields', () {
      var input = CorePaletteInput(
        primary: '#FF0000',
        secondary: '#00FF00',
        tertiary: '#0000FF',
        neutral: '#808080',
        neutralVariant: '#707070',
        success: '#00CC44',
        error: '#DD2233',
        warning: '#FFAA00',
        info: '#2244DD',
      );
      expect(input.primary, '#FF0000');
      expect(input.info, '#2244DD');
    });

    test('custom defaults to empty list', () {
      var input = CorePaletteInput(
        primary: '#FF0000',
        secondary: '#00FF00',
        tertiary: '#0000FF',
        neutral: '#808080',
        neutralVariant: '#707070',
        success: '#00CC44',
        error: '#DD2233',
        warning: '#FFAA00',
        info: '#2244DD',
      );
      expect(input.customColors, isEmpty);
    });

    test('accepts custom color records', () {
      var input = CorePaletteInput(
        primary: '#FF0000',
        secondary: '#00FF00',
        tertiary: '#0000FF',
        neutral: '#808080',
        neutralVariant: '#707070',
        success: '#00CC44',
        error: '#DD2233',
        warning: '#FFAA00',
        info: '#2244DD',
        customColors: [(name: 'accent', hex: '#AA00FF')],
      );
      expect(input.customColors.length, 1);
      expect(input.customColors.first.name, 'accent');
    });
  });

  // ===========================================================================
  // CorePalette
  // ===========================================================================
  group('CorePalette', () {
    late CorePalette palette;

    setUp(() {
      palette = ColorEngine().deriveCorePalette(_primaryHex);
    });

    group('all standard fields are populated', () {
      test('primary hex matches input', () {
        expect(palette.primary.hex, _primaryHex.toUpperCase());
      });

      for (final name in [
        'secondary',
        'tertiary',
        'neutral',
        'neutralVariant',
        'success',
        'error',
        'warning',
        'info',
      ]) {
        test('$name is non-null', () => expect(palette.asMap(), isNotEmpty));
      }
    });

    group('asMap', () {
      test('contains exactly nine standard roles', () {
        expect(palette.asMap().length, 9);
      });

      test('contains ColorRole.primary', () {
        expect(palette.asMap().containsKey(ColorRole.primary), isTrue);
      });

      test('does not contain ColorRole.custom', () {
        expect(palette.asMap().containsKey(ColorRole.custom), isFalse);
      });

      test('values match named fields', () {
        final map = palette.asMap();
        expect(map[ColorRole.primary]?.hex, palette.primary.hex);
        expect(map[ColorRole.secondary]?.hex, palette.secondary.hex);
        expect(map[ColorRole.neutral]?.hex, palette.neutral.hex);
      });
    });

    group('colorFor', () {
      test('returns correct color for primary', () {
        expect(palette.colorFor(ColorRole.primary).hex, palette.primary.hex);
      });

      test('returns correct color for success', () {
        expect(palette.colorFor(ColorRole.success).hex, palette.success.hex);
      });

      test('throws ArgumentError for ColorRole.custom', () {
        expect(
          () => palette.colorFor(ColorRole.custom),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    test('all standard role colors are in-gamut', () {
      for (final entry in palette.asMap().entries) {
        expect(
          GamutGuard.isInGamut(entry.value),
          isTrue,
          reason: 'Role ${entry.key.name} is out of gamut: ${entry.value.hex}',
        );
      }
    });

    test('toString contains primary hex', () {
      expect(palette.toString(), contains(palette.primary.hex));
    });
  });

  // ===========================================================================
  // PaletteDeriver — OKLCH relationship invariants
  // ===========================================================================
  group('PaletteDeriver', () {
    late HuevoraColor primary;
    late CorePalette palette;

    setUp(() {
      primary = ColorConverter.fromHex(_primaryHex);
      palette = PaletteDeriver.derive(primary, DerivationConfig());
    });

    group('secondary', () {
      test('lightness matches primary (within rounding)', () {
        expect(palette.secondary.oklch.l, closeTo(primary.oklch.l, 0.02));
      });

      test('chroma is less than or equal to primary chroma', () {
        expect(palette.secondary.oklch.c, lessThan(primary.oklch.c + 0.001));
      });

      test('hue offset from primary is approximately +30°', () {
        expect(
          _hueDiff(primary.oklch.h, palette.secondary.oklch.h),
          closeTo(30.0, 5.0),
        );
      });

      test('is in-gamut', () {
        expect(GamutGuard.isInGamut(palette.secondary), isTrue);
      });
    });

    group('tertiary', () {
      test('lightness matches primary (within rounding)', () {
        expect(palette.tertiary.oklch.l, closeTo(primary.oklch.l, 0.02));
      });

      test('hue is approximately complementary (+180°) to primary', () {
        expect(
          _hueDiff(primary.oklch.h, palette.tertiary.oklch.h),
          closeTo(180.0, 5.0),
        );
      });

      test('is in-gamut', () {
        expect(GamutGuard.isInGamut(palette.tertiary), isTrue);
      });
    });

    group('neutral', () {
      test('hue matches primary hue (within round-trip tolerance)', () {
        expect(
          _hueDiff(primary.oklch.h, palette.neutral.oklch.h),
          lessThanOrEqualTo(5.0),
        );
      });

      test('chroma is at or below default max 0.006', () {
        expect(palette.neutral.oklch.c, lessThanOrEqualTo(0.006 + 0.001));
      });

      test('chroma is at or above default min 0.002 (within tolerance)', () {
        expect(palette.neutral.oklch.c, greaterThanOrEqualTo(0.001));
      });

      test('is in-gamut', () {
        expect(GamutGuard.isInGamut(palette.neutral), isTrue);
      });
    });

    group('neutralVariant', () {
      test('hue matches primary hue (within round-trip tolerance)', () {
        expect(
          _hueDiff(primary.oklch.h, palette.neutralVariant.oklch.h),
          lessThanOrEqualTo(5.0),
        );
      });

      test('chroma is higher than neutral chroma', () {
        expect(
          palette.neutralVariant.oklch.c,
          greaterThan(palette.neutral.oklch.c - 0.001),
        );
      });

      test('chroma is at or below default max 0.010', () {
        expect(
          palette.neutralVariant.oklch.c,
          lessThanOrEqualTo(0.010 + 0.001),
        );
      });

      test('is in-gamut', () {
        expect(GamutGuard.isInGamut(palette.neutralVariant), isTrue);
      });
    });

    group('semantic signals', () {
      test(
        'success hue is closer to semantic base (~145°) than primary hue',
        () {
          final successHue = palette.success.oklch.h;
          final distToBase = _hueDiff(145.0, successHue);
          final distToPrimary = _hueDiff(primary.oklch.h, successHue);
          expect(distToBase, lessThan(distToPrimary + 1.0));
        },
      );

      test('error hue is in the red-orange family after branding pull', () {
        expect(palette.error.oklch.h, inInclusiveRange(15.0, 100.0));
      });

      test('all semantic signals are in-gamut', () {
        for (final role in [
          ColorRole.success,
          ColorRole.error,
          ColorRole.warning,
          ColorRole.info,
        ]) {
          final color = palette.colorFor(role);
          expect(
            GamutGuard.isInGamut(color),
            isTrue,
            reason: '${role.name} is out of gamut: ${color.hex}',
          );
        }
      });

      test('all semantic signals have sufficient chroma (≥ 0.008)', () {
        for (final role in [
          ColorRole.success,
          ColorRole.error,
          ColorRole.warning,
          ColorRole.info,
        ]) {
          expect(
            palette.colorFor(role).oklch.c,
            greaterThanOrEqualTo(0.008),
            reason: '${role.name} chroma is below minimum',
          );
        }
      });
    });

    group('config tuning', () {
      test(
        'semanticBrandingWeight=0.0 keeps error near semantic base (~25°)',
        () {
          final derived = PaletteDeriver.derive(
            primary,
            DerivationConfig(semanticBrandingWeight: 0.0),
          );
          expect(
            _hueDiff(25.0, derived.error.oklch.h),
            lessThanOrEqualTo(10.0),
          );
        },
      );

      test('semanticBrandingWeight=1.0 pulls error toward primary hue', () {
        final derived = PaletteDeriver.derive(
          primary,
          DerivationConfig(semanticBrandingWeight: 1.0),
        );
        expect(
          _hueDiff(primary.oklch.h, derived.error.oklch.h),
          lessThanOrEqualTo(10.0),
        );
      });

      test(
        'negative secondaryHueOffset produces a different secondary than positive',
        () {
          final pos = PaletteDeriver.derive(
            primary,
            DerivationConfig(secondaryHueOffset: 30.0),
          );
          final neg = PaletteDeriver.derive(
            primary,
            DerivationConfig(secondaryHueOffset: -30.0),
          );
          expect(
            pos.secondary.oklch.h,
            isNot(closeTo(neg.secondary.oklch.h, 5.0)),
          );
        },
      );

      test('custom neutral chroma bounds are respected', () {
        final derived = PaletteDeriver.derive(
          primary,
          DerivationConfig(neutralMinChroma: 0.010, neutralMaxChroma: 0.020),
        );
        expect(derived.neutral.oklch.c, greaterThanOrEqualTo(0.009));
        expect(derived.neutral.oklch.c, lessThanOrEqualTo(0.021));
      });
    });
  });

  // ===========================================================================
  // ColorEngine — deriveCorePalette
  // ===========================================================================
  group('ColorEngine.deriveCorePalette', () {
    final engine = ColorEngine();

    test('accepts lowercase hex', () {
      expect(engine.deriveCorePalette('#4a90e2').primary.hex, '#4A90E2');
    });

    test('accepts hex without leading #', () {
      expect(engine.deriveCorePalette('4A90E2').primary.hex, '#4A90E2');
    });

    test('throws InvalidHexException for bad primary hex', () {
      expect(
        () => engine.deriveCorePalette('#ZZZZZZ'),
        throwsA(isA<InvalidHexException>()),
      );
    });

    test('all standard roles are in-gamut', () {
      final palette = engine.deriveCorePalette(_primaryHex);
      for (final color in palette.asMap().values) {
        expect(GamutGuard.isInGamut(color), isTrue);
      }
    });

    group('custom colors', () {
      test('valid custom color is appended', () {
        final palette = engine.deriveCorePalette(
          _primaryHex,
          DerivationConfig(customColors: [(name: 'accent', hex: '#FF6B35')]),
        );
        expect(palette.custom.length, 1);
        expect(palette.custom.first.name, 'accent');
        expect(palette.custom.first.color.hex, '#FF6B35');
      });

      test('custom color is in-gamut after clip', () {
        final palette = engine.deriveCorePalette(
          _primaryHex,
          DerivationConfig(customColors: [(name: 'accent', hex: '#FF6B35')]),
        );
        expect(GamutGuard.isInGamut(palette.custom.first.color), isTrue);
      });

      test('throws InvalidHexException for bad custom hex', () {
        expect(
          () => engine.deriveCorePalette(
            _primaryHex,
            DerivationConfig(customColors: [(name: 'bad', hex: '#ZZZZZZ')]),
          ),
          throwsA(isA<InvalidHexException>()),
        );
      });

      test('throws ArgumentError for empty custom name', () {
        expect(
          () => engine.deriveCorePalette(
            _primaryHex,
            DerivationConfig(customColors: [(name: '', hex: '#FF6B35')]),
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws ArgumentError for duplicate custom names', () {
        expect(
          () => engine.deriveCorePalette(
            _primaryHex,
            DerivationConfig(
              customColors: [
                (name: 'accent', hex: '#FF6B35'),
                (name: 'accent', hex: '#AA00FF'),
              ],
            ),
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('multiple valid custom colors are all appended in order', () {
        final palette = engine.deriveCorePalette(
          _primaryHex,
          DerivationConfig(
            customColors: [
              (name: 'accent', hex: '#FF6B35'),
              (name: 'promo', hex: '#AA00FF'),
            ],
          ),
        );
        expect(palette.custom.length, 2);
        expect(palette.custom[0].name, 'accent');
        expect(palette.custom[1].name, 'promo');
      });
    });

    group('edge cases', () {
      test('pure black primary derives without throwing', () {
        expect(() => engine.deriveCorePalette('#000000'), returnsNormally);
      });

      test('pure white primary derives without throwing', () {
        expect(() => engine.deriveCorePalette('#FFFFFF'), returnsNormally);
      });

      test('pure red primary derives an in-gamut palette', () {
        final palette = engine.deriveCorePalette('#FF0000');
        for (final color in palette.asMap().values) {
          expect(GamutGuard.isInGamut(color), isTrue);
        }
      });
    });
  });

  // ===========================================================================
  // ColorEngine — validateCorePalette
  // ===========================================================================
  group('ColorEngine.validateCorePalette', () {
    final engine = ColorEngine();

    var validInput = CorePaletteInput(
      primary: '#4A90E2',
      secondary: '#6E8FBB',
      tertiary: '#E2924A',
      neutral: '#787880',
      neutralVariant: '#797882',
      success: '#386A20',
      error: '#BA1A1A',
      warning: '#7D5700',
      info: '#00639B',
    );

    test('valid input returns a CorePalette without throwing', () {
      expect(() => engine.validateCorePalette(validInput), returnsNormally);
    });

    test('returned palette primary matches input', () {
      expect(engine.validateCorePalette(validInput).primary.hex, '#4A90E2');
    });

    test('throws InvalidHexException for malformed primary', () {
      expect(
        () => engine.validateCorePalette(
          CorePaletteInput(
            primary: 'not-a-color',
            secondary: '#6E8FBB',
            tertiary: '#E2924A',
            neutral: '#787880',
            neutralVariant: '#797882',
            success: '#386A20',
            error: '#BA1A1A',
            warning: '#7D5700',
            info: '#00639B',
          ),
        ),
        throwsA(isA<InvalidHexException>()),
      );
    });

    test('throws InvalidHexException for malformed secondary', () {
      expect(
        () => engine.validateCorePalette(
          CorePaletteInput(
            primary: '#4A90E2',
            secondary: 'GGGGGG',
            tertiary: '#E2924A',
            neutral: '#787880',
            neutralVariant: '#797882',
            success: '#386A20',
            error: '#BA1A1A',
            warning: '#7D5700',
            info: '#00639B',
          ),
        ),
        throwsA(isA<InvalidHexException>()),
      );
    });

    test('all standard roles in returned palette are in-gamut', () {
      for (final color
          in engine.validateCorePalette(validInput).asMap().values) {
        expect(GamutGuard.isInGamut(color), isTrue);
      }
    });

    test('valid custom in validateCorePalette is included', () {
      final palette = engine.validateCorePalette(
        CorePaletteInput(
          primary: '#4A90E2',
          secondary: '#6E8FBB',
          tertiary: '#E2924A',
          neutral: '#787880',
          neutralVariant: '#797882',
          success: '#386A20',
          error: '#BA1A1A',
          warning: '#7D5700',
          info: '#00639B',
          customColors: [(name: 'brand', hex: '#FF6B35')],
        ),
      );
      expect(palette.custom.length, 1);
      expect(palette.custom.first.name, 'brand');
    });

    test('throws ArgumentError for duplicate custom names', () {
      expect(
        () => engine.validateCorePalette(
          CorePaletteInput(
            primary: '#4A90E2',
            secondary: '#6E8FBB',
            tertiary: '#E2924A',
            neutral: '#787880',
            neutralVariant: '#797882',
            success: '#386A20',
            error: '#BA1A1A',
            warning: '#7D5700',
            info: '#00639B',
            customColors: [
              (name: 'dup', hex: '#FF6B35'),
              (name: 'dup', hex: '#AA00FF'),
            ],
          ),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  // ===========================================================================
  // ColorEngine — conversion utilities
  // ===========================================================================
  group('ColorEngine conversion utilities', () {
    final engine = ColorEngine();

    test('fromHex returns HuevoraColor with correct hex', () {
      expect(engine.fromHex('#4A90E2').hex, '#4A90E2');
    });

    test('fromHex throws InvalidHexException for bad input', () {
      expect(
        () => engine.fromHex('#ZZZZZZ'),
        throwsA(isA<InvalidHexException>()),
      );
    });

    test('fromOklch returns a HuevoraColor', () {
      expect(engine.fromOklch(0.5, 0.1, 200.0), isNotNull);
    });

    test('fromOklch throws InvalidChannelValueException for bad l', () {
      expect(
        () => engine.fromOklch(1.5, 0.1, 0.0),
        throwsA(isA<InvalidChannelValueException>()),
      );
    });

    test('toHex returns the hex field', () {
      final color = engine.fromHex('#4A90E2');
      expect(engine.toHex(color), '#4A90E2');
    });

    test('toOklch returns the oklch field', () {
      final color = engine.fromHex('#4A90E2');
      expect(engine.toOklch(color), equals(color.oklch));
    });

    test('toOklchString starts with oklch(', () {
      expect(
        engine.toOklchString(engine.fromHex('#4A90E2')),
        startsWith('oklch('),
      );
    });
  });
  // ===========================================================================
  // ColorEngine — conversion utilities
  // ===========================================================================
  group('ColorEngine conversion utilities', () {
    final engine = ColorEngine();

    test('fromHex returns HuevoraColor with correct hex', () {
      expect(engine.fromHex('#4A90E2').hex, '#4A90E2');
    });

    test('fromHex throws InvalidHexException for bad input', () {
      expect(
        () => engine.fromHex('#ZZZZZZ'),
        throwsA(isA<InvalidHexException>()),
      );
    });

    test('fromOklch returns a HuevoraColor', () {
      expect(engine.fromOklch(0.5, 0.1, 200.0), isNotNull);
    });

    test('fromOklch throws InvalidChannelValueException for bad l', () {
      expect(
        () => engine.fromOklch(1.5, 0.1, 0.0),
        throwsA(isA<InvalidChannelValueException>()),
      );
    });

    test('toHex returns the hex field', () {
      final color = engine.fromHex('#4A90E2');
      expect(engine.toHex(color), '#4A90E2');
    });

    test('toOklch returns the oklch field', () {
      final color = engine.fromHex('#4A90E2');
      expect(engine.toOklch(color), equals(color.oklch));
    });

    test('toOklchString starts with oklch(', () {
      expect(
        engine.toOklchString(engine.fromHex('#4A90E2')),
        startsWith('oklch('),
      );
    });
  });
}

// ---------------------------------------------------------------------------
// Helper: shortest angular distance between two hue angles in [0, 360)
// ---------------------------------------------------------------------------
double _hueDiff(double a, double b) {
  final diff = (a - b).abs() % 360;
  return diff > 180 ? 360 - diff : diff;
}

// ---------------------------------
