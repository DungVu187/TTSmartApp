import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/widgets/error_panel.dart';
import '../../../../core/widgets/password_field.dart';
import '../../data/models/role_models.dart';
import '../../data/models/user_models.dart';
import '../controllers/users_controller.dart';
import '../widgets/access_layout.dart';

class UserFormScreen extends StatefulWidget {
  const UserFormScreen({
    super.key,
    required this.controller,
    this.existingUser,
  });

  final UsersController controller;
  final UserResponse? existingUser;

  bool get isEditing => existingUser != null;

  @override
  State<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends State<UserFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _userNameController;
  late final TextEditingController _fullNameController;
  late final TextEditingController _codeController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  late final TextEditingController _companyIdController;
  late final TextEditingController _departmentIdController;
  late final TextEditingController _positionIdController;
  late final TextEditingController _unitIdController;
  late final TextEditingController _branchIdController;
  late final TextEditingController _passwordController;
  late final Future<List<RoleListItemResponse>> _rolesFuture;
  final Set<int> _selectedRoleIds = <int>{};
  ApiException? _error;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final user = widget.existingUser;
    _userNameController = TextEditingController(text: user?.userName ?? '');
    _fullNameController = TextEditingController(text: user?.fullName ?? '');
    _codeController = TextEditingController(text: user?.code ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
    _addressController = TextEditingController(text: user?.address ?? '');
    _companyIdController = TextEditingController(
      text: user?.companyId?.toString() ?? '',
    );
    _departmentIdController = TextEditingController(
      text: user?.departmentId?.toString() ?? '',
    );
    _positionIdController = TextEditingController(
      text: user?.positionId?.toString() ?? '',
    );
    _unitIdController = TextEditingController(
      text: user?.unitId?.toString() ?? '',
    );
    _branchIdController = TextEditingController(text: user?.branchId ?? '');
    _passwordController = TextEditingController();
    _selectedRoleIds.addAll(user?.roles.map((role) => role.id) ?? const []);
    _rolesFuture = widget.controller.getAvailableRoles();
  }

  @override
  void dispose() {
    _userNameController.dispose();
    _fullNameController.dispose();
    _codeController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _companyIdController.dispose();
    _departmentIdController.dispose();
    _positionIdController.dispose();
    _unitIdController.dispose();
    _branchIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _pickRoles(List<RoleListItemResponse> roles) async {
    final selected = Set<int>.from(_selectedRoleIds);
    final result = await showModalBottomSheet<Set<int>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .76,
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.badge_outlined),
                  title: Text('Chọn vai trò'),
                ),
                const Divider(height: 1),
                Expanded(
                  child: roles.isEmpty
                      ? const Center(child: Text('Chưa có vai trò hiệu lực.'))
                      : ListView.builder(
                          itemCount: roles.length,
                          itemBuilder: (context, index) {
                            final role = roles[index];
                            return CheckboxListTile(
                              value: selected.contains(role.id),
                              title: Text(role.name),
                              subtitle: Text(
                                role.note?.trim().isNotEmpty == true
                                    ? '${role.code} • ${role.note}'
                                    : role.code,
                              ),
                              onChanged: (checked) => setModalState(() {
                                if (checked == true) {
                                  selected.add(role.id);
                                } else {
                                  selected.remove(role.id);
                                }
                              }),
                            );
                          },
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, selected),
                      child: const Text('Xong'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _selectedRoleIds
          ..clear()
          ..addAll(result);
      });
    }
  }

  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_submitting || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final existing = widget.existingUser;
      final response = widget.isEditing
          ? await widget.controller.update(
              existing!.id,
              UpdateUserRequest(
                userName: _userNameController.text.trim(),
                fullName: _emptyToNull(_fullNameController.text),
                email: _emptyToNull(_emailController.text),
                code: _emptyToNull(_codeController.text),
                regEmail: existing.regEmail,
                address: _emptyToNull(_addressController.text),
                phone: _emptyToNull(_phoneController.text),
                unitId: _nullableInt(_unitIdController.text),
                positionId: _nullableInt(_positionIdController.text),
                departmentId: _nullableInt(_departmentIdController.text),
                companyId: _nullableInt(_companyIdController.text),
                roleMax: existing.roleMax,
                roleLevel: existing.roleLevel,
                isRoleGroup: existing.isRoleGroup,
                branchId: _emptyToNull(_branchIdController.text),
              ),
            )
          : await widget.controller.create(
              CreateUserRequest(
                userName: _userNameController.text.trim(),
                password: _passwordController.text,
                roleIds: _selectedRoleIds.toList(growable: false),
                fullName: _emptyToNull(_fullNameController.text),
                email: _emptyToNull(_emailController.text),
                code: _emptyToNull(_codeController.text),
                address: _emptyToNull(_addressController.text),
                phone: _emptyToNull(_phoneController.text),
                unitId: _nullableInt(_unitIdController.text),
                positionId: _nullableInt(_positionIdController.text),
                departmentId: _nullableInt(_departmentIdController.text),
                companyId: _nullableInt(_companyIdController.text),
                branchId: _emptyToNull(_branchIdController.text),
              ),
            );
      if (mounted) Navigator.pop(context, response);
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
        title: Text(
          widget.isEditing ? 'Cập nhật người dùng' : 'Tạo người dùng',
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: accessPagePadding(context, bottom: 32),
            children: [
              AccessConstrainedContent(
                maxWidth: 820,
                child: Column(
                  children: [
                    if (_error != null) ...[
                      ErrorPanel(message: _error!.message),
                      const SizedBox(height: 16),
                    ],
                    AccessSection(
                      title: 'Tài khoản',
                      icon: Icons.manage_accounts_outlined,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _userNameController,
                              maxLength: 100,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                labelText: 'Tên đăng nhập *',
                                counterText: '',
                                errorText: _error?.fieldMessage('userName'),
                              ),
                              validator: (value) {
                                final text = value?.trim() ?? '';
                                if (text.isEmpty) {
                                  return 'Tên đăng nhập là bắt buộc.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _fullNameController,
                              maxLength: 200,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                labelText: 'Họ tên',
                                counterText: '',
                                errorText: _error?.fieldMessage('fullName'),
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _codeController,
                              maxLength: 100,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                labelText: 'Mã người dùng',
                                counterText: '',
                                errorText: _error?.fieldMessage('code'),
                              ),
                            ),
                            if (!widget.isEditing) ...[
                              const SizedBox(height: 14),
                              PasswordField(
                                controller: _passwordController,
                                label: 'Mật khẩu *',
                                textInputAction: TextInputAction.next,
                                errorText: _error?.fieldMessage('password'),
                                validator: (value) {
                                  final length = value?.length ?? 0;
                                  if (length < 6 || length > 200) {
                                    return 'Mật khẩu phải có từ 6 đến 200 ký tự.';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    AccessSection(
                      title: 'Liên hệ',
                      icon: Icons.contact_mail_outlined,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _emailController,
                              maxLength: 50,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                labelText: 'Email',
                                counterText: '',
                                errorText: _error?.fieldMessage('email'),
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _phoneController,
                              maxLength: 50,
                              keyboardType: TextInputType.phone,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                labelText: 'Số điện thoại',
                                counterText: '',
                                errorText: _error?.fieldMessage('phone'),
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _addressController,
                              maxLength: 200,
                              maxLines: 2,
                              decoration: InputDecoration(
                                labelText: 'Địa chỉ',
                                counterText: '',
                                errorText: _error?.fieldMessage('address'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    AccessSection(
                      title: 'Tổ chức',
                      icon: Icons.apartment_outlined,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _IdField(
                                    controller: _companyIdController,
                                    label: 'Company ID',
                                    errorText: _error?.fieldMessage(
                                      'companyId',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _IdField(
                                    controller: _departmentIdController,
                                    label: 'Department ID',
                                    errorText: _error?.fieldMessage(
                                      'departmentId',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: _IdField(
                                    controller: _positionIdController,
                                    label: 'Position ID',
                                    errorText: _error?.fieldMessage(
                                      'positionId',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _IdField(
                                    controller: _unitIdController,
                                    label: 'Unit ID',
                                    errorText: _error?.fieldMessage('unitId'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _branchIdController,
                              maxLength: 1000,
                              decoration: InputDecoration(
                                labelText: 'Phạm vi chi nhánh',
                                counterText: '',
                                errorText: _error?.fieldMessage('branchId'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (!widget.isEditing) ...[
                      const SizedBox(height: 20),
                      AccessSection(
                        title: 'Vai trò ban đầu',
                        icon: Icons.badge_outlined,
                        child: FutureBuilder<List<RoleListItemResponse>>(
                          future: _rolesFuture,
                          builder: (context, snapshot) {
                            return ListTile(
                              minVerticalPadding: 14,
                              title: Text(
                                _selectedRoleIds.isEmpty
                                    ? 'Chưa chọn vai trò'
                                    : 'Đã chọn ${_selectedRoleIds.length} vai trò',
                              ),
                              subtitle: snapshot.hasError
                                  ? const Text(
                                      'Không thể tải danh sách vai trò.',
                                    )
                                  : const Text(
                                      'Vai trò được gửi bằng ID số nguyên.',
                                    ),
                              trailing:
                                  snapshot.connectionState ==
                                      ConnectionState.waiting
                                  ? const SizedBox.square(
                                      dimension: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.chevron_right),
                              onTap: snapshot.hasData
                                  ? () => _pickRoles(snapshot.data!)
                                  : null,
                            );
                          },
                        ),
                      ),
                    ],
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
                          _submitting ? 'Đang lưu...' : 'Lưu người dùng',
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

class _IdField extends StatelessWidget {
  const _IdField({
    required this.controller,
    required this.label,
    required this.errorText,
  });

  final TextEditingController controller;
  final String label;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label, errorText: errorText),
      validator: (value) {
        final text = value?.trim() ?? '';
        if (text.isNotEmpty && int.tryParse(text) == null) {
          return 'ID phải là số nguyên.';
        }
        return null;
      },
    );
  }
}
