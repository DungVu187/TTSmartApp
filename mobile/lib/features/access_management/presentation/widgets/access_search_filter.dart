import 'package:flutter/material.dart';

import '../../data/models/pagination_models.dart';

class AccessSearchFilter extends StatelessWidget {
  const AccessSearchFilter({
    super.key,
    required this.controller,
    required this.hintText,
    required this.selectedStatus,
    required this.onSearchChanged,
    required this.onStatusChanged,
  });

  final TextEditingController controller;
  final String hintText;
  final int? selectedStatus;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<int?> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) => TextField(
            controller: controller,
            onChanged: onSearchChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: hintText,
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 15,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.primary,
                  width: 1.5,
                ),
              ),
              suffixIcon: value.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Xóa nội dung tìm kiếm',
                      onPressed: () {
                        controller.clear();
                        onSearchChanged('');
                      },
                      icon: const Icon(Icons.close),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _StatusChoice(
                label: 'Tất cả',
                selected: selectedStatus == null,
                onSelected: () => onStatusChanged(null),
              ),
              const SizedBox(width: 8),
              _StatusChoice(
                label: 'Đang dùng',
                selected: selectedStatus == AccessStatus.active,
                onSelected: () => onStatusChanged(AccessStatus.active),
              ),
              const SizedBox(width: 8),
              _StatusChoice(
                label: 'Đang tắt',
                selected: selectedStatus == AccessStatus.inactive,
                onSelected: () => onStatusChanged(AccessStatus.inactive),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusChoice extends StatelessWidget {
  const _StatusChoice({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: colors.primaryContainer,
      side: BorderSide(
        color: selected ? colors.primaryContainer : colors.outlineVariant,
      ),
      labelStyle: TextStyle(
        color: selected ? colors.onPrimaryContainer : colors.onSurface,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
    );
  }
}
