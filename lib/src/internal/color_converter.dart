/// Converts between Huevora color value objects and supported color spaces.
///
/// Core responsibility and abstraction boundary:
/// - Accept user-facing HEX, OKLCH, and ARGB inputs.
/// - Return only Huevora value types or primitive strings.
/// - Keep Prism types private to this implementation.
///
/// Key decisions:
/// - HEX normalization is centralized here so user input follows one path.
/// - OKLCH validation rejects non-finite values before Prism conversion.
/// - Gamut clipping is not performed here; that remains GamutGuard's boundary.
/// - ARGB alpha is ignored because Huevora models opaque colors only.
///
/// Limitations:
/// - Does not expose Prism objects.
/// - Does not perform palette derivation, tonal generation, or contrast checks.
import 'package:huevora/src/models/exceptions.dart';
import 'package:huevora/src/models/huevora_color.dart';
import 'package:prism/prism.dart';

abstract final class ColorConverter {
  static const int _shortHexLength = 3;
  static const int _longHexLength = 6;
  static const int _rgbByteMask = 0xFF;
  static const int _redShift = 16;
  static const int _greenShift = 8;

  static const double _minLightness = 0.0;
  static const double _maxLightness = 1.0;
  static const double _minChroma = 0.0;
  static const double _minHue = 0.0;
  static const double _maxHue = 360.0;

  static final RegExp _hexBodyPattern = RegExp(r'^[0-9a-fA-F]{6}$');

  /// Parses [hex] into a canonical [HuevoraColor].
  ///
  /// Accepts `#RGB`, `RGB`, `#RRGGBB`, or `RRGGBB`.
  ///
  /// Throws [InvalidHexException] when [hex] cannot normalize to `#RRGGBB`.
  static HuevoraColor fromHex(String hex) {
    final normalizedHex = _normalizeHex(hex);
    final rayRgb = RayRgb8.fromHex(normalizedHex, format: HexFormat.rgba);

    return HuevoraColor(
      hex: normalizedHex,
      oklch: _toComponents(rayRgb.toOklch()),
    );
  }

  /// Constructs a [HuevoraColor] from raw OKLCH channel values.
  ///
  /// Hue is wrapped by [OklchComponents] after finite-value validation.
  ///
  /// Throws [InvalidChannelValueException] when any channel is invalid.
  static HuevoraColor fromOklch(double l, double c, double h) {
    if (!h.isFinite) {
      throw InvalidChannelValueException(
        channel: 'hue',
        value: h,
        min: _minHue,
        max: _maxHue,
      );
    }

    return fromOklchComponents(OklchComponents(l: l, c: c, h: h));
  }

  /// Constructs a [HuevoraColor] from validated OKLCH components.
  ///
  /// Does not perform explicit gamut clipping.
  ///
  /// Throws [InvalidChannelValueException] when component values are invalid.
  static HuevoraColor fromOklchComponents(OklchComponents components) {
    _validateOklchComponents(components);

    final rayOklch = RayOklch.fromComponents(
      components.l,
      components.c,
      components.h,
    );
    final rayRgb = rayOklch.toRgb8();

    return HuevoraColor(hex: _rgbToHex(rayRgb), oklch: components);
  }

  /// Constructs a [HuevoraColor] from an ARGB integer.
  ///
  /// The alpha byte is ignored. RGB bytes are read from the low 24 bits.
  static HuevoraColor fromArgb(int argb) {
    final red = (argb >> _redShift) & _rgbByteMask;
    final green = (argb >> _greenShift) & _rgbByteMask;
    final blue = argb & _rgbByteMask;

    final rayRgb = RayRgb8.fromComponentsNative(red, green, blue);

    return HuevoraColor(
      hex: _rgbBytesToHex(red, green, blue),
      oklch: _toComponents(rayRgb.toOklch()),
    );
  }

  /// Formats [components] as a CSS `oklch()` string.
  static String toOklchString(OklchComponents components) {
    return 'oklch('
        '${components.l.toStringAsFixed(4)} '
        '${components.c.toStringAsFixed(4)} '
        '${components.h.toStringAsFixed(2)}'
        ')';
  }

  static String _normalizeHex(String input) {
    var hex = input.trim();

    if (hex.startsWith('#')) {
      hex = hex.substring(1);
    }

    if (hex.length == _shortHexLength) {
      hex = _expandShortHex(hex);
    }

    if (hex.length != _longHexLength || !_hexBodyPattern.hasMatch(hex)) {
      throw InvalidHexException(input);
    }

    return '#${hex.toUpperCase()}';
  }

  static String _expandShortHex(String hex) {
    return '${hex[0]}${hex[0]}${hex[1]}${hex[1]}${hex[2]}${hex[2]}';
  }

  static String _rgbToHex(RayRgb8 rgb) {
    return _rgbBytesToHex(rgb.redNative, rgb.greenNative, rgb.blueNative);
  }

  static String _rgbBytesToHex(int red, int green, int blue) {
    assert(_isRgbByte(red), 'red must be in 0..255');
    assert(_isRgbByte(green), 'green must be in 0..255');
    assert(_isRgbByte(blue), 'blue must be in 0..255');

    final rgb = (red << _redShift) | (green << _greenShift) | blue;
    return '#${rgb.toRadixString(16).padLeft(_longHexLength, '0').toUpperCase()}';
  }

  static bool _isRgbByte(int value) {
    return value >= 0 && value <= _rgbByteMask;
  }

  static OklchComponents _toComponents(RayOklch oklch) {
    return OklchComponents(l: oklch.lightness, c: oklch.chroma, h: oklch.hue);
  }

  static void _validateOklchComponents(OklchComponents components) {
    if (!components.l.isFinite ||
        components.l < _minLightness ||
        components.l > _maxLightness) {
      throw InvalidChannelValueException(
        channel: 'lightness',
        value: components.l,
        min: _minLightness,
        max: _maxLightness,
      );
    }

    if (!components.c.isFinite || components.c < _minChroma) {
      throw InvalidChannelValueException(
        channel: 'chroma',
        value: components.c,
        min: _minChroma,
        max: double.infinity,
      );
    }

    if (!components.h.isFinite ||
        components.h < _minHue ||
        components.h >= _maxHue) {
      throw InvalidChannelValueException(
        channel: 'hue',
        value: components.h,
        min: _minHue,
        max: _maxHue,
      );
    }
  }
}
