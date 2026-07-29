import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/widgets/password_field.dart';
import '../controllers/users_controller.dart';

class ResetPasswordDialog extends StatefulWidget {
  const ResetPasswordDialog({
    super.key,
    required this.controller,
    required this.userId,
  });

  final UsersController controller;
  final int userId;

  @override
  State<ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<ResetPasswordDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  ApiException? _error;
  bool _submitting = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.controller.resetPassword(
        widget.userId,
        _passwordController.text,
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
    return AlertDialog(
      title: const Text('Đặt mật khẩu mới'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_error != null) ...[
                Text(
                  _error!.message,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: 12),
              ],
              PasswordField(
                controller: _passwordController,
                label: 'Mật khẩu mới',
                textInputAction: TextInputAction.next,
                errorText: _error?.fieldMessage('newPassword'),
                validator: (value) {
                  final length = value?.length ?? 0;
                  if (length < 6 || length > 200) {
                    return 'Mật khẩu phải có từ 6 đến 200 ký tự.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              PasswordField(
                controller: _confirmController,
                label: 'Nhập lại mật khẩu',
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                validator: (value) => value != _passwordController.text
                    ? 'Mật khẩu nhập lại không khớp.'
                    : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Đặt lại'),
        ),
      ],
    );
  }
}
