/// Raw user-supplied palette input for explicit core palette validation.
///
/// Core responsibility and abstraction boundary:
/// - Carries raw hex strings for every standard palette role.
/// - Preserves optional custom colors in insertion order.
/// - Does not parse, normalize, validate, convert, or check gamut.
///
/// Key decisions:
/// - This type stores [String] values, not validated color objects, so the
///   engine can report validation failures with precise field context.
/// - Named constructor parameters mirror the standard role names and avoid
///   positional-order mistakes.
/// - [customColors] is defensively copied into an unmodifiable list so this
///   object behaves as a stable input snapshot.
///
/// Limitations:
/// - Hex format validation is intentionally deferred to the engine.
/// - Custom color name validation is intentionally deferred to the engine.
/// - Gamut validation is intentionally deferred to the engine.
final class CorePaletteInput {
  /// Raw hex for the primary role.
  final String primary;

  /// Raw hex for the secondary role.
  final String secondary;

  /// Raw hex for the tertiary role.
  final String tertiary;

  /// Raw hex for the neutral role.
  final String neutral;

  /// Raw hex for the neutral variant role.
  final String neutralVariant;

  /// Raw hex for the success semantic signal.
  final String success;

  /// Raw hex for the error semantic signal.
  final String error;

  /// Raw hex for the warning semantic signal.
  final String warning;

  /// Raw hex for the info semantic signal.
  final String info;

  final List<({String name, String hex})> _customColors;

  /// Optional additional colors beyond the standard nine roles.
  ///
  /// The returned list is unmodifiable. Entry name uniqueness and hex validity
  /// are validated by the engine.
  List<({String name, String hex})> get customColors => _customColors;

  /// Creates a raw palette input snapshot.
  ///
  /// Parameters are intentionally unvalidated so the engine can attach precise
  /// role-specific errors during validation.
  factory CorePaletteInput({
    required String primary,
    required String secondary,
    required String tertiary,
    required String neutral,
    required String neutralVariant,
    required String error,
    required String info,
    required String warning,
    required String success,
    List<({String name, String hex})> customColors = const [],
  }) {
    return CorePaletteInput._(
      primary: primary,
      secondary: secondary,
      tertiary: tertiary,
      neutral: neutral,
      neutralVariant: neutralVariant,
      error: error,
      info: info,
      warning: warning,
      success: success,
      customColors: List<({String name, String hex})>.unmodifiable(customColors),
    );
  }

  const CorePaletteInput._({
    required this.primary,
    required this.secondary,
    required this.tertiary,
    required this.neutral,
    required this.neutralVariant,
    required this.error,
    required this.info,
    required this.warning,
    required this.success,
    required List<({String name, String hex})> customColors,
    // ignore: prefer_initializing_formals
  }) : _customColors = customColors;
}
