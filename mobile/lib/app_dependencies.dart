import 'features/company_management/data/repositories/company_repository.dart';
import 'features/home/data/repositories/home_repository.dart';
import 'features/mix_design_management/data/repositories/mix_design_repository.dart';
import 'features/material_reporting/data/repositories/material_report_repository.dart';
import 'features/order_reporting/data/repositories/order_report_repository.dart';
import 'features/notifications/data/repositories/notification_repository.dart';
import 'features/notifications/data/models/notification_models.dart';
import 'features/reports/data/repositories/reports_repository.dart';
import 'features/station_management/data/repositories/station_repository.dart';
import 'features/weigh_station_management/data/repositories/weigh_station_repository.dart';

class AppFeatureRepositories {
  AppFeatureRepositories({
    required this.home,
    required this.mixDesigns,
    required this.materialReports,
    required this.orderReports,
    NotificationRepository? notifications,
    required this.reports,
    required this.companies,
    required this.stations,
    required this.weighStations,
  }) : notifications = notifications ?? const _EmptyNotificationRepository();

  final HomeRepository home;
  final MixDesignRepository mixDesigns;
  final MaterialReportRepository materialReports;
  final OrderReportRepository orderReports;
  final NotificationRepository notifications;
  final ReportsRepository reports;
  final CompanyRepository companies;
  final StationRepository stations;
  final WeighStationRepository weighStations;
}

class _EmptyNotificationRepository implements NotificationRepository {
  const _EmptyNotificationRepository();

  @override
  Future<NotificationPage> getNotifications({
    int pageNumber = 1,
    int pageSize = 20,
  }) => Future.value(
    const NotificationPage(
      items: <AppNotification>[],
      pageNumber: 1,
      pageSize: 20,
      totalCount: 0,
      totalPages: 0,
    ),
  );

  @override
  Future<int> getUnreadCount() => Future.value(0);

  @override
  Future<void> markAllRead() => Future.value();

  @override
  Future<void> markRead(int notificationId) => Future.value();
}
