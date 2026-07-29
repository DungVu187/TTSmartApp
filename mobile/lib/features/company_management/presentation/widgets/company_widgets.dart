import 'package:flutter/material.dart';

import '../../data/models/company_models.dart';

class CompanyPlanChip extends StatelessWidget {
  const CompanyPlanChip({super.key, required this.plan});

  final CompanyPlan plan;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isPaid = plan == CompanyPlan.paid;
    final foreground = isPaid
        ? colors.onSecondaryContainer
        : colors.onPrimaryContainer;
    return Chip(
      visualDensity: VisualDensity.compact,
      avatar: Icon(
        isPaid
            ? Icons.workspace_premium_outlined
            : Icons.card_giftcard_outlined,
        size: 17,
        color: foreground,
      ),
      label: Text(plan.label),
      labelStyle: TextStyle(color: foreground, fontWeight: FontWeight.w600),
      backgroundColor: isPaid
          ? colors.secondaryContainer
          : colors.primaryContainer,
      side: BorderSide.none,
    );
  }
}

class CompanyStatusChip extends StatelessWidget {
  const CompanyStatusChip({super.key, required this.isDeleted});

  final bool isDeleted;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = isDeleted
        ? colors.onSurfaceVariant
        : colors.onPrimaryContainer;
    return Chip(
      visualDensity: VisualDensity.compact,
      avatar: Icon(
        isDeleted ? Icons.delete_outline : Icons.check_circle_outline,
        size: 17,
        color: foreground,
      ),
      label: Text(isDeleted ? 'Đã xóa' : 'Đang hoạt động'),
      labelStyle: TextStyle(color: foreground, fontWeight: FontWeight.w600),
      backgroundColor: isDeleted
          ? colors.surfaceContainerHighest
          : colors.primaryContainer,
      side: BorderSide.none,
    );
  }
}

class CompanyLockChip extends StatelessWidget {
  const CompanyLockChip({super.key, required this.isLocked});

  final bool isLocked;

  @override
  Widget build(BuildContext context) {
    if (!isLocked) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    return Chip(
      visualDensity: VisualDensity.compact,
      avatar: Icon(Icons.lock_outline, size: 17, color: colors.error),
      label: const Text('Đang khóa'),
      labelStyle: TextStyle(color: colors.error, fontWeight: FontWeight.w600),
      backgroundColor: colors.errorContainer,
      side: BorderSide.none,
    );
  }
}

class CompanySection extends StatelessWidget {
  const CompanySection({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.trailing,
  });

  final String title;
  final Widget child;
  final IconData? icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
        const SizedBox(height: 10),
        DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: child,
        ),
      ],
    );
  }
}

class CompanyInfoRow extends StatelessWidget {
  const CompanyInfoRow({
    super.key,
    required this.label,
    required this.value,
    this.icon,
  });

  final String label;
  final String? value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 12),
          ],
          SizedBox(
            width: 116,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              normalized,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CompanyListCard extends StatelessWidget {
  const CompanyListCard({
    super.key,
    required this.company,
    this.onTap,
    this.onMenu,
  });

  final CompanyResponse company;
  final VoidCallback? onTap;
  final VoidCallback? onMenu;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final code = company.code?.trim();
    final address = company.address?.trim();
    final contact = _firstNonEmpty([company.phone, company.email]);
    return Semantics(
      button: onTap != null,
      label: '${company.displayName}${code == null ? '' : ', mã $code'}',
      child: Material(
        color: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.apartment_outlined,
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        company.displayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (code != null && code.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          code,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      if (address != null && address.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          address,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                      if (contact != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          contact,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          CompanyPlanChip(plan: company.plan),
                          CompanyStatusChip(isDeleted: company.isDeleted),
                          if (company.isLocked)
                            CompanyLockChip(isLocked: company.isLocked),
                        ],
                      ),
                    ],
                  ),
                ),
                if (onMenu != null)
                  IconButton(
                    tooltip: 'Thao tác',
                    onPressed: onMenu,
                    icon: const Icon(Icons.more_vert),
                  )
                else if (onTap != null)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Icon(Icons.chevron_right),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      final normalized = value?.trim();
      if (normalized != null && normalized.isNotEmpty) return normalized;
    }
    return null;
  }
}

String formatCompanyDate(DateTime? value) {
  if (value == null) return 'Không giới hạn';
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${twoDigits(value.day)}/${twoDigits(value.month)}/${value.year}';
}
