# Huevora — Contributor & User Onboarding Guide

## For Users

### Installation

```bash
dart pub add huevora
```

Or add to `pubspec.yaml`:

```yaml
dependencies:
  huevora: ^1.0.0
```

### First Palette

```dart
import 'package:huevora/huevora.dart';

void main() {
  final engine = ColorEngine();

  // Step 1: Derive a palette from your brand color
  final palette = engine.deriveCorePalette('#4A90E2');

  // Step 2: Generate tonal palettes
  final tonals = engine.generateTonalPalettes(palette);

  // Step 3: Use the colors
  print('Primary: ${palette.primary.hex}');
  print('Primary tone 40: ${tonals.getTonesForRole(ColorRole.primary)[40]?.hex}');

  // Step 4: Check contrast
  final contrast = ContrastEngine().check(
    foreground: palette.primary,
    background: engine.fromHex('#FFFFFF'),
  );
  print('WCAG: ${contrast.wcagRatio}:1 — ${contrast.wcagRating.label}');
}
```

### Common Patterns

#### Custom colors

```dart
final palette = engine.deriveCorePalette('#4A90E2', DerivationConfig(
  customColors: [
    (name: 'accent', hex: '#FF6B35'),
    (name: 'promo', hex: '#AA00FF'),
  ],
));
```

#### Tuning semantic branding

```dart
final palette = engine.deriveCorePalette('#4A90E2', DerivationConfig(
  semanticBrandingWeight: 0.0,  // Pure semantic hues
  // semanticBrandingWeight: 1.0,  // Fully primary-hued
));
```

#### Export for design tools

```dart
final export = ExportEngine();

// JSON for design tokens
final json = export.toJson(palette, tonals);
await export.writeToFile(json, './tokens.json');

// TXT for Figma
final text = export.toText(palette, tonals);
await export.writeToFile(text, './tokens.txt');
```

#### Contrast with tone suggestions

```dart

final result = ContrastEngine().check(
  foreground: palette.primary,
  background: palette.neutral,
  tonalResult: tonals,
  fgRole: ColorRole.primary,
  bgRole: ColorRole.neutral,
);

if (result.suggestedFgTones != null) {
  print('Try primary tone ${result.suggestedFgTones!.first}');
}
```

---

## For Contributors

### Repository Structure

```
huevora/
├── lib/
│   ├── huevora.dart              # Public barrel
│   └── src/
│       ├── api/                  # Public engines
│       ├── models/               # Value types, enums, exceptions
│       └── internal/             # Implementation details (never exported)
├── test/                         # Test suites
├── example/
│   └── example.dart              # Usage demonstration
├── pubspec.yaml
├── README.md
├── ARCHITECTURE.md
├── API.md
└── CHANGELOG.md
```

### Development Setup

```bash
# Clone
git clone https://github.com/you/huevora.git
cd huevora

# Install dependencies
dart pub get

# Run tests
dart test

# Run with coverage
dart test --coverage=coverage
dart run coverage:format_coverage --lcov --in=coverage --out=coverage/lcov.info --packages=.dart_tool/package_config.json --report-on=lib
```

### Code Conventions

1. **Documentation contract**: Every file begins with purpose, abstraction boundary, design intent, key decisions, and limitations.
2. **Naming**: Encode intent and domain meaning. Generic verbs (`handle`, `process`, `manage`) are prohibited.
3. **Information hiding**: Modules expose only essential behavior and stable interfaces. Never expose internal data structures.
4. **Comments**: Sparse and WHY-only. Never narrate code.
5. **Dependencies flow inward**: UI → Domain → Infrastructure. Never introduce layers without complexity justification.

### Adding a New Feature

1. **Pre-work phase**: Inspect architecture, establish minimal change scope, restate requirements precisely.
2. **Abstraction gate**: Before creating any abstraction, answer: what complexity is hidden? Is it recurring? Does it reduce cognitive load?
3. **Trade-off analysis**: Every non-trivial decision must document what is gained, what is lost, risks, scalability implications, and alternatives considered.
4. **Tests first**: New behavior requires tests. Edge cases must be covered.
5. **Public API stability**: Breaking changes require major version bump.

### Test Organization

| File | Coverage |
|------|----------|
| `test/color_conversion_test.dart` | Hex parsing, OKLCH, ARGB, gamut guard |
| `test/palette_deriver_test.dart` | Derivation invariants, config, validation |
| `test/tonal_generation_test.dart` | Tone steps, monotonicity, custom tones |
| `test/contrast_check_test.dart` | APCA reference values, WCAG, suggestions |
| `test/export_engine_test.dart` | JSON/TXT structure, flags, file I/O |

### Debugging Protocol

When a test fails:

1. **Reproduce** the issue with minimal input.
2. **Identify root cause** (not symptom). Reference relevant Dart behaviors (null safety, async, type system).
3. **Explain cause** before proposing a fix.
4. **Apply minimal fix** — surgical patch preferred over refactoring.
5. **Validate edge cases** — ensure the fix doesn't introduce regressions.

### Release Checklist

- [ ] All tests pass (`dart test`)
- [ ] Version bumped in `pubspec.yaml`
- [ ] `CHANGELOG.md` updated
- [ ] `README.md` examples verified
- [ ] API documentation updated
- [ ] No internal types leaked in barrel export
- [ ] Dart analysis clean (`dart analyze`)
- [ ] Formatting clean (`dart format .`)
