import 'package:flutter/material.dart';

import '../../../../app_dependencies.dart';
import '../../../../core/app_scope.dart';
import '../../../auth/presentation/screens/account_screen.dart';
import '../../../home/presentation/controllers/home_controller.dart';
import '../../../home/presentation/screens/home_screen.dart';
import '../../../more/presentation/screens/more_screen.dart';
import '../../../notifications/presentation/controllers/notifications_controller.dart';
import '../../../notifications/presentation/screens/notifications_screen.dart';
import '../../../orders/presentation/controllers/orders_controller.dart';
import '../../../orders/presentation/screens/orders_screen.dart';
import '../../../reports/presentation/controllers/reports_controller.dart';
import '../../../reports/presentation/screens/reports_screen.dart';
import '../../../settings/presentation/controllers/settings_controller.dart';
import '../../../settings/presentation/screens/settings_screen.dart';
import '../widgets/app_header.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.repositories});

  final AppFeatureRepositories repositories;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;
  late final HomeController _homeController;
  late final OrdersController _ordersController;
  late final ReportsController _reportsController;
  late final NotificationsController _notificationsController;
  late final SettingsController _settingsController;

  @override
  void initState() {
    super.initState();
    _homeController = HomeController(widget.repositories.home);
    _ordersController = OrdersController(widget.repositories.orders);
    _reportsController = ReportsController(widget.repositories.reports);
    _notificationsController = NotificationsController(
      widget.repositories.notifications,
    );
    _settingsController = SettingsController(widget.repositories.settings);
  }

  @override
  void dispose() {
    _homeController.dispose();
    _ordersController.dispose();
    _reportsController.dispose();
    _notificationsController.dispose();
    _settingsController.dispose();
    super.dispose();
  }

  void _selectTab(int index) {
    if (_selectedIndex == index) return;
    setState(() => _selectedIndex = index);
  }

  void _openAccount() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Thông tin tài khoản')),
          body: const SafeArea(child: AccountScreen()),
        ),
      ),
    );
  }

  void _openNotifications() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            NotificationsScreen(controller: _notificationsController),
      ),
    );
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SettingsScreen(controller: _settingsController),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = AppScope.of(context).session!;
    return Scaffold(
      body: Column(
        children: [
          AnimatedBuilder(
            animation: _notificationsController,
            builder: (context, _) => AppHeader(
              displayName: session.user.displayName,
              unreadNotificationCount: _notificationsController.unreadCount,
              onOpenAccount: _openAccount,
              onOpenNotifications: _openNotifications,
              onOpenSettings: _openSettings,
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                HomeScreen(
                  controller: _homeController,
                  onOpenOrders: () => _selectTab(1),
                  onOpenReports: () => _selectTab(2),
                  onOpenMore: () => _selectTab(3),
                ),
                OrdersScreen(controller: _ordersController),
                ReportsScreen(controller: _reportsController),
                MoreScreen(companyRepository: widget.repositories.companies),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _selectTab,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Trang chủ',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Đơn hàng',
          ),
          NavigationDestination(
            icon: Icon(Icons.query_stats_outlined),
            selectedIcon: Icon(Icons.query_stats),
            label: 'Báo cáo',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view),
            label: 'Xem thêm',
          ),
        ],
      ),
    );
  }
}
