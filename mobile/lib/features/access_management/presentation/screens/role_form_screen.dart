import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/widgets/error_panel.dart';
import '../../data/models/role_models.dart';
import '../controllers/roles_controller.dart';
import '../widgets/access_layout.dart';

class RoleFormScreen extends StatefulWidget {
  const RoleFormScreen({
    super.key,
    required this.controller,
    this.existingRole,
  });

  final RolesController controller;
  final RoleResponse? existingRole;

  bool get isEditing => existingRole != null;

  @override
  State<RoleFormScreen> createState() => _RoleFormScreenState();
}

class _RoleFormScreenState extends State<RoleFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _codeController;
  late final TextEditingController _nameController;
  late final TextEditingController _noteController;
  late final TextEditingController _levelController;
  ApiException? _error;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final role = widget.existingRole;
    _codeController = TextEditingController(text: role?.code ?? '');
    _nameController = TextEditingController(text: role?.name ?? '');
    _noteController = TextEditingController(text: role?.note ?? '');
    _levelController = TextEditingController(
      text: role?.levelRole?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _noteController.dispose();
    _levelController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_submitting || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final code = _codeController.text.trim();
      final name = _nameController.text.trim();
      final note = _emptyToNull(_noteController.text);
      final levelRole = _nullableInt(_levelController.text);
      final role = widget.isEditing
          ? await widget.controller.update(
              widget.existingRole!.id,
              UpdateRoleRequest(
                code: code,
                name: name,
                note: note,
                levelRole: levelRole,
              ),
            )
          : await widget.controller.create(
              CreateRoleRequest(
                code: code,
                name: name,
                note: note,
                levelRole: levelRole,
              ),
            );
      if (mounted) Navigator.pop(context, role);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Cập nhật vai trò' : 'Tạo vai trò'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: accessPagePadding(context, bottom: 32),
            children: [
              AccessConstrainedContent(
                maxWidth: 720,
                child: Column(
                  children: [
                    if (_error != null) ...[
                      ErrorPanel(message: _error!.message),
                      const SizedBox(height: 16),
                    ],
                    AccessSection(
                      title: 'Thông tin vai trò',
                      icon: Icons.admin_panel_settings_outlined,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _codeController,
                              maxLength: 100,
                              textCapitalization: TextCapitalization.characters,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                labelText: 'Mã vai trò *',
                                counterText: '',
                                errorText: _error?.fieldMessage('code'),
                              ),
                              validator: (value) =>
                                  (value?.trim().isEmpty ?? true)
                                  ? 'Mã vai trò là bắt buộc.'
                                  : null,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _nameController,
                              maxLength: 1000,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                labelText: 'Tên vai trò *',
                                counterText: '',
                                errorText: _error?.fieldMessage('name'),
                              ),
                              validator: (value) =>
                                  (value?.trim().isEmpty ?? true)
                                  ? 'Tên vai trò là bắt buộc.'
                                  : null,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _levelController,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                labelText: 'Cấp quản lý',
                                errorText: _error?.fieldMessage('levelRole'),
                              ),
                              validator: (value) {
                                final text = value?.trim() ?? '';
                                if (text.isNotEmpty &&
                                    int.tryParse(text) == null) {
                                  return 'Cấp quản lý phải là số nguyên.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _noteController,
                              maxLines: 4,
                              textInputAction: TextInputAction.newline,
                              decoration: InputDecoration(
                                labelText: 'Ghi chú',
                                alignLabelWithHint: true,
                                errorText: _error?.fieldMessage('note'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _submitting ? null : _submit,
                        icon: _submitting
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(
                          _submitting ? 'Đang lưu...' : 'Lưu vai trò',
                        ),
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

  String? _emptyToNull(String value) {
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }

  int? _nullableInt(String value) {
    final normalized = value.trim();
    return normalized.isEmpty ? null : int.parse(normalized);
  }
}
