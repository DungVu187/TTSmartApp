import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/widgets/error_panel.dart';
import '../../data/models/company_models.dart';
import '../controllers/companies_controller.dart';
import '../widgets/company_widgets.dart';

class CompanyFormScreen extends StatefulWidget {
  const CompanyFormScreen({
    super.key,
    required this.controller,
    this.existingCompany,
  });

  final CompaniesController controller;
  final CompanyResponse? existingCompany;

  bool get isEditing => existingCompany != null;

  @override
  State<CompanyFormScreen> createState() => _CompanyFormScreenState();
}

class _CompanyFormScreenState extends State<CompanyFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _codeController;
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  late final TextEditingController _faxController;
  late final TextEditingController _representativeController;
  late final TextEditingController _contactNameController;
  late final TextEditingController _contactEmailController;
  late final TextEditingController _contactPhoneController;
  late final TextEditingController _countUserController;
  late final TextEditingController _noteController;
  late CompanyPlan _plan;
  ApiException? _error;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final company = widget.existingCompany;
    _codeController = TextEditingController(text: company?.code ?? '');
    _nameController = TextEditingController(text: company?.name ?? '');
    _emailController = TextEditingController(text: company?.email ?? '');
    _phoneController = TextEditingController(text: company?.phone ?? '');
    _addressController = TextEditingController(text: company?.address ?? '');
    _faxController = TextEditingController(text: company?.fax ?? '');
    _representativeController = TextEditingController(
      text: company?.representative ?? '',
    );
    _contactNameController = TextEditingController(
      text: company?.contactName ?? '',
    );
    _contactEmailController = TextEditingController(
      text: company?.contactEmail ?? '',
    );
    _contactPhoneController = TextEditingController(
      text: company?.contactPhone ?? '',
    );
    _countUserController = TextEditingController(
      text: '${company?.countUser ?? 0}',
    );
    _noteController = TextEditingController(text: company?.note ?? '');
    _plan = company?.plan ?? CompanyPlan.free;
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _faxController.dispose();
    _representativeController.dispose();
    _contactNameController.dispose();
    _contactEmailController.dispose();
    _contactPhoneController.dispose();
    _countUserController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate() || _submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final request = CompanyUpsertRequest(
      code: _codeController.text.trim(),
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
      address: _emptyToNull(_addressController.text),
      fax: _emptyToNull(_faxController.text),
      representative: _emptyToNull(_representativeController.text),
      contactName: _emptyToNull(_contactNameController.text),
      contactEmail: _emptyToNull(_contactEmailController.text),
      contactPhone: _emptyToNull(_contactPhoneController.text),
      countUser: int.parse(_countUserController.text.trim()),
      plan: _plan,
      note: _emptyToNull(_noteController.text),
    );
    try {
      final company = widget.isEditing
          ? await widget.controller.update(widget.existingCompany!.id, request)
          : await widget.controller.create(request);
      if (mounted) Navigator.pop(context, company);
    } on ApiException catch (caught) {
      if (mounted) setState(() => _error = caught);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Sửa công ty' : 'Thêm công ty'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: _pagePadding(context),
            children: [
              if (_error != null) ...[
                ErrorPanel(message: _error!.message),
                const SizedBox(height: 16),
              ],
              CompanySection(
                title: 'Thông tin công ty',
                icon: Icons.apartment_outlined,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _FieldGrid(
                    children: [
                      TextFormField(
                        controller: _codeController,
                        enabled: !_submitting,
                        textInputAction: TextInputAction.next,
                        maxLength: 100,
                        decoration: InputDecoration(
                          labelText: 'Mã công ty *',
                          errorText: _error?.fieldMessage('code'),
                        ),
                        validator: (value) => _requiredMax(
                          value,
                          'Vui lòng nhập mã công ty.',
                          100,
                        ),
                      ),
                      TextFormField(
                        controller: _nameController,
                        enabled: !_submitting,
                        textInputAction: TextInputAction.next,
                        maxLength: 1000,
                        decoration: InputDecoration(
                          labelText: 'Tên công ty *',
                          errorText: _error?.fieldMessage('name'),
                        ),
                        validator: (value) => _requiredMax(
                          value,
                          'Vui lòng nhập tên công ty.',
                          1000,
                        ),
                      ),
                      TextFormField(
                        controller: _representativeController,
                        enabled: !_submitting,
                        textInputAction: TextInputAction.next,
                        maxLength: 400,
                        decoration: InputDecoration(
                          labelText: 'Người đại diện',
                          errorText: _error?.fieldMessage('representative'),
                        ),
                      ),
                      TextFormField(
                        controller: _addressController,
                        enabled: !_submitting,
                        minLines: 2,
                        maxLines: 4,
                        decoration: InputDecoration(
                          labelText: 'Địa chỉ',
                          alignLabelWithHint: true,
                          errorText: _error?.fieldMessage('address'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              CompanySection(
                title: 'Thông tin liên hệ',
                icon: Icons.contact_phone_outlined,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _FieldGrid(
                    children: [
                      TextFormField(
                        controller: _emailController,
                        enabled: !_submitting,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        maxLength: 1000,
                        decoration: InputDecoration(
                          labelText: 'Email công ty *',
                          errorText: _error?.fieldMessage('email'),
                        ),
                        validator: (value) => _emailValidator(
                          value,
                          required: true,
                          fieldName: 'email công ty',
                        ),
                      ),
                      TextFormField(
                        controller: _phoneController,
                        enabled: !_submitting,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        maxLength: 100,
                        decoration: InputDecoration(
                          labelText: 'Số điện thoại *',
                          errorText: _error?.fieldMessage('phone'),
                        ),
                        validator: (value) => _requiredMax(
                          value,
                          'Vui lòng nhập số điện thoại.',
                          100,
                        ),
                      ),
                      TextFormField(
                        controller: _faxController,
                        enabled: !_submitting,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        maxLength: 100,
                        decoration: InputDecoration(
                          labelText: 'Fax',
                          errorText: _error?.fieldMessage('fax'),
                        ),
                      ),
                      TextFormField(
                        controller: _contactNameController,
                        enabled: !_submitting,
                        textInputAction: TextInputAction.next,
                        maxLength: 400,
                        decoration: InputDecoration(
                          labelText: 'Người liên hệ',
                          errorText: _error?.fieldMessage('contactName'),
                        ),
                      ),
                      TextFormField(
                        controller: _contactEmailController,
                        enabled: !_submitting,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        maxLength: 1000,
                        decoration: InputDecoration(
                          labelText: 'Email liên hệ',
                          errorText: _error?.fieldMessage('contactEmail'),
                        ),
                        validator: (value) => _emailValidator(
                          value,
                          required: false,
                          fieldName: 'email liên hệ',
                        ),
                      ),
                      TextFormField(
                        controller: _contactPhoneController,
                        enabled: !_submitting,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        maxLength: 100,
                        decoration: InputDecoration(
                          labelText: 'Điện thoại liên hệ',
                          errorText: _error?.fieldMessage('contactPhone'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              CompanySection(
                title: 'Dịch vụ',
                icon: Icons.workspace_premium_outlined,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _FieldGrid(
                    children: [
                      DropdownButtonFormField<CompanyPlan>(
                        initialValue: _plan,
                        decoration: InputDecoration(
                          labelText: 'Gói sử dụng',
                          errorText: _error?.fieldMessage('active'),
                        ),
                        items: CompanyPlan.values
                            .map(
                              (plan) => DropdownMenuItem(
                                value: plan,
                                child: Text(plan.label),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: _submitting
                            ? null
                            : (value) {
                                if (value != null) {
                                  setState(() => _plan = value);
                                }
                              },
                      ),
                      TextFormField(
                        controller: _countUserController,
                        enabled: !_submitting,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: InputDecoration(
                          labelText: 'Số người dùng',
                          errorText: _error?.fieldMessage('countUser'),
                        ),
                        validator: (value) {
                          final parsed = int.tryParse(value?.trim() ?? '');
                          return parsed == null || parsed < 0
                              ? 'Số người dùng phải từ 0 trở lên.'
                              : null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              CompanySection(
                title: 'Ghi chú',
                icon: Icons.notes_outlined,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextFormField(
                    controller: _noteController,
                    enabled: !_submitting,
                    minLines: 3,
                    maxLines: 6,
                    decoration: InputDecoration(
                      labelText: 'Nội dung ghi chú',
                      alignLabelWithHint: true,
                      errorText: _error?.fieldMessage('note'),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(
                  _submitting
                      ? 'Đang lưu...'
                      : widget.isEditing
                      ? 'Lưu thay đổi'
                      : 'Tạo công ty',
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  EdgeInsets _pagePadding(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final horizontal = width >= 720 ? 24.0 : 16.0;
    return EdgeInsets.fromLTRB(horizontal, 16, horizontal, 24);
  }

  String? _requiredMax(String? value, String requiredMessage, int maxLength) {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) return requiredMessage;
    if (normalized.length > maxLength) {
      return 'Không được vượt quá $maxLength ký tự.';
    }
    return null;
  }

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
          runSpacing: 4,
          children: children
              .map((child) => SizedBox(width: itemWidth, child: child))
              .toList(growable: false),
        );
      },
    );
  }
}
