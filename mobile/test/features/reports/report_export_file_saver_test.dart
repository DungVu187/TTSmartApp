import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ttsmart_mobile/features/reports/data/repositories/reports_repository.dart';
import 'package:ttsmart_mobile/features/reports/data/services/report_export_file_saver.dart';

void main() {
  test('saves export bytes with a safe file name', () async {
    final directory = await Directory.systemTemp.createTemp(
      'ttsmart-order-statistics-export-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final saver = DeviceReportExportFileSaver(
      directoryProvider: () async => directory,
    );

    final path = await saver.save(
      OrderStatisticsExportFile(
        bytes: Uint8List.fromList(<int>[1, 2, 3]),
        fileName: 'thong:ke/don-hang.xlsx',
        contentType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      ),
    );

    expect(path, endsWith('thong_ke_don-hang.xlsx'));
    expect(await File(path).readAsBytes(), <int>[1, 2, 3]);
  });
}
