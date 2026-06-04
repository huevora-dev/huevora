# Huevora API Reference

## Table of Contents

- [ColorEngine](#colorengine)
- [ContrastEngine](#contrastengine)
- [ExportEngine](#exportengine)
- [Models](#models)
- [Exceptions](#exceptions)

---

## ColorEngine

Primary API for palette derivation and color-space conversion.

### Constructor

```dart
const ColorEngine()
```

Stateless. Safe to instantiate once and reuse.

### Methods

#### `deriveCorePalette`

```dart
CorePalette deriveCorePalette(String primaryHex, [DerivationConfig? config])
```

Derives a complete palette from a single primary hex color.

**Parameters**:
- `primaryHex` — `#RGB`, `#RRGGBB`, `RGB`, or `RRGGBB` format
- `config` — optional derivation parameters (branding weight, hue offsets, chroma bounds, custom colors)

**Returns**: `CorePalette` with all 9 standard roles populated.

**Throws**:
- `InvalidHexException` — primary hex cannot be parsed
- `ArgumentError` — duplicate custom color names or empty custom names

**Example**:
```dart
final palette = ColorEngine().deriveCorePalette('#4A90E2');
final withCustom = ColorEngine().deriveCorePalette(
  '#4A90E2',
  DerivationConfig(
    semanticBrandingWeight: 0.5,
    customColors: [(name: 'accent', hex: '#FF6B35')],
  ),
);
```

---

#### `validateCorePalette`

```dart
CorePalette validateCorePalette(CorePaletteInput input)
```

Validates and promotes a fully-specified palette input. Every color is asserted to be inside sRGB.

**Parameters**:
- `input` — `CorePaletteInput` with raw hex strings for all 9 standard roles plus optional custom colors

**Returns**: `CorePalette` with validated, gamut-safe colors.

**Throws**:
- `InvalidHexException` — any role hex cannot be parsed
- `OutOfGamutException` — any color is outside sRGB (only in strict mode)
- `ArgumentError` — duplicate custom color names

**Example**:
```dart
final palette = ColorEngine().validateCorePalette(CorePaletteInput(
  primary: '#4A90E2',
  secondary: '#6E84A3',
  // ... all 9 roles required
));
```

---

#### `generateTonalPalettes`

```dart
TonalPaletteResult generateTonalPalettes(CorePalette palette)
```

Generates tonal palettes for every role in the core palette.

**Parameters**:
- `palette` — validated `CorePalette`

**Returns**: `TonalPaletteResult` with tone maps for all standard roles and custom colors.

**Standard roles**: 18 tone steps (0–100).
**Neutral roles**: 28 tone steps (denser at dark/light extremes).
**Custom colors**: 18 tone steps each.

---

#### `fromHex`

```dart
HuevoraColor fromHex(String hex)
```

Parses a hex string into a `HuevoraColor`.

**Throws**: `InvalidHexException`

---

#### `fromOklch`

```dart
HuevoraColor fromOklch(double l, double c, double h)
```

Constructs a `HuevoraColor` from OKLCH channel values.

**Constraints**:
- `l` ∈ [0.0, 1.0]
- `c` ≥ 0.0
- `h` ∈ [0.0, 360.0)

**Throws**: `InvalidChannelValueException`

---

#### `toHex` / `toOklch` / `toOklchString`

```dart
String toHex(HuevoraColor color)
OklchComponents toOklch(HuevoraColor color)
String toOklchString(HuevoraColor color)
```

Accessor methods. `toOklchString` produces CSS `oklch()` format.

---

## ContrastEngine

Public API for contrast checking between foreground and background colors.

### Constructor

```dart
const ContrastEngine()
```

### Methods

#### `check`

```dart
ContrastResult check({
  required HuevoraColor foreground,
  required HuevoraColor background,
  TonalPaletteResult? tonalResult,
  ColorRole? fgRole,
  ColorRole? bgRole,
})
```

Computes APCA Lc and WCAG 2.x contrast ratio simultaneously.

**Parameters**:
- `foreground` — text/icon color
- `background` — surface color
- `tonalResult` — optional; enables tone suggestions
- `fgRole` — role to search for foreground tone alternatives
- `bgRole` — role to search for background tone alternatives

**Returns**: `ContrastResult` with scores, ratings, advice, and optional tone suggestions.

**Example**:
```dart
final result = ContrastEngine().check(
  foreground: palette.primary,
  background: ColorEngine().fromHex('#FFFFFF'),
  tonalResult: tonals,
  fgRole: ColorRole.primary,
);

print(result.apcaLc);        // e.g., 75.3
print(result.wcagRatio);     // e.g., 4.52
print(result.wcagRating);    // WcagRating.aa
print(result.apcaUsage);     // ApcaUsageLevel.bodyText
print(result.advice);        // Human-readable guidance
print(result.suggestedFgTones); // [40, 30, 50] — tones with |Lc| ≥ 45
```

---

## ExportEngine

Serializes palette models to JSON or plain text.

### Constructor

```dart
const ExportEngine()
```

### Methods

#### `toJson`

```dart
String toJson(CorePalette core, TonalPaletteResult? tonal, [ExportConfig config = const ExportConfig.full()])
```

Serializes palette to indented JSON.

**Parameters**:
- `core` — core palette to export
- `tonal` — tonal palettes (nullable; omitted from output if null)
- `config` — inclusion flags

**Config flags**:
- `includeCorePalette` — include `core_palette` section
- `includeTonalPalettes` — include `tonal_palettes` section
- `includeOklch` — include OKLCH strings alongside hex values

**Named constructors**:
- `ExportConfig.full()` — everything
- `ExportConfig.hexOnly()` — hex values only, no OKLCH
- `ExportConfig.coreOnly()` — core palette only
- `ExportConfig.tonalOnly()` — tonal palettes only

**Example**:
```dart
final json = ExportEngine().toJson(palette, tonals);
final minimal = ExportEngine().toJson(palette, tonals, ExportConfig.hexOnly());
```

---

#### `toText`

```dart
String toText(CorePalette core, TonalPaletteResult? tonal, [ExportConfig config = const ExportConfig.full()])
```

Serializes palette to plain-text token list (Figma-friendly).

**Format**:
```
-- HUEVORA EXPORT --
Generated: 2026-06-02T12:00:00.000Z
Version: 1.0.0

[CORE PALETTE]
primary                         #4A90E2  oklch(0.6274 0.1462 247.73)
...

[TONAL PALETTES]
primary-0                       #000000
primary-5                       #00101F
...
```

Standard role tokens use role name. `neutralVariant` uses `neutral-variant` (kebab-case). Custom colors use `custom-{name}`.

---

#### `writeToFile`

```dart
Future<void> writeToFile(String content, String filePath)
```

Writes content to disk as UTF-8.

**Throws**: `HuevoraExportException` on any IO failure.

**Platform note**: Uses conditional import. File export requires `dart:io`. On web platforms, throws `UnsupportedError` wrapped in `HuevoraExportException`.

---

## Models

### HuevoraColor

Immutable multi-space color value object.

```dart
final class HuevoraColor {
  String get hex;           // #RRGGBB, uppercase, 7 chars
  OklchComponents get oklch; // L ∈ [0,1], C ≥ 0, H ∈ [0,360)
  int get argb;             // 0xFFRRGGBB, lazy
}
```

**Equality**: Based on canonical hex string.

### OklchComponents

Immutable OKLCH channel triple with hue normalization.

```dart
final class OklchComponents {
  final double l;  // lightness
  final double c;  // chroma
  final double h;  // hue, normalized to [0, 360)

  OklchComponents withL(double newL);
  OklchComponents withC(double newC);
  OklchComponents withH(double newH);
}
```

Hue is forced to `0.0` when chroma is effectively achromatic (≤ 1e-9).

### CorePalette

```dart
final class CorePalette {
  final HuevoraColor primary;
  final HuevoraColor secondary;
  final HuevoraColor tertiary;
  final HuevoraColor neutral;
  final HuevoraColor neutralVariant;
  final HuevoraColor success;
  final HuevoraColor error;
  final HuevoraColor warning;
  final HuevoraColor info;
  List<({String name, HuevoraColor color})> get custom;

  Map<ColorRole, HuevoraColor> asMap();
  HuevoraColor colorFor(ColorRole role);
}
```

`colorFor` throws `ArgumentError` for `ColorRole.custom`.

### TonalPaletteResult

```dart
final class TonalPaletteResult {
  final Map<ColorRole, Map<int, HuevoraColor>> tones;
  final Map<String, Map<int, HuevoraColor>> customTones;

  Map<int, HuevoraColor> getTonesForRole(ColorRole role);
  Map<int, HuevoraColor> getCustomTonesForRole(String name);
  List<String> get customRoleNames;
}
```

`getTonesForRole` throws `ArgumentError` for `ColorRole.custom`. Missing lookups return empty maps.

### ContrastResult

```dart
final class ContrastResult {
  final double apcaLc;              // signed, polarity-aware
  final double wcagRatio;           // ≥ 1.0
  final WcagRating wcagRating;
  final ApcaUsageLevel apcaUsage;
  final String advice;
  final List<int>? suggestedFgTones;
  final List<int>? suggestedBgTones;

  bool get passesWcagAA;
  bool get passesWcagAAA;
  bool get passesApcaBodyText;
  bool get passesApcaUiMinimum;
}
```

### DerivationConfig

```dart
final class DerivationConfig {
  final double semanticBrandingWeight;   // [0, 1], default 0.25
  final double secondaryHueOffset;       // default +30.0
  final double neutralMinChroma;         // default 0.002
  final double neutralMaxChroma;         // default 0.006
  final double neutralVariantMinChroma;  // default 0.004
  final double neutralVariantMaxChroma;  // default 0.010
  final double semanticMinChroma;        // default 0.012
  final double semanticMaxChroma;        // default 0.048
  final List<({String name, String hex})> customColors;

  factory DerivationConfig.standard();
}
```

### ExportConfig

```dart
final class ExportConfig {
  final bool includeCorePalette;
  final bool includeTonalPalettes;
  final bool includeOklch;

  const ExportConfig.full();
  const ExportConfig.hexOnly();
  const ExportConfig.coreOnly();
  const ExportConfig.tonalOnly();
}
```

---

## Exceptions

All exceptions extend `HuevoraException` (sealed).

| Exception | Thrown When | Fields |
|-----------|-------------|--------|
| `InvalidHexException` | Hex string cannot be parsed | `String input` |
| `InvalidChannelValueException` | OKLCH channel out of range | `String channel`, `double value`, `double min`, `double max` |
| `OutOfGamutException` | Color outside sRGB in strict mode | `String sourceHex`, `String clampedHex` |
| `HuevoraExportException` | File write failure | `String filePath`, `Object cause` |

**Usage**:
```dart
try {
  final color = engine.fromHex('#ZZZZZZ');
} on InvalidHexException catch (e) {
  print('Invalid: ${e.input}');
}
```
