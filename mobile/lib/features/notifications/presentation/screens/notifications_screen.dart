import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/ui/app_ui.dart';
import '../../../../core/utils/vietnam_time.dart';
import '../../data/models/notification_models.dart';
import '../controllers/notifications_controller.dart';
import '../widgets/notification_list_item.dart';

enum _NotificationFilter { all, unread, orders, system }

/// Figma "04 Notifications": filter chips, day groups, card per event.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    super.key,
    required this.controller,
    required this.onOpenOrder,
  });

  final NotificationsController controller;
  final ValueChanged<AppNotification> onOpenOrder;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  var _filter = _NotificationFilter.all;

  NotificationsController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _controller.load());
  }

  bool _matches(AppNotification item) => switch (_filter) {
    _NotificationFilter.all => true,
    _NotificationFilter.unread => !item.isRead,
    _NotificationFilter.orders => isOrderNotification(item),
    _NotificationFilter.system => !isOrderNotification(item),
  };

  Future<void> _open(AppNotification item) async {
    await _controller.markRead(item);
    if (item.eventType == 'order.created' && mounted) {
      widget.onOpenOrder(item);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final items = _controller.items;
          // Category chips only help when both kinds are present.
          final hasOrders = items.any(isOrderNotification);
          final hasSystem = items.any((item) => !isOrderNotification(item));
          final showCategories = hasOrders && hasSystem;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SafeArea(
                bottom: false,
                child: TabTitleBar(
                  title: 'Thông báo',
                  horizontalPadding: 20,
                  leading: Padding(
                    padding: const EdgeInsets.only(left: 16, right: 8),
                    child: RoundIconButton(
                      icon: LucideIcons.arrowLeft,
                      tooltip: 'Quay lại',
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                  actions: [
                    _MarkAllButton(
                      enabled:
                          _controller.unreadCount > 0 &&
                          !_controller.isMarkingAllRead,
                      onPressed: _controller.markAllRead,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'Tất cả',
                        selected: _filter == _NotificationFilter.all,
                        onTap: () =>
                            setState(() => _filter = _NotificationFilter.all),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Chưa đọc',
                        count: _controller.unreadCount,
                        selected: _filter == _NotificationFilter.unread,
                        onTap: () => setState(
                          () => _filter = _NotificationFilter.unread,
                        ),
                      ),
                      if (showCategories) ...[
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Đơn hàng',
                          selected: _filter == _NotificationFilter.orders,
                          onTap: () => setState(
                            () => _filter = _NotificationFilter.orders,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Hệ thống',
                          selected: _filter == _NotificationFilter.system,
                          onTap: () => setState(
                            () => _filter = _NotificationFilter.system,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Expanded(child: _buildBody(p, items.where(_matches).toList())),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBody(AppPalette p, List<AppNotification> visible) {
    if (_controller.isLoading && _controller.items.isEmpty) {
      return const SkeletonList(rows: 5);
    }
    if (_controller.error != null && _controller.items.isEmpty) {
      return LoadErrorView(
        title: 'Không tải được thông báo',
        message: _controller.error!.message,
        onRetry: _controller.load,
      );
    }
    if (visible.isEmpty) {
      return RefreshIndicator(
        onRefresh: _controller.load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          children: [
            const SizedBox(height: 96),
            StateView(
              icon: LucideIcons.bell,
              title: _filter == _NotificationFilter.unread
                  ? 'Không có thông báo chưa đọc'
                  : 'Chưa có thông báo',
              message: 'Các thông báo mới sẽ xuất hiện tại đây.',
            ),
          ],
        ),
      );
    }
    final children = <Widget>[];
    String? currentDay;
    for (final item in visible) {
      final day = _dayLabel(item.occurredAtUtc);
      if (day != currentDay) {
        currentDay = day;
        children.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 18, 0, 8),
            child: GroupLabel(day),
          ),
        );
      } else {
        children.add(const SizedBox(height: 8));
      }
      children.add(
        NotificationListItem(notification: item, onTap: () => _open(item)),
      );
    }
    return RefreshIndicator(
      onRefresh: _controller.load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        children: children,
      ),
    );
  }

  static String _dayLabel(DateTime occurredAtUtc) {
    final day = vietnamDateOnly(occurredAtUtc);
    final today = vietnamDateOnly(DateTime.now().toUtc());
    final difference = today.difference(day).inDays;
    if (difference == 0) return 'Hôm nay';
    if (difference == 1) return 'Hôm qua';
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(day.day)}/${two(day.month)}/${day.year}';
  }
}

/// "Đọc tất cả": 40px tonal button of the title bar.
class _MarkAllButton extends StatelessWidget {
  const _MarkAllButton({required this.enabled, required this.onPressed});

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: p.primaryContainer,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          key: const ValueKey<String>('notifications-mark-all'),
          borderRadius: BorderRadius.circular(12),
          onTap: enabled ? onPressed : null,
          child: SizedBox(
            height: 44,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    LucideIcons.checkCheck,
                    size: 18,
                    color: p.onPrimaryContainer,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Đọc tất cả',
                    style: TextStyle(
                      color: p.onPrimaryContainer,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
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

/// 36px pill of the filter row; "Chưa đọc" carries a red count.
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.count = 0,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int count;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      button: true,
      selected: selected,
      child: TapArea(
        onTap: onTap,
        child: Material(
          color: selected ? p.primary : p.surface,
          shape: StadiumBorder(
            side: selected ? BorderSide.none : BorderSide(color: p.border),
          ),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: SizedBox(
              height: 36,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: selected ? p.onPrimary : p.text1,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (count > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        constraints: const BoxConstraints(minWidth: 22),
                        height: 18,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: p.danger,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Text(
                          count > 99 ? '99+' : '$count',
                          style: TextStyle(
                            color: p.onPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
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
