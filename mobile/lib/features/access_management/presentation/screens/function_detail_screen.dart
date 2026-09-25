import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/app_scope.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/ui/app_ui.dart';
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
        appBar: AppBar(),
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
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Same layout as the role / user details.
                          Row(
                            children: [
                              IconTile(
                                icon: function.isContainer
                                    ? LucideIcons.folder
                                    : LucideIcons.link,
                                tone: function.isContainer
                                    ? AppTone.primary
                                    : AppTone.neutral,
                                size: 60,
                                radius: 18,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      function.name,
                                      style: TextStyle(
                                        color: context.palette.text1,
                                        fontSize: 19,
                                        height: 24 / 19,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      function.code,
                                      style: TextStyle(
                                        color: context.palette.text2,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    AccessStatusChip(
                                      isActive: function.isActive,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          InsetGroup(
                            label: 'Tổng quan',
                            children: [
                              PairFieldRow(
                                first: (
                                  'Chức năng cha',
                                  _parentName(function.parentFunctionId),
                                ),
                                second: (
                                  'Số mục con',
                                  '${function.childCount}',
                                ),
                              ),
                              PairFieldRow(
                                first: (
                                  'Vai trò được gán',
                                  '${function.assignedRoleCount}',
                                ),
                                second: (
                                  'Vai trò có quyền',
                                  '${function.grantedRoleCount}',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          InsetGroup(
                            label: 'Hiển thị trong menu',
                            children: [
                              FieldRow(
                                label: 'Đường dẫn',
                                value: _display(function.url),
                              ),
                              PairFieldRow(
                                first: (
                                  'Vị trí',
                                  function.location?.toString() ??
                                      'Chưa cập nhật',
                                ),
                                second: ('Icon', _display(function.icon)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          InsetGroup(
                            label: 'Khác',
                            children: [
                              FieldRow(
                                label: 'Chú thích',
                                value: _display(function.note),
                              ),
                            ],
                          ),
                          if (canUpdate || canDelete) ...[
                            const SizedBox(height: 24),
                            InsetCard(
                              children: [
                                if (canUpdate)
                                  ActionRow(
                                    icon: LucideIcons.pencil,
                                    label: 'Sửa chức năng',
                                    onTap: _busy ? null : () => _edit(function),
                                  ),
                                if (canUpdate)
                                  ActionRow(
                                    icon: function.isActive
                                        ? LucideIcons.circlePause
                                        : LucideIcons.circlePlay,
                                    label: function.isActive
                                        ? 'Ngừng hiệu lực'
                                        : 'Kích hoạt',
                                    onTap: _busy
                                        ? null
                                        : () => _toggleStatus(function),
                                  ),
                                if (canDelete)
                                  ActionRow(
                                    icon: LucideIcons.trash2,
                                    label: 'Xóa chức năng',
                                    destructive: true,
                                    onTap: _busy
                                        ? null
                                        : () => _delete(function),
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

  /// Name of the parent from the loaded tree ("Chức năng gốc" at the top).
  String _parentName(int? parentId) {
    if (parentId == null) return 'Chức năng gốc';
    for (final node in widget.controller.items.expand(
      (item) => item.flatten(),
    )) {
      if (node.id == parentId) return node.name;
    }
    return 'Chức năng #$parentId';
  }

  String _display(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty
        ? 'Chưa cập nhật'
        : normalized;
  }
}
