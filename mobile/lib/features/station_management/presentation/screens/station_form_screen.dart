import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/widgets/error_panel.dart';
import '../../../company_management/data/models/company_models.dart';
import '../../../company_management/data/repositories/company_repository.dart';
import '../../../company_management/presentation/widgets/company_autocomplete_field.dart';
import '../../data/models/station_models.dart';
import '../controllers/stations_controller.dart';
import '../widgets/station_widgets.dart';

class StationFormScreen extends StatefulWidget {
  const StationFormScreen({
    super.key,
    required this.controller,
    required this.companyRepository,
    required this.isAdmin,
    this.existingStation,
  });

  final StationsController controller;
  final CompanyRepository companyRepository;
  final bool isAdmin;
  final StationResponse? existingStation;

  bool get isEditing => existingStation != null;

  @override
  State<StationFormScreen> createState() => _StationFormScreenState();
}

class _StationFormScreenState extends State<StationFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _codeController;
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  late final TextEditingController _pmqlXeController;
  late final TextEditingController _qlCameraController;
  late final Future<List<CompanyResponse>>? _companiesFuture;
  int? _companyId;
  int? _typeTram;
  ApiException? _error;
  bool _submitting = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    final station = widget.existingStation;
    _codeController = TextEditingController(text: station?.code ?? '');
    _nameController = TextEditingController(text: station?.name ?? '');
    _emailController = TextEditingController(text: station?.email ?? '');
    _phoneController = TextEditingController(text: station?.phone ?? '');
    _addressController = TextEditingController(text: station?.address ?? '');
    _usernameController = TextEditingController(text: station?.username ?? '');
    _passwordController = TextEditingController();
    _pmqlXeController = TextEditingController(text: station?.pmqlXe ?? '');
    _qlCameraController = TextEditingController(text: station?.qlCamera ?? '');
    _companyId = station?.companyId;
    _typeTram = station?.typeTram ?? StationType.mixing.value;
    _companiesFuture = widget.isAdmin ? _loadCompanies() : null;
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _pmqlXeController.dispose();
    _qlCameraController.dispose();
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

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate() || _submitting) return;
    if (widget.isAdmin && _companyId == null) {
      setState(
        () => _error = const ApiException(
          type: ApiFailureType.validation,
          message: 'Vui lòng tải và chọn công ty trước khi lưu trạm.',
        ),
      );
      return;
    }
    if (widget.isAdmin && _typeTram == null) {
      setState(
        () => _error = const ApiException(
          type: ApiFailureType.validation,
          message: 'Vui lòng chọn loại trạm trước khi lưu.',
        ),
      );
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final station = widget.isEditing
          ? await widget.controller.update(
              widget.existingStation!.id,
              _buildUpdateRequest(),
            )
          : await widget.controller.create(_buildCreateRequest());
      if (mounted) Navigator.of(context).pop(station);
    } on ApiException catch (caught) {
      if (mounted) {
        setState(() {
          _error = caught;
          _submitting = false;
        });
      }
    }
  }

  CreateStationRequest _buildCreateRequest() => CreateStationRequest(
    companyId: _companyId!,
    code: _codeController.text.trim(),
    name: _nameController.text.trim(),
    email: _emailController.text.trim(),
    phone: _phoneController.text.trim(),
    address: _emptyToNull(_addressController.text),
    username: _usernameController.text.trim(),
    password: _passwordController.text,
    pmqlXe: _emptyToNull(_pmqlXeController.text),
    qlCamera: _emptyToNull(_qlCameraController.text),
    typeTram: _typeTram!,
  );

  UpdateStationRequest _buildUpdateRequest() => UpdateStationRequest(
    companyId: widget.isAdmin ? _companyId : null,
    code: _codeController.text.trim(),
    name: _nameController.text.trim(),
    email: _emailController.text.trim(),
    phone: _phoneController.text.trim(),
    address: _addressController.text.trim(),
    username: widget.isAdmin ? _usernameController.text.trim() : null,
    password: _passwordController.text.trim().isEmpty
        ? null
        : _passwordController.text,
    pmqlXe: _pmqlXeController.text.trim(),
    qlCamera: _qlCameraController.text.trim(),
    typeTram: widget.isAdmin ? _typeTram : null,
  );

  @override
  Widget build(BuildContext context) {
    final title = widget.isEditing ? 'Sửa trạm' : 'Thêm trạm';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 960),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_error != null) ...[
                        ErrorPanel(message: _error!.message),
                        const SizedBox(height: 16),
                      ],
                      if (widget.isAdmin) ...[
                        _buildAdministrativeSection(),
                        const SizedBox(height: 20),
                      ] else if (widget.existingStation != null) ...[
                        _buildReadOnlyScope(),
                        const SizedBox(height: 20),
                      ],
                      StationSection(
                        title: 'Thông tin trạm',
                        icon: Icons.factory_outlined,
                        description: 'Thông tin nhận diện và liên hệ của trạm.',
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: _FieldGrid(
                            children: [
                              _textField(
                                controller: _codeController,
                                label: 'Mã trạm *',
                                icon: Icons.tag_outlined,
                                errorField: 'Code',
                                textCapitalization:
                                    TextCapitalization.characters,
                                validator: (value) => _requiredMax(
                                  value,
                                  'Vui lòng nhập mã trạm.',
                                  100,
                                ),
                              ),
                              _textField(
                                controller: _nameController,
                                label: 'Tên trạm *',
                                icon: Icons.badge_outlined,
                                errorField: 'Name',
                                validator: (value) => _requiredMax(
                                  value,
                                  'Vui lòng nhập tên trạm.',
                                  1000,
                                ),
                              ),
                              _textField(
                                controller: _emailController,
                                label: 'Email *',
                                icon: Icons.email_outlined,
                                keyboardType: TextInputType.emailAddress,
                                textCapitalization: TextCapitalization.none,
                                errorField: 'Email',
                                validator: (value) => _emailValidator(
                                  value,
                                  required: true,
                                  fieldName: 'Email',
                                ),
                              ),
                              _textField(
                                controller: _phoneController,
                                label: 'Số điện thoại *',
                                icon: Icons.phone_outlined,
                                keyboardType: TextInputType.phone,
                                textCapitalization: TextCapitalization.none,
                                errorField: 'Phone',
                                validator: (value) => _requiredMax(
                                  value,
                                  'Vui lòng nhập số điện thoại.',
                                  100,
                                ),
                              ),
                              _textField(
                                controller: _addressController,
                                label: 'Địa chỉ',
                                icon: Icons.location_on_outlined,
                                errorField: 'Address',
                                minLines: 2,
                                maxLines: 4,
                                alignLabelWithHint: true,
                                textInputAction: TextInputAction.newline,
                                validator: (value) => _optionalMax(value, 1000),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      StationSection(
                        title: 'Tích hợp vận hành',
                        icon: Icons.settings_input_component_outlined,
                        description:
                            'Có thể để trống nếu trạm chưa dùng hệ thống tích hợp.',
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: _FieldGrid(
                            children: [
                              _textField(
                                controller: _pmqlXeController,
                                label: 'Phần mềm quản lý xe',
                                icon: Icons.local_shipping_outlined,
                                errorField: 'pmqlXe',
                                textCapitalization: TextCapitalization.none,
                                validator: (value) => _optionalMax(value, 1000),
                              ),
                              _textField(
                                controller: _qlCameraController,
                                label: 'Phần mềm quản lý camera',
                                icon: Icons.videocam_outlined,
                                errorField: 'qlCamera',
                                textCapitalization: TextCapitalization.none,
                                textInputAction: widget.isAdmin
                                    ? TextInputAction.next
                                    : TextInputAction.done,
                                validator: (value) => _optionalMax(value, 1000),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (widget.isAdmin) ...[
                        const SizedBox(height: 20),
                        StationSection(
                          title: 'Tài khoản trạm',
                          icon: Icons.lock_person_outlined,
                          description: widget.isEditing
                              ? 'Để trống mật khẩu nếu không muốn thay đổi.'
                              : 'Dùng thông tin này để kết nối với trạm.',
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: _FieldGrid(
                              children: [
                                _textField(
                                  controller: _usernameController,
                                  label: 'Tài khoản *',
                                  icon: Icons.person_outline,
                                  errorField: 'Username',
                                  textCapitalization: TextCapitalization.none,
                                  validator: (value) => _requiredMax(
                                    value,
                                    'Vui lòng nhập tài khoản.',
                                    1000,
                                  ),
                                ),
                                _passwordField(),
                              ],
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
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.save_outlined),
                          label: Text(
                            _submitting
                                ? 'Đang lưu...'
                                : widget.isEditing
                                ? 'Lưu thay đổi'
                                : 'Tạo trạm',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdministrativeSection() {
    return StationSection(
      title: 'Phạm vi và loại trạm',
      icon: Icons.account_tree_outlined,
      description: 'Chỉ ADMIN có thể thay đổi công ty và loại trạm.',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: _FieldGrid(
          children: [
            FutureBuilder<List<CompanyResponse>>(
              future: _companiesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Công ty',
                      prefixIcon: Icon(Icons.apartment_outlined),
                    ),
                    child: LinearProgressIndicator(),
                  );
                }
                if (snapshot.hasError) {
                  return ErrorPanel(
                    message: snapshot.error is ApiException
                        ? (snapshot.error! as ApiException).message
                        : 'Không thể tải danh sách công ty.',
                  );
                }
                final companies = snapshot.data ?? const <CompanyResponse>[];
                return CompanyAutocompleteField(
                  key: ValueKey(
                    'station-company-$_companyId-${companies.length}',
                  ),
                  companies: companies,
                  selectedCompanyId: _companyId,
                  enabled: !_submitting,
                  errorText: _error?.fieldMessage('CompanyId'),
                  validator: (companyId) =>
                      companyId == null ? 'Vui lòng chọn công ty.' : null,
                  onSelected: (company) =>
                      setState(() => _companyId = company.id),
                );
              },
            ),
            DropdownButtonFormField<int>(
              isExpanded: true,
              initialValue: _typeTram,
              decoration: InputDecoration(
                labelText: 'Loại trạm',
                prefixIcon: const Icon(Icons.category_outlined),
                errorText: _error?.fieldMessage('TypeTram'),
              ),
              items: StationType.values
                  .map(
                    (type) => DropdownMenuItem<int>(
                      value: type.value,
                      child: Text(type.label),
                    ),
                  )
                  .toList(growable: false),
              onChanged: _submitting
                  ? null
                  : (value) => setState(() => _typeTram = value),
              validator: (value) =>
                  value == null ? 'Vui lòng chọn loại trạm.' : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadOnlyScope() {
    final station = widget.existingStation!;
    return StationSection(
      title: 'Thông tin không thay đổi trong vai trò hiện tại',
      icon: Icons.lock_outline,
      child: Column(
        children: [
          StationInfoRow(
            label: 'Công ty',
            value: station.companyName,
            icon: Icons.apartment_outlined,
          ),
          StationInfoRow(
            label: 'Loại trạm',
            value: station.type?.label,
            icon: Icons.category_outlined,
          ),
          StationInfoRow(
            label: 'Tài khoản',
            value: station.username,
            icon: Icons.person_outline,
          ),
        ],
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String errorField,
    required String? Function(String?) validator,
    TextInputType? keyboardType,
    TextInputAction textInputAction = TextInputAction.next,
    TextCapitalization textCapitalization = TextCapitalization.sentences,
    int? minLines,
    int? maxLines = 1,
    bool? alignLabelWithHint,
  }) {
    return TextFormField(
      controller: controller,
      enabled: !_submitting,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      minLines: minLines,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        alignLabelWithHint: alignLabelWithHint,
        errorText: _error?.fieldMessage(errorField),
      ),
    );
  }

  Widget _passwordField() {
    return TextFormField(
      controller: _passwordController,
      enabled: !_submitting,
      obscureText: _obscurePassword,
      textInputAction: TextInputAction.done,
      enableSuggestions: false,
      autocorrect: false,
      validator: _passwordValidator,
      decoration: InputDecoration(
        labelText: widget.isEditing
            ? 'Mật khẩu mới (để trống nếu không đổi)'
            : 'Mật khẩu *',
        prefixIcon: const Icon(Icons.lock_outline),
        errorText: _error?.fieldMessage('Password'),
        suffixIcon: IconButton(
          tooltip: _obscurePassword ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          icon: Icon(
            _obscurePassword
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
        ),
      ),
    );
  }

  String? _requiredMax(String? value, String requiredMessage, int maxLength) {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) return requiredMessage;
    return _maxLength(normalized, maxLength);
  }

  String? _optionalMax(String? value, int maxLength) {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) return null;
    return _maxLength(normalized, maxLength);
  }

  String? _maxLength(String value, int maxLength) =>
      value.length > maxLength ? 'Không được vượt quá $maxLength ký tự.' : null;

  String? _emailValidator(
    String? value, {
    required bool required,
    required String fieldName,
  }) {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) {
      return required ? 'Vui lòng nhập $fieldName.' : null;
    }
    if (normalized.length > 1000 ||
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(normalized)) {
      return '$fieldName không hợp lệ.';
    }
    return null;
  }

  String? _passwordValidator(String? value) {
    final normalized = value ?? '';
    if (normalized.isEmpty && widget.isEditing) return null;
    if (normalized.isEmpty) return 'Vui lòng nhập mật khẩu.';
    if (normalized.length < 8 || normalized.length > 1000) {
      return 'Mật khẩu phải có từ 8 đến 1000 ký tự.';
    }
    if (!RegExp(r'[a-z]').hasMatch(normalized) ||
        !RegExp(r'[A-Z]').hasMatch(normalized) ||
        !RegExp(r'[0-9]').hasMatch(normalized) ||
        !RegExp(r'[@#$%]').hasMatch(normalized)) {
      return 'Mật khẩu cần chữ thường, chữ hoa, số và ký tự @#\$%.';
    }
    return null;
  }

  String? _emptyToNull(String value) {
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }
}

class _FieldGrid extends StatelessWidget {
  const _FieldGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 680;
        final itemWidth = isWide
            ? (constraints.maxWidth - 12) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: children
              .map((child) => SizedBox(width: itemWidth, child: child))
              .toList(growable: false),
        );
      },
    );
  }
}
