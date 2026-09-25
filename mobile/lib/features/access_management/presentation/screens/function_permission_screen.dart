import 'package:flutter/material.dart';

import '../../../../core/ui/app_ui.dart';
import '../../data/models/permission_models.dart';
import '../../data/models/role_models.dart';

/// Chỉnh quyền một chức năng trong bản nháp của ma trận vai trò.
class FunctionPermissionScreen extends StatefulWidget {
  const FunctionPermissionScreen({
    super.key,
    required this.item,
    required this.canEdit,
    required this.onChanged,
  });

  final RoleFunctionMatrixItemResponse item;
  final bool canEdit;
  final ValueChanged<PermissionSet> onChanged;

  @override
  State<FunctionPermissionScreen> createState() =>
      _FunctionPermissionScreenState();
}

class _FunctionPermissionScreenState extends State<FunctionPermissionScreen> {
  late PermissionSet _permissions = widget.item.permissions;

  void _update(PermissionSet value) {
    if (!widget.canEdit) return;
    setState(() => _permissions = value);
    widget.onChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.item.name)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
          children: [
            InsetCard(
              children: [
                ToggleRow(
                  label: 'Cấp toàn bộ quyền',
                  value: _permissions.full,
                  emphasized: true,
                  onChanged: widget.canEdit
                      ? (value) => _update(
                          value
                              ? const PermissionSet.full()
                              : const PermissionSet.none(),
                        )
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 20),
            const GroupLabel('Chọn từng quyền'),
            const SizedBox(height: 8),
            InsetCard(
              children: [
                for (final definition in PermissionSet.definitions)
                  ToggleRow(
                    label: definition.label,
                    value: _permissions.allows(definition.permission),
                    onChanged: widget.canEdit
                        ? (value) => _update(
                            _permissions.withPermission(
                              definition.permission,
                              value,
                            ),
                          )
                        : null,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
