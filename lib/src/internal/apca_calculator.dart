import 'dart:math' as math;

/// APCA 0.0.98G-4g contrast calculation.
///
/// Core responsibility and abstraction boundary:
/// - Accept foreground/background sRGB byte triples.
/// - Return signed APCA Lc contrast.
/// - Keep the algorithm independent from Huevora models.
///
/// Key decisions:
/// - Constants mirror APCA-W3 0.0.98G-4g.
/// - Public input is validated once at the boundary.
/// - sRGB byte linearization is cached because byte inputs have only 256
///   possible channel values.
///
/// Limitations:
/// - sRGB only.
/// - Does not apply font size or weight lookup tables.
abstract final class ApcaCalculator {
  static const double _sRco = 0.2126729;
  static const double _sGco = 0.7151522;
  static const double _sBco = 0.0721750;

  static const double _mainTrc = 2.4;

  static const double _normTxt = 0.57;
  static const double _normBg = 0.56;
  static const double _revTxt = 0.62;
  static const double _revBg = 0.65;

  static const double _blkThrs = 0.022;
  static const double _blkClmp = 1.414;

  static const double _scaleBoW = 1.14;
  static const double _loBoWoffset = 0.027;
  static const double _scaleWoB = 1.14;
  static const double _loWoBoffset = 0.027;

  static const double _loClip = 0.1;
  static const double _deltaYmin = 0.0005;
  static const double _lcScale = 100.0;

  static final List<double> _linearRgbByByte = List<double>.generate(
    256,
    (channel) => math.pow(channel / 255.0, _mainTrc).toDouble(),
    growable: false,
  );

  /// Computes signed APCA Lc for a foreground/background RGB pair.
  static double computeLc(
    int fgR,
    int fgG,
    int fgB,
    int bgR,
    int bgG,
    int bgB,
  ) {
    _validateRgbByte('fgR', fgR);
    _validateRgbByte('fgG', fgG);
    _validateRgbByte('fgB', fgB);
    _validateRgbByte('bgR', bgR);
    _validateRgbByte('bgG', bgG);
    _validateRgbByte('bgB', bgB);

    final yTxt = _luminance(fgR, fgG, fgB);
    final yBg = _luminance(bgR, bgG, bgB);

    if ((yBg - yTxt).abs() < _deltaYmin) {
      return 0.0;
    }

    final yTxtClamped = _softClamp(yTxt);
    final yBgClamped = _softClamp(yBg);

    if (yBgClamped > yTxtClamped) {
      final sapc =
          (math.pow(yBgClamped, _normBg) - math.pow(yTxtClamped, _normTxt)) *
          _scaleBoW;

      if (sapc < _loClip) {
        return 0.0;
      }

      return (sapc - _loBoWoffset) * _lcScale;
    }

    final sapc =
        (math.pow(yBgClamped, _revBg) - math.pow(yTxtClamped, _revTxt)) *
        _scaleWoB;

    if (sapc > -_loClip) {
      return 0.0;
    }

    return (sapc + _loWoBoffset) * _lcScale;
  }

  static double _luminance(int r, int g, int b) {
    return _sRco * _linearRgbByByte[r] +
        _sGco * _linearRgbByByte[g] +
        _sBco * _linearRgbByByte[b];
  }

  static double _softClamp(double y) {
    if (y >= _blkThrs) {
      return y;
    }

    return y + math.pow(_blkThrs - y, _blkClmp).toDouble();
  }

  static void _validateRgbByte(String channel, int value) {
    if (value < 0 || value > 255) {
      throw ArgumentError.value(
        value,
        channel,
        'RGB channel must be in [0, 255].',
      );
    }
  }
}
