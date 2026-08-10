import 'features/company_management/data/repositories/company_repository.dart';
import 'features/home/data/repositories/home_repository.dart';
import 'features/mix_design_management/data/repositories/mix_design_repository.dart';
import 'features/notifications/data/repositories/notifications_repository.dart';
import 'features/order_reporting/data/repositories/order_report_repository.dart';
import 'features/reports/data/repositories/reports_repository.dart';
import 'features/settings/data/repositories/settings_repository.dart';
import 'features/station_management/data/repositories/station_repository.dart';
import 'features/weigh_station_management/data/repositories/weigh_station_repository.dart';

class AppFeatureRepositories {
  const AppFeatureRepositories({
    required this.home,
    required this.mixDesigns,
    required this.orderReports,
    required this.reports,
    required this.notifications,
    required this.settings,
    required this.companies,
    required this.stations,
    required this.weighStations,
  });

  final HomeRepository home;
  final MixDesignRepository mixDesigns;
  final OrderReportRepository orderReports;
  final ReportsRepository reports;
  final NotificationsRepository notifications;
  final SettingsRepository settings;
  final CompanyRepository companies;
  final StationRepository stations;
  final WeighStationRepository weighStations;
}
