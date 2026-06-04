/// Sealed exception hierarchy for Huevora.
///
/// Core responsibility: give callers exhaustive pattern-matching over all
/// failure modes without stringly-typed error codes.
///
/// Key decisions:
/// - Sealed so the compiler forces exhaustive handling at call sites.
/// - [OutOfGamutException] carries a pre-computed safe alternative so callers
///   never need to re-derive a fallback themselves.
/// - [HuevoraExportException] wraps the underlying cause to preserve the
///   original stack information.
///
/// Limitations:
/// - Does not model async cancellation — that is the caller's concern.
sealed class HuevoraException implements Exception {
  const HuevoraException();
}

/// Thrown when a hex string cannot be parsed as a valid #RRGGBB or #RGB color.
///
/// Guarantees:
/// - [input] is always the raw, unmodified string the caller supplied.
final class InvalidHexException extends HuevoraException {
  /// The raw input string that failed to parse.
  final String input;

  const InvalidHexException(this.input);

  @override
  String toString() =>
      'InvalidHexException: "$input" is not a valid hex color. '
      'Expected #RRGGBB or #RGB format.';
}

/// Thrown when a color's channel values fall outside their legal range.
///
/// Guarantees:
/// - [channel] names the specific out-of-range channel (e.g. "lightness",
///   "chroma", "hue", "r", "g", "b").
/// - [value] is the actual value that violated the constraint.
/// - [min] and [max] state the legal closed interval.
final class InvalidChannelValueException extends HuevoraException {
  /// Name of the channel that violated its constraint.
  final String channel;

  /// The value that was out of range.
  final double value;

  /// Minimum legal value (inclusive).
  final double min;

  /// Maximum legal value (inclusive).
  final double max;

  const InvalidChannelValueException({
    required this.channel,
    required this.value,
    required this.min,
    required this.max,
  });

  @override
  String toString() =>
      'InvalidChannelValueException: channel "$channel" value $value is '
      'outside the valid range [$min, $max].';
}

/// Thrown in strict-validation contexts when a color is outside the sRGB gamut.
///
/// In normal operation the engine clips rather than throws; this exception is
/// only raised when the caller explicitly opts into strict mode via
/// [GamutGuard.assertInSrgb].
///
/// Guarantees:
/// - [clampedHex] always holds a valid sRGB alternative produced by
///   CSS Color 4 gamut clipping (chroma reduction).
final class OutOfGamutException extends HuevoraException {
  /// The out-of-gamut hex string that triggered the exception.
  final String sourceHex;

  /// A clipped, in-gamut alternative at the same perceived hue and lightness.
  final String clampedHex;

  const OutOfGamutException({
    required this.sourceHex,
    required this.clampedHex,
  });

  @override
  String toString() =>
      'OutOfGamutException: "$sourceHex" is outside the sRGB gamut. '
      'Suggested in-gamut alternative: "$clampedHex".';
}

/// Thrown during file export when writing to disk fails.
///
/// Guarantees:
/// - [cause] is the original [Object] thrown by the IO layer so callers
///   can inspect it without losing stack information.
final class HuevoraExportException extends HuevoraException {
  /// The file path that could not be written.
  final String filePath;

  /// The underlying IO error.
  final Object cause;

  const HuevoraExportException({required this.filePath, required this.cause});

  @override
  String toString() =>
      'HuevoraExportException: failed to write to "$filePath". Cause: $cause';
}
