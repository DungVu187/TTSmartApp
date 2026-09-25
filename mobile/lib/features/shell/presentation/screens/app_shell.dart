import 'package:flutter/material.dart';

import '../../../../app_dependencies.dart';
import '../../../../core/app_scope.dart';
import '../../../../core/ui/app_ui.dart';
import '../../../auth/presentation/screens/account_screen.dart';
import '../../../home/presentation/controllers/home_controller.dart';
import '../../../home/presentation/screens/home_screen.dart';
import '../../../more/presentation/screens/more_screen.dart';
import '../../../more/presentation/screens/system_screen.dart';
import '../../../order_reporting/presentation/screens/order_reports_screen.dart';
import '../../../notifications/data/models/notification_models.dart';
import '../../../notifications/presentation/controllers/notifications_controller.dart';
import '../../../notifications/presentation/screens/notifications_screen.dart';
import '../../../reports/presentation/screens/reports_screen.dart';
import '../../../settings/presentation/screens/settings_screen.dart';
import '../widgets/app_header.dart';
import '../module_registry.dart';

enum _ShellTabKey { home, orders, statistics, system, more }

class _ShellTabDefinition {
  const _ShellTabDefinition({
    required this.keyName,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    this.child,
  });

  final _ShellTabKey keyName;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget? child;
}

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.repositories});

  final AppFeatureRepositories repositories;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  _ShellTabKey _selectedTab = _ShellTabKey.home;

  /// Tabs are built on first visit so hidden tabs do not call the API at
  /// start-up; once built they keep their state.
  final Set<_ShellTabKey> _visitedTabs = <_ShellTabKey>{_ShellTabKey.home};
  late final HomeController _homeController;
  late final NotificationsController _notificationsController;

  @override
  void initState() {
    super.initState();
    _homeController = HomeController(widget.repositories.home);
    _notificationsController = NotificationsController(
      widget.repositories.notifications,
    )..initialize();
  }

  @override
  void dispose() {
    _homeController.dispose();
    _notificationsController.dispose();
    super.dispose();
  }

  void _selectTab(_ShellTabKey tab) {
    FocusManager.instance.primaryFocus?.unfocus();
    // "Xem thêm" is a sheet over the current tab (Figma 05 More).
    if (tab == _ShellTabKey.more) {
      showMoreSheet(context, widget.repositories);
      return;
    }
    if (_selectedTab == tab) return;
    setState(() {
      _selectedTab = tab;
      _visitedTabs.add(tab);
    });
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

  void _openSettings() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
  }

  void _openNotifications() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NotificationsScreen(
          controller: _notificationsController,
          onOpenOrder: _openNotificationOrder,
        ),
      ),
    );
  }

  void _openNotificationOrder(AppNotification notification) {
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute(
        // The screen draws its own "Đơn hàng" title bar with a back button.
        builder: (_) => Scaffold(
          body: OrderReportsScreen(
            repository: widget.repositories.orderReports,
            companyRepository: widget.repositories.companies,
            showHeading: false,
            initialStationId: notification.stationId,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final session = app.session!;
    final visibleOperations = visibleOperationalModules(app);
    final orderReportsModule = visibleOperations
        .where((module) => module.keyName == 'order-reports')
        .firstOrNull;
    final orderStatisticsModule = visibleOperations
        .where((module) => module.keyName == 'order-statistics')
        .firstOrNull;
    final canViewOrderReports = orderReportsModule != null;
    final canViewOrderStatistics = orderStatisticsModule != null;
    final canViewSystem = visibleAccessModules(app).isNotEmpty;
    final tabs = <_ShellTabDefinition>[
      _ShellTabDefinition(
        keyName: _ShellTabKey.home,
        label: 'Trang chủ',
        icon: Icons.home_outlined,
        selectedIcon: Icons.home_outlined,
        child: Column(
          children: [
            AnimatedBuilder(
              animation: _notificationsController,
              builder: (context, _) => AppHeader(
                displayName: session.user.displayName,
                onOpenAccount: _openAccount,
                onOpenSettings: _openSettings,
                onOpenNotifications: _openNotifications,
                unreadNotificationCount: _notificationsController.unreadCount,
              ),
            ),
            Expanded(
              child: HomeScreen(
                controller: _homeController,
                onOpenOrders: canViewOrderReports
                    ? () => _selectTab(_ShellTabKey.orders)
                    : null,
                onOpenStatistics: canViewOrderStatistics
                    ? () => _selectTab(_ShellTabKey.statistics)
                    : null,
              ),
            ),
          ],
        ),
      ),
      if (canViewOrderReports)
        _ShellTabDefinition(
          keyName: _ShellTabKey.orders,
          label: orderReportsModule.label,
          icon: Icons.receipt_long_outlined,
          selectedIcon: Icons.receipt_long_outlined,
          child: OrderReportsScreen(
            repository: widget.repositories.orderReports,
            companyRepository: widget.repositories.companies,
            showHeading: false,
          ),
        ),
      if (canViewOrderStatistics)
        _ShellTabDefinition(
          keyName: _ShellTabKey.statistics,
          label: orderStatisticsModule.label,
          icon: Icons.bar_chart_rounded,
          selectedIcon: Icons.bar_chart_rounded,
          child: ReportsScreen(
            repository: widget.repositories.reports,
            companyRepository: widget.repositories.companies,
            showHeading: false,
          ),
        ),
      if (canViewSystem)
        _ShellTabDefinition(
          keyName: _ShellTabKey.system,
          label: 'Hệ thống',
          icon: Icons.settings_outlined,
          selectedIcon: Icons.settings_outlined,
          child: SystemScreen(repositories: widget.repositories),
        ),
      const _ShellTabDefinition(
        keyName: _ShellTabKey.more,
        label: 'Xem thêm',
        icon: Icons.grid_view_outlined,
        selectedIcon: Icons.grid_view_outlined,
      ),
    ];
    final contentTabs = tabs
        .where((tab) => tab.child != null)
        .toList(growable: false);
    final contentIndex = contentTabs.indexWhere(
      (tab) => tab.keyName == _selectedTab,
    );
    final effectiveContentIndex = contentIndex < 0 ? 0 : contentIndex;
    final selectedIndex = tabs.indexWhere(
      (tab) => tab.keyName == contentTabs[effectiveContentIndex].keyName,
    );
    return Scaffold(
      body: RepaintBoundary(
        child: IndexedStack(
          index: effectiveContentIndex,
          children: contentTabs
              .map(
                (tab) => KeyedSubtree(
                  key: ValueKey<_ShellTabKey>(tab.keyName),
                  child: _visitedTabs.contains(tab.keyName)
                      ? tab.child!
                      : const SizedBox.shrink(),
                ),
              )
              .toList(growable: false),
        ),
      ),
      bottomNavigationBar: _ShellBottomNavigation(
        tabs: tabs,
        selectedIndex: selectedIndex,
        onSelected: (index) => _selectTab(tabs[index].keyName),
      ),
    );
  }
}

class _ShellBottomNavigation extends StatelessWidget {
  const _ShellBottomNavigation({
    required this.tabs,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<_ShellTabDefinition> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return DecoratedBox(
      key: const ValueKey<String>('shell-bottom-navigation'),
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(top: BorderSide(color: p.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 54,
          child: Row(
            children: [
              for (var index = 0; index < tabs.length; index++)
                Expanded(
                  child: _ShellNavigationItem(
                    key: ValueKey<String>(
                      'shell-nav-${tabs[index].keyName.name}',
                    ),
                    tab: tabs[index],
                    selected: index == selectedIndex,
                    onTap: () => onSelected(index),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Figma nav item: 52×30 pill behind the icon only, label below.
class _ShellNavigationItem extends StatelessWidget {
  const _ShellNavigationItem({
    super.key,
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final _ShellTabDefinition tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final foregroundColor = selected ? p.primary : p.text2;
    return Semantics(
      button: true,
      selected: selected,
      label: tab.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                width: 52,
                height: 30,
                decoration: BoxDecoration(
                  color: selected ? p.primaryContainer : Colors.transparent,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  selected ? tab.selectedIcon : tab.icon,
                  size: 22,
                  color: foregroundColor,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                tab.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: foregroundColor,
                  fontSize: 11,
                  height: 13 / 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
