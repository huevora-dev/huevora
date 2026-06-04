/// Defines Huevora's pure Dart color value objects.
///
/// Core responsibility and abstraction boundary:
/// - `HuevoraColor` represents one opaque color in canonical HEX, OKLCH, and
///   lazily computed ARGB.
/// - `OklchComponents` carries OKLCH channels before conversion/promotion.
/// - This module does not import prism or material_color_utilities.
///
/// Key decisions:
/// - HEX validation uses exact canonical digit matching instead of integer
///   parsing, because integer parsing accepts signed values.
/// - `HuevoraColor` validates promoted colors; `OklchComponents` remains a
///   lightweight channel tuple for derivation code.
/// - ARGB remains lazy because only tonal generation needs it.
///
/// Limitations:
/// - Alpha, HCT, conversion, gamut mapping, and palette derivation are outside
///   this model.
import 'package:huevora/src/models/exceptions.dart';

const int _opaqueAlphaMask = 0xFF000000;
const double _degreesPerTurn = 360.0;
const double _achromaticChromaThreshold = 1e-9;

final RegExp _canonicalHexPattern = RegExp(r'^#[0-9A-F]{6}$');

/// Represents one fully opaque Huevora color.
///
/// What it hides and why:
/// - HEX normalization and structural validation.
/// - Lazy ARGB materialization for MCU ingestion.
/// - Equality by canonical RGB bytes.
///
/// Guarantees:
/// - [hex] is always `#RRGGBB`, uppercase, exactly 7 characters.
/// - [oklch.l] is finite and in `[0.0, 1.0]`.
/// - [oklch.c] is finite and `>= 0.0`.
/// - [oklch.h] is finite and in `[0.0, 360.0)`.
/// - [argb] is always `0xFFRRGGBB`.
///
/// Limitations:
/// - Does not prove [hex] and [oklch] were derived from each other. The
///   conversion layer owns cross-space consistency.
final class HuevoraColor {
  final String _hex;

  /// Canonical OKLCH representation used for perceptual manipulation.
  final OklchComponents oklch;

  int? _argb;

  /// Creates a [HuevoraColor] from trusted canonical components.
  ///
  /// When to use: internal construction after conversion and gamut handling.
  ///
  /// Design note:
  /// This constructor assumes validation already happened at the boundary.
  HuevoraColor._({required String hex, required this.oklch}) : _hex = hex;

  /// Creates a [HuevoraColor] from structurally valid HEX and OKLCH values.
  ///
  /// When to use: when the caller already has mutually consistent color
  /// components.
  ///
  /// Parameters:
  /// - [hex]: RGB hex string with or without a leading `#`.
  /// - [oklch]: OKLCH channel tuple.
  ///
  /// Throws:
  /// - [InvalidHexException] when [hex] cannot normalize to `#RRGGBB`.
  /// - [InvalidChannelValueException] when OKLCH channels are non-finite or
  ///   outside Huevora's promoted color invariants.
  ///
  /// Design note:
  /// This factory preserves the existing public API but only validates local
  /// shape/range invariants. Cross-space consistency belongs in conversion code.
  factory HuevoraColor({required String hex, required OklchComponents oklch}) {
    final normalizedHex = _normalizeHex(hex);

    _validateHex(originalHex: hex, normalizedHex: normalizedHex);
    _validateOklch(oklch);

    return HuevoraColor._(hex: normalizedHex, oklch: oklch);
  }

  /// ARGB integer expected by material_color_utilities: `0xFFRRGGBB`.
  int get argb =>
      _argb ??= _opaqueAlphaMask | int.parse(_hex.substring(1), radix: 16);

  /// Canonical HEX representation: `#RRGGBB`.
  String get hex => _hex;

  static String _normalizeHex(String hex) {
    return hex.startsWith('#') ? hex.toUpperCase() : '#${hex.toUpperCase()}';
  }

  static void _validateHex({
    required String originalHex,
    required String normalizedHex,
  }) {
    if (normalizedHex.length != 7 ||
        !_canonicalHexPattern.hasMatch(normalizedHex)) {
      throw InvalidHexException(originalHex);
    }
  }

  static void _validateOklch(OklchComponents oklch) {
    if (!oklch.l.isFinite || oklch.l < 0.0 || oklch.l > 1.0) {
      throw InvalidChannelValueException(
        channel: 'lightness',
        value: oklch.l,
        min: 0.0,
        max: 1.0,
      );
    }

    if (!oklch.c.isFinite || oklch.c < 0.0) {
      throw InvalidChannelValueException(
        channel: 'chroma',
        value: oklch.c,
        min: 0.0,
        max: double.infinity,
      );
    }

    if (!oklch.h.isFinite || oklch.h < 0.0 || oklch.h >= _degreesPerTurn) {
      throw InvalidChannelValueException(
        channel: 'hue',
        value: oklch.h,
        min: 0.0,
        max: _degreesPerTurn,
      );
    }
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is HuevoraColor && _hex == other._hex;
  }

  @override
  int get hashCode => _hex.hashCode;

  @override
  String toString() =>
      'HuevoraColor(hex: $_hex, oklch: L= ${oklch.l.toStringAsFixed(3)}, '
      'C=${oklch.c.toStringAsFixed(3)}, H=${oklch.h.toStringAsFixed(1)})';
}

/// Immutable OKLCH channel triple.
///
/// What it hides and why:
/// - Hue normalization.
/// - Achromatic hue collapse for near-zero chroma.
///
/// Guarantees:
/// - [h] is normalized to `[0.0, 360.0)` for finite hue inputs.
/// - Hue is forced to `0.0` when [c] is effectively achromatic.
///
/// Limitations:
/// - [l] and [c] are not validated here. Promotion to [HuevoraColor] enforces
///   package-level channel invariants.
final class OklchComponents {
  /// Perceptual lightness.
  final double l;

  /// Chroma / colorfulness.
  final double c;

  /// Hue angle in degrees.
  final double h;

  /// Constructs [OklchComponents], normalizing [h].
  const OklchComponents({required this.l, required this.c, required double h})
    : h = c <= _achromaticChromaThreshold
          ? 0.0
          : ((h % _degreesPerTurn) + _degreesPerTurn) % _degreesPerTurn;

  /// Returns a copy with [l] replaced.
  OklchComponents withL(double newL) => OklchComponents(l: newL, c: c, h: h);

  /// Returns a copy with [c] replaced.
  OklchComponents withC(double newC) => OklchComponents(l: l, c: newC, h: h);

  /// Returns a copy with [h] replaced and normalized.
  OklchComponents withH(double newH) => OklchComponents(l: l, c: c, h: newH);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is OklchComponents &&
            l == other.l &&
            c == other.c &&
            h == other.h;
  }

  @override
  int get hashCode => Object.hash(l, c, h);

  @override
  String toString() =>
      'oklch(${l.toStringAsFixed(4)}, c: ${c.toStringAsFixed(4)}, '
      'h: ${h.toStringAsFixed(2)})';
}
