import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/ui/app_ui.dart';

import '../../data/models/company_models.dart';

/// "Trả phí" (violet, award) / "Miễn phí" (neutral, gift).
class CompanyPlanChip extends StatelessWidget {
  const CompanyPlanChip({super.key, required this.plan});

  final CompanyPlan plan;

  @override
  Widget build(BuildContext context) {
    final isPaid = plan == CompanyPlan.paid;
    return AppTag(
      label: plan.label,
      icon: isPaid ? LucideIcons.award : LucideIcons.gift,
      tone: isPaid ? AppTone.violet : AppTone.neutral,
    );
  }
}

/// "Đang hoạt động" (green) / "Đã xóa" (neutral).
class CompanyStatusChip extends StatelessWidget {
  const CompanyStatusChip({super.key, required this.isDeleted});

  final bool isDeleted;

  @override
  Widget build(BuildContext context) => AppTag(
    label: isDeleted ? 'Đã xóa' : 'Đang hoạt động',
    icon: isDeleted ? LucideIcons.trash2 : LucideIcons.check,
    tone: isDeleted ? AppTone.neutral : AppTone.success,
  );
}

class CompanyLockChip extends StatelessWidget {
  const CompanyLockChip({super.key, required this.isLocked});

  final bool isLocked;

  @override
  Widget build(BuildContext context) {
    if (!isLocked) return const SizedBox.shrink();
    return const AppTag(
      label: 'Đang khóa',
      icon: LucideIcons.lock,
      tone: AppTone.danger,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: GroupLabel(title)),
            ?trailing,
          ],
        ),
        const SizedBox(height: 8),
        DecoratedBox(
          decoration: BoxDecoration(
            color: context.palette.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.palette.border),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: child,
          ),
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
    return FieldRow(label: label, value: normalized);
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
                    LucideIcons.building,
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
                    icon: const Icon(LucideIcons.ellipsisVertical),
                  )
                else if (onTap != null)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Icon(LucideIcons.chevronRight),
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
