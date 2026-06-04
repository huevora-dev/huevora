import 'dart:math' as math;

import 'package:huevora/src/internal/apca_calculator.dart';
import 'package:huevora/src/models/color_role.dart';

import 'package:huevora/src/models/contrast_result.dart';
import 'package:huevora/src/models/huevora_color.dart';
import 'package:huevora/src/models/tonal_palette_result.dart';

/// Public API for contrast checking between a foreground and background color.
///
/// Core responsibility: given two [HuevoraColor] inputs, compute both APCA Lc
/// and WCAG 2.x contrast ratio, classify them into human-readable ratings, and
/// optionally suggest tone alternatives from a [TonalPaletteResult].
///
/// Abstraction boundary:
/// - Input:  [HuevoraColor] instances.
/// - Output: [ContrastResult] — no internal types exposed.
/// - [ApcaCalculator] is a local implementation detail.
///
/// Key decisions:
/// - Both APCA and WCAG 2.x are always computed — negligible extra cost,
///   richer result.
/// - RGB byte extraction happens here at the API boundary, keeping
///   [ApcaCalculator] free of Huevora types.
/// - Tone suggestions scan all tones in the role's map for |Lc| ≥ 45,
///   sorted highest contrast first.
/// - [ContrastEngine] is instantiable (not static) to match [ColorEngine]
///   ergonomics.
///
/// WCAG linearisation note:
/// WCAG 2.x uses its own piecewise linearisation (different from APCA's pure
/// gamma). Both are implemented here to produce spec-compliant values from
/// each standard independently.
///
/// Limitations:
/// - Large-text WCAG thresholds not modelled in the enum; raw [wcagRatio]
///   is exposed for callers that need them.
/// - Tone suggestions use |Lc| ≥ 45 as the minimum — not configurable in
///   this version.
final class ContrastEngine {
  const ContrastEngine();

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Checks contrast between [foreground] and [background].
  ///
  /// Parameters:
  /// - [foreground]: the text / icon color.
  /// - [background]: the surface color behind the foreground.
  /// - [tonalResult]: optional — enables tone suggestions.
  /// - [fgRole]: role whose tone map is searched for fg suggestions.
  /// - [bgRole]: role whose tone map is searched for bg suggestions.
  ///
  /// Returns a [ContrastResult] with APCA Lc, WCAG ratio, ratings, advice,
  /// and optional tone suggestions. Side effects: none.
  ContrastResult check({
    required HuevoraColor foreground,
    required HuevoraColor background,
    TonalPaletteResult? tonalResult,
    ColorRole? fgRole,
    ColorRole? bgRole,
  }) {
    final fgArgb = foreground.argb;
    final bgArgb = background.argb;

    final fgR = (fgArgb >> 16) & 0xFF;
    final fgG = (fgArgb >> 8) & 0xFF;
    final fgB = fgArgb & 0xFF;

    final bgR = (bgArgb >> 16) & 0xFF;
    final bgG = (bgArgb >> 8) & 0xFF;
    final bgB = bgArgb & 0xFF;

    final apcaLc = ApcaCalculator.computeLc(fgR, fgG, fgB, bgR, bgG, bgB);
    final apcaUsage = ApcaUsageLevel.fromAbsoluteLc(apcaLc.abs());

    final wcagRatio = _wcagContrastRatio(fgR, fgG, fgB, bgR, bgG, bgB);
    final wcagRating = _wcagRating(wcagRatio);

    final advice = _buildAdvice(apcaLc, apcaUsage, wcagRatio, wcagRating);

    List<int>? suggestedFgTones;
    List<int>? suggestedBgTones;

    if (tonalResult != null) {
      if (fgRole != null && fgRole != ColorRole.custom) {
        final candidates = _suggestFgTones(
          fgRole: fgRole,
          bgR: bgR,
          bgG: bgG,
          bgB: bgB,
          tonalResult: tonalResult,
        );
        if (candidates.isNotEmpty) suggestedFgTones = candidates;
      }

      if (bgRole != null && bgRole != ColorRole.custom) {
        final candidates = _suggestBgTones(
          bgRole: bgRole,
          fgR: fgR,
          fgG: fgG,
          fgB: fgB,
          tonalResult: tonalResult,
        );
        if (candidates.isNotEmpty) suggestedBgTones = candidates;
      }
    }

    return ContrastResult(
      apcaLc: apcaLc,
      apcaUsage: apcaUsage,
      wcagRatio: wcagRatio,
      wcagRating: wcagRating,
      advice: advice,
      suggestedFgTones: suggestedFgTones,
      suggestedBgTones: suggestedBgTones,
    );
  }

  // ---------------------------------------------------------------------------
  // WCAG 2.x helpers
  // ---------------------------------------------------------------------------

  /// WCAG 2.x relative luminance — piecewise linearisation per the spec.
  static double _wcagLuminance(int r, int g, int b) {
    double toLinear(int channel) {
      final srgb = channel / 255.0;
      return srgb <= 0.04045
          ? srgb / 12.92
          : math.pow((srgb + 0.055) / 1.055, 2.4).toDouble();
    }

    return 0.2126 * toLinear(r) + 0.7152 * toLinear(g) + 0.0722 * toLinear(b);
  }

  /// WCAG 2.x contrast ratio = (Ylighter + 0.05) / (Ydarker + 0.05). Always ≥ 1.
  static double _wcagContrastRatio(
    int fgR,
    int fgG,
    int fgB,
    int bgR,
    int bgG,
    int bgB,
  ) {
    final Yfg = _wcagLuminance(fgR, fgG, fgB);
    final Ybg = _wcagLuminance(bgR, bgG, bgB);
    final lighter = math.max(Yfg, Ybg);
    final darker = math.min(Yfg, Ybg);
    return (lighter + 0.05) / (darker + 0.05);
  }

  static WcagRating _wcagRating(double ratio) {
    if (ratio >= 7.0) return WcagRating.aaa;
    if (ratio >= 4.5) return WcagRating.aa;
    if (ratio >= 3.0) return WcagRating.aaLargeOnly;
    return WcagRating.fail;
  }

  // ---------------------------------------------------------------------------
  // Advice generation
  // ---------------------------------------------------------------------------

  static String _buildAdvice(
    double apcaLc,
    ApcaUsageLevel apcaUsage,
    double wcagRatio,
    WcagRating wcagRating,
  ) {
    final buffer = StringBuffer();
    final absLc = apcaLc.abs().toStringAsFixed(1);
    final ratioStr = wcagRatio.toStringAsFixed(2);

    buffer.write('APCA Lc ${apcaLc.toStringAsFixed(1)} (|$absLc|): ');
    buffer.write(apcaUsage.description);
    buffer.write('. ');
    buffer.write('WCAG 2.x $ratioStr:1 — ${wcagRating.label}.');

    if (apcaUsage == ApcaUsageLevel.insufficient) {
      final hint = apcaLc >= 0
          ? 'Use a darker foreground or lighter background.'
          : 'Use a lighter foreground or darker background.';
      buffer.write(' Insufficient contrast for text or UI. $hint');
    } else if (wcagRating == WcagRating.fail) {
      buffer.write(
        ' WCAG 2.x ratio is below 3.0. Consider adjusting one color for '
        'broader compatibility with WCAG 2-based tooling.',
      );
    }

    return buffer.toString();
  }

  // ---------------------------------------------------------------------------
  // Tone suggestion helpers
  // ---------------------------------------------------------------------------

  List<int> _suggestFgTones({
    required ColorRole fgRole,
    required int bgR,
    required int bgG,
    required int bgB,
    required TonalPaletteResult tonalResult,
  }) {
    final passing = <MapEntry<int, double>>[];
    for (final entry in tonalResult.getTonesForRole(fgRole).entries) {
      final cArgb = entry.value.argb;
      final lc = ApcaCalculator.computeLc(
        (cArgb >> 16) & 0xFF,
        (cArgb >> 8) & 0xFF,
        cArgb & 0xFF,
        bgR,
        bgG,
        bgB,
      );
      final absLc = lc.abs();
      if (absLc >= 45.0) passing.add(MapEntry(entry.key, absLc));
    }
    passing.sort((a, b) => b.value.compareTo(a.value));
    return passing.map((e) => e.key).toList(growable: false);
  }

  List<int> _suggestBgTones({
    required ColorRole bgRole,
    required int fgR,
    required int fgG,
    required int fgB,
    required TonalPaletteResult tonalResult,
  }) {
    final passing = <MapEntry<int, double>>[];
    for (final entry in tonalResult.getTonesForRole(bgRole).entries) {
      final cArgb = entry.value.argb;
      final lc = ApcaCalculator.computeLc(
        fgR,
        fgG,
        fgB,
        (cArgb >> 16) & 0xFF,
        (cArgb >> 8) & 0xFF,
        cArgb & 0xFF,
      );
      final absLc = lc.abs();
      if (absLc >= 45.0) passing.add(MapEntry(entry.key, absLc));
    }
    passing.sort((a, b) => b.value.compareTo(a.value));
    return passing.map((e) => e.key).toList(growable: false);
  }
}
