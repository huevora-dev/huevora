/// Immutable result of a contrast check.
///
/// Core responsibility and abstraction boundary:
/// - Carries APCA and WCAG contrast metrics.
/// - Carries ratings derived from those metrics.
/// - Optionally carries tone suggestions computed by the contrast engine.
///
/// Key decisions:
/// - The factory validates derived ratings so impossible result states cannot
///   be represented.
/// - Suggestion lists are copied into unmodifiable lists.
/// - This model does not calculate contrast from colors; it only protects
///   already-computed result invariants.
///
/// Limitations:
/// - Does not model WCAG large-text pass helpers beyond [WcagRating].
/// - APCA thresholds are classification thresholds, not WCAG 3 conformance.
final class ContrastResult {
  static const double _minWcagRatio = 1.0;
  static const double _wcagAaaThreshold = 7.0;
  static const double _wcagAaThreshold = 4.5;
  static const double _wcagLargeTextThreshold = 3.0;

  /// Signed APCA Lc value.
  final double apcaLc;

  /// APCA usage level derived from [apcaLc.abs()].
  final ApcaUsageLevel apcaUsage;

  /// WCAG 2.x contrast ratio. Always `>= 1.0`.
  final double wcagRatio;

  /// WCAG 2.x compliance rating derived from [wcagRatio].
  final WcagRating wcagRating;

  /// Plain-language guidance.
  final String advice;

  final List<int>? _suggestedFgTones;
  final List<int>? _suggestedBgTones;

  /// Tone numbers from the foreground role that satisfy the engine threshold.
  List<int>? get suggestedFgTones => _suggestedFgTones;

  /// Tone numbers from the background role that satisfy the engine threshold.
  List<int>? get suggestedBgTones => _suggestedBgTones;

  const ContrastResult._({
    required this.apcaLc,
    required this.apcaUsage,
    required this.wcagRatio,
    required this.wcagRating,
    required this.advice,
    List<int>? suggestedFgTones,
    List<int>? suggestedBgTones,
  }) : _suggestedFgTones = suggestedFgTones,
       _suggestedBgTones = suggestedBgTones;

  factory ContrastResult({
    required double apcaLc,
    required ApcaUsageLevel apcaUsage,
    required double wcagRatio,
    required WcagRating wcagRating,
    required String advice,
    List<int>? suggestedFgTones,
    List<int>? suggestedBgTones,
  }) {
    _validateMetrics(apcaLc: apcaLc, wcagRatio: wcagRatio);
    _validateAdvice(advice);
    _validateApcaUsage(apcaLc: apcaLc, apcaUsage: apcaUsage);
    _validateWcagRating(wcagRatio: wcagRatio, wcagRating: wcagRating);

    return ContrastResult._(
      apcaLc: apcaLc,
      apcaUsage: apcaUsage,
      wcagRatio: wcagRatio,
      wcagRating: wcagRating,
      advice: advice,
      suggestedFgTones: _freezeSuggestions(suggestedFgTones),
      suggestedBgTones: _freezeSuggestions(suggestedBgTones),
    );
  }

  /// Whether the pair passes WCAG 2.x AA for normal text.
  bool get passesWcagAA => wcagRating.isPass;

  /// Whether the pair passes WCAG 2.x AAA for normal text.
  bool get passesWcagAAA => wcagRating == WcagRating.aaa;

  /// Whether the pair meets APCA minimum for UI components.
  bool get passesApcaUiMinimum => apcaUsage != ApcaUsageLevel.insufficient;

  /// Whether the pair meets APCA minimum for body text.
  bool get passesApcaBodyText => apcaUsage == ApcaUsageLevel.bodyText || apcaUsage == ApcaUsageLevel.fluentText;

  @override
  String toString() {
    return 'ContrastResult('
        'apcaLc: ${apcaLc.toStringAsFixed(1)}, '
        'apcaUsage: ${apcaUsage.name}, '
        'wcagRatio: ${wcagRatio.toStringAsFixed(2)}:1, '
        'wcagRating: ${wcagRating.name}'
        ')';
  }

  static void _validateMetrics({required double apcaLc, required double wcagRatio}) {
    if (!apcaLc.isFinite) {
      throw ArgumentError.value(apcaLc, 'apcaLc', 'Must be finite.');
    }

    if (!wcagRatio.isFinite || wcagRatio < _minWcagRatio) {
      throw ArgumentError.value(wcagRatio, 'wcagRatio', 'Must be finite and >= 1.0.');
    }
  }

  static void _validateAdvice(String advice) {
    if (advice.trim().isEmpty) {
      throw ArgumentError.value(advice, 'advice', 'Must be non-empty.');
    }
  }

  static void _validateApcaUsage({required double apcaLc, required ApcaUsageLevel apcaUsage}) {
    final expected = ApcaUsageLevel.fromAbsoluteLc(apcaLc.abs());

    if (apcaUsage != expected) {
      throw ArgumentError.value(apcaUsage, 'apcaUsage', 'Must match apcaLc.abs(). Expected ${expected.name}.');
    }
  }

  static void _validateWcagRating({required double wcagRatio, required WcagRating wcagRating}) {
    final expected = _ratingForWcagRatio(wcagRatio);

    if (wcagRating != expected) {
      throw ArgumentError.value(wcagRating, 'wcagRating', 'Must match wcagRatio. Expected ${expected.name}.');
    }
  }

  static WcagRating _ratingForWcagRatio(double ratio) {
    if (ratio >= _wcagAaaThreshold) return WcagRating.aaa;
    if (ratio >= _wcagAaThreshold) return WcagRating.aa;
    if (ratio >= _wcagLargeTextThreshold) return WcagRating.aaLargeOnly;
    return WcagRating.fail;
  }

  static List<int>? _freezeSuggestions(List<int>? tones) {
    if (tones == null || tones.isEmpty) {
      return null;
    }

    return List<int>.unmodifiable(tones);
  }
}

/// WCAG 2.x compliance level.
enum WcagRating {
  /// Ratio `>= 7.0`.
  aaa,

  /// `4.5 <= ratio < 7.0`.
  aa,

  /// `3.0 <= ratio < 4.5`.
  aaLargeOnly,

  /// Ratio `< 3.0`.
  fail;

  /// Whether this rating passes normal-text AA.
  bool get isPass => this == aa || this == aaa;

  /// Human-readable label.
  String get label => switch (this) {
    WcagRating.aaa => 'AAA',
    WcagRating.aa => 'AA',
    WcagRating.aaLargeOnly => 'AA (large text only)',
    WcagRating.fail => 'Fail',
  };
}

/// APCA usage classification derived from absolute Lc value.
enum ApcaUsageLevel {
  fluentText,
  bodyText,
  largeText,
  uiComponent,
  insufficient;

  static ApcaUsageLevel fromAbsoluteLc(double absLc) {
    if (!absLc.isFinite || absLc < 0.0) {
      throw ArgumentError.value(absLc, 'absLc', 'Must be finite and non-negative.');
    }

    if (absLc >= 90.0) return fluentText;
    if (absLc >= 75.0) return bodyText;
    if (absLc >= 60.0) return largeText;
    if (absLc >= 45.0) return uiComponent;
    return insufficient;
  }

  String get description => switch (this) {
    ApcaUsageLevel.fluentText => 'Fluent body text at any size',
    ApcaUsageLevel.bodyText => 'Body text and subheadings',
    ApcaUsageLevel.largeText => 'Large text and UI components',
    ApcaUsageLevel.uiComponent => 'Non-text UI elements and icons',
    ApcaUsageLevel.insufficient => 'Insufficient for text or UI use',
  };
}
