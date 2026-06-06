import 'dart:convert';

import 'package:huevora/src/internal/color_converter.dart';
import 'package:huevora/src/internal/export_file_writer.dart';
import 'package:huevora/src/models/color_role.dart';
import 'package:huevora/src/models/core_palette.dart';
import 'package:huevora/src/models/exceptions.dart';
import 'package:huevora/src/models/export_config.dart';
import 'package:huevora/src/models/huevora_color.dart';
import 'package:huevora/src/models/tonal_palette_result.dart';

/// Serializes Huevora palette models to JSON or plain text.
///
/// Core responsibility and abstraction boundary:
/// - Transform palette models into export strings.
/// - Keep file-system writing behind an internal platform writer.
/// - Avoid exposing conversion, tonal, prism, MCU, or IO details.
///
/// Key decisions:
/// - JSON and TXT are built fully in memory because palette output is small.
/// - File writing remains opt-in through [writeToFile].
/// - Standard role ordering is centralized.
///
/// Limitations:
/// - Does not stream output.
/// - Does not create parent directories.
/// - Does not produce adapter-specific token formats.
final class ExportEngine {
  static const String _version = '1.0.3';
  static const JsonEncoder _jsonEncoder = JsonEncoder.withIndent('  ');

  static const List<ColorRole> _standardRoles = <ColorRole>[
    ColorRole.primary,
    ColorRole.secondary,
    ColorRole.tertiary,
    ColorRole.neutral,
    ColorRole.neutralVariant,
    ColorRole.success,
    ColorRole.error,
    ColorRole.warning,
    ColorRole.info,
  ];

  const ExportEngine();

  String toJson(
    CorePalette core,
    TonalPaletteResult? tonal, [
    ExportConfig config = const ExportConfig.full(),
  ]) {
    final root = <String, Object>{
      'huevora_version': _version,
      'generated_at': _utcTimestamp(),
    };

    if (config.includeCorePalette) {
      root['core_palette'] = _buildCoreJson(core, config);
    }

    if (config.includeTonalPalettes && tonal != null) {
      root['tonal_palettes'] = _buildTonalJson(tonal, config);
    }

    return _jsonEncoder.convert(root);
  }

  String toText(
    CorePalette core,
    TonalPaletteResult? tonal, [
    ExportConfig config = const ExportConfig.full(),
  ]) {
    final buffer = StringBuffer()
      ..writeln('-- HUEVORA EXPORT --')
      ..writeln('Generated: ${_utcTimestamp()}')
      ..writeln('Version: $_version');

    if (config.includeCorePalette) {
      buffer
        ..writeln()
        ..writeln('[CORE PALETTE]');
      _writeCorePaletteText(buffer, core, config);
    }

    if (config.includeTonalPalettes && tonal != null) {
      buffer
        ..writeln()
        ..writeln('[TONAL PALETTES]');
      _writeTonalPalettesText(buffer, tonal, config);
    }

    return buffer.toString();
  }

  Future<void> writeToFile(String content, String filePath) async {
    try {
      await ExportFileWriter.write(content, filePath);
    } catch (error) {
      throw HuevoraExportException(filePath: filePath, cause: error);
    }
  }

  Map<String, Object> _buildCoreJson(CorePalette core, ExportConfig config) {
    final map = <String, Object>{};
    final roleColors = core.asMap();

    for (final role in _standardRoles) {
      map[_roleKey(role)] = _colorJson(roleColors[role]!, config);
    }

    map['custom'] = <Map<String, Object>>[
      for (final custom in core.custom)
        <String, Object>{
          'name': custom.name,
          ..._colorJson(custom.color, config),
        },
    ];

    return map;
  }

  Map<String, Object> _buildTonalJson(
    TonalPaletteResult tonal,
    ExportConfig config,
  ) {
    final map = <String, Object>{};

    for (final role in _standardRoles) {
      final toneMap = tonal.getTonesForRole(role);
      if (toneMap.isNotEmpty) {
        map[_roleKey(role)] = _toneMapJson(toneMap, config);
      }
    }

    final customMap = <String, Object>{};
    for (final name in tonal.customRoleNames) {
      final toneMap = tonal.getCustomTonesForRole(name);
      if (toneMap.isNotEmpty) {
        customMap[name] = _toneMapJson(toneMap, config);
      }
    }

    if (customMap.isNotEmpty) {
      map['custom'] = customMap;
    }

    return map;
  }

  Map<String, Object> _toneMapJson(
    Map<int, HuevoraColor> toneMap,
    ExportConfig config,
  ) {
    final tones = _sortedToneKeys(toneMap);

    return <String, Object>{
      for (final tone in tones)
        tone.toString(): _colorJson(toneMap[tone]!, config),
    };
  }

  Map<String, String> _colorJson(HuevoraColor color, ExportConfig config) {
    final map = <String, String>{'hex': color.hex};

    if (config.includeOklch) {
      map['oklch'] = ColorConverter.toOklchString(color.oklch);
    }

    return map;
  }

  void _writeCorePaletteText(
    StringBuffer buffer,
    CorePalette core,
    ExportConfig config,
  ) {
    final roleColors = core.asMap();

    for (final role in _standardRoles) {
      _writeColorLine(buffer, _roleToken(role), roleColors[role]!, config);
    }

    for (final custom in core.custom) {
      _writeColorLine(buffer, 'custom-${custom.name}', custom.color, config);
    }
  }

  void _writeTonalPalettesText(
    StringBuffer buffer,
    TonalPaletteResult tonal,
    ExportConfig config,
  ) {
    for (final role in _standardRoles) {
      _writeToneMapText(
        buffer,
        _roleToken(role),
        tonal.getTonesForRole(role),
        config,
      );
    }

    for (final name in tonal.customRoleNames) {
      _writeToneMapText(
        buffer,
        'custom-$name',
        tonal.getCustomTonesForRole(name),
        config,
      );
    }
  }

  void _writeToneMapText(
    StringBuffer buffer,
    String tokenPrefix,
    Map<int, HuevoraColor> toneMap,
    ExportConfig config,
  ) {
    if (toneMap.isEmpty) {
      return;
    }

    for (final tone in _sortedToneKeys(toneMap)) {
      _writeColorLine(buffer, '$tokenPrefix-$tone', toneMap[tone]!, config);
    }
  }

  void _writeColorLine(
    StringBuffer buffer,
    String token,
    HuevoraColor color,
    ExportConfig config,
  ) {
    buffer.write('${token.padRight(30)}  ${color.hex}');

    if (config.includeOklch) {
      buffer.write('  ${ColorConverter.toOklchString(color.oklch)}');
    }

    buffer.writeln();
  }

  static List<int> _sortedToneKeys(Map<int, HuevoraColor> toneMap) {
    return toneMap.keys.toList(growable: false)..sort();
  }

  static String _utcTimestamp() {
    return DateTime.now().toUtc().toIso8601String();
  }

  static String _roleKey(ColorRole role) => switch (role) {
    ColorRole.primary => 'primary',
    ColorRole.secondary => 'secondary',
    ColorRole.tertiary => 'tertiary',
    ColorRole.neutral => 'neutral',
    ColorRole.neutralVariant => 'neutralVariant',
    ColorRole.success => 'success',
    ColorRole.error => 'error',
    ColorRole.warning => 'warning',
    ColorRole.info => 'info',
    ColorRole.custom => 'custom',
  };

  static String _roleToken(ColorRole role) => switch (role) {
    ColorRole.primary => 'primary',
    ColorRole.secondary => 'secondary',
    ColorRole.tertiary => 'tertiary',
    ColorRole.neutral => 'neutral',
    ColorRole.neutralVariant => 'neutral-variant',
    ColorRole.success => 'success',
    ColorRole.error => 'error',
    ColorRole.warning => 'warning',
    ColorRole.info => 'info',
    ColorRole.custom => 'custom',
  };
}
