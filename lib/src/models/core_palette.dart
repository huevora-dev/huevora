import 'dart:collection';

import 'package:huevora/src/models/color_role.dart';
import 'package:huevora/src/models/huevora_color.dart';

/// Defines the immutable core Huevora semantic palette model.
///
/// Core responsibility and abstraction boundary:
/// - Store one [HuevoraColor] for each standard [ColorRole].
/// - Store optional user custom colors in insertion order.
/// - Provide role-based lookup and iteration helpers.
///
/// Key decisions:
/// - Standard roles are named fields, not a primary map, so callers get
///   compile-time access and autocomplete.
/// - [custom] is copied into an unmodifiable list to prevent callers from
///   mutating palette state after construction.
/// - Validation of gamut safety and custom-name uniqueness remains outside
///   this pure model.
///
/// Limitations:
/// - Does not derive, validate, clip, export, or generate tonal palettes.
/// - Does not encode light/dark theme variants.
final class CorePalette {
  /// The origin color from which all other palette roles are derived.
  final HuevoraColor primary;

  /// Analogous to [primary].
  final HuevoraColor secondary;

  /// Complementary to [primary].
  final HuevoraColor tertiary;

  /// Low-chroma primary hue for backgrounds and surfaces.
  final HuevoraColor neutral;

  /// Slightly more saturated neutral role for outlines and containers.
  final HuevoraColor neutralVariant;

  /// Branded green-family signal color for positive states.
  final HuevoraColor success;

  /// Branded red-family signal color for destructive states.
  final HuevoraColor error;

  /// Branded amber-family signal color for cautionary states.
  final HuevoraColor warning;

  /// Branded blue-family signal color for informational states.
  final HuevoraColor info;

  final List<({String name, HuevoraColor color})> _custom;

  /// User-supplied additional colors beyond the standard roles.
  ///
  /// The returned list is unmodifiable and preserves insertion order.
  List<({String name, HuevoraColor color})> get custom => _custom;

  /// Creates a core palette from validated role colors.
  ///
  /// Validation remains the responsibility of the engine layer. This constructor
  /// only preserves model immutability by defensively copying [custom].
  factory CorePalette({
    required HuevoraColor primary,
    required HuevoraColor secondary,
    required HuevoraColor tertiary,
    required HuevoraColor neutral,
    required HuevoraColor neutralVariant,
    required HuevoraColor error,
    required HuevoraColor info,
    required HuevoraColor warning,
    required HuevoraColor success,
    List<({String name, HuevoraColor color})> custom = const [],
  }) {
    return CorePalette._(
      primary: primary,
      secondary: secondary,
      tertiary: tertiary,
      neutral: neutral,
      neutralVariant: neutralVariant,
      error: error,
      info: info,
      warning: warning,
      success: success,
      custom: List<({String name, HuevoraColor color})>.unmodifiable(custom),
    );
  }

  const CorePalette._({
    required this.primary,
    required this.secondary,
    required this.tertiary,
    required this.neutral,
    required this.neutralVariant,
    required this.error,
    required this.info,
    required this.warning,
    required this.success,
    required List<({String name, HuevoraColor color})> custom,
    // ignore: prefer_initializing_formals
  }) : _custom = custom;

  /// Returns the nine standard role colors as an ordered map.
  ///
  /// [ColorRole.custom] is not included because it does not represent a single
  /// standard role color.
  Map<ColorRole, HuevoraColor> asMap() {
    return UnmodifiableMapView<ColorRole, HuevoraColor>(
      <ColorRole, HuevoraColor>{
        ColorRole.primary: primary,
        ColorRole.secondary: secondary,
        ColorRole.tertiary: tertiary,
        ColorRole.neutral: neutral,
        ColorRole.neutralVariant: neutralVariant,
        ColorRole.error: error,
        ColorRole.info: info,
        ColorRole.warning: warning,
        ColorRole.success: success,
      },
    );
  }

  /// Returns the color assigned to [role].
  ///
  /// Throws [ArgumentError] when [role] is [ColorRole.custom].
  HuevoraColor colorFor(ColorRole role) {
    return switch (role) {
      ColorRole.primary => primary,
      ColorRole.secondary => secondary,
      ColorRole.tertiary => tertiary,
      ColorRole.neutral => neutral,
      ColorRole.neutralVariant => neutralVariant,
      ColorRole.error => error,
      ColorRole.info => info,
      ColorRole.warning => warning,
      ColorRole.success => success,
      ColorRole.custom => throw ArgumentError.value(
        role,
        'role',
        'ColorRole.custom does not map to a single standard color.',
      ),
    };
  }

  @override
  String toString() {
    final buffer = StringBuffer('CorePalette(\n');

    _writeRole(buffer, ColorRole.primary, primary);
    _writeRole(buffer, ColorRole.secondary, secondary);
    _writeRole(buffer, ColorRole.tertiary, tertiary);
    _writeRole(buffer, ColorRole.neutral, neutral);
    _writeRole(buffer, ColorRole.neutralVariant, neutralVariant);
    _writeRole(buffer, ColorRole.error, error);
    _writeRole(buffer, ColorRole.info, info);
    _writeRole(buffer, ColorRole.warning, warning);
    _writeRole(buffer, ColorRole.success, success);

    if (_custom.isNotEmpty) {
      buffer.writeln('  custom: [');
      for (final entry in _custom) {
        buffer.writeln('    ${entry.name}: ${entry.color.hex},');
      }
      buffer.writeln('  ],');
    }

    buffer.write(')');
    return buffer.toString();
  }

  static void _writeRole(
    StringBuffer buffer,
    ColorRole role,
    HuevoraColor color,
  ) {
    buffer.writeln('  $role: ${color.hex},');
  }
}
