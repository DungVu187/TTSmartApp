// Temporary read-only mode: write handlers remain available for a later
// re-enable, but their controls are intentionally hidden from mobile.
// ignore_for_file: unused_element, unused_field, unused_local_variable

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/app_scope.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/utils/date_time_format.dart';
import '../../../../core/widgets/app_date_picker.dart';
import '../../../../core/widgets/error_panel.dart';
import '../../../access_management/data/models/permission_models.dart';
import '../../../shell/presentation/screens/no_access_screen.dart';
import '../../data/models/company_models.dart';
import '../controllers/companies_controller.dart';
import '../widgets/company_widgets.dart';
import 'company_form_screen.dart';

class CompanyDetailScreen extends StatefulWidget {
  const CompanyDetailScreen({
    super.key,
    required this.companyId,
    required this.controller,
  });

  final int companyId;
  final CompaniesController controller;

  @override
  State<CompanyDetailScreen> createState() => _CompanyDetailScreenState();
}

class _CompanyDetailScreenState extends State<CompanyDetailScreen> {
  late Future<CompanyResponse> _future;
  Future<Uint8List>? _logoFuture;
  bool _busy = false;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _future = _loadCompany();
  }

  Future<CompanyResponse> _loadCompany() async {
    final company = await widget.controller.getById(widget.companyId);
    _logoFuture = company.hasLogo
        ? widget.controller.getLogo(company.id)
        : null;
    return company;
  }

  void _setCompany(CompanyResponse company, {bool reloadLogo = false}) {
    if (reloadLogo) {
      _logoFuture = company.hasLogo
          ? widget.controller.getLogo(company.id)
          : null;
    }
    setState(() {
      _future = Future<CompanyResponse>.value(company);
      _changed = true;
    });
  }

  Future<void> _edit(CompanyResponse company) async {
    final updated = await Navigator.of(context).push<CompanyResponse>(
      MaterialPageRoute(
        builder: (_) => CompanyFormScreen(
          controller: widget.controller,
          existingCompany: company,
        ),
      ),
    );
    if (updated != null && mounted) _setCompany(updated);
  }

  Future<void> _setLock(CompanyResponse company) async {
    final nextLocked = !company.isLocked;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(nextLocked ? 'Khóa công ty?' : 'Mở khóa công ty?'),
        content: Text(
          nextLocked
              ? 'Các tài khoản thuộc công ty sẽ không thể tiếp tục đăng nhập.'
              : 'Các tài khoản thuộc công ty sẽ được phép đăng nhập lại nếu còn hiệu lực.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(nextLocked ? 'Khóa' : 'Mở khóa'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _runAction(
      () => widget.controller.setLock(company.id, nextLocked),
      successMessage: nextLocked ? 'Đã khóa công ty.' : 'Đã mở khóa công ty.',
    );
  }

  Future<void> _setExpiration(CompanyResponse company) async {
    final selection = await showAppDatePicker(
      context: context,
      initialDate:
          company.expiredDate ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 20)),
      title: 'Hạn sử dụng',
      keyPrefix: 'company-expiration',
      allowClear: true,
      showTime: false,
    );
    if (selection == null) return;
    final date = selection.cleared ? null : selection.date;
    await _runAction(
      () => widget.controller.setExpiration(company.id, date),
      successMessage: date == null
          ? 'Đã bỏ giới hạn thời gian sử dụng.'
          : 'Đã cập nhật hạn sử dụng.',
    );
  }

  Future<void> _uploadLogo(CompanyResponse company) async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 2000,
        imageQuality: 92,
      );
      if (file == null || !mounted) return;
      final contentType = _contentTypeFor(file.name);
      if (contentType == null) {
        _showMessage('Logo chỉ nhận JPG, JPEG, PNG hoặc WEBP.');
        return;
      }
      final length = await file.length();
      if (length <= 0 || length > 5 * 1024 * 1024) {
        _showMessage('Logo phải có dung lượng từ 1 byte đến 5 MB.');
        return;
      }
      final bytes = await file.readAsBytes();
      final updated = await _runAction(
        () => widget.controller.uploadLogo(
          id: company.id,
          bytes: bytes,
          fileName: file.name,
          contentType: contentType,
        ),
        successMessage: 'Đã cập nhật logo công ty.',
        applyResult: false,
      );
      if (updated != null && mounted) {
        _setCompany(updated, reloadLogo: true);
      }
    } on PlatformException {
      if (mounted) {
        _showMessage('Không thể mở thư viện ảnh trên thiết bị.');
      }
    } on ApiException catch (error) {
      if (mounted) _showMessage(error.message);
    }
  }

  Future<void> _delete(CompanyResponse company) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa công ty?'),
        content: Text(
          'Xóa ${company.displayName} khỏi danh sách hiệu lực. Bạn có thể khôi phục từ bộ lọc Đã xóa.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _runAction(
      () => widget.controller.delete(company.id),
      successMessage: 'Đã xóa công ty.',
    );
  }

  Future<void> _restore(CompanyResponse company) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Khôi phục công ty?'),
        content: Text(
          'Khôi phục ${company.displayName} về danh sách hiệu lực. Trạng thái khóa và hạn sử dụng vẫn được giữ nguyên.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Khôi phục'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _runAction(
      () => widget.controller.restore(company.id),
      successMessage: 'Đã khôi phục công ty.',
    );
  }

  Future<CompanyResponse?> _runAction(
    Future<CompanyResponse> Function() action, {
    required String successMessage,
    bool applyResult = true,
  }) async {
    if (_busy) return null;
    setState(() => _busy = true);
    try {
      final updated = await action();
      if (mounted) {
        if (applyResult) _setCompany(updated);
        _showMessage(successMessage);
      }
      return updated;
    } on ApiException catch (error) {
      if (mounted) _showMessage(error.message);
      return null;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    if (!app.hasPermission(
      AccessFunctionCodes.companies,
      AccessPermission.view,
    )) {
      return const NoAccessScreen();
    }
    final canUpdate = app.hasPermission(
      AccessFunctionCodes.companies,
      AccessPermission.update,
    );
    final canDelete = app.hasPermission(
      AccessFunctionCodes.companies,
      AccessPermission.delete,
    );
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: FutureBuilder<CompanyResponse>(
        future: _future,
        builder: (context, snapshot) {
          final company = snapshot.data;
          return Scaffold(
            appBar: AppBar(
              title: const Text('Chi tiết công ty'),
              /* actions: [
                if (_busy)
                  const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else if (company != null) ...[
                  if (canUpdate && !company.isDeleted)
                    TextButton.icon(
                      onPressed: () => _edit(company),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Sửa'),
                    ),
                  if ((canUpdate && !company.isDeleted) ||
                      (canDelete && !company.isDeleted) ||
                      (canUpdate && company.isDeleted))
                    PopupMenuButton<_CompanyAction>(
                      tooltip: 'Thao tác khác',
                      onSelected: (action) => switch (action) {
                        _CompanyAction.lock => _setLock(company),
                        _CompanyAction.expiration => _setExpiration(company),
                        _CompanyAction.logo => _uploadLogo(company),
                        _CompanyAction.delete => _delete(company),
                        _CompanyAction.restore => _restore(company),
                      },
                      itemBuilder: (context) => [
                        if (canUpdate && !company.isDeleted) ...[
                          PopupMenuItem(
                            value: _CompanyAction.lock,
                            child: ListTile(
                              leading: Icon(
                                company.isLocked
                                    ? Icons.lock_open_outlined
                                    : Icons.lock_outline,
                              ),
                              title: Text(
                                company.isLocked ? 'Mở khóa' : 'Khóa công ty',
                              ),
                            ),
                          ),
                          const PopupMenuItem(
                            value: _CompanyAction.expiration,
                            child: ListTile(
                              leading: Icon(Icons.event_outlined),
                              title: Text('Cập nhật hạn sử dụng'),
                            ),
                          ),
                          const PopupMenuItem(
                            value: _CompanyAction.logo,
                            child: ListTile(
                              leading: Icon(Icons.image_outlined),
                              title: Text('Đổi logo'),
                            ),
                          ),
                        ],
                        if (canDelete && !company.isDeleted)
                          const PopupMenuItem(
                            value: _CompanyAction.delete,
                            child: ListTile(
                              leading: Icon(Icons.delete_outline),
                              title: Text('Xóa công ty'),
                            ),
                          ),
                        if (canUpdate && company.isDeleted)
                          const PopupMenuItem(
                            value: _CompanyAction.restore,
                            child: ListTile(
                              leading: Icon(Icons.restore_outlined),
                              title: Text('Khôi phục'),
                            ),
                          ),
                      ],
                    ),
                ],
              ], */
            ),
            body: _buildBody(snapshot),
          );
        },
      ),
    );
  }

  Widget _buildBody(AsyncSnapshot<CompanyResponse> snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }
    if (snapshot.hasError) {
      final error = snapshot.error;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ErrorPanel(
              message: error is ApiException
                  ? error.message
                  : 'Không thể tải thông tin công ty.',
              onRetry: () => setState(() => _future = _loadCompany()),
            ),
          ),
        ),
      );
    }
    final company = snapshot.requireData;
    return SafeArea(
      child: ListView(
        padding: _pagePadding(context),
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _CompanyHeaderCard(company: company, logoFuture: _logoFuture),
                  const SizedBox(height: 20),
                  CompanySection(
                    title: 'Thông tin công ty',
                    icon: Icons.apartment_outlined,
                    child: Column(
                      children: [
                        CompanyInfoRow(
                          label: 'Mã công ty',
                          value: company.code,
                          icon: Icons.tag_outlined,
                        ),
                        CompanyInfoRow(
                          label: 'Địa chỉ',
                          value: company.address,
                          icon: Icons.location_on_outlined,
                        ),
                        CompanyInfoRow(
                          label: 'Đại diện',
                          value: company.representative,
                          icon: Icons.person_outline,
                        ),
                        CompanyInfoRow(
                          label: 'Fax',
                          value: company.fax,
                          icon: Icons.print_outlined,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  CompanySection(
                    title: 'Thông tin liên hệ',
                    icon: Icons.contact_phone_outlined,
                    child: Column(
                      children: [
                        CompanyInfoRow(
                          label: 'Điện thoại',
                          value: company.phone,
                          icon: Icons.phone_outlined,
                        ),
                        CompanyInfoRow(
                          label: 'Email',
                          value: company.email,
                          icon: Icons.email_outlined,
                        ),
                        CompanyInfoRow(
                          label: 'Người liên hệ',
                          value: company.contactName,
                          icon: Icons.badge_outlined,
                        ),
                        CompanyInfoRow(
                          label: 'Điện thoại LH',
                          value: company.contactPhone,
                          icon: Icons.phone_in_talk_outlined,
                        ),
                        CompanyInfoRow(
                          label: 'Email LH',
                          value: company.contactEmail,
                          icon: Icons.alternate_email,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  CompanySection(
                    title: 'Dịch vụ và hiệu lực',
                    icon: Icons.workspace_premium_outlined,
                    child: Column(
                      children: [
                        CompanyInfoRow(
                          label: 'Gói sử dụng',
                          value: company.plan.label,
                          icon: Icons.sell_outlined,
                        ),
                        CompanyInfoRow(
                          label: 'Người dùng',
                          value: '${company.countUser}',
                          icon: Icons.people_outline,
                        ),
                        CompanyInfoRow(
                          label: 'Hạn sử dụng',
                          value: formatCompanyDate(company.expiredDate),
                          icon: Icons.event_outlined,
                        ),
                        CompanyInfoRow(
                          label: 'Khóa dịch vụ',
                          value: company.isLocked ? 'Đang khóa' : 'Không khóa',
                          icon: company.isLocked
                              ? Icons.lock_outline
                              : Icons.lock_open_outlined,
                        ),
                        CompanyInfoRow(
                          label: 'Dữ liệu',
                          value: company.isDeleted
                              ? 'Đã xóa mềm'
                              : 'Đang hiệu lực',
                          icon: Icons.data_usage_outlined,
                        ),
                      ],
                    ),
                  ),
                  if (company.note?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 20),
                    CompanySection(
                      title: 'Ghi chú',
                      icon: Icons.notes_outlined,
                      child: CompanyInfoRow(
                        label: 'Nội dung',
                        value: company.note,
                      ),
                    ),
                  ],
                  if (company.createdAtUtc != null ||
                      company.updatedAtUtc != null) ...[
                    const SizedBox(height: 20),
                    CompanySection(
                      title: 'Thông tin cập nhật',
                      icon: Icons.history_outlined,
                      child: Column(
                        children: [
                          CompanyInfoRow(
                            label: 'Ngày tạo',
                            value: company.createdAtUtc == null
                                ? null
                                : formatLocalDateTime(company.createdAtUtc!),
                          ),
                          CompanyInfoRow(
                            label: 'Cập nhật',
                            value: company.updatedAtUtc == null
                                ? null
                                : formatLocalDateTime(company.updatedAtUtc!),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  EdgeInsets _pagePadding(BuildContext context) {
    final horizontal = MediaQuery.sizeOf(context).width >= 720 ? 24.0 : 16.0;
    return EdgeInsets.fromLTRB(horizontal, 16, horizontal, 24);
  }

  String? _contentTypeFor(String fileName) {
    final lowerName = fileName.toLowerCase();
    if (lowerName.endsWith('.jpg') || lowerName.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (lowerName.endsWith('.png')) return 'image/png';
    if (lowerName.endsWith('.webp')) return 'image/webp';
    return null;
  }
}

enum _CompanyAction { lock, expiration, logo, delete, restore }

class _CompanyHeaderCard extends StatelessWidget {
  const _CompanyHeaderCard({required this.company, required this.logoFuture});

  final CompanyResponse company;
  final Future<Uint8List>? logoFuture;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Container(
              width: 112,
              height: 76,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: logoFuture == null
                  ? Icon(
                      Icons.apartment_outlined,
                      size: 42,
                      color: theme.colorScheme.primary,
                    )
                  : FutureBuilder<Uint8List>(
                      future: logoFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          );
                        }
                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return Icon(
                            Icons.broken_image_outlined,
                            color: theme.colorScheme.onSurfaceVariant,
                          );
                        }
                        return Image.memory(
                          snapshot.data!,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.medium,
                          semanticLabel: 'Logo ${company.displayName}',
                        );
                      },
                    ),
            ),
            const SizedBox(height: 14),
            Text(
              company.displayName,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            if (company.code?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 4),
              Text(
                company.code!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              runSpacing: 4,
              children: [
                CompanyPlanChip(plan: company.plan),
                CompanyStatusChip(isDeleted: company.isDeleted),
                if (company.isLocked)
                  CompanyLockChip(isLocked: company.isLocked),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
