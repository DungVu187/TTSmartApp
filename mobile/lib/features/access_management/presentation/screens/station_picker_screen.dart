import 'package:flutter/material.dart';

import '../../../../core/ui/app_ui.dart';
import '../../../station_management/data/models/station_models.dart';

/// Chọn nhiều trạm đã được backend lọc theo công ty của form người dùng.
class StationPickerScreen extends StatefulWidget {
  const StationPickerScreen({
    super.key,
    required this.stations,
    required this.selectedIds,
  });

  final List<StationListItem> stations;
  final Set<int> selectedIds;

  @override
  State<StationPickerScreen> createState() => _StationPickerScreenState();
}

class _StationPickerScreenState extends State<StationPickerScreen> {
  late final Set<int> _selected = Set<int>.from(widget.selectedIds);
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _toggle(int id) => setState(() {
    if (!_selected.add(id)) _selected.remove(id);
  });

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final visible = widget.stations
        .where((station) {
          if (query.isEmpty) return true;
          return station.displayName.toLowerCase().contains(query) ||
              station.id.toString().contains(query);
        })
        .toList(growable: false);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Đóng',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text('Chọn trạm trộn'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _selected),
            child: const Text('Xong'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
          children: [
            TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Tìm trạm trộn',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 20),
            GroupLabel(
              'Đã chọn ${_selected.length} / ${widget.stations.length} trạm',
            ),
            const SizedBox(height: 8),
            if (visible.isEmpty)
              const StateView(
                icon: Icons.factory_outlined,
                title: 'Không tìm thấy trạm',
                message: 'Thử từ khóa khác hoặc kiểm tra công ty đang chọn.',
              )
            else
              // Figma S09: plain rows, round check on the right.
              InsetCard(
                children: [
                  for (final station in visible)
                    Semantics(
                      selected: _selected.contains(station.id),
                      child: NavRow(
                        title: station.displayName,
                        subtitle: station.type?.label ?? _phoneOf(station),
                        showChevron: false,
                        trailing: _selected.contains(station.id)
                            ? Icon(
                                Icons.check_circle_outline_rounded,
                                size: 24,
                                color: context.palette.primary,
                              )
                            : Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: context.palette.border,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                        onTap: () => _toggle(station.id),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

String? _phoneOf(StationListItem station) {
  final phone = station.phone?.trim();
  return phone == null || phone.isEmpty ? null : phone;
}
