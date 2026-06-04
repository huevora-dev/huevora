/// Configuration flags controlling export output shape.
///
/// Core responsibility and abstraction boundary:
/// - Carry inclusion flags for export sections.
/// - Decide whether OKLCH strings are included beside hex values.
/// - Remain a pure Dart value object with no engine dependencies.
///
/// Key decisions:
/// - The default mode is opt-out: all sections and representations are enabled.
/// - OKLCH inclusion is independent of section inclusion.
/// - Named constructors cover common export profiles while redirecting through
///   the primary constructor to keep defaults centralized.
///
/// Limitations:
/// - Does not control role ordering.
/// - Does not control file encoding.
final class ExportConfig {
  /// Whether to include the core palette section.
  final bool includeCorePalette;

  /// Whether to include the tonal palettes section.
  final bool includeTonalPalettes;

  /// Whether to include OKLCH strings beside hex values.
  final bool includeOklch;

  /// Creates an [ExportConfig] with explicit flag values.
  const ExportConfig({
    this.includeCorePalette = true,
    this.includeTonalPalettes = true,
    this.includeOklch = true,
  });

  /// Includes every export section and representation.
  const ExportConfig.full() : this();

  /// Includes both sections in hex-only mode.
  const ExportConfig.hexOnly()
    : this(
        includeCorePalette: true,
        includeTonalPalettes: true,
        includeOklch: false,
      );

  /// Includes only the core palette section.
  const ExportConfig.coreOnly()
    : this(
        includeCorePalette: true,
        includeTonalPalettes: false,
        includeOklch: true,
      );

  /// Includes only the tonal palettes section.
  const ExportConfig.tonalOnly()
    : this(
        includeCorePalette: false,
        includeTonalPalettes: true,
        includeOklch: true,
      );

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ExportConfig &&
            includeCorePalette == other.includeCorePalette &&
            includeTonalPalettes == other.includeTonalPalettes &&
            includeOklch == other.includeOklch;
  }

  @override
  int get hashCode {
    return Object.hash(includeCorePalette, includeTonalPalettes, includeOklch);
  }

  @override
  String toString() {
    return 'ExportConfig('
        'includeCorePalette: $includeCorePalette, '
        'includeTonalPalettes: $includeTonalPalettes, '
        'includeOklch: $includeOklch'
        ')';
  }
}
