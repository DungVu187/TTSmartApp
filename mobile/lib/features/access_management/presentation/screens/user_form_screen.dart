import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/app_scope.dart';
import '../../../../core/widgets/error_panel.dart';
import '../../../../core/widgets/password_field.dart';
import '../../../company_management/data/models/company_models.dart';
import '../../../company_management/data/repositories/company_repository.dart';
import '../../../company_management/presentation/widgets/company_autocomplete_field.dart';
import '../../../station_management/data/models/station_models.dart';
import '../../../station_management/data/repositories/station_repository.dart';
import '../../data/models/role_models.dart';
import '../../data/models/user_models.dart';
import '../controllers/users_controller.dart';
import '../widgets/access_layout.dart';

class UserFormScreen extends StatefulWidget {
  const UserFormScreen({
    super.key,
    required this.controller,
    required this.companyRepository,
    required this.stationRepository,
    this.existingUser,
  });

  final UsersController controller;
  final CompanyRepository companyRepository;
  final StationRepository stationRepository;
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
  late final TextEditingController _departmentIdController;
  late final TextEditingController _positionIdController;
  late final TextEditingController _unitIdController;
  late final TextEditingController _passwordController;
  late final Future<List<RoleListItemResponse>> _rolesFuture;
  late final Future<List<CompanyResponse>> _companiesFuture;
  final Set<int> _selectedRoleIds = <int>{};
  final Set<int> _selectedBranchIds = <int>{};
  Future<List<StationListItem>>? _stationsFuture;
  late final bool _canSelectCompany;
  int? _companyId;
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
    _departmentIdController = TextEditingController(
      text: user?.departmentId?.toString() ?? '',
    );
    _positionIdController = TextEditingController(
      text: user?.positionId?.toString() ?? '',
    );
    _unitIdController = TextEditingController(
      text: user?.unitId?.toString() ?? '',
    );
    _passwordController = TextEditingController();
    _selectedRoleIds.addAll(user?.roles.map((role) => role.id) ?? const []);
    final app = AppScope.read(context);
    _canSelectCompany = app.hasRole('ADMIN');
    _companyId =
        user?.companyId ??
        (_canSelectCompany ? null : app.session?.user.companyId);
    _selectedBranchIds.addAll(_parseBranchIds(user?.branchId));
    _rolesFuture = widget.controller.getAvailableRoles();
    _companiesFuture = _canSelectCompany
        ? _loadCompanies()
        : Future.value(const <CompanyResponse>[]);
    _stationsFuture = _loadStations(_companyId);
  }

  @override
  void dispose() {
    _userNameController.dispose();
    _fullNameController.dispose();
    _codeController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _departmentIdController.dispose();
    _positionIdController.dispose();
    _unitIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<List<CompanyResponse>> _loadCompanies() async {
    final result = <CompanyResponse>[];
    var pageNumber = 1;
    var totalPages = 1;
    do {
      final page = await widget.companyRepository.getCompanies(
        pageNumber: pageNumber,
        pageSize: 100,
        status: CompanyDataStatus.active,
      );
      result.addAll(page.items);
      totalPages = page.totalPages;
      pageNumber++;
    } while (pageNumber <= totalPages);
    return result;
  }

  Future<List<StationListItem>> _loadStations(int? companyId) async {
    if (companyId == null) return const <StationListItem>[];
    final result = <StationListItem>[];
    var pageNumber = 1;
    var totalPages = 1;
    do {
      final page = await widget.stationRepository.getStations(
        pageNumber: pageNumber,
        pageSize: 100,
        companyId: companyId,
        status: StationDataStatus.active,
      );
      result.addAll(page.items);
      totalPages = page.totalPages;
      pageNumber++;
    } while (pageNumber <= totalPages);
    return result;
  }

  void _selectCompany(CompanyResponse company) {
    setState(() {
      if (_companyId != company.id) _selectedBranchIds.clear();
      _companyId = company.id;
      _stationsFuture = _loadStations(company.id);
    });
  }

  void _clearCompany() {
    setState(() {
      _companyId = null;
      _selectedBranchIds.clear();
      _stationsFuture = _loadStations(null);
    });
  }

  Future<void> _pickStations(List<StationListItem> stations) async {
    final selected = Set<int>.from(_selectedBranchIds);
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
                  leading: Icon(Icons.factory_outlined),
                  title: Text('Chọn trạm'),
                  subtitle: Text('Có thể chọn nhiều trạm thuộc công ty.'),
                ),
                const Divider(height: 1),
                Expanded(
                  child: stations.isEmpty
                      ? const Center(
                          child: Text('Công ty chưa có trạm hiệu lực.'),
                        )
                      : ListView.builder(
                          itemCount: stations.length,
                          itemBuilder: (context, index) {
                            final station = stations[index];
                            return CheckboxListTile(
                              value: selected.contains(station.id),
                              title: Text(station.displayName),
                              subtitle: Text(station.type?.label ?? 'Trạm'),
                              onChanged: (checked) => setModalState(() {
                                if (checked == true) {
                                  selected.add(station.id);
                                } else {
                                  selected.remove(station.id);
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
        _selectedBranchIds
          ..clear()
          ..addAll(result);
      });
    }
  }

  List<int> _parseBranchIds(String? value) => (value ?? '')
      .split(',')
      .map(int.tryParse)
      .whereType<int>()
      .where((id) => id > 0)
      .toSet()
      .toList(growable: false);

  String? _branchIdValue() =>
      _selectedBranchIds.isEmpty ? null : _selectedBranchIds.join(',');

  Widget _buildOrganizationScope() {
    return FutureBuilder<List<CompanyResponse>>(
      future: _companiesFuture,
      builder: (context, companySnapshot) {
        final companies = companySnapshot.data ?? const <CompanyResponse>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_canSelectCompany) ...[
              CompanyAutocompleteField(
                companies: companies,
                selectedCompanyId: _companyId,
                onSelected: _selectCompany,
                onCleared: _clearCompany,
                enabled:
                    !_submitting &&
                    !companySnapshot.hasError &&
                    companySnapshot.connectionState != ConnectionState.waiting,
                hintText: 'Chọn công ty',
                labelText: 'Công ty',
                errorText: _error?.fieldMessage('companyId'),
              ),
              if (companySnapshot.connectionState == ConnectionState.waiting)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: LinearProgressIndicator(),
                ),
              if (companySnapshot.hasError)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('Không thể tải danh sách công ty.'),
                ),
              const SizedBox(height: 14),
            ],
            FutureBuilder<List<StationListItem>>(
              future: _stationsFuture,
              builder: (context, stationSnapshot) {
                final stations =
                    stationSnapshot.data ?? const <StationListItem>[];
                final stationById = {
                  for (final station in stations) station.id: station,
                };
                final staleIds = _selectedBranchIds
                    .where((id) => !stationById.containsKey(id))
                    .toList(growable: false);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: _companyId == null || stationSnapshot.hasError
                          ? null
                          : () => _pickStations(stations),
                      borderRadius: BorderRadius.circular(12),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Trạm trộn / trạm cân',
                          prefixIcon: const Icon(Icons.factory_outlined),
                          suffixIcon: const Icon(Icons.arrow_drop_down),
                          errorText: _error?.fieldMessage('branchId'),
                        ),
                        child: Text(
                          _selectedBranchIds.isEmpty
                              ? _companyId == null
                                    ? 'Chọn công ty trước'
                                    : 'Chọn một hoặc nhiều trạm'
                              : 'Đã chọn ${_selectedBranchIds.length} trạm',
                          style: TextStyle(
                            color: _companyId == null
                                ? Theme.of(context).colorScheme.onSurfaceVariant
                                : null,
                          ),
                        ),
                      ),
                    ),
                    if (stationSnapshot.connectionState ==
                        ConnectionState.waiting)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: LinearProgressIndicator(),
                      ),
                    if (staleIds.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Có trạm cũ không thuộc công ty hiện tại. Hãy gỡ trước khi lưu.',
                        style: TextStyle(color: Colors.red),
                      ),
                    ],
                    if (_selectedBranchIds.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final id in _selectedBranchIds)
                            InputChip(
                              label: Text(
                                stationById[id]?.displayName ??
                                    'Trạm #$id (không hợp lệ)',
                              ),
                              onDeleted: () =>
                                  setState(() => _selectedBranchIds.remove(id)),
                            ),
                        ],
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
        );
      },
    );
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
                companyId: _companyId,
                roleMax: existing.roleMax,
                roleLevel: existing.roleLevel,
                isRoleGroup: existing.isRoleGroup,
                branchId: _branchIdValue(),
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
                companyId: _companyId,
                branchId: _branchIdValue(),
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
        title: Text(widget.isEditing ? 'Sửa người dùng' : 'Thêm người dùng'),
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
                              decoration: InputDecoration(
                                labelText: 'Tên đăng nhập *',
                                counterText: '',
                                errorText: _error?.fieldMessage('userName'),
                              ),
                              validator: (value) =>
                                  value?.trim().isEmpty != false
                                  ? 'Tên đăng nhập là bắt buộc.'
                                  : null,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _fullNameController,
                              maxLength: 200,
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
                                errorText: _error?.fieldMessage('password'),
                                validator: (value) =>
                                    value == null || value.length < 4
                                    ? 'Mật khẩu phải có từ 4 đến 200 ký tự.'
                                    : null,
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
                        child: _buildOrganizationScope(),
                      ),
                    ),
                    if (!widget.isEditing) ...[
                      const SizedBox(height: 20),
                      AccessSection(
                        title: 'Vai trò ban đầu',
                        icon: Icons.badge_outlined,
                        child: FutureBuilder<List<RoleListItemResponse>>(
                          future: _rolesFuture,
                          builder: (context, snapshot) => ListTile(
                            title: Text(
                              _selectedRoleIds.isEmpty
                                  ? 'Chưa chọn vai trò'
                                  : 'Đã chọn ${_selectedRoleIds.length} vai trò',
                            ),
                            subtitle: Text(
                              snapshot.hasError
                                  ? 'Không thể tải danh sách vai trò.'
                                  : 'Vai trò được gửi bằng ID số nguyên.',
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
                          ),
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
