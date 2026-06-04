import 'package:huevora/src/models/color_role.dart';
import 'package:huevora/src/models/exceptions.dart';
import 'package:huevora/src/models/huevora_color.dart';
import 'package:test/test.dart';
import 'package:huevora/src/internal/color_converter.dart';
import 'package:huevora/src/internal/gamut_guard.dart';

void main() {
  // ===========================================================================
  // OklchComponents
  // ===========================================================================
  group('OklchComponents', () {
    group('hue normalisation — double-modulo correctness', () {
      test('positive hue within [0, 360) is unchanged', () {
        final c = OklchComponents(l: 0.5, c: 0.1, h: 120.0);
        expect(c.h, 120.0);
      });

      test('hue of exactly 0 stays 0', () {
        final c = OklchComponents(l: 0.5, c: 0.1, h: 0.0);
        expect(c.h, 0.0);
      });

      test('hue of exactly 360 wraps to 0, not 360', () {
        final c = OklchComponents(l: 0.5, c: 0.1, h: 360.0);
        expect(c.h, 0.0);
      });

      test('hue of exactly -360 wraps to 0, not 360', () {
        // The old `h < 0 ? (h % 360) + 360` pattern fails here:
        // -360 % 360 == 0 in Dart, then 0 + 360 == 360, violating [0, 360).
        final c = OklchComponents(l: 0.5, c: 0.1, h: -360.0);
        expect(c.h, 0.0);
      });

      test('negative hue -30 wraps to 330', () {
        final c = OklchComponents(l: 0.5, c: 0.1, h: -30.0);
        expect(c.h, closeTo(330.0, 1e-9));
      });

      test('hue 390 wraps to 30', () {
        final c = OklchComponents(l: 0.5, c: 0.1, h: 390.0);
        expect(c.h, closeTo(30.0, 1e-9));
      });

      test('hue 720 wraps to 0', () {
        final c = OklchComponents(l: 0.5, c: 0.1, h: 720.0);
        expect(c.h, closeTo(0.0, 1e-9));
      });

      test('hue -370 wraps to 350', () {
        final c = OklchComponents(l: 0.5, c: 0.1, h: -370.0);
        expect(c.h, closeTo(350.0, 1e-9));
      });

      test('hue 359.999 is unchanged (just below 360)', () {
        final c = OklchComponents(l: 0.5, c: 0.1, h: 359.999);
        expect(c.h, closeTo(359.999, 1e-9));
      });
    });

    group('copy methods', () {
      final base = OklchComponents(l: 0.5, c: 0.15, h: 200.0);

      test('withL replaces lightness only', () {
        final copy = base.withL(0.8);
        expect(copy.l, 0.8);
        expect(copy.c, 0.15);
        expect(copy.h, 200.0);
      });

      test('withC replaces chroma only', () {
        final copy = base.withC(0.05);
        expect(copy.c, 0.05);
        expect(copy.l, 0.5);
        expect(copy.h, 200.0);
      });

      test('withH replaces hue and normalises', () {
        final copy = base.withH(370.0);
        expect(copy.h, closeTo(10.0, 1e-9));
        expect(copy.l, 0.5);
        expect(copy.c, 0.15);
      });
    });

    group('equality and hashing', () {
      test('identical channel values are equal', () {
        final a = OklchComponents(l: 0.5, c: 0.1, h: 100.0);
        final b = OklchComponents(l: 0.5, c: 0.1, h: 100.0);
        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('different lightness is unequal', () {
        final a = OklchComponents(l: 0.5, c: 0.1, h: 100.0);
        final b = OklchComponents(l: 0.6, c: 0.1, h: 100.0);
        expect(a, isNot(equals(b)));
      });

      test('different chroma is unequal', () {
        final a = OklchComponents(l: 0.5, c: 0.1, h: 100.0);
        final b = OklchComponents(l: 0.5, c: 0.2, h: 100.0);
        expect(a, isNot(equals(b)));
      });

      test('different hue is unequal', () {
        final a = OklchComponents(l: 0.5, c: 0.1, h: 100.0);
        final b = OklchComponents(l: 0.5, c: 0.1, h: 200.0);
        expect(a, isNot(equals(b)));
      });
    });

    group('toString', () {
      test('format matches oklch(L C H)', () {
        final c = OklchComponents(l: 0.5, c: 0.1, h: 120.0);
        expect(c.toString(), startsWith('oklch('));
      });
    });
  });

  // ===========================================================================
  // ColorConverter.fromHex
  // ===========================================================================
  group('ColorConverter.fromHex', () {
    group('hex → canonical form', () {
      test('lowercase is normalised to uppercase', () {
        final color = ColorConverter.fromHex('#4a90e2');
        expect(color.hex, '#4A90E2');
      });

      test('uppercase is unchanged', () {
        final color = ColorConverter.fromHex('#4A90E2');
        expect(color.hex, '#4A90E2');
      });

      test('optional # prefix is handled — no prefix', () {
        final a = ColorConverter.fromHex('4A90E2');
        final b = ColorConverter.fromHex('#4A90E2');
        expect(a.hex, b.hex);
      });

      test('pure black produces #000000', () {
        expect(ColorConverter.fromHex('#000000').hex, '#000000');
      });

      test('pure white produces #FFFFFF', () {
        expect(ColorConverter.fromHex('#FFFFFF').hex, '#FFFFFF');
      });

      test('pure red produces #FF0000', () {
        expect(ColorConverter.fromHex('#FF0000').hex, '#FF0000');
      });

      test('pure green produces #00FF00', () {
        expect(ColorConverter.fromHex('#00FF00').hex, '#00FF00');
      });

      test('pure blue produces #0000FF', () {
        expect(ColorConverter.fromHex('#0000FF').hex, '#0000FF');
      });
    });

    group('shorthand #RGB expansion', () {
      test('#FFF expands to #FFFFFF', () {
        expect(ColorConverter.fromHex('#FFF').hex, '#FFFFFF');
      });

      test('#000 expands to #000000', () {
        expect(ColorConverter.fromHex('#000').hex, '#000000');
      });

      test('#F0A expands to #FF00AA', () {
        expect(ColorConverter.fromHex('#F0A').hex, '#FF00AA');
      });

      test('#ABC expands to #AABBCC', () {
        expect(ColorConverter.fromHex('#ABC').hex, '#AABBCC');
      });
    });

    group('OKLCH output plausibility', () {
      test('black has near-zero lightness', () {
        final color = ColorConverter.fromHex('#000000');
        expect(color.oklch.l, closeTo(0.0, 0.01));
      });

      test('white has near-unit lightness', () {
        final color = ColorConverter.fromHex('#FFFFFF');
        expect(color.oklch.l, closeTo(1.0, 0.01));
      });

      test('white has near-zero chroma (achromatic)', () {
        final color = ColorConverter.fromHex('#FFFFFF');
        expect(color.oklch.c, closeTo(0.0, 0.01));
      });

      test('black has near-zero chroma (achromatic)', () {
        final color = ColorConverter.fromHex('#000000');
        expect(color.oklch.c, closeTo(0.0, 0.01));
      });

      test('pure red hue is approximately 29°', () {
        final color = ColorConverter.fromHex('#FF0000');
        expect(color.oklch.h, inInclusiveRange(20.0, 40.0));
      });

      test('oklch.h is always in [0, 360)', () {
        for (final hex in ['#FF0000', '#00FF00', '#0000FF', '#FFFF00', '#FF00FF']) {
          final color = ColorConverter.fromHex(hex);
          expect(color.oklch.h, inInclusiveRange(0.0, 360.0));
          expect(color.oklch.h, isNot(equals(360.0)));
        }
      });
    });

    group('ARGB output', () {
      test('white ARGB is 0xFFFFFFFF', () {
        expect(ColorConverter.fromHex('#FFFFFF').argb, 0xFFFFFFFF);
      });

      test('black ARGB is 0xFF000000', () {
        expect(ColorConverter.fromHex('#000000').argb, 0xFF000000);
      });

      test('alpha byte is always 0xFF', () {
        final color = ColorConverter.fromHex('#4A90E2');
        expect((color.argb >> 24) & 0xFF, 0xFF);
      });

      test('ARGB red channel matches hex R byte', () {
        final color = ColorConverter.fromHex('#4A90E2');
        expect((color.argb >> 16) & 0xFF, 0x4A);
      });

      test('ARGB green channel matches hex G byte', () {
        final color = ColorConverter.fromHex('#4A90E2');
        expect((color.argb >> 8) & 0xFF, 0x90);
      });

      test('ARGB blue channel matches hex B byte', () {
        final color = ColorConverter.fromHex('#4A90E2');
        expect(color.argb & 0xFF, 0xE2);
      });

      test('ARGB is memoised — same value on repeated access', () {
        final color = ColorConverter.fromHex('#4A90E2');
        final first = color.argb;
        final second = color.argb;
        expect(identical(first, second), isTrue);
      });
    });

    group('invalid input → InvalidHexException', () {
      test('empty string', () {
        expect(() => ColorConverter.fromHex(''), throwsA(isA<InvalidHexException>()));
      });

      test('5-digit hex', () {
        expect(() => ColorConverter.fromHex('#ABCDE'), throwsA(isA<InvalidHexException>()));
      });

      test('7-digit hex (too long)', () {
        expect(() => ColorConverter.fromHex('#1234567'), throwsA(isA<InvalidHexException>()));
      });

      test('non-hex characters', () {
        expect(() => ColorConverter.fromHex('#ZZZZZZ'), throwsA(isA<InvalidHexException>()));
      });

      test('InvalidHexException carries the original input', () {
        try {
          ColorConverter.fromHex('NOT_A_COLOR');
          fail('Expected InvalidHexException');
        } on InvalidHexException catch (e) {
          expect(e.input, 'NOT_A_COLOR');
        }
      });
    });
  });

  // ===========================================================================
  // ColorConverter.fromOklch
  // ===========================================================================
  group('ColorConverter.fromOklch', () {
    test('l=0 c=0 h=0 produces #000000', () {
      final color = ColorConverter.fromOklch(0.0, 0.0, 0.0);
      expect(color.hex, '#000000');
    });

    test('l=1 c=0 h=0 produces #FFFFFF', () {
      final color = ColorConverter.fromOklch(1.0, 0.0, 0.0);
      expect(color.hex, '#FFFFFF');
    });

    test('l > 1.0 throws InvalidChannelValueException', () {
      expect(() => ColorConverter.fromOklch(1.1, 0.1, 100.0), throwsA(isA<InvalidChannelValueException>()));
    });

    test('l < 0.0 throws InvalidChannelValueException', () {
      expect(() => ColorConverter.fromOklch(-0.01, 0.1, 100.0), throwsA(isA<InvalidChannelValueException>()));
    });

    test('negative chroma throws InvalidChannelValueException', () {
      expect(() => ColorConverter.fromOklch(0.5, -0.01, 100.0), throwsA(isA<InvalidChannelValueException>()));
    });

    test('exception carries the channel name', () {
      try {
        ColorConverter.fromOklch(1.5, 0.1, 0.0);
        fail('Expected InvalidChannelValueException');
      } on InvalidChannelValueException catch (e) {
        expect(e.channel, 'lightness');
      }
    });

    test('hue 360 is stored as 0 (normalised)', () {
      final color = ColorConverter.fromOklch(0.5, 0.1, 360.0);
      expect(color.oklch.h, closeTo(0.0, 1e-9));
    });

    test('hex→oklch→hex round-trip is stable to ±1 per channel', () {
      final original = ColorConverter.fromHex('#4A90E2');
      final rt = ColorConverter.fromOklch(original.oklch.l, original.oklch.c, original.oklch.h);
      final origR = (original.argb >> 16) & 0xFF;
      final origG = (original.argb >> 8) & 0xFF;
      final origB = original.argb & 0xFF;
      final rtR = (rt.argb >> 16) & 0xFF;
      final rtG = (rt.argb >> 8) & 0xFF;
      final rtB = rt.argb & 0xFF;
      expect((origR - rtR).abs(), lessThanOrEqualTo(1));
      expect((origG - rtG).abs(), lessThanOrEqualTo(1));
      expect((origB - rtB).abs(), lessThanOrEqualTo(1));
    });
  });

  // ===========================================================================
  // ColorConverter.fromOklchComponents
  // ===========================================================================
  group('ColorConverter.fromOklchComponents', () {
    test('pre-built components produce same result as fromOklch', () {
      const components = OklchComponents(l: 0.6, c: 0.12, h: 248.0);
      final a = ColorConverter.fromOklchComponents(components);
      final b = ColorConverter.fromOklch(0.6, 0.12, 248.0);
      expect(a.hex, b.hex);
    });

    test('invalid lightness still throws', () {
      const bad = OklchComponents(l: 1.5, c: 0.1, h: 0.0);
      expect(() => ColorConverter.fromOklchComponents(bad), throwsA(isA<InvalidChannelValueException>()));
    });
  });

  // ===========================================================================
  // ColorConverter.fromArgb
  // ===========================================================================
  group('ColorConverter.fromArgb', () {
    test('0xFFFFFFFF → #FFFFFF', () {
      expect(ColorConverter.fromArgb(0xFFFFFFFF).hex, '#FFFFFF');
    });

    test('0xFF000000 → #000000', () {
      expect(ColorConverter.fromArgb(0xFF000000).hex, '#000000');
    });

    test('alpha byte is ignored — 0xFF4A90E2 == 0x004A90E2', () {
      final a = ColorConverter.fromArgb(0xFF4A90E2);
      final b = ColorConverter.fromArgb(0x004A90E2);
      expect(a.hex, b.hex);
    });

    test('round-trip: fromHex → argb → fromArgb is lossless', () {
      final original = ColorConverter.fromHex('#4A90E2');
      final roundTripped = ColorConverter.fromArgb(original.argb);
      expect(roundTripped.hex, original.hex);
    });
  });

  // ===========================================================================
  // ColorConverter.toOklchString
  // ===========================================================================
  group('ColorConverter.toOklchString', () {
    test('format is oklch(L C H) with four decimal places for L and C', () {
      const comp = OklchComponents(l: 0.5, c: 0.1234, h: 120.0);
      final s = ColorConverter.toOklchString(comp);
      expect(s, startsWith('oklch('));
      expect(s, contains('0.5000'));
      expect(s, contains('0.1234'));
    });
  });

  // ===========================================================================
  // HuevoraColor — equality and hashing
  // ===========================================================================
  group('HuevoraColor equality and hashing', () {
    test('same hex → equal and same hashCode', () {
      final a = ColorConverter.fromHex('#4A90E2');
      final b = ColorConverter.fromHex('#4A90E2');
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('lowercase and uppercase hex → equal', () {
      final a = ColorConverter.fromHex('#4a90e2');
      final b = ColorConverter.fromHex('#4A90E2');
      expect(a, equals(b));
    });

    test('different hex → not equal', () {
      final a = ColorConverter.fromHex('#FF0000');
      final b = ColorConverter.fromHex('#0000FF');
      expect(a, isNot(equals(b)));
    });

    test('toString contains hex and OKLCH components', () {
      final c = ColorConverter.fromHex('#4A90E2');
      expect(c.toString(), contains('#4A90E2'));
      expect(c.toString(), contains('oklch'));
    });
  });

  // ===========================================================================
  // GamutGuard
  // ===========================================================================
  group('GamutGuard', () {
    group('isInGamut — must not false-positive on boundary sRGB colors', () {
      test('mid-range sRGB color #4A90E2 is in-gamut', () {
        expect(GamutGuard.isInGamut(ColorConverter.fromHex('#4A90E2')), isTrue);
      });

      test('pure black #000000 is in-gamut', () {
        expect(GamutGuard.isInGamut(ColorConverter.fromHex('#000000')), isTrue);
      });

      test('pure white #FFFFFF is in-gamut', () {
        expect(GamutGuard.isInGamut(ColorConverter.fromHex('#FFFFFF')), isTrue);
      });

      test('pure red #FF0000 is in-gamut', () {
        // R=255 is a legitimate sRGB boundary. The old heuristic incorrectly
        // classified this as out-of-gamut.
        expect(GamutGuard.isInGamut(ColorConverter.fromHex('#FF0000')), isTrue);
      });

      test('pure green #00FF00 is in-gamut', () {
        expect(GamutGuard.isInGamut(ColorConverter.fromHex('#00FF00')), isTrue);
      });

      test('pure blue #0000FF is in-gamut', () {
        expect(GamutGuard.isInGamut(ColorConverter.fromHex('#0000FF')), isTrue);
      });

      test('yellow #FFFF00 is in-gamut', () {
        expect(GamutGuard.isInGamut(ColorConverter.fromHex('#FFFF00')), isTrue);
      });
    });

    group('clip — in-gamut passthrough', () {
      test('in-gamut color is returned with same hex', () {
        final color = ColorConverter.fromHex('#4A90E2');
        final clipped = GamutGuard.clip(color);
        expect(clipped.hex, color.hex);
      });

      test('pure red passes through unchanged', () {
        final color = ColorConverter.fromHex('#FF0000');
        expect(GamutGuard.clip(color).hex, '#FF0000');
      });

      test('pure white passes through unchanged', () {
        final color = ColorConverter.fromHex('#FFFFFF');
        expect(GamutGuard.clip(color).hex, '#FFFFFF');
      });
    });

    group('clip — out-of-gamut reduction', () {
      test('very high chroma OKLCH clips to in-gamut result', () {
        final raw = ColorConverter.fromOklchComponents(const OklchComponents(l: 0.5, c: 0.5, h: 200.0));
        final clipped = GamutGuard.clip(raw);
        expect(GamutGuard.isInGamut(clipped), isTrue);
      });

      test('clipping preserves hue within ±5°', () {
        final raw = ColorConverter.fromOklchComponents(const OklchComponents(l: 0.5, c: 0.5, h: 200.0));
        final clipped = GamutGuard.clip(raw);
        expect((clipped.oklch.h - 200.0).abs(), lessThanOrEqualTo(5.0));
      });

      test('clipped color has lower or equal chroma than source', () {
        final source = ColorConverter.fromOklchComponents(const OklchComponents(l: 0.5, c: 0.5, h: 30.0));
        final clipped = GamutGuard.clip(source);
        expect(clipped.oklch.c, lessThanOrEqualTo(source.oklch.c + 0.001));
      });
    });

    group('clipAll', () {
      test('returns a list of the same length', () {
        final colors = [
          ColorConverter.fromHex('#FF0000'),
          ColorConverter.fromHex('#00FF00'),
          ColorConverter.fromHex('#0000FF'),
        ];
        expect(GamutGuard.clipAll(colors).length, equals(3));
      });

      test('all results are in-gamut', () {
        final colors = [
          ColorConverter.fromOklchComponents(const OklchComponents(l: 0.5, c: 0.5, h: 30.0)),
          ColorConverter.fromOklchComponents(const OklchComponents(l: 0.6, c: 0.5, h: 180.0)),
          ColorConverter.fromHex('#FF0000'),
        ];
        for (final c in GamutGuard.clipAll(colors)) {
          expect(GamutGuard.isInGamut(c), isTrue);
        }
      });

      test('returns a fixed-length list (not growable)', () {
        final result = GamutGuard.clipAll([ColorConverter.fromHex('#4A90E2')]);
        expect(() => result.add(ColorConverter.fromHex('#FF0000')), throwsUnsupportedError);
      });
    });

    group('clipComponents', () {
      test('in-gamut components are returned with same L and H', () {
        const comp = OklchComponents(l: 0.5, c: 0.05, h: 200.0);
        final result = GamutGuard.clipComponents(comp);
        expect(result.l, closeTo(comp.l, 0.001));
        expect((result.h - comp.h).abs(), lessThanOrEqualTo(1.0));
      });

      test('out-of-gamut components are clipped to in-gamut', () {
        const comp = OklchComponents(l: 0.5, c: 0.5, h: 200.0);
        final result = GamutGuard.clipComponents(comp);
        final color = ColorConverter.fromOklchComponents(result);
        expect(GamutGuard.isInGamut(color), isTrue);
      });
    });

    group('assertInSrgb', () {
      test('does not throw for a standard sRGB color', () {
        final color = ColorConverter.fromHex('#4A90E2');
        expect(() => GamutGuard.assertInSrgb(color), returnsNormally);
      });

      test('does not throw for pure red (boundary sRGB color)', () {
        final color = ColorConverter.fromHex('#FF0000');
        expect(() => GamutGuard.assertInSrgb(color), returnsNormally);
      });

      test('does not throw for pure white', () {
        final color = ColorConverter.fromHex('#FFFFFF');
        expect(() => GamutGuard.assertInSrgb(color), returnsNormally);
      });
    });
  });

  // ===========================================================================
  // ColorRole
  // ===========================================================================
  group('ColorRole', () {
    group('isNeutralRole', () {
      test('neutral is a neutral role', () {
        expect(ColorRole.neutral.isNeutralRole, isTrue);
      });

      test('neutralVariant is a neutral role', () {
        expect(ColorRole.neutralVariant.isNeutralRole, isTrue);
      });

      test('primary is not a neutral role', () {
        expect(ColorRole.primary.isNeutralRole, isFalse);
      });

      test('success is not a neutral role', () {
        expect(ColorRole.success.isNeutralRole, isFalse);
      });
    });

    group('isSemanticSignal', () {
      test('success is a semantic signal', () {
        expect(ColorRole.success.isSemanticSignal, isTrue);
      });

      test('error is a semantic signal', () {
        expect(ColorRole.error.isSemanticSignal, isTrue);
      });

      test('warning is a semantic signal', () {
        expect(ColorRole.warning.isSemanticSignal, isTrue);
      });

      test('info is a semantic signal', () {
        expect(ColorRole.info.isSemanticSignal, isTrue);
      });

      test('primary is not a semantic signal', () {
        expect(ColorRole.primary.isSemanticSignal, isFalse);
      });

      test('neutral is not a semantic signal', () {
        expect(ColorRole.neutral.isSemanticSignal, isFalse);
      });

      test('custom is not a semantic signal', () {
        expect(ColorRole.custom.isSemanticSignal, isFalse);
      });
    });
  });

  // ===========================================================================
  // Exception hierarchy
  // ===========================================================================
  group('Exceptions', () {
    group('InvalidHexException', () {
      test('toString contains the original input', () {
        const e = InvalidHexException('not-a-color');
        expect(e.toString(), contains('not-a-color'));
      });

      test('is a HuevoraException', () {
        expect(const InvalidHexException('x'), isA<HuevoraException>());
      });
    });

    group('InvalidChannelValueException', () {
      test('toString contains channel name and value', () {
        const e = InvalidChannelValueException(channel: 'lightness', value: 1.5, min: 0.0, max: 1.0);
        expect(e.toString(), contains('lightness'));
        expect(e.toString(), contains('1.5'));
      });

      test('toString contains the legal range', () {
        const e = InvalidChannelValueException(channel: 'chroma', value: -0.1, min: 0.0, max: double.infinity);
        expect(e.toString(), contains('0.0'));
      });
    });

    group('OutOfGamutException', () {
      test('toString contains sourceHex and clampedHex', () {
        const e = OutOfGamutException(sourceHex: '#SOURCE1', clampedHex: '#CLAMPED');
        expect(e.toString(), contains('#SOURCE1'));
        expect(e.toString(), contains('#CLAMPED'));
      });
    });

    group('HuevoraExportException', () {
      test('toString contains filePath and cause', () {
        const e = HuevoraExportException(filePath: '/tmp/export.json', cause: 'no space left');
        expect(e.toString(), contains('/tmp/export.json'));
        expect(e.toString(), contains('no space left'));
      });
    });
  });
}
