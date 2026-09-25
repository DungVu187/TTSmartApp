import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/app_scope.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/ui/app_ui.dart';
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
      final appController = AppScope.read(context);
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
      if (mounted) {
        // Function metadata (name, location, status and tree) is also the
        // source for the shell menu, so refresh the session before returning.
        await appController.refreshCurrentSession();
        if (mounted) Navigator.pop(context, response);
      }
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
        leading: IconButton(
          tooltip: 'Đóng',
          icon: const Icon(LucideIcons.x),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text(widget.isEditing ? 'Sửa chức năng' : 'Tạo chức năng'),
        actions: [
          AccessSaveAction(submitting: _submitting, onPressed: _submit),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: accessPagePadding(context, top: 8, bottom: 32),
            children: [
              AccessConstrainedContent(
                maxWidth: 820,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_error != null) ...[
                      ErrorBanner(message: _error!.message),
                      const SizedBox(height: 16),
                    ],
                    FormFieldGroup(
                      label: 'Định danh',
                      children: [
                        LabeledTextField(
                          label: 'Mã chức năng *',
                          controller: _codeController,
                          maxLength: 100,
                          textInputAction: TextInputAction.next,
                          errorText: _error?.fieldMessage('code'),
                          validator: (value) => (value?.trim().isEmpty ?? true)
                              ? 'Mã chức năng là bắt buộc.'
                              : null,
                        ),
                        LabeledTextField(
                          label: 'Tên chức năng *',
                          controller: _nameController,
                          maxLength: 200,
                          textInputAction: TextInputAction.next,
                          errorText: _error?.fieldMessage('name'),
                          validator: (value) => (value?.trim().isEmpty ?? true)
                              ? 'Tên chức năng là bắt buộc.'
                              : null,
                        ),
                        _buildParentField(),
                      ],
                    ),
                    const SizedBox(height: 24),
                    FormFieldGroup(
                      label: 'Hiển thị trong menu',
                      children: [
                        LabeledTextField(
                          label: 'Đường dẫn',
                          controller: _urlController,
                          maxLength: 400,
                          keyboardType: TextInputType.url,
                          textInputAction: TextInputAction.next,
                          errorText: _error?.fieldMessage('url'),
                        ),
                        LabeledTextField(
                          label: 'Vị trí',
                          controller: _locationController,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.next,
                          errorText: _error?.fieldMessage('location'),
                          validator: (value) {
                            final text = value?.trim() ?? '';
                            if (text.isNotEmpty && int.tryParse(text) == null) {
                              return 'Phải là số nguyên.';
                            }
                            return null;
                          },
                        ),
                        LabeledTextField(
                          label: 'Icon',
                          controller: _iconController,
                          maxLength: 1000,
                          textInputAction: TextInputAction.next,
                          errorText: _error?.fieldMessage('icon'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    FormFieldGroup(
                      label: 'Khác',
                      children: [
                        LabeledTextField(
                          label: 'Chú thích',
                          controller: _noteController,
                          maxLength: 4000,
                          minLines: 3,
                          maxLines: 6,
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.newline,
                          errorText: _error?.fieldMessage('note'),
                        ),
                      ],
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

  /// Parent picker: searchable sheet, indented by tree depth. Itself and
  /// its descendants are not offered.
  Widget _buildParentField() {
    return FutureBuilder<List<FunctionResponse>>(
      future: _functionsFuture,
      builder: (context, snapshot) {
        final loading = snapshot.connectionState == ConnectionState.waiting;
        final options = snapshot.hasData
            ? _eligibleParents(snapshot.data!)
            : const <_ParentOption>[];
        String? currentName;
        for (final option in options) {
          if (option.function.id == _parentFunctionId) {
            currentName = option.function.name;
          }
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SelectFieldButton(
              key: const ValueKey<String>('function-form-parent'),
              label: 'Chức năng cha',
              placeholder: loading
                  ? 'Đang tải chức năng…'
                  : 'Không có chức năng cha',
              value:
                  currentName ??
                  (_parentFunctionId == null
                      ? null
                      : 'Chức năng #$_parentFunctionId'),
              icon: LucideIcons.gitBranch,
              enabled: snapshot.hasData && !_submitting,
              errorText: _error?.fieldMessage('parentFunctionId'),
              onTap: () => _pickParent(options),
              onClear: _parentFunctionId == null
                  ? null
                  : () => setState(() => _parentFunctionId = null),
            ),
            const SizedBox(height: 6),
            if (snapshot.hasError)
              const FieldError('Không thể tải danh sách chức năng.')
            else
              Text(
                'Không thể chọn chính nó hoặc mục con làm mục chứa.',
                style: TextStyle(color: context.palette.text3, fontSize: 13),
              ),
          ],
        );
      },
    );
  }

  Future<void> _pickParent(List<_ParentOption> options) async {
    final picked = await showPickerSheet<int>(
      context: context,
      title: 'Chức năng cha',
      searchHint: 'Tìm chức năng',
      icon: LucideIcons.gitBranch,
      clearLabel: 'Không có chức năng cha',
      selected: _parentFunctionId,
      options: [
        for (final option in options)
          PickerOption(
            value: option.function.id,
            title: '${'— ' * option.depth}${option.function.name}',
            subtitle: option.function.code,
          ),
      ],
    );
    if (!mounted || picked == null) return;
    setState(() => _parentFunctionId = picked.value);
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
