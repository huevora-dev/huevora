/// File writing fallback for platforms without `dart:io`.
abstract final class ExportFileWriter {
  static Future<void> write(String content, String filePath) {
    throw UnsupportedError('File export is only available on Dart IO platforms.');
  }
}
