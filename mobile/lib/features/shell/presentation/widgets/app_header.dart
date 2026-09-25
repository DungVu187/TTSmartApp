import 'package:flutter/material.dart';

import '../../../../core/ui/app_ui.dart';

/// Home header (Figma "02 Home"): gradient avatar, logo, bell + settings.
class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    required this.displayName,
    required this.onOpenAccount,
    required this.onOpenSettings,
    this.onOpenNotifications,
    this.unreadNotificationCount = 0,
  });

  final String displayName;
  final VoidCallback onOpenAccount;
  final VoidCallback onOpenSettings;
  final VoidCallback? onOpenNotifications;
  final int unreadNotificationCount;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ColoredBox(
      color: p.canvas,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 50,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Semantics(
                  button: true,
                  label: 'Thông tin tài khoản',
                  child: GestureDetector(
                    onTap: onOpenAccount,
                    child: Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(11),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [p.primary, p.secondary],
                        ),
                      ),
                      child: Text(
                        _initial(displayName),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Image.asset(
                  'assets/images/ttsmart_logo_transparent.png',
                  width: 122,
                  height: 26,
                  fit: BoxFit.contain,
                  alignment: Alignment.centerLeft,
                  filterQuality: FilterQuality.medium,
                  semanticLabel: 'Logo TTSmart',
                ),
                const Spacer(),
                _HeaderButton(
                  tooltip: onOpenNotifications == null
                      ? 'Thông báo chưa được triển khai'
                      : 'Thông báo',
                  icon: Icons.notifications_none_rounded,
                  onPressed: onOpenNotifications,
                  badgeCount: unreadNotificationCount,
                ),
                const SizedBox(width: 10),
                _HeaderButton(
                  tooltip: 'Cài đặt',
                  icon: Icons.settings_outlined,
                  onPressed: onOpenSettings,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Vietnamese names end with the given name ("Vũ Đức Dũng" → "D").
  static String _initial(String value) {
    final words = value.trim().split(RegExp(r'\s+'));
    final last = words.isEmpty ? '' : words.last;
    return last.isEmpty ? '?' : last.characters.first.toUpperCase();
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.badgeCount = 0,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Tooltip(
          message: tooltip,
          child: Material(
            color: p.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: p.border),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onPressed,
              child: SizedBox.square(
                dimension: 36,
                child: Icon(icon, size: 20, color: p.text1),
              ),
            ),
          ),
        ),
        if (badgeCount > 0)
          Positioned(
            top: -4,
            right: -5,
            child: IgnorePointer(
              child: Container(
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                padding: const EdgeInsets.symmetric(horizontal: 3),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: p.danger,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: p.canvas, width: 1.5),
                ),
                child: Text(
                  badgeCount > 99 ? '99+' : '$badgeCount',
                  style: TextStyle(
                    color: p.onPrimary,
                    fontSize: 10,
                    height: 12 / 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
