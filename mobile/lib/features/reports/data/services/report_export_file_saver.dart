import '../../../../core/files/export_file.dart';
import '../../../../core/files/export_file_saver.dart';
import '../repositories/reports_repository.dart';

typedef ReportExportDirectoryProvider = ExportDirectoryProvider;

abstract interface class ReportExportFileSaver {
  Future<String> save(OrderStatisticsExportFile file);
}

class DeviceReportExportFileSaver implements ReportExportFileSaver {
  DeviceReportExportFileSaver({
    ReportExportDirectoryProvider? directoryProvider,
  }) : _delegate = DeviceExportFileSaver(directoryProvider: directoryProvider);

  final DeviceExportFileSaver _delegate;

  @override
  Future<String> save(OrderStatisticsExportFile file) async {
    return _delegate.save(
      ExportFile(
        bytes: file.bytes,
        fileName: file.fileName,
        contentType: file.contentType,
      ),
    );
  }
}

String safeReportExportFileName(String value) => safeExportFileName(value);
