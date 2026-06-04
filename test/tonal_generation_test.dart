import 'package:test/test.dart';

import 'package:huevora/huevora.dart';
import 'package:huevora/src/internal/tonal_generator.dart';

const _primaryHex = '#4A90E2';

void main() {
  // ===========================================================================
  // TonalPaletteResult — model contract
  // ===========================================================================
  group('TonalPaletteResult model', () {
    late TonalPaletteResult result;

    setUp(() {
      final palette = ColorEngine().deriveCorePalette(_primaryHex);
      result = ColorEngine().generateTonalPalettes(palette);
    });

    group('tones map structure', () {
      test('contains exactly nine standard roles', () {
        expect(result.tones.length, 9);
      });

      test('contains ColorRole.primary', () {
        expect(result.tones.containsKey(ColorRole.primary), isTrue);
      });

      test('contains ColorRole.neutral', () {
        expect(result.tones.containsKey(ColorRole.neutral), isTrue);
      });

      test('contains ColorRole.neutralVariant', () {
        expect(result.tones.containsKey(ColorRole.neutralVariant), isTrue);
      });

      test('does not contain ColorRole.custom key', () {
        expect(result.tones.containsKey(ColorRole.custom), isFalse);
      });

      test('customTones is empty for a palette with no custom colors', () {
        expect(result.customTones, isEmpty);
      });

      test('customNames is empty for a palette with no custom colors', () {
        expect(result.customRoleNames, isEmpty);
      });
    });

    group('tonesFor', () {
      test('returns non-empty map for primary role', () {
        expect(result.getTonesForRole(ColorRole.primary), isNotEmpty);
      });

      test('returns non-empty map for neutral role', () {
        expect(result.getTonesForRole(ColorRole.neutral), isNotEmpty);
      });

      test('throws ArgumentError for ColorRole.custom', () {
        expect(
          () => result.getTonesForRole(ColorRole.custom),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('tonesForCustom', () {
      test('returns empty map for unknown custom name', () {
        expect(result.getCustomTonesForRole('nonexistent'), isEmpty);
      });
    });

    test('toString contains role names', () {
      expect(result.toString(), contains('primary'));
      expect(result.toString(), contains('neutral'));
    });
  });

  // ===========================================================================
  // TonalGenerator — tone step arrays
  // ===========================================================================
  group('TonalGenerator tone step arrays', () {
    late TonalPaletteResult result;

    setUp(() {
      final palette = ColorEngine().deriveCorePalette(_primaryHex);
      result = ColorEngine().generateTonalPalettes(palette);
    });

    group('standard roles use 18-step array', () {
      const standardSteps = [
        0,
        5,
        10,
        15,
        20,
        25,
        30,
        35,
        40,
        50,
        60,
        70,
        80,
        90,
        95,
        98,
        99,
        100,
      ];

      for (final role in [
        ColorRole.primary,
        ColorRole.secondary,
        ColorRole.tertiary,
        ColorRole.success,
        ColorRole.error,
        ColorRole.warning,
        ColorRole.info,
      ]) {
        test('${role.name} has ${standardSteps.length} tone steps', () {
          expect(result.getTonesForRole(role).length, standardSteps.length);
        });

        test('${role.name} contains tone 0 (black anchor)', () {
          expect(result.getTonesForRole(role).containsKey(0), isTrue);
        });

        test('${role.name} contains tone 40 (accessible dark label)', () {
          expect(result.getTonesForRole(role).containsKey(40), isTrue);
        });

        test('${role.name} contains tone 80 (accessible light label)', () {
          expect(result.getTonesForRole(role).containsKey(80), isTrue);
        });

        test('${role.name} contains tone 100 (white anchor)', () {
          expect(result.getTonesForRole(role).containsKey(100), isTrue);
        });

        test('${role.name} tone keys match standard step array exactly', () {
          final sortedKeys = result.getTonesForRole(role).keys.toList()..sort();
          expect(sortedKeys, equals([...standardSteps]..sort()));
        });
      }
    });

    group('neutral roles use 28-step array', () {
      const neutralSteps = [
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

      for (final role in [ColorRole.neutral, ColorRole.neutralVariant]) {
        test('${role.name} has ${neutralSteps.length} tone steps', () {
          expect(result.getTonesForRole(role).length, neutralSteps.length);
        });

        test('${role.name} contains tone 0', () {
          expect(result.getTonesForRole(role).containsKey(0), isTrue);
        });

        test('${role.name} contains tone 100', () {
          expect(result.getTonesForRole(role).containsKey(100), isTrue);
        });

        test('${role.name} contains dark extreme tone 4', () {
          expect(result.getTonesForRole(role).containsKey(4), isTrue);
        });

        test('${role.name} contains light extreme tone 94', () {
          expect(result.getTonesForRole(role).containsKey(94), isTrue);
        });

        test('${role.name} tone keys match neutral step array exactly', () {
          final sortedKeys = result.getTonesForRole(role).keys.toList()..sort();
          expect(sortedKeys, equals([...neutralSteps]..sort()));
        });
      }
    });
  });

  // ===========================================================================
  // TonalGenerator — HuevoraColor output quality
  // ===========================================================================
  group('TonalGenerator HuevoraColor output', () {
    late TonalPaletteResult result;

    setUp(() {
      final palette = ColorEngine().deriveCorePalette(_primaryHex);
      result = ColorEngine().generateTonalPalettes(palette);
    });

    group('tone 0 ≈ black, tone 100 ≈ white across all standard roles', () {
      for (final role in ColorRole.values.where((r) => r != ColorRole.custom)) {
        test('${role.name} tone 0 has near-zero OKLCH lightness', () {
          final toneMap = result.getTonesForRole(role);
          if (toneMap.isEmpty) return;
          expect(
            toneMap[0]!.oklch.l,
            lessThan(0.15),
            reason:
                '${role.name} tone 0 L=${toneMap[0]!.oklch.l} not near black',
          );
        });

        test('${role.name} tone 100 has near-unit OKLCH lightness', () {
          final toneMap = result.getTonesForRole(role);
          if (toneMap.isEmpty) return;
          expect(
            toneMap[100]!.oklch.l,
            greaterThan(0.90),
            reason:
                '${role.name} tone 100 L=${toneMap[100]!.oklch.l} not near white',
          );
        });
      }
    });

    group('tonal ramp is monotonically lighter (higher tone → higher L)', () {
      test('primary ramp is monotonically lighter', () {
        final toneMap = result.getTonesForRole(ColorRole.primary);
        final sortedTones = toneMap.keys.toList()..sort();
        for (var i = 1; i < sortedTones.length; i++) {
          final prevL = toneMap[sortedTones[i - 1]]!.oklch.l;
          final currL = toneMap[sortedTones[i]]!.oklch.l;
          expect(
            currL,
            greaterThanOrEqualTo(prevL - 0.01),
            reason:
                'Tone ${sortedTones[i]} (L=$currL) lighter than '
                'tone ${sortedTones[i - 1]} (L=$prevL)',
          );
        }
      });

      test('neutral ramp is monotonically lighter', () {
        final toneMap = result.getTonesForRole(ColorRole.neutral);
        final sortedTones = toneMap.keys.toList()..sort();
        for (var i = 1; i < sortedTones.length; i++) {
          final prevL = toneMap[sortedTones[i - 1]]!.oklch.l;
          final currL = toneMap[sortedTones[i]]!.oklch.l;
          expect(currL, greaterThanOrEqualTo(prevL - 0.01));
        }
      });
    });

    group('all HuevoraColor instances are valid', () {
      test('every primary tone has a valid #RRGGBB hex', () {
        for (final color in result.getTonesForRole(ColorRole.primary).values) {
          expect(color.hex, matches(r'^#[0-9A-F]{6}$'));
        }
      });

      test('every neutral tone has a valid #RRGGBB hex', () {
        for (final color in result.getTonesForRole(ColorRole.neutral).values) {
          expect(color.hex, matches(r'^#[0-9A-F]{6}$'));
        }
      });

      test('every error tone has a valid #RRGGBB hex', () {
        for (final color in result.getTonesForRole(ColorRole.error).values) {
          expect(color.hex, matches(r'^#[0-9A-F]{6}$'));
        }
      });

      test('OKLCH components are valid for every primary tone', () {
        for (final color in result.getTonesForRole(ColorRole.primary).values) {
          expect(color.oklch.l, inInclusiveRange(0.0, 1.0));
          expect(color.oklch.c, greaterThanOrEqualTo(0.0));
          expect(color.oklch.h, inInclusiveRange(0.0, 360.0));
        }
      });
    });

    group('accessible tone pairs', () {
      test('primary: tone 40 is darker than tone 80', () {
        final map = result.getTonesForRole(ColorRole.primary);
        expect(map[40]!.oklch.l, lessThan(map[80]!.oklch.l));
      });

      test('secondary: tone 40 is darker than tone 80', () {
        final map = result.getTonesForRole(ColorRole.secondary);
        expect(map[40]!.oklch.l, lessThan(map[80]!.oklch.l));
      });

      test('error: tone 40 is darker than tone 80', () {
        final map = result.getTonesForRole(ColorRole.error);
        expect(map[40]!.oklch.l, lessThan(map[80]!.oklch.l));
      });
    });
  });

  // ===========================================================================
  // TonalGenerator — custom colors
  // ===========================================================================
  group('TonalGenerator custom colors', () {
    test('custom color produces a tone map in customTones', () {
      final palette = ColorEngine().deriveCorePalette(
        _primaryHex,
        DerivationConfig(
          customColors: [(name: 'brand-accent', hex: '#FF6B35')],
        ),
      );
      final result = ColorEngine().generateTonalPalettes(palette);
      expect(result.customTones.containsKey('brand-accent'), isTrue);
    });

    test('custom color tone map has 18 steps (standard array)', () {
      final palette = ColorEngine().deriveCorePalette(
        _primaryHex,
        DerivationConfig(
          customColors: [(name: 'brand-accent', hex: '#FF6B35')],
        ),
      );
      final result = ColorEngine().generateTonalPalettes(palette);
      expect(result.getCustomTonesForRole('brand-accent').length, 18);
    });

    test('tonesForCustom returns correct map by name', () {
      final palette = ColorEngine().deriveCorePalette(
        _primaryHex,
        DerivationConfig(
          customColors: [(name: 'brand-accent', hex: '#FF6B35')],
        ),
      );
      final result = ColorEngine().generateTonalPalettes(palette);
      final tones = result.getCustomTonesForRole('brand-accent');
      expect(tones.containsKey(0), isTrue);
      expect(tones.containsKey(100), isTrue);
    });

    test('multiple custom colors each get their own tone map', () {
      final palette = ColorEngine().deriveCorePalette(
        _primaryHex,
        DerivationConfig(
          customColors: [
            (name: 'accent', hex: '#FF6B35'),
            (name: 'promo', hex: '#AA00FF'),
          ],
        ),
      );
      final result = ColorEngine().generateTonalPalettes(palette);
      expect(result.customTones.length, 2);
      expect(result.customRoleNames, containsAll(['accent', 'promo']));
    });

    test('customNames preserves insertion order', () {
      final palette = ColorEngine().deriveCorePalette(
        _primaryHex,
        DerivationConfig(
          customColors: [
            (name: 'first', hex: '#FF6B35'),
            (name: 'second', hex: '#AA00FF'),
            (name: 'third', hex: '#00CC44'),
          ],
        ),
      );
      final result = ColorEngine().generateTonalPalettes(palette);
      expect(result.customRoleNames, equals(['first', 'second', 'third']));
    });

    test('tonesForCustom returns empty map for unknown name', () {
      final palette = ColorEngine().deriveCorePalette(_primaryHex);
      final result = ColorEngine().generateTonalPalettes(palette);
      expect(result.getCustomTonesForRole('does-not-exist'), isEmpty);
    });
  });

  // ===========================================================================
  // ColorEngine.generateTonalPalettes — integration
  // ===========================================================================
  group('ColorEngine.generateTonalPalettes integration', () {
    final engine = ColorEngine();

    test('full workflow: hex → corePalette → tonalResult', () {
      final palette = engine.deriveCorePalette('#4A90E2');
      final result = engine.generateTonalPalettes(palette);
      expect(result.tones.length, 9);
      expect(result.getTonesForRole(ColorRole.primary), isNotEmpty);
    });

    test('validated palette also generates tonal result', () {
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
        ),
      );
      final result = engine.generateTonalPalettes(palette);
      expect(result.tones.length, 9);
      expect(result.getTonesForRole(ColorRole.primary)[40], isNotNull);
    });

    test('pure black primary generates a valid tonal result', () {
      final result = engine.generateTonalPalettes(
        engine.deriveCorePalette('#000000'),
      );
      expect(result.getTonesForRole(ColorRole.primary), isNotEmpty);
    });

    test('pure white primary generates a valid tonal result', () {
      final result = engine.generateTonalPalettes(
        engine.deriveCorePalette('#FFFFFF'),
      );
      expect(result.getTonesForRole(ColorRole.primary), isNotEmpty);
    });

    test('pure red primary generates a valid tonal result', () {
      final result = engine.generateTonalPalettes(
        engine.deriveCorePalette('#FF0000'),
      );
      expect(result.getTonesForRole(ColorRole.primary), isNotEmpty);
    });

    test('result.tones is unmodifiable', () {
      final result = engine.generateTonalPalettes(
        engine.deriveCorePalette(_primaryHex),
      );
      expect(
        () => result.tones[ColorRole.primary] = {},
        throwsUnsupportedError,
      );
    });

    test('result.customTones is unmodifiable', () {
      final result = engine.generateTonalPalettes(
        engine.deriveCorePalette(_primaryHex),
      );
      expect(() => result.customTones['new'] = {}, throwsUnsupportedError);
    });
  });

  // ===========================================================================
  // TonalGenerator — direct internal API
  // ===========================================================================
  group('TonalGenerator.generate (internal)', () {
    test('generates result with all nine standard roles', () {
      final palette = ColorEngine().deriveCorePalette(_primaryHex);
      final result = TonalGenerator.generate(palette);
      expect(
        result.tones.keys.toSet(),
        equals({
          ColorRole.primary,
          ColorRole.secondary,
          ColorRole.tertiary,
          ColorRole.neutral,
          ColorRole.neutralVariant,
          ColorRole.success,
          ColorRole.error,
          ColorRole.warning,
          ColorRole.info,
        }),
      );
    });

    test('neutral role step count differs from primary step count', () {
      final palette = ColorEngine().deriveCorePalette(_primaryHex);
      final result = TonalGenerator.generate(palette);
      expect(
        result.getTonesForRole(ColorRole.primary).length,
        isNot(equals(result.getTonesForRole(ColorRole.neutral).length)),
      );
    });

    test('all ARGB values have alpha byte 0xFF', () {
      final palette = ColorEngine().deriveCorePalette(_primaryHex);
      final result = TonalGenerator.generate(palette);
      for (final toneMap in result.tones.values) {
        for (final color in toneMap.values) {
          expect(
            color.argb >> 24,
            equals(0xFF),
            reason: 'Alpha byte not 0xFF: ${color.argb.toRadixString(16)}',
          );
        }
      }
    });
  });
}
