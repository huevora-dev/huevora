/// Huevora — Color Engine for Dart.
///
/// A complete color system toolkit covering bidirectional color-space
/// conversion, branded palette derivation, tonal palette generation,
/// APCA + WCAG contrast checking, and JSON/TXT export.
///
/// ## Quickstart
///
/// ```dart
/// import 'package:huevora/huevora.dart';
///
/// void main() {
///   final engine = ColorEngine();
///
///   // Derive a full branded palette from a single primary hex.
///   final palette = engine.deriveCorePalette('#4A90E2');
///
///   // Generate tonal palettes for every role.
///   final tonals = engine.generateTonalPalettes(palette);
///
///   // Check contrast between two colors.
///   final contrast = ContrastEngine().check(
///     foreground: palette.primary,
///     background: engine.fromHex('#FFFFFF'),
///   );
///
///   // Export to JSON.
///   final json = ExportEngine().toJson(palette, tonals);
///   print(json);
/// }
/// ```
///
/// ## What is NOT exported
/// Everything under `src/internal/` is intentionally hidden. Internal types
/// ([ColorConverter], [GamutGuard], [PaletteDeriver], [TonalGenerator],
/// [ApcaCalculator]) are implementation details and may change without notice.
library;

// Models — value types and enums used across all API surfaces.
export 'src/models/color_role.dart';
export 'src/models/exceptions.dart';
export 'src/models/huevora_color.dart';
export 'src/models/core_palette.dart';
export 'src/models/core_palette_input.dart';
export 'src/models/tonal_palette_result.dart';
export 'src/models/contrast_result.dart';
export 'src/models/export_config.dart';
export 'src/models/derivation_config.dart';

// API engines — uncomment as each phase lands:
export 'src/api/color_engine.dart';
export 'src/api/contrast_engine.dart';
export 'src/api/export_engine.dart';
