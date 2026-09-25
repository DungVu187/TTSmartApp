import 'package:flutter/material.dart';

import '../../../../core/ui/app_ui.dart';

class AccessConstrainedContent extends StatelessWidget {
  const AccessConstrainedContent({
    super.key,
    required this.child,
    this.maxWidth = 960,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

EdgeInsets accessPagePadding(
  BuildContext context, {
  double top = 16,
  double bottom = 24,
}) {
  final horizontal = MediaQuery.sizeOf(context).width >= 720 ? 24.0 : 16.0;
  return EdgeInsets.fromLTRB(horizontal, top, horizontal, bottom);
}

class AccessSection extends StatelessWidget {
  const AccessSection({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.trailing,
  });

  final String title;
  final IconData? icon;
  final Widget? trailing;
  final Widget child;

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

class AccessInfoRow extends StatelessWidget {
  const AccessInfoRow({
    super.key,
    required this.label,
    required this.value,
    this.icon,
  });

  final String label;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return FieldRow(label: label, value: value);
  }
}

/// "Lưu" in the app bar of the access forms (Figma S08 / S11).
class AccessSaveAction extends StatelessWidget {
  const AccessSaveAction({
    super.key,
    required this.submitting,
    required this.onPressed,
  });

  final bool submitting;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: TextButton(
        key: const ValueKey<String>('access-form-save'),
        onPressed: submitting ? null : onPressed,
        style: TextButton.styleFrom(minimumSize: const Size(56, 44)),
        child: Text(
          submitting ? 'Đang lưu...' : 'Lưu',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class AccessEmptyState extends StatelessWidget {
  const AccessEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actions = const [],
  });

  final IconData icon;
  final String title;
  final String message;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return StateView(
      icon: icon,
      title: title,
      message: message,
      actions: actions,
    );
  }
}

/// Empty list body: pull-to-refresh plus the S12 state. [filtered] swaps the
/// "nothing yet + create" copy for "no match, change the filters".
class AccessEmptyList extends StatelessWidget {
  const AccessEmptyList({
    super.key,
    required this.onRefresh,
    required this.filtered,
    required this.icon,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.noMatchTitle,
    this.createLabel,
    this.onCreate,
  });

  final Future<void> Function() onRefresh;
  final bool filtered;
  final IconData icon;
  final String emptyTitle;
  final String emptyMessage;
  final String noMatchTitle;
  final String? createLabel;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        children: [
          const SizedBox(height: 96),
          AccessEmptyState(
            icon: icon,
            title: filtered ? noMatchTitle : emptyTitle,
            message: filtered
                ? 'Thử thay đổi từ khóa hoặc bộ lọc.'
                : emptyMessage,
            actions: [
              if (!filtered && onCreate != null && createLabel != null)
                AppButton(
                  label: createLabel!,
                  icon: Icons.add_rounded,
                  expand: false,
                  onPressed: onCreate,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
