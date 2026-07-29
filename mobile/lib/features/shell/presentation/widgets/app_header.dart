import 'package:flutter/material.dart';

class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    required this.displayName,
    required this.onOpenAccount,
    required this.onOpenNotifications,
    required this.onOpenSettings,
    this.unreadNotificationCount = 0,
  });

  final String displayName;
  final VoidCallback onOpenAccount;
  final VoidCallback onOpenNotifications;
  final VoidCallback onOpenSettings;
  final int unreadNotificationCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      child: SafeArea(
        bottom: false,
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
          ),
          child: Row(
            children: [
              Tooltip(
                message: 'Thông tin tài khoản',
                child: InkResponse(
                  radius: 28,
                  onTap: onOpenAccount,
                  child: CircleAvatar(
                    radius: 21,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    foregroundColor: theme.colorScheme.onPrimaryContainer,
                    child: Text(
                      _initial(displayName),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(child: _CompanyLogo()),
              Badge(
                isLabelVisible: unreadNotificationCount > 0,
                label: Text(
                  unreadNotificationCount > 99
                      ? '99+'
                      : '$unreadNotificationCount',
                ),
                child: IconButton(
                  tooltip: 'Thông báo',
                  onPressed: onOpenNotifications,
                  icon: const Icon(Icons.notifications_none),
                ),
              ),
              IconButton(
                tooltip: 'Cài đặt',
                onPressed: onOpenSettings,
                icon: const Icon(Icons.settings_outlined),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _initial(String value) {
    final normalized = value.trim();
    return normalized.isEmpty ? '?' : normalized[0].toUpperCase();
  }
}

class _CompanyLogo extends StatelessWidget {
  const _CompanyLogo();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 146),
        child: SizedBox(
          height: 40,
          width: 146,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Image.asset(
              'assets/images/ttsmart_logo.png',
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
              semanticLabel: 'Logo TTSmart',
            ),
          ),
        ),
      ),
    );
  }
}