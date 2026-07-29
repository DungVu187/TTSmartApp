import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/widgets/error_panel.dart';
import '../../data/models/role_models.dart';
import '../../data/models/user_models.dart';
import '../controllers/users_controller.dart';
import '../widgets/access_layout.dart';

class UserRolesScreen extends StatefulWidget {
  const UserRolesScreen({
    super.key,
    required this.controller,
    required this.user,
  });

  final UsersController controller;
  final UserResponse user;

  @override
  State<UserRolesScreen> createState() => _UserRolesScreenState();
}

class _UserRolesScreenState extends State<UserRolesScreen> {
  late final Future<List<RoleListItemResponse>> _future;
  final Set<int> _selectedRoleIds = <int>{};
  ApiException? _error;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _selectedRoleIds.addAll(widget.user.roles.map((role) => role.id));
    _future = widget.controller.getAvailableRoles();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.controller.setRoles(
        widget.user.id,
        _selectedRoleIds.toList(growable: false),
      );
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gán vai trò')),
      body: FutureBuilder<List<RoleListItemResponse>>(
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
                        : 'Không thể tải danh sách vai trò.',
                  ),
                ),
              ),
            );
          }
          final roles = snapshot.data ?? const <RoleListItemResponse>[];
          return Column(
            children: [
              if (_error != null)
                AccessConstrainedContent(
                  child: Padding(
                    padding: accessPagePadding(context, bottom: 0),
                    child: ErrorPanel(message: _error!.message),
                  ),
                ),
              Expanded(
                child: roles.isEmpty
                    ? const Center(
                        child: Text('Chưa có vai trò hiệu lực để gán.'),
                      )
                    : ListView.builder(
                        padding: accessPagePadding(context),
                        itemCount: roles.length,
                        itemBuilder: (context, index) {
                          final role = roles[index];
                          return Align(
                            alignment: Alignment.topCenter,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 760),
                              child: CheckboxListTile(
                                value: _selectedRoleIds.contains(role.id),
                                title: Text(role.name),
                                subtitle: Text(
                                  role.note?.trim().isNotEmpty == true
                                      ? '${role.code} • ${role.note}'
                                      : role.code,
                                ),
                                onChanged: _submitting
                                    ? null
                                    : (checked) => setState(() {
                                        if (checked == true) {
                                          _selectedRoleIds.add(role.id);
                                        } else {
                                          _selectedRoleIds.remove(role.id);
                                        }
                                      }),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: accessPagePadding(context, top: 8, bottom: 16),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: SizedBox(
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
                        label: const Text('Lưu vai trò'),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
