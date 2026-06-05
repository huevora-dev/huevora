import 'package:huevora/huevora.dart';

/// Huevora Example — Complete workflow demonstration.
///
/// This example shows:
/// 1. Deriving a branded palette from a single hex color
/// 2. Generating tonal palettes
/// 3. Checking contrast
/// 4. Exporting to JSON and TXT
void main() async {
  final engine = ColorEngine();
  final export = ExportEngine();

  // -------------------------------------------------------------------------
  // 1. Derive a core palette from your brand color.
  // -------------------------------------------------------------------------
  print('=== Deriving palette ===');
  final palette = engine.deriveCorePalette(
    '#4A90E2',
    DerivationConfig(semanticBrandingWeight: 0.25, customColors: [(name: 'accent', hex: '#FF6B35')]),
  );

  print('Primary:    ${palette.primary.hex}');
  print('Secondary:  ${palette.secondary.hex}');
  print('Tertiary:   ${palette.tertiary.hex}');
  print('Neutral:    ${palette.neutral.hex}');
  print('Error:      ${palette.error.hex}');
  print('Custom:     ${palette.custom.first.color.hex}');

  // -------------------------------------------------------------------------
  // 2. Generate tonal palettes for every role.
  // -------------------------------------------------------------------------
  print('=== Generating tonal palettes ===');
  final tonals = engine.generateTonalPalettes(palette);

  final primaryTones = tonals.getTonesForRole(ColorRole.primary);
  print('Primary tone 0:   ${primaryTones[0]?.hex}');
  print('Primary tone 40:  ${primaryTones[40]?.hex}');
  print('Primary tone 100: ${primaryTones[100]?.hex}');

  // -------------------------------------------------------------------------
  // 3. Check contrast between colors.
  // -------------------------------------------------------------------------
  print('=== Contrast check ===');
  final contrast = ContrastEngine().check(
    foreground: palette.primary,
    background: engine.fromHex('#FFFFFF'),
    tonalResult: tonals,
    fgRole: ColorRole.primary,
  );

  print('APCA Lc:     ${contrast.apcaLc.toStringAsFixed(1)}');
  print('WCAG ratio:  ${contrast.wcagRatio.toStringAsFixed(2)}:1');
  print('WCAG rating: ${contrast.wcagRating.label}');
  print('APCA usage:  ${contrast.apcaUsage.description}');
  print('Advice:      ${contrast.advice}');

  if (contrast.suggestedFgTones != null) {
    print('Suggested fg tones: ${contrast.suggestedFgTones}');
  }

  // -------------------------------------------------------------------------
  // 4. Export to JSON (full metadata).
  // -------------------------------------------------------------------------
  print('=== JSON Export (full) ===');
  final jsonFull = export.toJson(palette, tonals);
  print(jsonFull.substring(0, jsonFull.indexOf('') * 6));
  print('... (${jsonFull.length} chars total)');

  // -------------------------------------------------------------------------
  // 5. Export to JSON (hex-only, core-only).
  // -------------------------------------------------------------------------
  print('=== JSON Export (hex-only, core-only) ===');
  final jsonMinimal = export.toJson(palette, tonals, ExportConfig.hexOnly());
  print(jsonMinimal.substring(0, jsonMinimal.indexOf('') * 4));
  print('... (${jsonMinimal.length} chars total)');

  // -------------------------------------------------------------------------
  // 6. Export to plain text.
  // -------------------------------------------------------------------------
  print('=== TXT Export (first 20 lines) ===');
  final text = export.toText(palette, tonals);
  final lines = text.split('');
  for (final line in lines.take(20)) {
    print(line);
  }
  print('... (${lines.length} lines total)');

  // -------------------------------------------------------------------------
  // 7. Write to file (optional — uncomment to enable).
  // -------------------------------------------------------------------------
  // await export.writeToFile(jsonFull, './palette.json');
  // await export.writeToFile(text, './palette.txt');
  // print('Files written to ./palette.json and ./palette.txt');
}
