# Huevora — System Architecture

## 1. Problem Analysis

Huevora solves the problem of **deterministic, branded color system generation** for design systems and applications. Core concerns:

| Concern | Complexity Driver |
|---------|-----------------|
| Bidirectional color conversion | Multiple color spaces, precision loss, gamut boundaries |
| Core palette derivation | Perceptual relationships in OKLCH space |
| Tonal palette generation | HCT space (MCU), non-uniform tone steps for neutral |
| Contrast checking | Two standards (APCA + WCAG 2.x), different math |
| Export | Serialization shape, format negotiation, platform abstraction |

## 2. Dependency Audit

| Package | Pin | Latest Stable | Status |
|---------|-----|---------------|--------|
| `prism` | ^2.1.0 | 2.1.0 (Oct 2025, Dart ≥3.3) | ✅ Exact match |
| `material_color_utilities` | ^0.13.0 | 0.12.0 last confirmed; 0.13.0 may be pre-release | ⚠️ Verify on pub.dev |

**MCU version note**: The architecture is version-agnostic at the MCU boundary. Only `TonalGenerator` touches MCU types. A version bump requires zero internal changes beyond the dependency pin.

## 3. System Boundary Map

```
┌─────────────────────────────────────────────────────────────┐
│                        PUBLIC API                            │
│   Huevora  (single entry point, barrel export)               │
└───────────────────────┬─────────────────────────────────────┘
                        │
        ┌───────────────┼────────────────┐
        ▼               ▼                ▼
┌──────────────┐ ┌──────────────┐ ┌───────────────┐
│  ColorEngine │ │ContrastEngine│ │ ExportEngine  │
│  (subsystem) │ │  (subsystem) │ │  (subsystem)  │
└──────┬───────┘ └──────┬───────┘ └───────┬───────┘
       │                │                  │
       ▼                ▼                  ▼
┌──────────────────────────────────────────────────┐
│              Internal Layer (hidden)              │
│  ColorConverter │ PaletteDeriver │ TonalGenerator │
│           GamutGuard │ ColorNormalizer            │
│           ApcaCalculator │ ExportFileWriter       │
└──────────────────────────────────────────────────┘
       │                              │
       ▼                              ▼
  prism ^2.1.0              material_color_utilities
  (Oklch, Oklab,             (TonalPalette, Hct)
   Rgb8, gamut clip)
```

**Boundary rule**: Nothing outside the internal layer touches `prism` or `material_color_utilities` types directly.

## 4. Module Catalogue

### 4.1 Public Surface

```
lib/
├── huevora.dart                  ← barrel: exports only public types
└── src/
    ├── api/
    │   ├── color_engine.dart     ← palette derivation + conversion + tonal generation
    │   ├── contrast_engine.dart  ← APCA + WCAG contrast checking
    │   └── export_engine.dart    ← JSON / TXT serialization + file I/O
    ├── models/
    │   ├── huevora_color.dart    ← multi-space color value object
    │   ├── core_palette.dart     ← typed bag of 9+ named roles
    │   ├── tonal_palette_result.dart
    │   ├── contrast_result.dart  ← APCA score + WCAG rating + advice
    │   ├── export_config.dart    ← inclusion flags
    │   ├── derivation_config.dart ← derivation parameters
    │   ├── core_palette_input.dart
    │   ├── color_role.dart
    │   └── exceptions.dart       ← sealed HuevoraException hierarchy
    └── internal/               ← NEVER exported
        ├── color_converter.dart  ← all space math, wraps prism
        ├── palette_deriver.dart  ← OKLCH-based derivation logic
        ├── tonal_generator.dart  ← wraps MCU TonalPalette
        ├── gamut_guard.dart      ← sRGB gamut clamping + detection
        ├── apca_calculator.dart  ← APCA Lc math (self-contained)
        ├── export_file_writer.dart ← conditional dart:io export
        ├── export_file_writer_io.dart
        └── export_file_writer_unsupported.dart
```

### 4.2 Barrel Export Rule

`huevora.dart` exports only the three engines and all models. Zero internal types leak out. Users never import from `src/internal/`.

## 5. Data Flow — The Three Pipelines

### Pipeline A: Core Palette Generation

```
User: hex string (#4A90E2)
         │
         ▼
  ColorConverter.hexToOklch()
         │
         ▼
  GamutGuard.assertInSrgb()          ← strict validation (optional)
         │
         ▼
  PaletteDeriver.derive(primaryOklch)
    ├─ secondary  = analogous(±30°, chroma ×0.85)
    ├─ tertiary   = complementary(+180°, chroma ×0.9)
    ├─ neutral    = primary hue, chroma clamp [2..6], L=0.5
    ├─ neutralVar = primary hue, chroma clamp [4..10], L=0.5
    ├─ success    = hue ~145°, blended toward primary ×0.25
    ├─ error      = hue ~25°, blended toward primary ×0.25
    ├─ warning    = hue ~75°, blended toward primary ×0.25
    ├─ info       = hue ~240°, blended toward primary ×0.25
    └─ custom[]   = passed through, gamut-checked
         │
         ▼
  GamutGuard.clipAll()               ← clamp all derived colors to sRGB
         │
         ▼
  CorePalette (HuevoraColor per role)
```

### Pipeline B: Tonal Palette Generation

```
CorePalette
    │  for each role color:
    ▼
  ColorConverter.hexToArgb()           ← 0xFFRRGGBB integer MCU expects
    │
    ▼
  GamutGuard.clipToSrgb()              ← second check before MCU ingestion
    │
    ▼
  TonalGenerator.generate(argb, role)
    ├─ standard roles → 18 tone steps
    └─ neutral roles  → 28 tone steps (denser at extremes)
         │
         ▼
  TonalPaletteEntry { role, tone → HuevoraColor }
```

### Pipeline C: Contrast Check

```
User: (foreground, background)
         │
         ▼
  ColorConverter → linearized sRGB luminance (Y) per color
         │
         ├─ WCAG 2.x path:
         │    ratio = (Ylight + 0.05) / (Ydark + 0.05)
         │    rating = AAA|AA|AA Large|fail
         │
         └─ APCA path:
              Lc = f(Ytext, Ybg)
              usage advice based on |Lc| thresholds
         │
         ▼
  ContrastResult { apcaLc, wcagRatio, wcagRating, apcaUsage, advice,
                   suggestedFgTones?, suggestedBgTones? }
```

## 6. Model Definitions

### HuevoraColor

Immutable value object. Canonical sources: hex (#RRGGBB) and OKLCH. ARGB is lazy-computed for MCU ingestion.

### ColorRole

```dart
enum ColorRole {
  primary, secondary, tertiary,
  neutral, neutralVariant,
  success, error, warning, info,
  custom;
}
```

### CorePalette

Named fields for 9 standard roles. Custom colors stored as unmodifiable list of `({String name, HuevoraColor color})`.

### TonalPaletteResult

```dart
// role → (tone → HuevoraColor)
final Map<ColorRole, Map<int, HuevoraColor>> tones;
// custom colors keyed by user-provided name
final Map<String, Map<int, HuevoraColor>> customTones;
```

### ContrastResult

```dart
final double apcaLc;              // signed, polarity-aware
final double wcagRatio;           // always ≥ 1.0
final WcagRating wcagRating;      // aaa, aa, aaLargeOnly, fail
final ApcaUsageLevel apcaUsage;   // fluentText, bodyText, largeText, uiComponent, insufficient
final String advice;
final List<int>? suggestedFgTones;
final List<int>? suggestedBgTones;
```

## 7. Gamut Strategy

**The GamutGuard is the most important internal module.**

Every color crosses it twice: once after derivation, once before MCU ingestion.

**Approach**:
- Fast path: `RayOklab.getMaxValidChroma()` (linear cusp approximation)
- Fallback: OKLCH→RGB8→OKLCH round-trip verification (catches approximation errors)
- Clip: binary search on chroma using the round-trip predicate as ground truth

**Rationale**: The linear cusp approximation is conservative for some hues (saturated reds, oranges) and liberal for others (yellows, cyans). Round-trip verification is the only reliable ground truth.

## 8. APCA Implementation

Self-contained, ~100 lines, no third-party package. Constants mirror APCA-W3 0.0.98G-4g:

```
Rc=0.2126729, Gc=0.7151522, Bc=0.0721750
Gamma: 2.4 (pure power, not piecewise)
Soft clamp: blkThrs=0.022, blkClmp=1.414
Scale: 1.14, offset: 0.027
```

## 9. Export Format Design

### JSON

```json
{
  "huevora_version": "1.0.0",
  "generated_at": "2026-06-02T...",
  "core_palette": {
    "primary": { "hex": "#4A90E2", "oklch": "oklch(0.6274 0.1462 247.73)" },
    "neutralVariant": { "hex": "#...", "oklch": "..." },
    "custom": [
      { "name": "accent", "hex": "#FF6B35", "oklch": "..." }
    ]
  },
  "tonal_palettes": {
    "primary": { "0": { "hex": "#000000" }, "5": { "hex": "#..." } },
    "custom": { "accent": { "0": { "hex": "#000000" } } }
  }
}
```

### TXT (token-style, Figma-friendly)

```
-- HUEVORA EXPORT --
Generated: 2026-06-02T12:00:00.000Z
Version: 1.0.0

[CORE PALETTE]
primary                         #4A90E2  oklch(0.6274 0.1462 247.73)
secondary                       #...     oklch(...)
...
neutral-variant                 #...     oklch(...)

[TONAL PALETTES]
primary-0                       #000000
primary-5                       #...
...
neutral-0                       #000000
neutral-4                       #...
```

## 10. Error Handling Strategy

```dart
sealed class HuevoraException implements Exception {}

final class InvalidHexException extends HuevoraException { final String input; }
final class InvalidChannelValueException extends HuevoraException { final String channel; final double value; final double min; final double max; }
final class OutOfGamutException extends HuevoraException { final String sourceHex; final String clampedHex; }
final class HuevoraExportException extends HuevoraException { final String filePath; final Object cause; }
```

**Design principle**: Sealed hierarchy forces exhaustive handling at call sites. No stringly-typed error codes.

## 11. Key Design Decisions — Trade-Off Record

| Decision | Chosen | Rejected | Reason |
|----------|--------|----------|--------|
| Primary color space | OKLCH | HSL, LCH | Perceptually uniform, CSS native, prism-native |
| Tonal space | HCT (via MCU) | OKLCH lightness steps | Material 3 tones are defined in HCT |
| APCA implementation | Hand-ported (internal) | Third-party pkg | No mature Dart APCA package exists |
| Gamut strategy | Clip at every boundary | Reject and throw | Rejection breaks workflow; clamped alternative returned |
| Semantic hue blending | Linear interpolation | Shortest-path circular | Shortest-path jumps perceptual family boundaries |
| Export as string | Always return string, file write optional | Write-only | Strings are composable; callers can pipe to APIs |
| MCU version pin | ^0.13.0 (verify) | ^0.12.0 | Design is version-agnostic at boundary |
| File writer | Conditional import (dart:io / unsupported) | Direct dart:io import | Supports web compilation |

## 12. Testing Strategy

| Suite | Coverage |
|-------|----------|
| `color_conversion_test.dart` | Hex parsing, OKLCH round-trip, ARGB, shorthand expansion, gamut guard |
| `palette_deriver_test.dart` | Derivation invariants, config tuning, custom colors, validation, edge cases |
| `tonal_generation_test.dart` | Tone step arrays, monotonicity, neutral vs standard steps, custom tones |
| `contrast_check_test.dart` | APCA reference values, WCAG boundaries, tone suggestions, integration |
| `export_engine_test.dart` | JSON/TXT structure, config flags, custom colors, column alignment, file I/O |
