import 'features/company_management/data/repositories/company_repository.dart';
import 'features/home/data/repositories/home_repository.dart';
import 'features/notifications/data/repositories/notifications_repository.dart';
import 'features/orders/data/repositories/orders_repository.dart';
import 'features/reports/data/repositories/reports_repository.dart';
import 'features/settings/data/repositories/settings_repository.dart';

class AppFeatureRepositories {
  const AppFeatureRepositories({
    required this.home,
    required this.orders,
    required this.reports,
    required this.notifications,
    required this.settings,
    required this.companies,
  });

  final HomeRepository home;
  final OrdersRepository orders;
  final ReportsRepository reports;
  final NotificationsRepository notifications;
  final SettingsRepository settings;
  final CompanyRepository companies;
}
