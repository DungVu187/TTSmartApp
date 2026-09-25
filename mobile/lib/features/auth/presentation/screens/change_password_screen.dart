import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/app_scope.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/ui/app_ui.dart';
import '../../../../core/widgets/error_panel.dart';
import '../../../../core/widgets/password_field.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  ApiException? _error;
  bool _submitting = false;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!(_formKey.currentState?.validate() ?? false) || _submitting) {
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await AppScope.read(context).changePassword(
        currentPassword: _currentController.text,
        newPassword: _newController.text,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _error = error);
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đổi mật khẩu')),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 728),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_error != null) ...[
                        ErrorPanel(message: _error!.message),
                        const SizedBox(height: 16),
                      ],
                      PasswordField(
                        controller: _currentController,
                        label: 'Mật khẩu hiện tại',
                        labelAbove: true,
                        textInputAction: TextInputAction.next,
                        errorText: _error?.fieldMessage('currentPassword'),
                        validator: (value) => (value == null || value.isEmpty)
                            ? 'Vui lòng nhập mật khẩu hiện tại.'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      PasswordField(
                        controller: _newController,
                        label: 'Mật khẩu mới',
                        labelAbove: true,
                        helperText:
                            'Ít nhất 4 ký tự và phải khác mật khẩu hiện tại.',
                        textInputAction: TextInputAction.next,
                        errorText: _error?.fieldMessage('newPassword'),
                        validator: (value) {
                          if (value == null || value.length < 4) {
                            return 'Mật khẩu mới phải có ít nhất 4 ký tự.';
                          }
                          if (value.length > 200) {
                            return 'Mật khẩu mới không được vượt quá 200 ký tự.';
                          }
                          if (value == _currentController.text) {
                            return 'Mật khẩu mới phải khác mật khẩu hiện tại.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      PasswordField(
                        controller: _confirmController,
                        label: 'Nhập lại mật khẩu mới',
                        labelAbove: true,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submit(),
                        validator: (value) => value != _newController.text
                            ? 'Mật khẩu nhập lại không khớp.'
                            : null,
                      ),
                      const SizedBox(height: 28),
                      AppButton(
                        onPressed: _submitting ? null : _submit,
                        loading: _submitting,
                        icon: LucideIcons.keyRound,
                        label: _submitting ? 'Đang lưu...' : 'Đổi mật khẩu',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
