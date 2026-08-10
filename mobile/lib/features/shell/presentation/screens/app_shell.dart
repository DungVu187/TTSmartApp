import 'package:flutter/material.dart';

import '../../../../app_dependencies.dart';
import '../../../../core/app_scope.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/screens/account_screen.dart';
import '../../../home/presentation/controllers/home_controller.dart';
import '../../../home/presentation/screens/home_screen.dart';
import '../../../more/presentation/screens/more_screen.dart';
import '../../../more/presentation/screens/system_screen.dart';
import '../../../notifications/presentation/controllers/notifications_controller.dart';
import '../../../notifications/presentation/screens/notifications_screen.dart';
import '../../../order_reporting/presentation/screens/order_reports_screen.dart';
import '../../../reports/presentation/screens/reports_screen.dart';
import '../../../settings/presentation/controllers/settings_controller.dart';
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

class _AppShellState extends State<AppShell>
    with SingleTickerProviderStateMixin {
  _ShellTabKey _selectedTab = _ShellTabKey.home;
  _ShellTabKey _contentTab = _ShellTabKey.home;
  _ShellTabKey? _panelTab;
  late final HomeController _homeController;
  late final NotificationsController _notificationsController;
  late final SettingsController _settingsController;
  late final AnimationController _panelController;
  late final Animation<Offset> _panelSlideAnimation;
  late final Animation<double> _panelScrimAnimation;

  @override
  void initState() {
    super.initState();
    _panelController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      reverseDuration: const Duration(milliseconds: 240),
    )..addStatusListener(_handlePanelAnimationStatus);
    _panelSlideAnimation =
        Tween<Offset>(begin: const Offset(0, 1.02), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _panelController,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          ),
        );
    _panelScrimAnimation = CurvedAnimation(
      parent: _panelController,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );
    _homeController = HomeController(widget.repositories.home);
    _notificationsController = NotificationsController(
      widget.repositories.notifications,
    );
    _settingsController = SettingsController(widget.repositories.settings);
  }

  @override
  void dispose() {
    _panelController
      ..removeStatusListener(_handlePanelAnimationStatus)
      ..dispose();
    _homeController.dispose();
    _notificationsController.dispose();
    _settingsController.dispose();
    super.dispose();
  }

  void _selectTab(_ShellTabKey tab) {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_isPanelTab(tab)) {
      if (_selectedTab == tab && _panelController.isCompleted) return;
      setState(() {
        _selectedTab = tab;
        _panelTab = tab;
      });
      _panelController.forward();
      return;
    }
    if (_selectedTab == tab && _panelTab == null) return;
    setState(() {
      _selectedTab = tab;
      _contentTab = tab;
    });
    if (_panelTab != null) _panelController.reverse();
  }

  bool _isPanelTab(_ShellTabKey tab) =>
      tab == _ShellTabKey.system || tab == _ShellTabKey.more;

  void _closePanel() {
    if (_panelTab == null) return;
    setState(() => _selectedTab = _contentTab);
    _panelController.reverse();
  }

  void _handlePanelAnimationStatus(AnimationStatus status) {
    if (status != AnimationStatus.dismissed || _panelTab == null || !mounted) {
      return;
    }
    setState(() => _panelTab = null);
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
    final app = AppScope.of(context);
    final session = app.session!;
    final visibleOperations = visibleOperationalModules(app);
    final canViewOrderReports = visibleOperations.any(
      (module) => module.keyName == 'order-reports',
    );
    final canViewOrderStatistics = visibleOperations.any(
      (module) => module.keyName == 'order-statistics',
    );
    final tabs = <_ShellTabDefinition>[
      _ShellTabDefinition(
        keyName: _ShellTabKey.home,
        label: 'Trang chủ',
        icon: Icons.home_outlined,
        selectedIcon: Icons.home,
        child: HomeScreen(
          controller: _homeController,
          onOpenOrders: canViewOrderReports
              ? () => _selectTab(_ShellTabKey.orders)
              : null,
          onOpenStatistics: canViewOrderStatistics
              ? () => _selectTab(_ShellTabKey.statistics)
              : null,
          onOpenMore: () => _selectTab(_ShellTabKey.more),
        ),
      ),
      if (canViewOrderReports)
        _ShellTabDefinition(
          keyName: _ShellTabKey.orders,
          label: 'Đơn hàng',
          icon: Icons.receipt_long_outlined,
          selectedIcon: Icons.receipt_long,
          child: OrderReportsScreen(
            repository: widget.repositories.orderReports,
            companyRepository: widget.repositories.companies,
          ),
        ),
      if (canViewOrderStatistics)
        _ShellTabDefinition(
          keyName: _ShellTabKey.statistics,
          label: 'Thống kê',
          icon: Icons.query_stats_outlined,
          selectedIcon: Icons.query_stats,
          child: ReportsScreen(
            repository: widget.repositories.reports,
            companyRepository: widget.repositories.companies,
          ),
        ),
      _ShellTabDefinition(
        keyName: _ShellTabKey.system,
        label: 'Hệ thống',
        icon: Icons.settings_outlined,
        selectedIcon: Icons.settings,
      ),
      _ShellTabDefinition(
        keyName: _ShellTabKey.more,
        label: 'Xem thêm',
        icon: Icons.grid_view_outlined,
        selectedIcon: Icons.grid_view,
      ),
    ];
    final contentTabs = tabs
        .where((tab) => tab.child != null)
        .toList(growable: false);
    final contentIndex = contentTabs.indexWhere(
      (tab) => tab.keyName == _contentTab,
    );
    final effectiveContentIndex = contentIndex < 0 ? 0 : contentIndex;
    final selectedIndex = tabs.indexWhere((tab) => tab.keyName == _selectedTab);
    final effectiveSelectedIndex = selectedIndex < 0 ? 0 : selectedIndex;
    final panel = switch (_panelTab) {
      _ShellTabKey.system => const _ShellPanelDefinition(
        keyName: 'system',
        title: 'Hệ thống',
      ),
      _ShellTabKey.more => const _ShellPanelDefinition(
        keyName: 'more',
        title: 'Xem thêm',
      ),
      _ => null,
    };
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Column(
              children: [
                AnimatedBuilder(
                  animation: _notificationsController,
                  builder: (context, _) => AppHeader(
                    displayName: session.user.displayName,
                    unreadNotificationCount:
                        _notificationsController.unreadCount,
                    onOpenAccount: _openAccount,
                    onOpenNotifications: _openNotifications,
                    onOpenSettings: _openSettings,
                  ),
                ),
                Expanded(
                  child: RepaintBoundary(
                    child: IndexedStack(
                      index: effectiveContentIndex,
                      children: contentTabs
                          .map(
                            (tab) => KeyedSubtree(
                              key: ValueKey<_ShellTabKey>(tab.keyName),
                              child: tab.child!,
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (panel != null)
            Positioned.fill(
              child: _ShellBottomPanel(
                key: ValueKey<String>('shell-panel-${panel.keyName}'),
                title: panel.title,
                slideAnimation: _panelSlideAnimation,
                scrimAnimation: _panelScrimAnimation,
                onClose: _closePanel,
                child: panel.keyName == 'system'
                    ? const SystemScreen()
                    : MoreScreen(
                        companyRepository: widget.repositories.companies,
                        mixDesignRepository: widget.repositories.mixDesigns,
                        stationRepository: widget.repositories.stations,
                        weighStationRepository:
                            widget.repositories.weighStations,
                      ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: _ShellBottomNavigation(
        tabs: tabs,
        selectedIndex: effectiveSelectedIndex,
        onSelected: (index) => _selectTab(tabs[index].keyName),
      ),
    );
  }
}

class _ShellPanelDefinition {
  const _ShellPanelDefinition({required this.keyName, required this.title});

  final String keyName;
  final String title;
}

class _ShellBottomPanel extends StatelessWidget {
  const _ShellBottomPanel({
    super.key,
    required this.title,
    required this.slideAnimation,
    required this.scrimAnimation,
    required this.onClose,
    required this.child,
  });

  final String title;
  final Animation<Offset> slideAnimation;
  final Animation<double> scrimAnimation;
  final VoidCallback onClose;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        const minHeight = 340.0;
        const maxHeight = 520.0;
        const heightFactor = 0.40;
        final effectiveMinHeight = constraints.maxHeight < minHeight
            ? constraints.maxHeight
            : minHeight;
        final effectiveMaxHeight = constraints.maxHeight < maxHeight
            ? constraints.maxHeight
            : maxHeight;
        final panelHeight = (constraints.maxHeight * heightFactor)
            .clamp(effectiveMinHeight, effectiveMaxHeight)
            .toDouble();
        return Stack(
          children: [
            Positioned.fill(
              child: FadeTransition(
                opacity: scrimAnimation,
                child: GestureDetector(
                  key: const ValueKey<String>('shell-panel-scrim'),
                  behavior: HitTestBehavior.opaque,
                  onTap: onClose,
                  child: ColoredBox(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.40),
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: SlideTransition(
                position: slideAnimation,
                child: RepaintBoundary(
                  child: SizedBox(
                    width: double.infinity,
                    height: panelHeight,
                    child: Material(
                      key: const ValueKey<String>('shell-panel-surface'),
                      color: Colors.white,
                      elevation: 14,
                      shadowColor: const Color(
                        0xFF0F172A,
                      ).withValues(alpha: 0.16),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          const SizedBox(height: 16),
                          Container(
                            width: 54,
                            height: 5,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.outline.withValues(
                                alpha: 0.55,
                              ),
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    style: theme.textTheme.headlineSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.4,
                                        ),
                                  ),
                                ),
                                SizedBox.square(
                                  dimension: 32,
                                  child: IconButton(
                                    key: const ValueKey<String>(
                                      'shell-panel-close',
                                    ),
                                    tooltip: 'Đóng',
                                    onPressed: onClose,
                                    style: IconButton.styleFrom(
                                      foregroundColor: const Color(0xFF6B7280),
                                      backgroundColor: const Color(0xFFEEF2FF),
                                      minimumSize: const Size.square(32),
                                      maximumSize: const Size.square(32),
                                      padding: EdgeInsets.zero,
                                    ),
                                    icon: const Icon(Icons.close, size: 16),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(child: child),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
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
    return DecoratedBox(
      key: const ValueKey<String>('shell-bottom-navigation'),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 78,
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
    final foregroundColor = selected
        ? AppColors.brandBlue
        : const Color(0xFF6B7280);
    return Semantics(
      button: true,
      selected: selected,
      label: tab.label,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                color: selected ? const Color(0xFFEEF2FF) : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 7),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    selected ? tab.selectedIcon : tab.icon,
                    size: 25,
                    color: foregroundColor,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tab.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: foregroundColor,
                      fontSize: 11,
                      height: 1,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
