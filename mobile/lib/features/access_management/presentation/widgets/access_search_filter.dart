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
                label: 'Hiệu lực',
                selected: selectedStatus == AccessStatus.active,
                onSelected: () => onStatusChanged(AccessStatus.active),
              ),
              const SizedBox(width: 8),
              _StatusChoice(
                label: 'Ngừng hiệu lực',
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
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
    );
  }
}
