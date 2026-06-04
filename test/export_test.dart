import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:huevora/huevora.dart';

void main() {
  final engine = ColorEngine();
  late CorePalette palette;
  late TonalPaletteResult tonal;

  setUp(() {
    palette = engine.deriveCorePalette('#4A90E2');
    tonal = engine.generateTonalPalettes(palette);
  });

  // ===========================================================================
  // ExportConfig — defaults and constructors
  // ===========================================================================
  group('ExportConfig', () {
    test('full() enables all flags', () {
      final config = ExportConfig.full();
      expect(config.includeCorePalette, isTrue);
      expect(config.includeTonalPalettes, isTrue);
      expect(config.includeOklch, isTrue);
    });

    test('hexOnly() disables includeOklch', () {
      final config = ExportConfig.hexOnly();
      expect(config.includeCorePalette, isTrue);
      expect(config.includeTonalPalettes, isTrue);
      expect(config.includeOklch, isFalse);
    });

    test('coreOnly() disables tonal and keeps Oklch', () {
      final config = ExportConfig.coreOnly();
      expect(config.includeCorePalette, isTrue);
      expect(config.includeTonalPalettes, isFalse);
      expect(config.includeOklch, isTrue);
    });

    test('tonalOnly() disables core and keeps Oklch', () {
      final config = ExportConfig.tonalOnly();
      expect(config.includeCorePalette, isFalse);
      expect(config.includeTonalPalettes, isTrue);
      expect(config.includeOklch, isTrue);
    });

    test('default constructor matches full()', () {
      const a = ExportConfig();
      final b = ExportConfig.full();
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('different flags produce unequal configs', () {
      const a = ExportConfig(includeOklch: true);
      const b = ExportConfig(includeOklch: false);
      expect(a, isNot(equals(b)));
    });

    test('toString contains flag names and values', () {
      const config = ExportConfig(includeOklch: false);
      expect(config.toString(), contains('includeOklch: false'));
      expect(config.toString(), contains('includeCorePalette'));
      expect(config.toString(), contains('includeTonalPalettes'));
    });
  });

  // ===========================================================================
  // toJson — structure
  // ===========================================================================
  group('ExportEngine.toJson structure', () {
    late Map<String, dynamic> decoded;

    setUp(() {
      final json = ExportEngine().toJson(palette, tonal);
      decoded = jsonDecode(json) as Map<String, dynamic>;
    });

    test('root envelope has version and generated_at', () {
      expect(decoded['huevora_version'], '1.0.0');
      expect(decoded['generated_at'], isA<String>());
      expect(DateTime.tryParse(decoded['generated_at'] as String), isNotNull);
    });

    test('core_palette contains all nine standard roles', () {
      final core = decoded['core_palette'] as Map<String, dynamic>;
      for (final role in [
        'primary',
        'secondary',
        'tertiary',
        'neutral',
        'neutralVariant',
        'success',
        'error',
        'warning',
        'info',
      ]) {
        expect(core.containsKey(role), isTrue, reason: 'Missing role: $role');
      }
    });

    test('neutralVariant key is camelCase', () {
      final core = decoded['core_palette'] as Map<String, dynamic>;
      expect(core.containsKey('neutralVariant'), isTrue);
      expect(core.containsKey('neutral_variant'), isFalse);
    });

    test('each role has hex field', () {
      final core = decoded['core_palette'] as Map<String, dynamic>;
      for (final entry in core.entries.where((e) => e.key != 'custom')) {
        final roleData = entry.value as Map<String, dynamic>;
        expect(roleData['hex'], isA<String>());
        expect((roleData['hex'] as String).startsWith('#'), isTrue);
      }
    });

    test('each role has oklch field when includeOklch is true', () {
      final core = decoded['core_palette'] as Map<String, dynamic>;
      for (final entry in core.entries.where((e) => e.key != 'custom')) {
        final roleData = entry.value as Map<String, dynamic>;
        expect(roleData['oklch'], isA<String>());
        expect((roleData['oklch'] as String).startsWith('oklch('), isTrue);
      }
    });

    test('tonal_palettes has string tone keys', () {
      final tonals = decoded['tonal_palettes'] as Map<String, dynamic>;
      final primaryTones = tonals['primary'] as Map<String, dynamic>;
      for (final key in primaryTones.keys) {
        expect(key, isA<String>());
        expect(int.tryParse(key), isNotNull);
      }
    });

    test('tonal tone values are objects with hex', () {
      final tonals = decoded['tonal_palettes'] as Map<String, dynamic>;
      final primaryTones = tonals['primary'] as Map<String, dynamic>;
      final firstTone = primaryTones.values.first as Map<String, dynamic>;
      expect(firstTone['hex'], isA<String>());
    });

    test('tonal tone keys are ordered ascending', () {
      final tonals = decoded['tonal_palettes'] as Map<String, dynamic>;
      final primaryTones = tonals['primary'] as Map<String, dynamic>;
      final keys = primaryTones.keys.map(int.parse).toList();
      final sorted = List<int>.from(keys)..sort();
      expect(keys, equals(sorted));
    });
  });

  // ===========================================================================
  // toJson — ExportConfig flags
  // ===========================================================================
  group('ExportEngine.toJson ExportConfig flags', () {
    test('includeCorePalette=false omits core_palette', () {
      final json = ExportEngine().toJson(palette, tonal, const ExportConfig(includeCorePalette: false));
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      expect(decoded.containsKey('core_palette'), isFalse);
    });

    test('includeTonalPalettes=false omits tonal_palettes', () {
      final json = ExportEngine().toJson(palette, tonal, const ExportConfig(includeTonalPalettes: false));
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      expect(decoded.containsKey('tonal_palettes'), isFalse);
    });

    test('includeOklch=false omits oklch fields', () {
      final json = ExportEngine().toJson(palette, tonal, const ExportConfig(includeOklch: false));
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      final core = decoded['core_palette'] as Map<String, dynamic>;
      final primary = core['primary'] as Map<String, dynamic>;
      expect(primary.containsKey('oklch'), isFalse);
      expect(primary.containsKey('hex'), isTrue);
    });

    test('null tonal result omits tonal_palettes even when flag is true', () {
      final json = ExportEngine().toJson(palette, null);
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      expect(decoded.containsKey('tonal_palettes'), isFalse);
    });

    test('hexOnly() produces hex-only output', () {
      final json = ExportEngine().toJson(palette, tonal, ExportConfig.hexOnly());
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      final core = decoded['core_palette'] as Map<String, dynamic>;
      final primary = core['primary'] as Map<String, dynamic>;
      expect(primary.containsKey('hex'), isTrue);
      expect(primary.containsKey('oklch'), isFalse);
    });

    test('coreOnly() produces core-only output', () {
      final json = ExportEngine().toJson(palette, tonal, ExportConfig.coreOnly());
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      expect(decoded.containsKey('core_palette'), isTrue);
      expect(decoded.containsKey('tonal_palettes'), isFalse);
    });

    test('tonalOnly() produces tonal-only output', () {
      final json = ExportEngine().toJson(palette, tonal, ExportConfig.tonalOnly());
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      expect(decoded.containsKey('core_palette'), isFalse);
      expect(decoded.containsKey('tonal_palettes'), isTrue);
    });
  });

  // ===========================================================================
  // toJson — custom colors
  // ===========================================================================
  group('ExportEngine.toJson custom colors', () {
    late CorePalette customPalette;
    late TonalPaletteResult customTonal;

    setUp(() {
      customPalette = engine.deriveCorePalette(
        '#4A90E2',
        DerivationConfig(customColors: [(name: 'accent', hex: '#FF6B35'), (name: 'brand', hex: '#00CC44')]),
      );
      customTonal = engine.generateTonalPalettes(customPalette);
    });

    test('core_palette.custom is an array of objects', () {
      final json = ExportEngine().toJson(customPalette, customTonal);
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      final core = decoded['core_palette'] as Map<String, dynamic>;
      final custom = core['custom'] as List<dynamic>;

      expect(custom.length, 2);
      expect(custom.first, isA<Map<String, dynamic>>());
    });

    test('custom entry has name, hex, and oklch', () {
      final json = ExportEngine().toJson(customPalette, customTonal);
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      final core = decoded['core_palette'] as Map<String, dynamic>;
      final custom = core['custom'] as List<dynamic>;
      final first = custom.first as Map<String, dynamic>;

      expect(first['name'], 'accent');
      expect(first['hex'], '#FF6B35');
      expect(first['oklch'], isA<String>());
    });

    test('tonal_palettes.custom is an object keyed by name', () {
      final json = ExportEngine().toJson(customPalette, customTonal);
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      final tonals = decoded['tonal_palettes'] as Map<String, dynamic>;
      final custom = tonals['custom'] as Map<String, dynamic>;

      expect(custom.containsKey('accent'), isTrue);
      expect(custom.containsKey('brand'), isTrue);
    });

    test('custom tonal entry has tone objects with hex', () {
      final json = ExportEngine().toJson(customPalette, customTonal);
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      final tonals = decoded['tonal_palettes'] as Map<String, dynamic>;
      final custom = tonals['custom'] as Map<String, dynamic>;
      final accentTones = custom['accent'] as Map<String, dynamic>;

      expect(accentTones.isNotEmpty, isTrue);
      expect(accentTones.values.first, isA<Map<String, dynamic>>());
      expect((accentTones.values.first as Map<String, dynamic>)['hex'], isA<String>());
    });

    test('palette without custom colors has empty custom array', () {
      final json = ExportEngine().toJson(palette, tonal);
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      final core = decoded['core_palette'] as Map<String, dynamic>;
      final custom = core['custom'] as List<dynamic>;
      expect(custom, isEmpty);
    });
  });

  // ===========================================================================
  // toJson — JSON validity
  // ===========================================================================
  group('ExportEngine.toJson JSON validity', () {
    test('output is valid JSON', () {
      final json = ExportEngine().toJson(palette, tonal);
      expect(() => jsonDecode(json), returnsNormally);
    });

    test('uses 2-space indentation', () {
      final json = ExportEngine().toJson(palette, tonal);
      expect(json, contains('\n  "huevora_version"'));
      expect(json, contains('\n  "core_palette"'));
    });
  });

  // ===========================================================================
  // toText — structure
  // ===========================================================================
  group('ExportEngine.toText structure', () {
    late String text;

    setUp(() {
      text = ExportEngine().toText(palette, tonal);
    });

    test('header contains HUEVORA EXPORT', () {
      expect(text, contains('-- HUEVORA EXPORT --'));
    });

    test('header contains Generated timestamp', () {
      expect(text, contains('Generated:'));
    });

    test('header contains Version', () {
      expect(text, contains('Version:'));
    });

    test('contains [CORE PALETTE] section', () {
      expect(text, contains('[CORE PALETTE]'));
    });

    test('contains all nine standard role tokens', () {
      for (final token in [
        'primary',
        'secondary',
        'tertiary',
        'neutral',
        'neutral-variant',
        'success',
        'error',
        'warning',
        'info',
      ]) {
        expect(text, contains(token), reason: 'Missing token: $token');
      }
    });

    test('neutralVariant token is kebab-case', () {
      expect(text, contains('neutral-variant'));
      expect(text, isNot(contains('neutralVariant')));
    });

    test('contains [TONAL PALETTES] section', () {
      expect(text, contains('[TONAL PALETTES]'));
    });

    test('contains tonal tokens with tone numbers', () {
      expect(text, contains('primary-0'));
      expect(text, contains('primary-100'));
      expect(text, contains('neutral-0'));
      expect(text, contains('neutral-4'));
    });
  });

  // ===========================================================================
  // toText — ExportConfig flags
  // ===========================================================================
  group('ExportEngine.toText ExportConfig flags', () {
    test('includeCorePalette=false omits [CORE PALETTE]', () {
      final text = ExportEngine().toText(palette, tonal, const ExportConfig(includeCorePalette: false));
      expect(text, isNot(contains('[CORE PALETTE]')));
    });

    test('includeTonalPalettes=false omits [TONAL PALETTES]', () {
      final text = ExportEngine().toText(palette, tonal, const ExportConfig(includeTonalPalettes: false));
      expect(text, isNot(contains('[TONAL PALETTES]')));
    });

    test('includeOklch=false omits oklch strings', () {
      final text = ExportEngine().toText(palette, tonal, const ExportConfig(includeOklch: false));
      expect(text, isNot(contains('oklch(')));
      expect(text, contains('#'));
    });

    test('null tonal result omits tonal section even when flag is true', () {
      final text = ExportEngine().toText(palette, null);
      expect(text, isNot(contains('[TONAL PALETTES]')));
    });
  });

  // ===========================================================================
  // toText — custom colors
  // ===========================================================================
  group('ExportEngine.toText custom colors', () {
    late CorePalette customPalette;
    late TonalPaletteResult customTonal;

    setUp(() {
      customPalette = engine.deriveCorePalette(
        '#4A90E2',
        DerivationConfig(customColors: [(name: 'accent', hex: '#FF6B35')]),
      );
      customTonal = engine.generateTonalPalettes(customPalette);
    });

    test('custom core token uses custom-<name> prefix', () {
      final text = ExportEngine().toText(customPalette, customTonal);
      expect(text, contains('custom-accent'));
    });

    test('custom tonal tokens use custom-<name>-<tone> format', () {
      final text = ExportEngine().toText(customPalette, customTonal);
      expect(text, contains('custom-accent-0'));
      expect(text, contains('custom-accent-100'));
    });
  });

  // ===========================================================================
  // toText — column alignment
  // ===========================================================================
  group('ExportEngine.toText column alignment', () {
    test('hex values appear at consistent column in core palette', () {
      final text = ExportEngine().toText(palette, tonal);
      final lines = text.split('\n');

      final coreLines = lines
          .skipWhile((l) => !l.contains('[CORE PALETTE]'))
          .skip(1)
          .takeWhile((l) => l.isNotEmpty && !l.startsWith('['))
          .where((l) => l.contains('#'))
          .toList();

      expect(coreLines.length, greaterThanOrEqualTo(9));

      final hexPositions = coreLines.map((l) => l.indexOf('#')).toList();
      final firstPos = hexPositions.first;
      for (final pos in hexPositions) {
        expect(pos, equals(firstPos));
      }
    });
  });

  // ===========================================================================
  // writeToFile
  // ===========================================================================
  group('ExportEngine.writeToFile', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('huevora_export_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('happy path writes JSON', () async {
      final path = '${tempDir.path}/palette.json';
      final content = ExportEngine().toJson(palette, tonal);
      await ExportEngine().writeToFile(content, path);

      expect(File(path).existsSync(), isTrue);
      expect(File(path).readAsStringSync(), content);
    });

    test('happy path writes TXT', () async {
      final path = '${tempDir.path}/palette.txt';
      final content = ExportEngine().toText(palette, tonal);
      await ExportEngine().writeToFile(content, path);

      expect(File(path).existsSync(), isTrue);
    });

    test('overwrite existing file', () async {
      final path = '${tempDir.path}/overwrite.txt';
      await ExportEngine().writeToFile('first', path);
      await ExportEngine().writeToFile('second', path);

      expect(File(path).readAsStringSync(), 'second');
    });

    test('bad path throws HuevoraExportException', () async {
      await expectLater(
        () => ExportEngine().writeToFile('content', '/nonexistent/dir/file.txt'),
        throwsA(isA<HuevoraExportException>()),
      );
    });

    test('exception carries filePath', () async {
      const badPath = '/nonexistent/dir/file.txt';
      try {
        await ExportEngine().writeToFile('content', badPath);
        fail('Expected HuevoraExportException');
      } on HuevoraExportException catch (e) {
        expect(e.filePath, badPath);
      }
    });

    test('exception carries cause', () async {
      try {
        await ExportEngine().writeToFile('content', '/nonexistent/dir/file.txt');
        fail('Expected HuevoraExportException');
      } on HuevoraExportException catch (e) {
        expect(e.cause, isNotNull);
      }
    });

    test('round-trip integrity: written JSON matches read JSON', () async {
      final path = '${tempDir.path}/roundtrip.json';
      final original = ExportEngine().toJson(palette, tonal);
      await ExportEngine().writeToFile(original, path);

      final readBack = File(path).readAsStringSync();
      expect(jsonDecode(readBack), equals(jsonDecode(original)));
    });
  });

  // ===========================================================================
  // Full workflow integration
  // ===========================================================================
  group('ExportEngine full workflow integration', () {
    test('hex → palette → tonal → JSON → parseable', () {
      final json = ExportEngine().toJson(palette, tonal);
      final decoded = jsonDecode(json) as Map<String, dynamic>;

      expect(decoded['huevora_version'], isNotNull);
      expect(decoded['core_palette'], isA<Map<String, dynamic>>());
      expect(decoded['tonal_palettes'], isA<Map<String, dynamic>>());
    });

    test('validated palette exports without throwing', () {
      final validated = engine.validateCorePalette(
        CorePaletteInput(
          primary: '#4A90E2',
          secondary: '#6E8FBB',
          tertiary: '#E2924A',
          neutral: '#787880',
          neutralVariant: '#797882',
          success: '#386A20',
          error: '#BA1A1A',
          warning: '#7D5700',
          info: '#00639B',
        ),
      );
      final validatedTonal = engine.generateTonalPalettes(validated);

      expect(() => ExportEngine().toJson(validated, validatedTonal), returnsNormally);
      expect(() => ExportEngine().toText(validated, validatedTonal), returnsNormally);
    });

    test('extreme primaries export without throwing', () {
      for (final hex in ['#000000', '#FFFFFF', '#FF0000']) {
        final p = engine.deriveCorePalette(hex);
        final t = engine.generateTonalPalettes(p);
        expect(() => ExportEngine().toJson(p, t), returnsNormally, reason: hex);
        expect(() => ExportEngine().toText(p, t), returnsNormally, reason: hex);
      }
    });

    test('all tonal hex values are valid #RRGGBB', () {
      final json = ExportEngine().toJson(palette, tonal);
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      final tonals = decoded['tonal_palettes'] as Map<String, dynamic>;

      void validateHexValues(Map<String, dynamic> toneMap) {
        for (final entry in toneMap.entries) {
          if (entry.value is Map<String, dynamic>) {
            final colorData = entry.value as Map<String, dynamic>;
            final hex = colorData['hex'] as String?;
            if (hex != null) {
              expect(hex, matches(r'^#[0-9A-F]{6}$'), reason: 'Invalid hex: $hex');
            }
          }
        }
      }

      for (final roleEntry in tonals.entries.where((e) => e.key != 'custom')) {
        validateHexValues(roleEntry.value as Map<String, dynamic>);
      }

      if (tonals.containsKey('custom')) {
        final custom = tonals['custom'] as Map<String, dynamic>;
        for (final entry in custom.entries) {
          validateHexValues(entry.value as Map<String, dynamic>);
        }
      }
    });
  });
}
