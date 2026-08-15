import 'dart:typed_data';

import 'package:ttsmart_mobile/features/reports/data/models/report_models.dart';
import 'package:ttsmart_mobile/features/reports/data/repositories/reports_repository.dart';

class EmptyReportsRepository implements ReportsRepository {
  const EmptyReportsRepository();

  @override
  Future<List<OrderStatisticsStation>> getStations({int? companyId}) async =>
      const <OrderStatisticsStation>[];

  @override
  Future<OrderStatisticsFilterOptions> getFilterOptions(
    OrderStatisticsFilterQuery query,
  ) async => OrderStatisticsFilterOptions.empty;

  @override
  Future<OrderStatisticsPage> search(OrderStatisticsQuery query) async =>
      OrderStatisticsPage.empty(
        viewMode: query.viewMode,
        pageNumber: query.pageNumber,
      );

  @override
  Future<OrderStatisticsExportFile> export(
    OrderStatisticsExportQuery query,
  ) async => OrderStatisticsExportFile(bytes: Uint8List(0));
}
