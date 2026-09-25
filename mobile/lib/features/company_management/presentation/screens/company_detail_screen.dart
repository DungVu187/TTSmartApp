// Temporary read-only mode: write handlers remain available for a later
// re-enable, but their controls are intentionally hidden from mobile.
// ignore_for_file: unused_element, unused_field, unused_local_variable

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/app_scope.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/ui/app_ui.dart';
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
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: StatTile(
                          label: 'Gói sử dụng',
                          valueFontSize: 16,
                          value: company.plan.label,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: StatTile(
                          label: 'Người dùng',
                          valueFontSize: 16,
                          value: '${company.countUser}',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: StatTile(
                          label: 'Hạn sử dụng',
                          valueFontSize: 16,
                          value: formatCompanyDate(company.expiredDate),
                        ),
                      ),
                    ],
                  ),
                  // Figma B02: contact, company, service, note, then
                  // the created / updated line. Empty values are skipped.
                  ..._groups(company),
                  if (company.createdAtUtc != null ||
                      company.updatedAtUtc != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      [
                        if (company.createdAtUtc != null)
                          'Tạo ${formatLocalDateTime(company.createdAtUtc!)}',
                        if (company.updatedAtUtc != null)
                          'Cập nhật ${formatLocalDateTime(company.updatedAtUtc!)}',
                      ].join('  ·  '),
                      style: TextStyle(
                        color: context.palette.text3,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
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

  List<Widget> _groups(CompanyResponse company) {
    String? text(String? value) {
      final normalized = value?.trim();
      return normalized == null || normalized.isEmpty ? null : normalized;
    }

    List<Widget> group(String label, List<(String, String?)> rows) {
      final visible = [
        for (final (title, value) in rows)
          if (text(value) != null) FieldRow(label: title, value: text(value)!),
      ];
      if (visible.isEmpty) return const [];
      return [
        const SizedBox(height: 20),
        InsetGroup(label: label, children: visible),
      ];
    }

    return [
      ...group('Liên hệ', [
        ('Điện thoại', company.phone),
        ('Email', company.email),
        ('Người liên hệ', company.contactName),
        ('Điện thoại liên hệ', company.contactPhone),
        ('Email liên hệ', company.contactEmail),
      ]),
      ...group('Thông tin công ty', [
        ('Địa chỉ', company.address),
        ('Người đại diện', company.representative),
        ('Fax', company.fax),
      ]),
      ...group('Dịch vụ và hiệu lực', [
        ('Khóa dịch vụ', company.isLocked ? 'Đang khóa' : 'Không khóa'),
        ('Dữ liệu', company.isDeleted ? 'Đã xóa mềm' : 'Đang hiệu lực'),
      ]),
      ...group('Ghi chú', [('Nội dung', company.note)]),
    ];
  }

  EdgeInsets _pagePadding(BuildContext context) {
    final horizontal = MediaQuery.sizeOf(context).width >= 720 ? 24.0 : 16.0;
    return EdgeInsets.fromLTRB(horizontal, 6, horizontal, 24);
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
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 19),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.border),
      ),
      child: Column(
        children: [
          Container(
            width: 112,
            height: 76,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: p.surfaceMuted,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: p.border),
            ),
            child: logoFuture == null
                ? Icon(Icons.apartment_outlined, size: 36, color: p.primary)
                : FutureBuilder<Uint8List>(
                    future: logoFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        );
                      }
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return Icon(
                          Icons.apartment_outlined,
                          size: 36,
                          color: p.primary,
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
            style: TextStyle(
              color: p.text1,
              fontSize: 19,
              height: 24 / 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (company.code?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 3),
            Text(
              company.code!.trim(),
              style: TextStyle(
                color: p.text2,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: [
              CompanyPlanChip(plan: company.plan),
              CompanyStatusChip(isDeleted: company.isDeleted),
              if (company.isLocked) CompanyLockChip(isLocked: company.isLocked),
            ],
          ),
        ],
      ),
    );
  }
}
