import 'dart:convert';
import 'dart:io';

/// Writes export output on Dart IO platforms.
abstract final class ExportFileWriter {
  static Future<void> write(String content, String filePath) async {
    await File(filePath).writeAsString(content, encoding: utf8, flush: true);
  }
}
