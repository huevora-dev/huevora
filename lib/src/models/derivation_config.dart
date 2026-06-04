/// Configuration for Huevora's palette derivation algorithm.
///
/// Core responsibility and abstraction boundary:
/// - Carries derivation parameters only.
/// - Does not perform palette derivation, color conversion, gamut validation,
///   or custom color parsing.
/// - Keeps custom color input as raw strings so validation remains at the
///   engine boundary.
///
/// Key decisions:
/// - Defaults are centralized as constants to keep constructor behavior and
///   documentation aligned.
/// - Numeric invariants are validated at construction because invalid bounds
///   make later derivation ambiguous.
/// - Custom colors are defensively copied so this value object is stable after
///   construction.
///
/// Limitations:
/// - Does not validate custom color names or hex strings.
/// - Does not normalize hue offsets.
final class DerivationConfig {
  static const double defaultSemanticBrandingWeight = 0.25;
  static const double defaultSecondaryHueOffset = 30.0;

  static const double defaultNeutralMinChroma = 0.002;
  static const double defaultNeutralMaxChroma = 0.006;

  static const double defaultNeutralVariantMinChroma = 0.004;
  static const double defaultNeutralVariantMaxChroma = 0.010;

  static const double defaultSemanticMinChroma = 0.012;
  static const double defaultSemanticMaxChroma = 0.048;

  /// How strongly semantic signal colors are pulled toward the primary hue.
  ///
  /// Must be finite and in `[0.0, 1.0]`.
  final double semanticBrandingWeight;

  /// Angular offset in degrees added to the primary hue for secondary.
  ///
  /// May be any finite value. The derivation algorithm normalizes it when used.
  final double secondaryHueOffset;

  /// Minimum chroma for the neutral role.
  final double neutralMinChroma;

  /// Maximum chroma for the neutral role.
  final double neutralMaxChroma;

  /// Minimum chroma for the neutral variant role.
  final double neutralVariantMinChroma;

  /// Maximum chroma for the neutral variant role.
  final double neutralVariantMaxChroma;

  /// Minimum chroma for semantic roles.
  final double semanticMinChroma;

  /// Maximum chroma for semantic roles.
  final double semanticMaxChroma;

  final List<({String name, String hex})> _customColors;

  /// User-supplied additional colors to include alongside the derived palette.
  ///
  /// The returned list is unmodifiable. Name and hex validation is deferred to
  /// the engine boundary.
  List<({String name, String hex})> get customColors => _customColors;

  /// Creates a [DerivationConfig] with explicit derivation parameters.
  factory DerivationConfig({
    double semanticBrandingWeight = defaultSemanticBrandingWeight,
    double secondaryHueOffset = defaultSecondaryHueOffset,
    double neutralMinChroma = defaultNeutralMinChroma,
    double neutralMaxChroma = defaultNeutralMaxChroma,
    double neutralVariantMinChroma = defaultNeutralVariantMinChroma,
    double neutralVariantMaxChroma = defaultNeutralVariantMaxChroma,
    double semanticMinChroma = defaultSemanticMinChroma,
    double semanticMaxChroma = defaultSemanticMaxChroma,
    List<({String name, String hex})> customColors = const [],
  }) {
    _validateUnitInterval('semanticBrandingWeight', semanticBrandingWeight);
    _validateFinite('secondaryHueOffset', secondaryHueOffset);
    _validateChromaRange('neutral', neutralMinChroma, neutralMaxChroma);
    _validateChromaRange('neutralVariant', neutralVariantMinChroma, neutralVariantMaxChroma);
    _validateChromaRange('semantic', semanticMinChroma, semanticMaxChroma);

    return DerivationConfig._(
      semanticBrandingWeight: semanticBrandingWeight,
      secondaryHueOffset: secondaryHueOffset,
      neutralMinChroma: neutralMinChroma,
      neutralMaxChroma: neutralMaxChroma,
      neutralVariantMinChroma: neutralVariantMinChroma,
      neutralVariantMaxChroma: neutralVariantMaxChroma,
      semanticMinChroma: semanticMinChroma,
      semanticMaxChroma: semanticMaxChroma,
      customColors: List<({String name, String hex})>.unmodifiable(customColors),
    );
  }

  /// Standard Material 3-aligned defaults.
  factory DerivationConfig.standard() => DerivationConfig();

  DerivationConfig._({
    required this.semanticBrandingWeight,
    required this.secondaryHueOffset,
    required this.neutralMinChroma,
    required this.neutralMaxChroma,
    required this.neutralVariantMinChroma,
    required this.neutralVariantMaxChroma,
    required this.semanticMinChroma,
    required this.semanticMaxChroma,
    required List<({String name, String hex})> customColors,
  }) : _customColors = customColors;

  static void _validateUnitInterval(String name, double value) {
    if (!value.isFinite || value < 0.0 || value > 1.0) {
      throw ArgumentError.value(value, name, 'Must be finite and in [0.0, 1.0].');
    }
  }

  static void _validateFinite(String name, double value) {
    if (!value.isFinite) {
      throw ArgumentError.value(value, name, 'Must be finite.');
    }
  }

  static void _validateChromaRange(String name, double min, double max) {
    if (!min.isFinite || min < 0.0) {
      throw ArgumentError.value(min, '${name}MinChroma', 'Must be finite and >= 0.0.');
    }

    if (!max.isFinite || max < 0.0) {
      throw ArgumentError.value(max, '${name}MaxChroma', 'Must be finite and >= 0.0.');
    }

    if (min > max) {
      throw ArgumentError(
        '${name}MinChroma must be <= ${name}MaxChroma. '
        'Received min=$min, max=$max.',
      );
    }
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is DerivationConfig &&
            semanticBrandingWeight == other.semanticBrandingWeight &&
            secondaryHueOffset == other.secondaryHueOffset &&
            neutralMinChroma == other.neutralMinChroma &&
            neutralMaxChroma == other.neutralMaxChroma &&
            neutralVariantMinChroma == other.neutralVariantMinChroma &&
            neutralVariantMaxChroma == other.neutralVariantMaxChroma &&
            semanticMinChroma == other.semanticMinChroma &&
            semanticMaxChroma == other.semanticMaxChroma &&
            _recordsEqual(customColors, other.customColors);
  }

  @override
  int get hashCode => Object.hash(
    semanticBrandingWeight,
    secondaryHueOffset,
    neutralMinChroma,
    neutralMaxChroma,
    neutralVariantMinChroma,
    neutralVariantMaxChroma,
    semanticMinChroma,
    semanticMaxChroma,
    Object.hashAll(customColors),
  );

  @override
  String toString() {
    return 'DerivationConfig('
        'semanticBrandingWeight: $semanticBrandingWeight, '
        'secondaryHueOffset: $secondaryHueOffset, '
        'neutralChroma: [$neutralMinChroma, $neutralMaxChroma], '
        'neutralVariantChroma: [$neutralVariantMinChroma, $neutralVariantMaxChroma], '
        'semanticChroma: [$semanticMinChroma, $semanticMaxChroma], '
        'customColors: ${customColors.length}'
        ')';
  }

  static bool _recordsEqual(List<({String name, String hex})> left, List<({String name, String hex})> right) {
    if (identical(left, right)) return true;
    if (left.length != right.length) return false;

    for (var index = 0; index < left.length; index++) {
      final leftEntry = left[index];
      final rightEntry = right[index];

      if (leftEntry.name != rightEntry.name || leftEntry.hex != rightEntry.hex) {
        return false;
      }
    }

    return true;
  }
}
