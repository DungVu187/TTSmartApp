import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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
import '../../../../core/theme/app_system_ui.dart';

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
        icon: LucideIcons.house,
        selectedIcon: LucideIcons.house,
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
          label: 'Đơn hàng',
          icon: LucideIcons.clipboardList,
          selectedIcon: LucideIcons.clipboardList,
          child: OrderReportsScreen(
            repository: widget.repositories.orderReports,
            companyRepository: widget.repositories.companies,
            showHeading: false,
          ),
        ),
      if (canViewOrderStatistics)
        _ShellTabDefinition(
          keyName: _ShellTabKey.statistics,
          label: 'Thống kê',
          icon: LucideIcons.chartColumn,
          selectedIcon: LucideIcons.chartColumn,
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
          // Accounts and permissions; the gear stays for Cài đặt.
          icon: LucideIcons.userCog,
          selectedIcon: LucideIcons.userCog,
          child: SystemScreen(repositories: widget.repositories),
        ),
      const _ShellTabDefinition(
        keyName: _ShellTabKey.more,
        label: 'Xem thêm',
        icon: LucideIcons.layoutGrid,
        selectedIcon: LucideIcons.layoutGrid,
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
    return AppSystemUi(
      navigationBar: p.surface,
      child: DecoratedBox(
        key: const ValueKey<String>('shell-bottom-navigation'),
        decoration: BoxDecoration(
          color: p.surface,
          border: Border(top: BorderSide(color: p.border)),
        ),
        child: SafeArea(
          top: false,
          // Tab labels follow the phone's font size up to 1.2× (like the
          // system tab bars) and the bar grows with them instead of cutting
          // the label (it overflowed at 1.3×).
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.2,
            child: Builder(
              builder: (context) => SizedBox(
                height: math.max(
                  54,
                  39 + MediaQuery.textScalerOf(context).scale(15),
                ),
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
                  color: selected ? p.onPrimaryContainer : p.text2,
                ),
              ),
              const SizedBox(height: 3),
              // Side padding keeps neighbouring labels apart on 360dp
              // phones with a large font (they touched at 1.3×).
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    tab.label,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: foregroundColor,
                      fontSize: 12,
                      height: 15 / 12,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
