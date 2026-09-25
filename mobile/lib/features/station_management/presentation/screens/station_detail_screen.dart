import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/app_scope.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/ui/app_ui.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/error_panel.dart';
import '../../../access_management/data/models/permission_models.dart';
import '../../../company_management/data/repositories/company_repository.dart';
import '../../data/models/station_models.dart';
import '../../data/repositories/station_repository.dart';
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

  // ignore: unused_element, mobile station management is read-only.
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

  // ignore: unused_element, mobile station management is read-only.
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

  // ignore: unused_element, mobile station management is read-only.
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
          icon: LucideIcons.lock,
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
          /* actions: [
            if (_canUpdate && station != null && !station.isDeleted)
              TextButton.icon(
                onPressed: _actionInProgress ? null : _edit,
                icon: const Icon(LucideIcons.pencil, size: 18),
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
                        leading: Icon(LucideIcons.trash2),
                        title: Text('Xóa mềm'),
                      ),
                    ),
                  if (station.isDeleted)
                    const PopupMenuItem(
                      value: _StationAction.restore,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(LucideIcons.rotateCcw),
                        title: Text('Khôi phục'),
                      ),
                    ),
                ],
              ),
          ], */
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
        icon: LucideIcons.factory,
        title: 'Không tìm thấy trạm',
        message: 'Trạm có thể đã bị xóa hoặc nằm ngoài phạm vi được cấp.',
      );
    }
    final p = context.palette;
    final changes = [
      if (station.createdAtUtc != null)
        'Tạo ${formatStationDate(station.createdAtUtc)}',
      if (station.updatedAtUtc != null)
        'Cập nhật ${formatStationDate(station.updatedAtUtc)}',
    ];
    final note = TextStyle(
      color: p.text3,
      fontSize: 13,
      height: 18 / 13,
      fontWeight: FontWeight.w500,
    );
    // Figma B05: header, station info, account + integrations, the password
    // note and the created / updated line. Empty values are skipped.
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null) ...[
                    ErrorPanel(message: _error!.message),
                    const SizedBox(height: 16),
                  ],
                  _buildHeader(station),
                  ..._group('Thông tin trạm', [
                    ('Email', station.email),
                    ('Điện thoại', station.phone),
                    ('Địa chỉ', station.address),
                  ]),
                  ..._group('Tài khoản và tích hợp', [
                    ('Tài khoản', station.username),
                    ('Mật khẩu', stationPasswordStatus(station.password)),
                    ('Quản lý xe', station.pmqlXe),
                    ('Camera', station.qlCamera),
                  ]),
                  const SizedBox(height: 8),
                  Text(
                    'Mật khẩu được ẩn để bảo vệ thông tin đăng nhập.',
                    style: note,
                  ),
                  if (changes.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Text(changes.join('  ·  '), style: note),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _group(String label, List<(String, String?)> rows) {
    final visible = [
      for (final (title, value) in rows)
        if (value?.trim().isNotEmpty == true)
          FieldRow(label: title, value: value!.trim()),
    ];
    if (visible.isEmpty) return const [];
    return [
      const SizedBox(height: 20),
      InsetGroup(label: label, children: visible),
    ];
  }

  Widget _buildHeader(StationResponse station) {
    final p = context.palette;
    final (toneForeground, toneBackground) = p.tone(
      stationTypeTone(station.type),
    );
    final avatarValue = station.avatar?.trim();
    final resolvedAvatar = widget.controller.repository is ApiStationRepository
        ? (widget.controller.repository as ApiStationRepository)
              .resolveMediaUrl(avatarValue)
        : avatarValue;
    final avatarUri = resolvedAvatar == null || resolvedAvatar.isEmpty
        ? null
        : Uri.tryParse(resolvedAvatar);
    final hasAvatarUrl = avatarUri?.hasScheme == true;
    final metadata = <String>[
      if (station.code?.trim().isNotEmpty == true) 'Mã ${station.code!.trim()}',
      if (station.companyName?.trim().isNotEmpty == true)
        station.companyName!.trim(),
    ].join(' · ');
    final fallbackIcon = Icon(
      stationTypeIcon(station.type),
      color: toneForeground,
      size: 28,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: toneBackground,
            borderRadius: BorderRadius.circular(17),
          ),
          clipBehavior: Clip.antiAlias,
          child: hasAvatarUrl
              ? Image.network(
                  avatarUri.toString(),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => fallbackIcon,
                  loadingBuilder: (context, child, progress) =>
                      progress == null ? child : fallbackIcon,
                )
              : fallbackIcon,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                station.displayName,
                style: TextStyle(
                  color: p.text1,
                  fontSize: 19,
                  height: 24 / 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (metadata.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  metadata,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: p.text2,
                    fontSize: 14,
                    height: 19 / 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  StationTypeChip(type: station.type),
                  StationStatusChip(isDeleted: station.isDeleted),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ignore: unused_element, unused_field, retained for the web/admin flow.
enum _StationAction { delete, restore }
