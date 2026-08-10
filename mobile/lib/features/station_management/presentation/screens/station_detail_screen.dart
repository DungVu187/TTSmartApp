import 'package:flutter/material.dart';

import '../../../../core/app_scope.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/error_panel.dart';
import '../../../access_management/data/models/permission_models.dart';
import '../../../company_management/data/repositories/company_repository.dart';
import '../../data/models/station_models.dart';
import '../controllers/stations_controller.dart';
import '../widgets/station_widgets.dart';
import 'station_form_screen.dart';

class StationDetailScreen extends StatefulWidget {
  const StationDetailScreen({
    super.key,
    required this.stationId,
    required this.controller,
    required this.companyRepository,
    required this.isAdmin,
    required this.isCompanyRole,
  });

  final int stationId;
  final StationsController controller;
  final CompanyRepository companyRepository;
  final bool isAdmin;
  final bool isCompanyRole;

  @override
  State<StationDetailScreen> createState() => _StationDetailScreenState();
}

class _StationDetailScreenState extends State<StationDetailScreen> {
  StationResponse? _station;
  ApiException? _error;
  bool _loading = true;
  bool _actionInProgress = false;
  bool _changed = false;

  bool get _canView {
    final app = AppScope.read(context);
    return widget.isAdmin ||
        app.hasPermission(AccessFunctionCodes.branches, AccessPermission.view);
  }

  bool get _canUpdate {
    final app = AppScope.read(context);
    return widget.isAdmin ||
        (widget.isCompanyRole &&
            app.hasPermission(
              AccessFunctionCodes.branches,
              AccessPermission.update,
            ));
  }

  bool get _canDelete => widget.isAdmin;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!_canView) return;
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final station = await widget.controller.getById(widget.stationId);
      if (!mounted) return;
      setState(() {
        _station = station;
        _loading = false;
      });
    } on ApiException catch (caught) {
      if (mounted) {
        setState(() {
          _error = caught;
          _loading = false;
        });
      }
    }
  }

  Future<void> _edit() async {
    final station = _station;
    if (station == null || !_canUpdate) return;
    final updated = await Navigator.of(context).push<StationResponse>(
      MaterialPageRoute(
        builder: (_) => StationFormScreen(
          controller: widget.controller,
          companyRepository: widget.companyRepository,
          isAdmin: widget.isAdmin,
          existingStation: station,
        ),
      ),
    );
    if (updated != null && mounted) {
      setState(() {
        _station = updated;
        _changed = true;
      });
    }
  }

  Future<void> _delete() async {
    final station = _station;
    if (station == null || !_canDelete || _actionInProgress) return;
    final confirmed = await _confirm(
      title: 'Xóa trạm?',
      message:
          'Trạm "${station.displayName}" sẽ được xóa mềm và không còn xuất hiện trong danh sách hoạt động.',
      confirmLabel: 'Xóa trạm',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _actionInProgress = true;
      _error = null;
    });
    try {
      await widget.controller.delete(station.id);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (caught) {
      if (mounted) {
        setState(() {
          _error = caught;
          _actionInProgress = false;
        });
      }
    }
  }

  Future<void> _restore() async {
    final station = _station;
    if (station == null || !_canDelete || _actionInProgress) return;
    final confirmed = await _confirm(
      title: 'Khôi phục trạm?',
      message: 'Hệ thống sẽ kiểm tra lại mã và tài khoản trước khi khôi phục.',
      confirmLabel: 'Khôi phục',
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _actionInProgress = true;
      _error = null;
    });
    try {
      final restored = await widget.controller.restore(station.id);
      if (mounted) {
        setState(() {
          _station = restored;
          _changed = true;
          _actionInProgress = false;
        });
      }
    } on ApiException catch (caught) {
      if (mounted) {
        setState(() {
          _error = caught;
          _actionInProgress = false;
        });
      }
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
    bool destructive = false,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Hủy'),
              ),
              FilledButton(
                style: destructive
                    ? FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.error,
                      )
                    : null,
                onPressed: () => Navigator.pop(context, true),
                child: Text(confirmLabel),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    if (!_canView) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chi tiết trạm')),
        body: const AppEmptyState(
          icon: Icons.lock_outline,
          title: 'Không có quyền xem',
          message: 'Phiên hiện tại không được phép xem chi tiết trạm này.',
        ),
      );
    }
    final station = _station;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Chi tiết trạm'),
          bottom: _actionInProgress
              ? const PreferredSize(
                  preferredSize: Size.fromHeight(2),
                  child: LinearProgressIndicator(minHeight: 2),
                )
              : null,
          actions: [
            if (_canUpdate && station != null && !station.isDeleted)
              TextButton.icon(
                onPressed: _actionInProgress ? null : _edit,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Sửa'),
              ),
            if (_canDelete && station != null)
              PopupMenuButton<_StationAction>(
                tooltip: 'Thao tác khác',
                enabled: !_actionInProgress,
                onSelected: (action) => switch (action) {
                  _StationAction.delete => _delete(),
                  _StationAction.restore => _restore(),
                },
                itemBuilder: (context) => [
                  if (!station.isDeleted)
                    const PopupMenuItem(
                      value: _StationAction.delete,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.delete_outline),
                        title: Text('Xóa mềm'),
                      ),
                    ),
                  if (station.isDeleted)
                    const PopupMenuItem(
                      value: _StationAction.restore,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.restore_outlined),
                        title: Text('Khôi phục'),
                      ),
                    ),
                ],
              ),
          ],
        ),
        body: _buildBody(station),
      ),
    );
  }

  Widget _buildBody(StationResponse? station) {
    if (_loading && station == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && station == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ErrorPanel(message: _error!.message, onRetry: _load),
          ),
        ),
      );
    }
    if (station == null) {
      return const AppEmptyState(
        icon: Icons.factory_outlined,
        title: 'Không tìm thấy trạm',
        message: 'Trạm có thể đã bị xóa hoặc nằm ngoài phạm vi được cấp.',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
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
                  _buildHeader(station),
                  const SizedBox(height: 20),
                  StationSection(
                    title: 'Thông tin trạm',
                    icon: Icons.factory_outlined,
                    description:
                        'Thông tin nhận diện, phạm vi và liên hệ của trạm.',
                    child: Column(
                      children: [
                        StationInfoRow(
                          label: 'Mã trạm',
                          value: station.code,
                          icon: Icons.tag_outlined,
                        ),
                        StationInfoRow(
                          label: 'Tên trạm',
                          value: station.name,
                          icon: Icons.badge_outlined,
                        ),
                        StationInfoRow(
                          label: 'Công ty',
                          value: station.companyName,
                          icon: Icons.apartment_outlined,
                        ),
                        StationInfoRow(
                          label: 'Email',
                          value: station.email,
                          icon: Icons.email_outlined,
                        ),
                        StationInfoRow(
                          label: 'Điện thoại',
                          value: station.phone,
                          icon: Icons.phone_outlined,
                        ),
                        StationInfoRow(
                          label: 'Địa chỉ',
                          value: station.address,
                          icon: Icons.location_on_outlined,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  StationSection(
                    title: 'Tài khoản và tích hợp',
                    icon: Icons.settings_input_component_outlined,
                    description:
                        'Mật khẩu được ẩn để bảo vệ thông tin đăng nhập.',
                    child: Column(
                      children: [
                        StationInfoRow(
                          label: 'Tài khoản',
                          value: station.username,
                          icon: Icons.person_outline,
                        ),
                        StationInfoRow(
                          label: 'Mật khẩu',
                          value: stationPasswordStatus(station.password),
                          icon: Icons.lock_outline,
                        ),
                        StationInfoRow(
                          label: 'Quản lý xe',
                          value: station.pmqlXe,
                          icon: Icons.local_shipping_outlined,
                        ),
                        StationInfoRow(
                          label: 'Camera',
                          value: station.qlCamera,
                          icon: Icons.videocam_outlined,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  StationSection(
                    title: 'Theo dõi thay đổi',
                    icon: Icons.history_outlined,
                    description: 'Thời gian hiển thị theo múi giờ thiết bị.',
                    child: Column(
                      children: [
                        StationInfoRow(
                          label: 'Tạo lúc',
                          value: formatStationDate(station.createdAtUtc),
                          icon: Icons.add_circle_outline,
                        ),
                        StationInfoRow(
                          label: 'Cập nhật lúc',
                          value: formatStationDate(station.updatedAtUtc),
                          icon: Icons.update_outlined,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(StationResponse station) {
    final theme = Theme.of(context);
    final metadata = <String>[
      if (station.code?.trim().isNotEmpty == true) 'Mã ${station.code!.trim()}',
      if (station.companyName?.trim().isNotEmpty == true)
        station.companyName!.trim(),
    ].join(' • ');
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(17),
              ),
              child: Icon(
                stationTypeIcon(station.type),
                color: theme.colorScheme.primary,
                size: 30,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    station.displayName,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  if (metadata.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      metadata,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      StationTypeChip(type: station.type),
                      StationStatusChip(isDeleted: station.isDeleted),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _StationAction { delete, restore }
