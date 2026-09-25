import 'package:flutter/material.dart';

import '../../../../core/app_scope.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/ui/app_ui.dart';
import '../../../../core/utils/date_time_format.dart';
import '../../../../core/widgets/error_panel.dart';
import '../../../shell/presentation/screens/no_access_screen.dart';
import '../../../company_management/data/repositories/company_repository.dart';
import '../../../station_management/data/repositories/station_repository.dart';
import '../../data/models/permission_models.dart';
import '../../data/models/user_models.dart';
import '../controllers/users_controller.dart';
import '../widgets/access_layout.dart';
import '../widgets/access_status_chip.dart';
import 'user_form_screen.dart';
import 'user_roles_screen.dart';

class UserDetailScreen extends StatefulWidget {
  const UserDetailScreen({
    super.key,
    required this.userId,
    required this.controller,
    required this.companyRepository,
    required this.stationRepository,
  });

  final int userId;
  final UsersController controller;
  final CompanyRepository companyRepository;
  final StationRepository stationRepository;

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  late Future<UserResponse> _future;
  bool _busy = false;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _future = widget.controller.getById(widget.userId);
  }

  void _reload() => setState(() {
    _future = widget.controller.getById(widget.userId);
  });

  void _setUser(UserResponse user) {
    setState(() {
      _future = Future<UserResponse>.value(user);
      _changed = true;
    });
  }

  Future<void> _edit(UserResponse user) async {
    final updated = await Navigator.of(context).push<UserResponse>(
      MaterialPageRoute(
        builder: (_) => UserFormScreen(
          controller: widget.controller,
          companyRepository: widget.companyRepository,
          stationRepository: widget.stationRepository,
          existingUser: user,
        ),
      ),
    );
    if (updated != null && mounted) _setUser(updated);
  }

  Future<void> _manageRoles(UserResponse user) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            UserRolesScreen(controller: widget.controller, user: user),
      ),
    );
    if (changed == true && mounted) _reloadChanged();
  }

  void _reloadChanged() {
    setState(() {
      _changed = true;
      _future = widget.controller.getById(widget.userId);
    });
  }

  Future<void> _resetPassword(UserResponse user) async {
    final confirmed = await showAppConfirmDialog(
      context,
      icon: Icons.lock_reset_rounded,
      title: 'Đặt lại mật khẩu?',
      message: 'Mật khẩu của ${user.displayName} sẽ được đặt lại về 123456.',
      confirmLabel: 'Đặt lại',
      destructive: false,
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.controller.resetPassword(user.id);
      if (mounted) {
        _showMessage('Đã đặt lại mật khẩu về 123456.');
      }
    } on ApiException catch (error) {
      if (mounted) _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(UserResponse user) async {
    final confirmed = await showAppConfirmDialog(
      context,
      icon: Icons.delete_outline_rounded,
      title: 'Xóa người dùng?',
      message:
          'Xóa ${user.displayName} khỏi danh sách hiệu lực. Thao tác này cần được backend xác nhận.',
      confirmLabel: 'Xóa',
    );
    if (!confirmed || !mounted || _busy) return;
    setState(() => _busy = true);
    try {
      await widget.controller.delete(user.id);
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (error) {
      if (mounted) _showMessage(error.message);
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
    if (!app.hasPermission(AccessFunctionCodes.users, AccessPermission.view)) {
      return const NoAccessScreen();
    }
    final canUpdate = app.hasPermission(
      AccessFunctionCodes.users,
      AccessPermission.update,
    );
    final canResetPassword = app.hasPermission(
      AccessFunctionCodes.users,
      AccessPermission.delete,
    );
    final canDelete = app.hasRole('ADMIN') && canResetPassword;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        // Figma S03: no title, the profile header names the user.
        appBar: AppBar(),
        body: FutureBuilder<UserResponse>(
          future: _future,
          builder: (context, snapshot) {
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
                          : 'Không thể tải thông tin người dùng.',
                      onRetry: _reload,
                    ),
                  ),
                ),
              );
            }
            final user = snapshot.data!;
            return Stack(
              children: [
                ListView(
                  padding: accessPagePadding(context, bottom: 32),
                  children: [
                    AccessConstrainedContent(
                      maxWidth: 820,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _ProfileHeader(user: user),
                          const SizedBox(height: 20),
                          // Figma S03: contact, organisation (names, not
                          // IDs), then the actions card.
                          InsetGroup(
                            label: 'Thông tin liên hệ',
                            children: [
                              FieldRow(
                                label: 'Email',
                                value: _display(user.email),
                              ),
                              FieldRow(
                                label: 'Số điện thoại',
                                value: _display(user.phone),
                              ),
                              FieldRow(
                                label: 'Địa chỉ',
                                value: _display(user.address),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          FutureBuilder<_OrganizationNames>(
                            future: _organizationFor(user),
                            builder: (context, names) => InsetGroup(
                              label: 'Tổ chức',
                              children: [
                                FieldRow(
                                  label: 'Công ty',
                                  value: user.companyId == null
                                      ? 'Chưa cập nhật'
                                      : names.data?.company ??
                                            (names.hasError
                                                ? 'Công ty #${user.companyId}'
                                                : 'Đang tải…'),
                                ),
                                FieldRow(
                                  label: 'Trạm trộn',
                                  value: _branchIds(user).isEmpty
                                      ? 'Chưa gán trạm'
                                      : names.data?.stations ??
                                            (names.hasError
                                                ? '${_branchIds(user).length} trạm'
                                                : 'Đang tải…'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          InsetGroup(
                            label: 'Tài khoản',
                            children: [
                              PairFieldRow(
                                first: ('Mã người dùng', _display(user.code)),
                                second: ('Ngày tạo', _date(user.createdAtUtc)),
                              ),
                            ],
                          ),
                          if (canUpdate || canResetPassword) ...[
                            const SizedBox(height: 24),
                            _UserActions(
                              busy: _busy,
                              canUpdate: canUpdate,
                              canDelete: canDelete,
                              canResetPassword: canResetPassword,
                              onEdit: () => _edit(user),
                              onRoles: () => _manageRoles(user),
                              onResetPassword: () => _resetPassword(user),
                              onDelete: () => _delete(user),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                if (_busy) const LinearProgressIndicator(),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<_OrganizationNames>? _organizationFuture;
  int? _organizationUserId;

  List<int> _branchIds(UserResponse user) => (user.branchId ?? '')
      .split(',')
      .map((part) => int.tryParse(part.trim()))
      .whereType<int>()
      .toList(growable: false);

  /// Company and station names for the "Tổ chức" group (cached per user).
  Future<_OrganizationNames> _organizationFor(UserResponse user) {
    if (_organizationFuture != null && _organizationUserId == user.id) {
      return _organizationFuture!;
    }
    _organizationUserId = user.id;
    return _organizationFuture = () async {
      final companyId = user.companyId;
      String? company;
      String? stations;
      if (companyId != null) {
        company = (await widget.companyRepository.getCompany(
          companyId,
        )).displayName;
        final ids = _branchIds(user).toSet();
        if (ids.isNotEmpty) {
          final page = await widget.stationRepository.getStations(
            pageNumber: 1,
            pageSize: 100,
            companyId: companyId,
          );
          final names = [
            for (final station in page.items)
              if (ids.contains(station.id)) station.displayName,
          ];
          stations = names.isEmpty ? '${ids.length} trạm' : names.join(', ');
        }
      }
      return _OrganizationNames(company: company, stations: stations);
    }();
  }

  String _display(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty
        ? 'Chưa cập nhật'
        : normalized;
  }

  String _date(DateTime? value) =>
      value == null ? 'Chưa cập nhật' : formatLocalDateTime(value);
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user});

  final UserResponse user;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      children: [
        InitialsAvatar(text: user.displayName, size: 60, radius: 18),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.displayName,
                style: TextStyle(
                  color: p.text1,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '@${user.userName}',
                style: TextStyle(color: p.text2, fontSize: 15),
              ),
              const SizedBox(height: 6),
              if (user.roles.isNotEmpty)
                AppTag(label: user.roles.first.name, tone: AppTone.violet)
              else
                AccessStatusChip(isActive: user.isActive),
            ],
          ),
        ),
      ],
    );
  }
}

class _UserActions extends StatelessWidget {
  const _UserActions({
    required this.busy,
    required this.canUpdate,
    required this.canDelete,
    required this.canResetPassword,
    required this.onEdit,
    required this.onRoles,
    required this.onResetPassword,
    required this.onDelete,
  });

  final bool busy;
  final bool canUpdate;
  final bool canDelete;
  final bool canResetPassword;
  final VoidCallback onEdit;
  final VoidCallback onRoles;
  final VoidCallback onResetPassword;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return InsetCard(
      dividerIndent: 46,
      children: [
        if (canUpdate)
          ActionRow(
            icon: Icons.edit_outlined,
            label: 'Sửa thông tin',
            onTap: busy ? null : onEdit,
          ),
        if (canUpdate)
          ActionRow(
            icon: Icons.badge_outlined,
            label: 'Gán vai trò',
            onTap: busy ? null : onRoles,
          ),
        if (canResetPassword)
          ActionRow(
            icon: Icons.key_outlined,
            label: 'Đặt lại mật khẩu',
            onTap: busy ? null : onResetPassword,
          ),
        if (canDelete)
          ActionRow(
            icon: Icons.delete_outline,
            label: 'Xóa người dùng',
            destructive: true,
            onTap: busy ? null : onDelete,
          ),
      ],
    );
  }
}

class _OrganizationNames {
  const _OrganizationNames({this.company, this.stations});

  final String? company;
  final String? stations;
}
