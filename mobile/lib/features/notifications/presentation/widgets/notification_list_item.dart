import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/ui/app_ui.dart';
import '../../../../core/utils/vietnam_time.dart';
import '../../data/models/notification_models.dart';

bool isOrderNotification(AppNotification item) =>
    item.eventType.startsWith('order.');

/// Card of Figma "04 Notifications". Unread: primary border, left accent,
/// dot after the title and a tinted icon.
class NotificationListItem extends StatelessWidget {
  const NotificationListItem({
    super.key,
    required this.notification,
    required this.onTap,
  });

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final unread = !notification.isRead;
    final order = isOrderNotification(notification);
    final (iconColor, iconBackground) = unread
        ? p.tone(order ? AppTone.primary : AppTone.warning)
        : p.tone(AppTone.neutral);
    final time = utcToVietnamTime(notification.occurredAtUtc.toUtc());
    String two(int number) => number.toString().padLeft(2, '0');
    final meta =
        '${two(time.hour)}:${two(time.minute)} · '
        '${order ? 'Đơn hàng' : 'Hệ thống'}';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: unread ? p.primary : p.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F0F172A),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Stack(
            children: [
              if (unread)
                Positioned(
                  left: 0,
                  top: 16,
                  child: Container(
                    width: 3,
                    height: 42,
                    decoration: BoxDecoration(
                      color: p.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(15),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: iconBackground,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(
                        order ? LucideIcons.clipboardList : LucideIcons.info,
                        size: 22,
                        color: iconColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  notification.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: p.text1,
                                    fontSize: 14,
                                    height: 17 / 14,
                                    fontWeight: unread
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (unread) ...[
                                const SizedBox(width: 6),
                                Semantics(
                                  label: 'Chưa đọc',
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: p.primary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            notification.body,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: p.text2,
                              fontSize: 13,
                              height: 18 / 13,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            meta,
                            style: TextStyle(
                              color: p.text3,
                              fontSize: 12,
                              height: 15 / 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
