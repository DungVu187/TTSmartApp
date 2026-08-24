import 'package:flutter/material.dart';

import '../../../../core/app_scope.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/widgets/error_panel.dart';
import '../../../shell/presentation/screens/no_access_screen.dart';
import '../../data/models/function_models.dart';
import '../../data/models/permission_models.dart';
import '../controllers/functions_controller.dart';
import '../widgets/access_layout.dart';
import '../widgets/access_status_chip.dart';
import 'function_form_screen.dart';

class FunctionDetailScreen extends StatefulWidget {
  const FunctionDetailScreen({
    super.key,
    required this.functionId,
    required this.controller,
  });

  final int functionId;
  final FunctionsController controller;

  @override
  State<FunctionDetailScreen> createState() => _FunctionDetailScreenState();
}

class _FunctionDetailScreenState extends State<FunctionDetailScreen> {
  late Future<FunctionResponse> _future;
  bool _busy = false;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _future = widget.controller.getById(widget.functionId);
  }

  void _reload() => setState(() {
    _future = widget.controller.getById(widget.functionId);
  });

  Future<void> _edit(FunctionResponse function) async {
    final updated = await Navigator.of(context).push<FunctionResponse>(
      MaterialPageRoute(
        builder: (_) => FunctionFormScreen(
          controller: widget.controller,
          existingFunction: function,
        ),
      ),
    );
    if (updated != null && mounted) {
      setState(() {
        _changed = true;
        _future = Future<FunctionResponse>.value(updated);
      });
    }
  }

  Future<void> _toggleStatus(FunctionResponse function) async {
    final nextActive = !function.isActive;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(nextActive ? 'Bật chức năng?' : 'Tắt chức năng?'),
        content: Text(
          nextActive
              ? 'Chức năng sẽ được dùng trong menu.'
              : 'Chức năng sẽ bị tắt; các mục con vẫn được giữ lại.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(nextActive ? 'Kích hoạt' : 'Ngừng'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || _busy) return;
    setState(() => _busy = true);
    try {
      final appController = AppScope.read(context);
      final updated = await widget.controller.setActive(
        function.id,
        nextActive,
      );
      await appController.refreshCurrentSession();
      if (mounted) {
        setState(() {
          _changed = true;
          _future = Future<FunctionResponse>.value(updated);
        });
      }
    } on ApiException catch (error) {
      if (mounted) _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(FunctionResponse function) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa chức năng?'),
        content: Text(
          function.isContainer
              ? 'Mục này còn ${function.childCount} mục con. Khi xóa, các mục con sẽ chuyển lên cấp cao hơn.'
              : 'Xóa ${function.name} khỏi menu.',
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
    if (confirmed != true || !mounted || _busy) return;
    setState(() => _busy = true);
    try {
      final appController = AppScope.read(context);
      await widget.controller.delete(function.id);
      await appController.refreshCurrentSession();
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
    if (!app.hasPermission(
      AccessFunctionCodes.functions,
      AccessPermission.view,
    )) {
      return const NoAccessScreen();
    }
    final canUpdate = app.hasPermission(
      AccessFunctionCodes.functions,
      AccessPermission.update,
    );
    final canDelete = app.hasPermission(
      AccessFunctionCodes.functions,
      AccessPermission.delete,
    );
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Chi tiết chức năng')),
        body: FutureBuilder<FunctionResponse>(
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
                          : 'Không thể tải thông tin function.',
                      onRetry: _reload,
                    ),
                  ),
                ),
              );
            }
            final function = snapshot.data!;
            return Stack(
              children: [
                ListView(
                  padding: accessPagePadding(context, bottom: 32),
                  children: [
                    AccessConstrainedContent(
                      maxWidth: 820,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 26,
                                      child: Icon(
                                        function.isContainer
                                            ? Icons.folder_outlined
                                            : Icons.webhook_outlined,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            function.name,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleLarge
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w800,
                                                ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(function.code),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                AccessStatusChip(isActive: function.isActive),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          AccessSection(
                            title: 'Tổng quan',
                            icon: Icons.analytics_outlined,
                            child: Column(
                              children: [
                                AccessInfoRow(
                                  label: 'Số chức năng con',
                                  value: '${function.childCount}',
                                ),
                                const Divider(height: 1),
                                AccessInfoRow(
                                  label: 'Số vai trò áp dụng',
                                  value: '${function.assignedRoleCount}',
                                ),
                                const Divider(height: 1),
                                AccessInfoRow(
                                  label: 'Số người được cấp quyền',
                                  value: '${function.grantedRoleCount}',
                                ),
                                const Divider(height: 1),
                                AccessInfoRow(
                                  label: 'Chức năng cha',
                                  value:
                                      function.parentFunctionId?.toString() ??
                                      'Chức năng gốc',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          AccessSection(
                            title: 'Thông tin chức năng',
                            icon: Icons.open_in_new_outlined,
                            child: Column(
                              children: [
                                AccessInfoRow(
                                  label: 'Đường dẫn',
                                  value: _display(function.url),
                                ),
                                const Divider(height: 1),
                                AccessInfoRow(
                                  label: 'Icon',
                                  value: _display(function.icon),
                                ),
                                const Divider(height: 1),
                                AccessInfoRow(
                                  label: 'Chú thích',
                                  value: _display(function.note),
                                ),
                              ],
                            ),
                          ),
                          if (canUpdate || canDelete) ...[
                            const SizedBox(height: 24),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                if (canUpdate)
                                  OutlinedButton.icon(
                                    onPressed: _busy
                                        ? null
                                        : () => _edit(function),
                                    icon: const Icon(Icons.edit_outlined),
                                    label: const Text('Cập nhật'),
                                  ),
                                if (canUpdate)
                                  OutlinedButton.icon(
                                    onPressed: _busy
                                        ? null
                                        : () => _toggleStatus(function),
                                    icon: Icon(
                                      function.isActive
                                          ? Icons.pause_circle_outline
                                          : Icons.play_circle_outline,
                                    ),
                                    label: Text(
                                      function.isActive
                                          ? 'Ngừng hiệu lực'
                                          : 'Kích hoạt',
                                    ),
                                  ),
                                if (canDelete)
                                  TextButton.icon(
                                    onPressed: _busy
                                        ? null
                                        : () => _delete(function),
                                    icon: const Icon(Icons.delete_outline),
                                    label: const Text('Xóa'),
                                  ),
                              ],
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

  String _display(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty
        ? 'Chưa cập nhật'
        : normalized;
  }
}
