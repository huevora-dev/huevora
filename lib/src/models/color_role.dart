/// Typed enumeration of every semantic color role Huevora manages.
///
/// Core responsibility: give the rest of the system a closed, compile-time
/// checked vocabulary of color roles so no stringly-typed role names leak
/// into any API or serialisation boundary.
///
/// Key decisions:
/// - [custom] is the catch-all for user-supplied colors that do not map to a
///   standard semantic role. Named custom colors are tracked separately in
///   [CorePalette] via a record list keyed by user-provided name strings.
/// - Neutral roles are separated ([neutral] vs [neutralVariant]) because they
///   require different tonal generation parameters in downstream phases.
///
/// Limitations:
/// - Does not encode light/dark theme variants — those are concerns of the
///   tonal palette layer, not the role layer.
enum ColorRole {
  primary,
  secondary,
  tertiary,
  neutral,
  neutralVariant,
  success,
  error,
  warning,
  info,

  /// Catch-all for user-supplied colors not covered by a standard role.
  custom;

  /// Whether this role uses the neutral-specific tonal step array.
  ///
  /// Neutral roles require denser steps at the dark and light extremes to
  /// support elevation overlays and surface tints at precise tone values.
  bool get isNeutralRole => this == neutral || this == neutralVariant;

  /// Whether this role is a semantic signal color (success / error / etc.).
  ///
  /// Semantic signal colors undergo hue blending toward the primary during
  /// derivation to produce branded-but-recognisable output.
  bool get isSemanticSignal => this == success || this == error || this == warning || this == info;
}
