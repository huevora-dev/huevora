/// Stores generated tonal palettes for standard and custom color roles.
///
/// Core responsibility and abstraction boundary:
/// - Hold precomputed tone maps.
/// - Provide read-only role-based tone lookup.
/// - Keep tonal generation, MCU details, and color conversion out of this type.
///
/// Key decisions:
/// - Standard role tones are keyed by [ColorRole].
/// - Custom tones are keyed by user-provided custom color names.
/// - Both outer maps and nested tone maps are defensively copied and frozen at
///   construction so the result is immutable after creation.
/// - Missing custom tone lookups return an empty map to avoid null handling.
///
/// Limitations:
/// - Does not generate tones.
/// - Does not validate tone step arrays beyond role-key correctness.
import 'package:huevora/src/models/color_role.dart';
import 'package:huevora/src/models/huevora_color.dart';

final class TonalPaletteResult {
  static const Set<ColorRole> _standardRoles = <ColorRole>{
    ColorRole.primary,
    ColorRole.secondary,
    ColorRole.tertiary,
    ColorRole.neutral,
    ColorRole.neutralVariant,
    ColorRole.success,
    ColorRole.info,
    ColorRole.warning,
    ColorRole.error,
  };

  static const Map<int, HuevoraColor> _emptyToneMap = <int, HuevoraColor>{};

  /// Tone maps for the standard palette roles.
  ///
  /// Key: [ColorRole], excluding [ColorRole.custom].
  /// Value: tone number to [HuevoraColor].
  final Map<ColorRole, Map<int, HuevoraColor>> tones;

  /// Tone maps for named custom colors.
  ///
  /// Key: user-provided custom color name.
  /// Value: tone number to [HuevoraColor].
  final Map<String, Map<int, HuevoraColor>> customTones;

  TonalPaletteResult._({required this.tones, required this.customTones});

  /// Creates an immutable tonal palette result.
  ///
  /// Throws [ArgumentError] if [tones] is missing a standard role or contains
  /// [ColorRole.custom].
  factory TonalPaletteResult({
    required Map<ColorRole, Map<int, HuevoraColor>> tones,
    Map<String, Map<int, HuevoraColor>>? customTones,
  }) {
    return TonalPaletteResult._(
      tones: _freezeStandardTones(tones),
      customTones: _freezeCustomTones(
        customTones ?? const <String, Map<int, HuevoraColor>>{},
      ),
    );
  }

  /// Returns the tone map for a standard [role].
  ///
  /// Throws [ArgumentError] when [role] is [ColorRole.custom].
  Map<int, HuevoraColor> getTonesForRole(ColorRole role) {
    if (role == ColorRole.custom) {
      throw ArgumentError.value(
        role,
        'role',
        'ColorRole.custom does not map to a single standard tone map.',
      );
    }

    return tones[role] ?? _emptyToneMap;
  }

  /// Returns the tone map for a named custom color.
  ///
  /// Returns an empty map when [name] is absent.
  Map<int, HuevoraColor> getCustomTonesForRole(String name) {
    return customTones[name] ?? _emptyToneMap;
  }

  /// Returns all custom color names in insertion order.
  List<String> get customRoleNames {
    return customTones.keys.toList(growable: false);
  }

  @override
  String toString() {
    final buffer = StringBuffer('TonalPaletteResult:\n');

    for (final entry in tones.entries) {
      buffer.writeln('${entry.key}: ${entry.value.length} tones');
    }

    if (customTones.isNotEmpty) {
      buffer.writeln('Custom Roles:');

      for (final entry in customTones.entries) {
        buffer.writeln('${entry.key}: ${entry.value.length} tones');
      }
    }

    return buffer.toString();
  }

  static Map<ColorRole, Map<int, HuevoraColor>> _freezeStandardTones(
    Map<ColorRole, Map<int, HuevoraColor>> tones,
  ) {
    _validateStandardToneRoles(tones);

    final frozen = <ColorRole, Map<int, HuevoraColor>>{};

    for (final entry in tones.entries) {
      frozen[entry.key] = Map<int, HuevoraColor>.unmodifiable(entry.value);
    }

    return Map<ColorRole, Map<int, HuevoraColor>>.unmodifiable(frozen);
  }

  static Map<String, Map<int, HuevoraColor>> _freezeCustomTones(
    Map<String, Map<int, HuevoraColor>> customTones,
  ) {
    if (customTones.isEmpty) {
      return const <String, Map<int, HuevoraColor>>{};
    }

    final frozen = <String, Map<int, HuevoraColor>>{};

    for (final entry in customTones.entries) {
      frozen[entry.key] = Map<int, HuevoraColor>.unmodifiable(entry.value);
    }

    return Map<String, Map<int, HuevoraColor>>.unmodifiable(frozen);
  }

  static void _validateStandardToneRoles(
    Map<ColorRole, Map<int, HuevoraColor>> tones,
  ) {
    final missingRoles = <ColorRole>[];

    for (final role in _standardRoles) {
      if (!tones.containsKey(role)) {
        missingRoles.add(role);
      }
    }

    if (missingRoles.isNotEmpty) {
      throw ArgumentError.value(
        _formatRoles(missingRoles),
        'tones',
        'Missing tone maps for standard roles.',
      );
    }

    final unsupportedRoles = <ColorRole>[];

    for (final role in tones.keys) {
      if (!_standardRoles.contains(role)) {
        unsupportedRoles.add(role);
      }
    }

    if (unsupportedRoles.isNotEmpty) {
      throw ArgumentError.value(
        _formatRoles(unsupportedRoles),
        'tones',
        'Only standard color roles are allowed. Use customTones for custom colors.',
      );
    }
  }

  static String _formatRoles(Iterable<ColorRole> roles) {
    return roles.map((role) => role.name).join(', ');
  }
}
