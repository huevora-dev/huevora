# Huevora

A production-grade color engine for Dart. Derive complete design-system palettes from a single hex color, generate Material-style tonal palettes, validate contrast via APCA and WCAG 2.x, and export to JSON or plain text.

[![Dart SDK](https://img.shields.io/badge/dart-%5E3.0+-blue.svg)](https://dart.dev) [![GitHub Stars](https://img.shields.io/github/stars/huevora-dev/huevora?style=social)](https://github.com/huevora-dev/huevora) [![Issues](https://img.shields.io/github/issues/huevora-dev/huevora)](https://github.com/huevora-dev/huevora/issues) [![CI](https://github.com/huevora-dev/huevora/actions/workflows/ci.yml/badge.svg)](https://github.com/huevora-dev/huevora/actions)

<!-- [![Pub Version](https://img.shields.io/pub/v/your_package_name)](https://pub.dev/packages/your_package_name)

[![Pub Points](https://img.shields.io/pub/points/your_package_name)](https://pub.dev/packages/your_package_name/score)

[![Popularity](https://img.shields.io/pub/popularity/your_package_name)](https://pub.dev/packages/your_package_name/score) -->

<!-- [![Likes](https://img.shields.io/pub/likes/your_package_name)](https://pub.dev/packages/your_package_name) -->

<!-- [![License](https://img.shields.io/github/license/huevora-dev/huevora)](LICENSE) -->

---

## Features

| Feature                            | Description                                                                                                                                 |
| ---------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| **Bidirectional color conversion** | HEX ↔ OKLCH ↔ RGB with prism-backed precision                                                                                             |
| **Branded palette derivation**     | 9 standard roles (primary, secondary, tertiary, neutral, neutralVariant, success, error, warning, info) derived perceptually in OKLCH space |
| **Tonal palette generation**       | Material 3-style tone steps via `material_color_utilities`, with asymmetric neutral step arrays                                             |
| **Contrast validation**            | APCA 0.0.98G + WCAG 2.x simultaneous checking with tone suggestions                                                                         |
| **Export system**                  | JSON (structured) and TXT (token-style, Figma-friendly) with configurable inclusion flags                                                   |
| **Gamut-safe by design**           | Every derived color is verified in-gamut via round-trip OKLCH→RGB8→OKLCH validation                                                         |
| **Null-safe, sealed errors**       | Exhaustive exception hierarchy; no stringly-typed failures                                                                                  |

---

## Quickstart

```dart
import 'package:huevora/huevora.dart';

void main() {
  final engine = ColorEngine();

  // Derive a complete branded palette from one hex color.
  final palette = engine.deriveCorePalette('#4A90E2');

  // Generate tonal palettes for every role.
  final tonals = engine.generateTonalPalettes(palette);

  // Check contrast.
  final contrast = ContrastEngine().check(
    foreground: palette.primary,
    background: engine.fromHex('#FFFFFF'),
  );
  print('APCA Lc: ${contrast.apcaLc}, WCAG: ${contrast.wcagRatio}:1');

  // Export to JSON.
  final json = ExportEngine().toJson(palette, tonals);
  print(json);
}
```

---

## Installation

```yaml
dependencies:
  huevora: ^1.0.0
```

```bash
dart pub add huevora
```

---

## API Overview

### ColorEngine

```dart
final engine = ColorEngine();

// Derive from primary hex
final palette = engine.deriveCorePalette('#4A90E2', DerivationConfig(
  semanticBrandingWeight: 0.25,
  customColors: [(name: 'accent', hex: '#FF6B35')],
));

// Or validate a fully-specified palette
final validated = engine.validateCorePalette(CorePaletteInput(...));

// Tonal generation
final tonals = engine.generateTonalPalettes(palette);
```

### ContrastEngine

```dart
final result = ContrastEngine().check(
  foreground: palette.primary,
  background: engine.fromHex('#FFFFFF'),
  tonalResult: tonals,
  fgRole: ColorRole.primary,
);

print(result.advice);
print(result.suggestedFgTones); // tone alternatives from the palette
```

### ExportEngine

```dart
final export = ExportEngine();

// JSON with full metadata
final json = export.toJson(palette, tonals);

// Hex-only, core-only
final minimal = export.toJson(
  palette,
  tonals,
  ExportConfig.hexOnly(),
);

// Plain text tokens
final text = export.toText(palette, tonals);

// Write to disk
await export.writeToFile(json, './palette.json');
```

---

## Architecture

Huevora is organized in three layers:

```
Public API (lib/src/api/)
├── ColorEngine        — palette derivation, conversion, tonal generation
├── ContrastEngine     — APCA + WCAG contrast checking
└── ExportEngine       — JSON/TXT serialization, file I/O

Models (lib/src/models/)
├── HuevoraColor       — canonical hex + OKLCH value object
├── CorePalette        — 9 standard roles + custom colors
├── TonalPaletteResult — role → tone → color maps
├── ContrastResult     — scores, ratings, advice, tone suggestions
├── ExportConfig       — inclusion flags for export
└── HuevoraException   — sealed error hierarchy

Internal (lib/src/internal/)
├── ColorConverter     — wraps prism for space conversion
├── PaletteDeriver     — OKLCH-based role derivation
├── TonalGenerator     — wraps MCU TonalPalette
├── GamutGuard         — sRGB gamut assertion + chroma clipping
├── ApcaCalculator     — self-contained APCA 0.0.98G-4g
└── ExportFileWriter   — conditional dart:io export
```

**Boundary rule**: No internal types leak into the public API. prism and material_color_utilities types are confined to the internal layer.

---

## Color Derivation Logic

| Role             | Derivation                                           |
| ---------------- | ---------------------------------------------------- |
| `primary`        | Input seed color                                     |
| `secondary`      | Analogous (+30° hue offset, 85% chroma)              |
| `tertiary`       | Complementary (+180° hue, 90% chroma)                |
| `neutral`        | Primary hue, chroma clamped to [0.002, 0.006], L=0.5 |
| `neutralVariant` | Primary hue, chroma clamped to [0.004, 0.010], L=0.5 |
| `success`        | Base hue 145°, pulled 25% toward primary hue         |
| `error`          | Base hue 25°, pulled 25% toward primary hue          |
| `warning`        | Base hue 75°, pulled 25% toward primary hue          |
| `info`           | Base hue 240°, pulled 25% toward primary hue         |

Semantic hue blending uses linear interpolation: `derivedHue = base + (primary - base) × brandingWeight`.

---

## Tone Step Arrays

| Role type            | Steps                                                                                                       |
| -------------------- | ----------------------------------------------------------------------------------------------------------- |
| Standard (chromatic) | 0, 5, 10, 15, 20, 25, 30, 35, 40, 50, 60, 70, 80, 90, 95, 98, 99, 100                                       |
| Neutral              | 0, 4, 5, 6, 10, 12, 15, 17, 20, 22, 24, 25, 30, 35, 40, 50, 60, 70, 80, 87, 90, 92, 94, 95, 96, 98, 99, 100 |

Neutral roles use denser steps at dark and light extremes for precise elevation overlay and surface tint control.

---

## Contrast Standards

| Standard     | Metric                         | Thresholds                                                        |
| ------------ | ------------------------------ | ----------------------------------------------------------------- |
| **APCA**     | Signed Lc (lightness contrast) | ≥90 fluent text, ≥75 body text, ≥60 large text, ≥45 UI components |
| **WCAG 2.x** | Contrast ratio                 | ≥7.0 AAA, ≥4.5 AA, ≥3.0 AA Large, <3.0 fail                       |

APCA is polarity-sensitive (dark-on-light ≠ light-on-dark in |Lc|). WCAG 2.x is order-independent.

---

## Error Handling

All failures are typed via a sealed `HuevoraException` hierarchy:

```dart
try {
  final color = engine.fromHex('#ZZZZZZ');
} on InvalidHexException catch (e) {
  print('Bad input: ${e.input}');
}

try {
  GamutGuard.assertInSrgb(color);
} on OutOfGamutException catch (e) {
  print('Use ${e.clampedHex} instead of ${e.sourceHex}');
}
```

---

## Dependencies

| Package                    | Version | Purpose                                     |
| -------------------------- | ------- | ------------------------------------------- |
| `prism`                    | ^2.1.0  | OKLCH/OKLab/RGB8 conversion, gamut clipping |
| `material_color_utilities` | ^0.13.0 | HCT tonal palette generation                |

---

## License

MIT

---

## Contributing

Issues and PRs welcome. All changes must pass the full test suite (`dart test`) and maintain backward compatibility of public API types.
