import 'package:test/test.dart';

import 'package:huevora/huevora.dart';
import 'package:huevora/src/internal/apca_calculator.dart';
import 'package:huevora/src/internal/color_converter.dart';

void main() {
  // ===========================================================================
  // ApcaCalculator — unit tests against known reference values
  // ===========================================================================
  group('ApcaCalculator.computeLc', () {
    group('black on white (maximum positive Lc)', () {
      test('Lc is approximately +106', () {
        expect(
          ApcaCalculator.computeLc(0, 0, 0, 255, 255, 255),
          closeTo(106.0, 2.0),
        );
      });

      test('Lc is positive (dark fg on light bg)', () {
        expect(
          ApcaCalculator.computeLc(0, 0, 0, 255, 255, 255),
          greaterThan(0.0),
        );
      });
    });

    group('white on black (maximum negative Lc)', () {
      test('Lc is approximately −108', () {
        expect(
          ApcaCalculator.computeLc(255, 255, 255, 0, 0, 0),
          closeTo(-107.9, 2.0),
        );
      });

      test('Lc is negative (light fg on dark bg)', () {
        expect(ApcaCalculator.computeLc(255, 255, 255, 0, 0, 0), lessThan(0.0));
      });
    });

    group('identical colors → Lc = 0.0', () {
      test('white on white', () {
        expect(ApcaCalculator.computeLc(255, 255, 255, 255, 255, 255), 0.0);
      });

      test('black on black', () {
        expect(ApcaCalculator.computeLc(0, 0, 0, 0, 0, 0), 0.0);
      });

      test('mid-grey on mid-grey', () {
        expect(ApcaCalculator.computeLc(128, 128, 128, 128, 128, 128), 0.0);
      });
    });

    group('APCA asymmetry — dark-on-light ≠ light-on-dark in |Lc|', () {
      test('|Lc(A on B)| ≠ |Lc(B on A)| for non-trivial pairs', () {
        final fwd = ApcaCalculator.computeLc(50, 50, 50, 200, 200, 200).abs();
        final rev = ApcaCalculator.computeLc(200, 200, 200, 50, 50, 50).abs();
        expect((fwd - rev).abs(), greaterThan(0.0));
      });
    });

    group('ApcaUsageLevel.fromAbsoluteLc — threshold boundaries', () {
      test('|Lc| = 106 → fluentText', () {
        final lc = ApcaCalculator.computeLc(0, 0, 0, 255, 255, 255);
        expect(
          ApcaUsageLevel.fromAbsoluteLc(lc.abs()),
          ApcaUsageLevel.fluentText,
        );
      });

      test('|Lc| = 90.0 → fluentText', () {
        expect(ApcaUsageLevel.fromAbsoluteLc(90.0), ApcaUsageLevel.fluentText);
      });

      test('|Lc| = 89.9 → bodyText', () {
        expect(ApcaUsageLevel.fromAbsoluteLc(89.9), ApcaUsageLevel.bodyText);
      });

      test('|Lc| = 75.0 → bodyText', () {
        expect(ApcaUsageLevel.fromAbsoluteLc(75.0), ApcaUsageLevel.bodyText);
      });

      test('|Lc| = 74.9 → largeText', () {
        expect(ApcaUsageLevel.fromAbsoluteLc(74.9), ApcaUsageLevel.largeText);
      });

      test('|Lc| = 60.0 → largeText', () {
        expect(ApcaUsageLevel.fromAbsoluteLc(60.0), ApcaUsageLevel.largeText);
      });

      test('|Lc| = 59.9 → uiComponent', () {
        expect(ApcaUsageLevel.fromAbsoluteLc(59.9), ApcaUsageLevel.uiComponent);
      });

      test('|Lc| = 45.0 → uiComponent', () {
        expect(ApcaUsageLevel.fromAbsoluteLc(45.0), ApcaUsageLevel.uiComponent);
      });

      test('|Lc| = 44.9 → insufficient', () {
        expect(
          ApcaUsageLevel.fromAbsoluteLc(44.9),
          ApcaUsageLevel.insufficient,
        );
      });

      test('|Lc| = 0.0 → insufficient', () {
        expect(ApcaUsageLevel.fromAbsoluteLc(0.0), ApcaUsageLevel.insufficient);
      });
    });
  });

  // ===========================================================================
  // WcagRating enum
  // ===========================================================================
  group('WcagRating', () {
    test('aaa.isPass is true', () => expect(WcagRating.aaa.isPass, isTrue));
    test('aa.isPass is true', () => expect(WcagRating.aa.isPass, isTrue));

    test('aaLargeOnly.isPass is false', () {
      expect(WcagRating.aaLargeOnly.isPass, isFalse);
    });

    test('fail.isPass is false', () => expect(WcagRating.fail.isPass, isFalse));

    test('aaa.label is "AAA"', () => expect(WcagRating.aaa.label, 'AAA'));
    test('fail.label is "Fail"', () => expect(WcagRating.fail.label, 'Fail'));

    test('aaLargeOnly.label mentions large text', () {
      expect(WcagRating.aaLargeOnly.label.toLowerCase(), contains('large'));
    });
  });

  // ===========================================================================
  // ApcaUsageLevel enum
  // ===========================================================================
  group('ApcaUsageLevel', () {
    test('fluentText.description is non-empty', () {
      expect(ApcaUsageLevel.fluentText.description, isNotEmpty);
    });

    test('insufficient.description mentions insufficient', () {
      expect(
        ApcaUsageLevel.insufficient.description.toLowerCase(),
        contains('insufficient'),
      );
    });
  });

  // ===========================================================================
  // ContrastResult model
  // ===========================================================================
  group('ContrastResult model', () {
    late ContrastResult high;
    late ContrastResult low;

    setUp(() {
      high = ContrastEngine().check(
        foreground: ColorConverter.fromHex('#000000'),
        background: ColorConverter.fromHex('#FFFFFF'),
      );
      low = ContrastEngine().check(
        foreground: ColorConverter.fromHex('#777777'),
        background: ColorConverter.fromHex('#888888'),
      );
    });

    group('black on white', () {
      test('apcaLc ≈ +106', () => expect(high.apcaLc, closeTo(106.0, 2.0)));
      test(
        'apcaUsage is fluentText',
        () => expect(high.apcaUsage, ApcaUsageLevel.fluentText),
      );
      test(
        'wcagRatio ≈ 21.0',
        () => expect(high.wcagRatio, closeTo(21.0, 0.1)),
      );
      test('wcagRating is aaa', () => expect(high.wcagRating, WcagRating.aaa));
      test('passesWcagAA', () => expect(high.passesWcagAA, isTrue));
      test('passesWcagAAA', () => expect(high.passesWcagAAA, isTrue));
      test('passesApcaBodyText', () => expect(high.passesApcaBodyText, isTrue));
      test(
        'passesApcaUiMinimum',
        () => expect(high.passesApcaUiMinimum, isTrue),
      );
      test('advice is non-empty', () => expect(high.advice, isNotEmpty));
      test(
        'advice contains APCA',
        () => expect(high.advice.toLowerCase(), contains('apca')),
      );
      test(
        'advice contains WCAG',
        () => expect(high.advice.toLowerCase(), contains('wcag')),
      );
      test(
        'suggestedFgTones is null (no palette)',
        () => expect(high.suggestedFgTones, isNull),
      );
      test(
        'suggestedBgTones is null (no palette)',
        () => expect(high.suggestedBgTones, isNull),
      );
    });

    group('low contrast (similar greys)', () {
      test('passesWcagAA is false', () => expect(low.passesWcagAA, isFalse));
      test(
        'passesApcaBodyText is false',
        () => expect(low.passesApcaBodyText, isFalse),
      );
      test('wcagRating is fail', () => expect(low.wcagRating, WcagRating.fail));
      test(
        'apcaUsage is insufficient',
        () => expect(low.apcaUsage, ApcaUsageLevel.insufficient),
      );
      test('advice mentions improvement', () {
        expect(
          low.advice.toLowerCase(),
          anyOf(
            contains('insufficient'),
            contains('adjust'),
            contains('darker'),
            contains('lighter'),
          ),
        );
      });
    });

    group('white on black', () {
      test('apcaLc is negative (light on dark)', () {
        final r = ContrastEngine().check(
          foreground: ColorConverter.fromHex('#FFFFFF'),
          background: ColorConverter.fromHex('#000000'),
        );
        expect(r.apcaLc, lessThan(0.0));
      });

      test('wcagRatio is still ≈ 21.0 (ratio is order-independent)', () {
        final r = ContrastEngine().check(
          foreground: ColorConverter.fromHex('#FFFFFF'),
          background: ColorConverter.fromHex('#000000'),
        );
        expect(r.wcagRatio, closeTo(21.0, 0.1));
      });
    });

    group('WCAG boundary cases', () {
      test('#767676 on #FFFFFF passes WCAG AA', () {
        final r = ContrastEngine().check(
          foreground: ColorConverter.fromHex('#767676'),
          background: ColorConverter.fromHex('#FFFFFF'),
        );
        expect(r.wcagRating.isPass, isTrue);
      });

      test('#777777 on #FFFFFF fails WCAG AA', () {
        final r = ContrastEngine().check(
          foreground: ColorConverter.fromHex('#777777'),
          background: ColorConverter.fromHex('#FFFFFF'),
        );
        expect(r.wcagRating, isNot(WcagRating.aa));
        expect(r.wcagRating, isNot(WcagRating.aaa));
      });

      test('identical colors → wcagRatio = 1.0', () {
        final r = ContrastEngine().check(
          foreground: ColorConverter.fromHex('#4A90E2'),
          background: ColorConverter.fromHex('#4A90E2'),
        );
        expect(r.wcagRatio, closeTo(1.0, 0.01));
        expect(r.wcagRating, WcagRating.fail);
      });
    });

    test('toString contains apcaLc and wcagRatio', () {
      expect(high.toString(), contains('apcaLc'));
      expect(high.toString(), contains('wcagRatio'));
    });
  });

  // ===========================================================================
  // ContrastEngine — tone suggestions
  // ===========================================================================
  group('ContrastEngine tone suggestions', () {
    final ce = ColorEngine();

    test('suggestedFgTones is populated when palette + role supplied', () {
      final palette = ce.deriveCorePalette('#4A90E2');
      final tonals = ce.generateTonalPalettes(palette);
      final result = ContrastEngine().check(
        foreground: palette.primary,
        background: ColorConverter.fromHex('#FFFFFF'),
        tonalResult: tonals,
        fgRole: ColorRole.primary,
      );
      expect(result.suggestedFgTones, isNotNull);
      expect(result.suggestedFgTones, isNotEmpty);
    });

    test('suggestedBgTones is populated when palette + role supplied', () {
      final palette = ce.deriveCorePalette('#4A90E2');
      final tonals = ce.generateTonalPalettes(palette);
      final result = ContrastEngine().check(
        foreground: ColorConverter.fromHex('#000000'),
        background: palette.neutral,
        tonalResult: tonals,
        bgRole: ColorRole.neutral,
      );
      expect(result.suggestedBgTones, isNotNull);
      expect(result.suggestedBgTones, isNotEmpty);
    });

    test('all suggested fg tones meet |Lc| ≥ 45 against the background', () {
      final palette = ce.deriveCorePalette('#4A90E2');
      final tonals = ce.generateTonalPalettes(palette);
      final white = ColorConverter.fromHex('#FFFFFF');
      final result = ContrastEngine().check(
        foreground: palette.primary,
        background: white,
        tonalResult: tonals,
        fgRole: ColorRole.primary,
      );

      if (result.suggestedFgTones != null) {
        final bgArgb = white.argb;
        final bgR = (bgArgb >> 16) & 0xFF;
        final bgG = (bgArgb >> 8) & 0xFF;
        final bgB = bgArgb & 0xFF;

        for (final tone in result.suggestedFgTones!) {
          final color = tonals.getTonesForRole(ColorRole.primary)[tone]!;
          final cArgb = color.argb;
          final absLc = ApcaCalculator.computeLc(
            (cArgb >> 16) & 0xFF,
            (cArgb >> 8) & 0xFF,
            cArgb & 0xFF,
            bgR,
            bgG,
            bgB,
          ).abs();
          expect(
            absLc,
            greaterThanOrEqualTo(45.0),
            reason: 'Tone $tone has |Lc|=$absLc below minimum',
          );
        }
      }
    });

    test('suggestions are null without tonalResult', () {
      final r = ContrastEngine().check(
        foreground: ColorConverter.fromHex('#000000'),
        background: ColorConverter.fromHex('#FFFFFF'),
      );
      expect(r.suggestedFgTones, isNull);
      expect(r.suggestedBgTones, isNull);
    });

    test('suggestions are null when ColorRole.custom is supplied', () {
      final palette = ce.deriveCorePalette('#4A90E2');
      final tonals = ce.generateTonalPalettes(palette);
      final result = ContrastEngine().check(
        foreground: palette.primary,
        background: ColorConverter.fromHex('#FFFFFF'),
        tonalResult: tonals,
        fgRole: ColorRole.custom,
      );
      expect(result.suggestedFgTones, isNull);
    });
  });

  // ===========================================================================
  // ContrastEngine — integration
  // ===========================================================================
  group('ContrastEngine integration', () {
    final ce = ColorEngine();
    final contrast = ContrastEngine();

    test('all nine role colors checked against white without throwing', () {
      final palette = ce.deriveCorePalette('#4A90E2');
      final white = ce.fromHex('#FFFFFF');
      for (final color in palette.asMap().values) {
        expect(
          () => contrast.check(foreground: color, background: white),
          returnsNormally,
          reason: 'Failed for ${color.hex}',
        );
      }
    });

    test('all nine role colors checked against black without throwing', () {
      final palette = ce.deriveCorePalette('#4A90E2');
      final black = ce.fromHex('#000000');
      for (final color in palette.asMap().values) {
        expect(
          () => contrast.check(foreground: color, background: black),
          returnsNormally,
          reason: 'Failed for ${color.hex}',
        );
      }
    });

    test('wcagRatio is always ≥ 1.0 across all tonal palette entries', () {
      final palette = ce.deriveCorePalette('#4A90E2');
      final tonals = ce.generateTonalPalettes(palette);
      final white = ce.fromHex('#FFFFFF');

      for (final toneMap in tonals.tones.values) {
        for (final color in toneMap.values) {
          final r = contrast.check(foreground: color, background: white);
          expect(r.wcagRatio, greaterThanOrEqualTo(1.0));
        }
      }
    });

    test('passesApcaUiMinimum implies |apcaLc| ≥ 45', () {
      final palette = ce.deriveCorePalette('#4A90E2');
      final white = ce.fromHex('#FFFFFF');

      for (final color in palette.asMap().values) {
        final r = contrast.check(foreground: color, background: white);
        if (r.passesApcaUiMinimum) {
          expect(r.apcaLc.abs(), greaterThanOrEqualTo(45.0));
        }
      }
    });
  });
}
