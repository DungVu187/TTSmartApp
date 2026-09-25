import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/app_scope.dart';
import '../../../../core/ui/app_ui.dart';
import '../../../../core/widgets/password_field.dart';
import '../../../company_management/data/models/company_models.dart';
import '../../../company_management/data/repositories/company_repository.dart';
import '../../../station_management/data/models/station_models.dart';
import '../../../station_management/data/repositories/station_repository.dart';
import '../../data/models/role_models.dart';
import '../../data/models/user_models.dart';
import '../controllers/users_controller.dart';
import '../widgets/access_layout.dart';
import 'station_picker_screen.dart';

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
    final result = await Navigator.of(context).push<Set<int>>(
      MaterialPageRoute(
        builder: (_) => StationPickerScreen(
          stations: stations,
          selectedIds: _selectedBranchIds,
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

  String _stationErrorMessage(Object error) => error is ApiException
      ? 'Không thể tải danh sách trạm: ${error.message}'
      : 'Không thể tải danh sách trạm.';

  List<int> _parseBranchIds(String? value) => (value ?? '')
      .split(',')
      .map(int.tryParse)
      .whereType<int>()
      .where((id) => id > 0)
      .toSet()
      .toList(growable: false);

  String? _branchIdValue() =>
      _selectedBranchIds.isEmpty ? null : _selectedBranchIds.join(',');

  Future<void> _pickCompany(List<CompanyResponse> companies) async {
    final picked = await showPickerSheet<int>(
      context: context,
      title: 'Chọn công ty',
      searchHint: 'Tìm công ty',
      icon: Icons.apartment_outlined,
      selected: _companyId,
      options: [
        for (final company in companies)
          PickerOption(
            value: company.id,
            title: company.displayName,
            subtitle: company.code,
          ),
      ],
    );
    final companyId = picked?.value;
    if (!mounted || companyId == null) return;
    _selectCompany(companies.firstWhere((company) => company.id == companyId));
  }

  Widget _buildOrganizationScope() {
    return FutureBuilder<List<CompanyResponse>>(
      future: _companiesFuture,
      builder: (context, companySnapshot) {
        final companies = companySnapshot.data ?? const <CompanyResponse>[];
        final loadingCompanies =
            companySnapshot.connectionState == ConnectionState.waiting;
        String? companyName;
        for (final company in companies) {
          if (company.id == _companyId) companyName = company.displayName;
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_canSelectCompany) ...[
              SelectFieldButton(
                key: const ValueKey<String>('user-form-company'),
                label: 'Công ty',
                placeholder: loadingCompanies
                    ? 'Đang tải công ty…'
                    : 'Chọn công ty',
                value:
                    companyName ??
                    (_companyId == null ? null : 'Công ty #$_companyId'),
                icon: Icons.apartment_outlined,
                enabled:
                    !_submitting &&
                    !companySnapshot.hasError &&
                    !loadingCompanies,
                errorText: _error?.fieldMessage('companyId'),
                onTap: () => _pickCompany(companies),
                onClear: _companyId == null ? null : _clearCompany,
              ),
              if (companySnapshot.hasError) ...[
                const SizedBox(height: 6),
                const FieldError('Không thể tải danh sách công ty.'),
              ],
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
                // Chỉ kết luận "trạm cũ" khi danh sách đã tải xong; nếu request lỗi
                // thì list rỗng không có nghĩa là các trạm đã gán không hợp lệ.
                final stationsLoaded =
                    stationSnapshot.connectionState == ConnectionState.done &&
                    !stationSnapshot.hasError;
                final staleIds = stationsLoaded
                    ? _selectedBranchIds
                          .where((id) => !stationById.containsKey(id))
                          .toList(growable: false)
                    : const <int>[];
                final loadingStations =
                    stationSnapshot.connectionState == ConnectionState.waiting;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SelectFieldButton(
                      key: const ValueKey<String>('user-form-stations'),
                      label: 'Trạm trộn / trạm cân',
                      placeholder: _companyId == null
                          ? 'Chọn công ty trước'
                          : loadingStations
                          ? 'Đang tải trạm…'
                          : 'Chọn một hoặc nhiều trạm',
                      value: _selectedBranchIds.isEmpty
                          ? null
                          : 'Đã chọn ${_selectedBranchIds.length} trạm',
                      icon: Icons.factory_outlined,
                      enabled:
                          !_submitting &&
                          _companyId != null &&
                          !loadingStations &&
                          !stationSnapshot.hasError,
                      errorText: _error?.fieldMessage('branchId'),
                      onTap: () => _pickStations(stations),
                    ),
                    if (stationSnapshot.hasError) ...[
                      const SizedBox(height: 6),
                      FieldError(_stationErrorMessage(stationSnapshot.error!)),
                    ],
                    if (staleIds.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      const FieldError(
                        'Có trạm cũ không thuộc công ty hiện tại. '
                        'Hãy gỡ trước khi lưu.',
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
                                    (stationsLoaded
                                        ? 'Trạm #$id (không hợp lệ)'
                                        : 'Trạm #$id'),
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
    final result = await showAppModalSheet<Set<int>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AppSheetFrame(
          title: 'Chọn vai trò',
          footer: AppButton(
            key: const ValueKey<String>('user-form-roles-done'),
            label: selected.isEmpty ? 'Xong' : 'Xong · ${selected.length}',
            onPressed: () => Navigator.pop(context, selected),
          ),
          child: roles.isEmpty
              ? const StateView(
                  icon: Icons.badge_outlined,
                  title: 'Chưa có vai trò',
                  message: 'Chưa có vai trò hiệu lực để gán.',
                )
              : InsetCard(
                  children: [
                    for (final role in roles)
                      CheckboxListTile(
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
                      ),
                  ],
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
        leading: IconButton(
          tooltip: 'Đóng',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text(widget.isEditing ? 'Sửa người dùng' : 'Thêm người dùng'),
        actions: [
          AccessSaveAction(submitting: _submitting, onPressed: _submit),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: accessPagePadding(context, top: 8, bottom: 32),
            children: [
              AccessConstrainedContent(
                maxWidth: 820,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_error != null) ...[
                      ErrorBanner(message: _error!.message),
                      const SizedBox(height: 16),
                    ],
                    FormFieldGroup(
                      label: 'Tài khoản',
                      children: [
                        LabeledTextField(
                          label: 'Tên đăng nhập *',
                          controller: _userNameController,
                          maxLength: 100,
                          textInputAction: TextInputAction.next,
                          errorText: _error?.fieldMessage('userName'),
                          validator: (value) => value?.trim().isEmpty != false
                              ? 'Tên đăng nhập là bắt buộc.'
                              : null,
                        ),
                        LabeledTextField(
                          label: 'Họ và tên',
                          controller: _fullNameController,
                          maxLength: 200,
                          textInputAction: TextInputAction.next,
                          errorText: _error?.fieldMessage('fullName'),
                        ),
                        LabeledTextField(
                          label: 'Mã người dùng',
                          controller: _codeController,
                          maxLength: 100,
                          textInputAction: TextInputAction.next,
                          errorText: _error?.fieldMessage('code'),
                        ),
                        if (!widget.isEditing)
                          PasswordField(
                            controller: _passwordController,
                            label: 'Mật khẩu *',
                            labelAbove: true,
                            errorText: _error?.fieldMessage('password'),
                            validator: (value) =>
                                value == null || value.length < 4
                                ? 'Mật khẩu phải có từ 4 đến 200 ký tự.'
                                : null,
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    FormFieldGroup(
                      label: 'Tổ chức',
                      children: [
                        _buildOrganizationScope(),
                        if (!widget.isEditing) _buildRolesField(),
                      ],
                    ),
                    const SizedBox(height: 24),
                    FormFieldGroup(
                      label: 'Liên hệ',
                      children: [
                        LabeledTextField(
                          label: 'Email',
                          controller: _emailController,
                          maxLength: 50,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          errorText: _error?.fieldMessage('email'),
                        ),
                        LabeledTextField(
                          label: 'Số điện thoại',
                          controller: _phoneController,
                          maxLength: 50,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                          errorText: _error?.fieldMessage('phone'),
                        ),
                        LabeledTextField(
                          label: 'Địa chỉ',
                          controller: _addressController,
                          maxLength: 200,
                          minLines: 1,
                          maxLines: 3,
                          errorText: _error?.fieldMessage('address'),
                        ),
                      ],
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

  /// Initial roles of a new user (the edit flow manages roles elsewhere).
  Widget _buildRolesField() {
    return FutureBuilder<List<RoleListItemResponse>>(
      future: _rolesFuture,
      builder: (context, snapshot) {
        final roles = snapshot.data ?? const <RoleListItemResponse>[];
        final names = [
          for (final role in roles)
            if (_selectedRoleIds.contains(role.id)) role.name,
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SelectFieldButton(
              key: const ValueKey<String>('user-form-roles'),
              label: 'Vai trò ban đầu',
              placeholder: snapshot.connectionState == ConnectionState.waiting
                  ? 'Đang tải vai trò…'
                  : 'Chưa chọn vai trò',
              value: _selectedRoleIds.isEmpty
                  ? null
                  : names.length == _selectedRoleIds.length
                  ? names.join(', ')
                  : 'Đã chọn ${_selectedRoleIds.length} vai trò',
              icon: Icons.badge_outlined,
              trailingIcon: Icons.chevron_right_rounded,
              enabled: snapshot.hasData && !_submitting,
              onTap: () => _pickRoles(roles),
            ),
            if (snapshot.hasError) ...[
              const SizedBox(height: 6),
              const FieldError('Không thể tải danh sách vai trò.'),
            ],
          ],
        );
      },
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
