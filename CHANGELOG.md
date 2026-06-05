# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] — 2026-06-03

### Added

- **ColorEngine** — bidirectional color conversion (HEX ↔ OKLCH ↔ RGB) and palette derivation from a single primary hex color.
- **CorePalette** — 9 standard semantic roles (primary, secondary, tertiary, neutral, neutralVariant, success, error, warning, info) with optional custom colors.
- **PaletteDeriver** — OKLCH-based perceptual derivation with configurable semantic branding weight, hue offsets, and chroma bounds.
- **TonalGenerator** — Material 3-style tonal palette generation via `material_color_utilities`, with asymmetric 28-step neutral arrays and 18-step standard arrays.
- **ContrastEngine** — simultaneous APCA 0.0.98G-4g and WCAG 2.x contrast checking with tone suggestions from generated palettes.
- **ApcaCalculator** — self-contained APCA implementation with no third-party dependencies.
- **ExportEngine** — JSON and plain-text serialization with configurable inclusion flags (`ExportConfig`).
- **ExportFileWriter** — conditional `dart:io` import for cross-platform file export support.
- **GamutGuard** — round-trip-verified sRGB gamut checking with binary search chroma clipping. Resolves false positives and false negatives from linear cusp approximation.
- **Sealed exception hierarchy** — `HuevoraException` with `InvalidHexException`, `InvalidChannelValueException`, `OutOfGamutException`, `HuevoraExportException`.
- **Comprehensive test suite** — 5 test files covering color conversion, palette derivation, tonal generation, contrast checking, and export functionality.

### Design Decisions

- Primary manipulation space: OKLCH (perceptually uniform, CSS native).
- Tonal generation space: HCT (Material 3 standard, handled by MCU).
- Semantic hue blending: linear interpolation (not shortest-path circular) to preserve perceptual color families.
- Gamut strategy: clip at every boundary, never reject. Clamped alternatives returned with warnings.
- Public API: three stateless engines (`ColorEngine`, `ContrastEngine`, `ExportEngine`) with immutable value objects.
- Internal boundary: prism and material_color_utilities types never leak into public API.

## [Unreleased]

### Planned

- HCT exposure in `HuevoraColor` and export output.
- CSS variable export format (`:root` tokens).
- Figma plugin integration helpers.
- P3/display-p3 gamut support.

## [1.0.1] — 2026-06-04

### Added

- **PaletteDeriver** — Updated the OKLCH-based perceptual derivation with configurable semantic branding weight, hue offsets, and chroma bounds.

## [1.0.1+1] — 2026-06-04

### Added

- Documentation fixes.

## [1.0.2] — 2026-06-04

### Added

- Documentation fixes.
