import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'export_file.dart';

typedef ExportDirectoryProvider = Future<Directory> Function();

abstract interface class ExportFileSaver {
  Future<String> save(ExportFile file);
}

class DeviceExportFileSaver implements ExportFileSaver {
  DeviceExportFileSaver({ExportDirectoryProvider? directoryProvider})
    : _directoryProvider = directoryProvider ?? _defaultDirectory;

  final ExportDirectoryProvider _directoryProvider;

  @override
  Future<String> save(ExportFile file) async {
    final directory = await _directoryProvider();
    await directory.create(recursive: true);
    final output = File(
      '${directory.path}${Platform.pathSeparator}${safeExportFileName(file.fileName)}',
    );
    await output.writeAsBytes(file.bytes, flush: true);
    return output.path;
  }

  static Future<Directory> _defaultDirectory() async =>
      await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
}

String safeExportFileName(String value) {
  final fileName = value.trim().replaceAll(RegExp(r'[\\/:*?\x22<>|]'), '_');
  return fileName.isEmpty ? 'du-lieu.xlsx' : fileName;
}
