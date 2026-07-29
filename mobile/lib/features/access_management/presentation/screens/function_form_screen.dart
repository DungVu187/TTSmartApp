import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/widgets/error_panel.dart';
import '../../data/models/function_models.dart';
import '../../data/models/pagination_models.dart';
import '../controllers/functions_controller.dart';
import '../widgets/access_layout.dart';

class FunctionFormScreen extends StatefulWidget {
  const FunctionFormScreen({
    super.key,
    required this.controller,
    this.existingFunction,
  });

  final FunctionsController controller;
  final FunctionResponse? existingFunction;

  bool get isEditing => existingFunction != null;

  @override
  State<FunctionFormScreen> createState() => _FunctionFormScreenState();
}

class _FunctionFormScreenState extends State<FunctionFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _codeController;
  late final TextEditingController _nameController;
  late final TextEditingController _urlController;
  late final TextEditingController _noteController;
  late final TextEditingController _locationController;
  late final TextEditingController _iconController;
  late final Future<List<FunctionResponse>> _functionsFuture;
  int? _parentFunctionId;
  ApiException? _error;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final function = widget.existingFunction;
    _codeController = TextEditingController(text: function?.code ?? '');
    _nameController = TextEditingController(text: function?.name ?? '');
    _urlController = TextEditingController(text: function?.url ?? '');
    _noteController = TextEditingController(text: function?.note ?? '');
    _locationController = TextEditingController(
      text: function?.location?.toString() ?? '',
    );
    _iconController = TextEditingController(text: function?.icon ?? '');
    _parentFunctionId = function?.parentFunctionId;
    _functionsFuture = widget.controller.getAll(status: AccessStatus.active);
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _urlController.dispose();
    _noteController.dispose();
    _locationController.dispose();
    _iconController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_submitting || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final fields = FunctionFieldsRequest(
        parentFunctionId: _parentFunctionId,
        code: _codeController.text.trim(),
        name: _nameController.text.trim(),
        url: _emptyToNull(_urlController.text),
        note: _emptyToNull(_noteController.text),
        location: _nullableInt(_locationController.text),
        icon: _emptyToNull(_iconController.text),
      );
      final response = widget.isEditing
          ? await widget.controller.update(
              widget.existingFunction!.id,
              UpdateFunctionRequest(
                parentFunctionId: fields.parentFunctionId,
                code: fields.code,
                name: fields.name,
                url: fields.url,
                note: fields.note,
                location: fields.location,
                icon: fields.icon,
              ),
            )
          : await widget.controller.create(
              CreateFunctionRequest(
                parentFunctionId: fields.parentFunctionId,
                code: fields.code,
                name: fields.name,
                url: fields.url,
                note: fields.note,
                location: fields.location,
                icon: fields.icon,
              ),
            );
      if (mounted) Navigator.pop(context, response);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Cập nhật function' : 'Tạo function'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: accessPagePadding(context, bottom: 32),
            children: [
              AccessConstrainedContent(
                maxWidth: 820,
                child: Column(
                  children: [
                    if (_error != null) ...[
                      ErrorPanel(message: _error!.message),
                      const SizedBox(height: 16),
                    ],
                    AccessSection(
                      title: 'Cấu trúc function',
                      icon: Icons.account_tree_outlined,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: FutureBuilder<List<FunctionResponse>>(
                          future: _functionsFuture,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const LinearProgressIndicator();
                            }
                            final options = snapshot.hasData
                                ? _eligibleParents(snapshot.data!)
                                : const <_ParentOption>[];
                            final hasCurrent = options.any(
                              (item) => item.function.id == _parentFunctionId,
                            );
                            return DropdownButtonFormField<int?>(
                              initialValue: hasCurrent
                                  ? _parentFunctionId
                                  : null,
                              decoration: const InputDecoration(
                                labelText: 'Function cha',
                                helperText:
                                    'Không thể chọn chính nó hoặc function con làm cha.',
                                prefixIcon: Icon(Icons.account_tree_outlined),
                              ),
                              items: [
                                const DropdownMenuItem<int?>(
                                  value: null,
                                  child: Text('Không có function cha'),
                                ),
                                ...options.map(
                                  (item) => DropdownMenuItem<int?>(
                                    value: item.function.id,
                                    child: Text(
                                      '${List.filled(item.depth, '  ').join()}${item.function.name} (${item.function.code})',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                              onChanged: _submitting
                                  ? null
                                  : (value) => setState(
                                      () => _parentFunctionId = value,
                                    ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    AccessSection(
                      title: 'Thông tin function',
                      icon: Icons.webhook_outlined,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _codeController,
                              maxLength: 100,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                labelText: 'Mã function *',
                                counterText: '',
                                errorText: _error?.fieldMessage('code'),
                              ),
                              validator: (value) =>
                                  (value?.trim().isEmpty ?? true)
                                  ? 'Mã function là bắt buộc.'
                                  : null,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _nameController,
                              maxLength: 200,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                labelText: 'Tên function *',
                                counterText: '',
                                errorText: _error?.fieldMessage('name'),
                              ),
                              validator: (value) =>
                                  (value?.trim().isEmpty ?? true)
                                  ? 'Tên function là bắt buộc.'
                                  : null,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _urlController,
                              maxLength: 400,
                              keyboardType: TextInputType.url,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                labelText: 'URL',
                                counterText: '',
                                errorText: _error?.fieldMessage('url'),
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _noteController,
                              maxLength: 4000,
                              maxLines: 4,
                              textInputAction: TextInputAction.newline,
                              decoration: InputDecoration(
                                labelText: 'Ghi chú',
                                alignLabelWithHint: true,
                                counterText: '',
                                errorText: _error?.fieldMessage('note'),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _locationController,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: 'Thứ tự',
                                      errorText: _error?.fieldMessage(
                                        'location',
                                      ),
                                    ),
                                    validator: (value) {
                                      final text = value?.trim() ?? '';
                                      if (text.isNotEmpty &&
                                          int.tryParse(text) == null) {
                                        return 'Phải là số nguyên.';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _iconController,
                                    maxLength: 1000,
                                    decoration: InputDecoration(
                                      labelText: 'Icon',
                                      counterText: '',
                                      errorText: _error?.fieldMessage('icon'),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
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
                        label: Text(
                          _submitting ? 'Đang lưu...' : 'Lưu function',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<_ParentOption> _eligibleParents(List<FunctionResponse> functions) {
    final currentId = widget.existingFunction?.id;
    final byId = <int, FunctionResponse>{
      for (final function in functions) function.id: function,
    };
    final excluded = <int>{};
    if (currentId != null) excluded.add(currentId);
    if (currentId != null) {
      for (final function in functions) {
        var parent = function.parentFunctionId;
        final visited = <int>{};
        while (parent != null && visited.add(parent)) {
          if (parent == currentId) {
            excluded.add(function.id);
            break;
          }
          parent = byId[parent]?.parentFunctionId;
        }
      }
    }
    final childrenByParent = <int?, List<FunctionResponse>>{};
    for (final function in functions.where(
      (item) => !excluded.contains(item.id),
    )) {
      childrenByParent
          .putIfAbsent(function.parentFunctionId, () => [])
          .add(function);
    }
    for (final values in childrenByParent.values) {
      values.sort((a, b) {
        final location = (a.location ?? 1 << 30).compareTo(
          b.location ?? 1 << 30,
        );
        return location != 0 ? location : a.name.compareTo(b.name);
      });
    }
    final options = <_ParentOption>[];
    void visit(int? parentId, int depth) {
      for (final function in childrenByParent[parentId] ?? const []) {
        options.add(_ParentOption(function: function, depth: depth));
        visit(function.id, depth + 1);
      }
    }

    visit(null, 0);
    return options;
  }

  String? _emptyToNull(String value) {
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }

  int? _nullableInt(String value) {
    final normalized = value.trim();
    return normalized.isEmpty ? null : int.parse(normalized);
  }
}

class _ParentOption {
  const _ParentOption({required this.function, required this.depth});

  final FunctionResponse function;
  final int depth;
}
