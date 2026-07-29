import 'package:flutter/material.dart';

import '../../../../core/app_scope.dart';
import '../../../../core/widgets/error_panel.dart';
import '../../../../core/widgets/password_field.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userNameController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _userNameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final controller = AppScope.read(context);
    await controller.login(
      userName: _userNameController.text,
      password: _passwordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final loginError = controller.loginError;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          Icons.apartment_rounded,
                          size: 38,
                          color: Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'TTsmart',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Đăng nhập để truy cập hệ thống quản lý nội bộ.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (controller.notice != null) ...[
                        const SizedBox(height: 20),
                        ErrorPanel(message: controller.notice!),
                      ],
                      if (loginError != null) ...[
                        const SizedBox(height: 20),
                        ErrorPanel(message: loginError.message),
                      ],
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _userNameController,
                        autofocus: true,
                        maxLength: 20,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.username],
                        onChanged: (_) => controller.clearLoginError(),
                        validator: (value) {
                          final text = value?.trim() ?? '';
                          if (text.isEmpty) {
                            return 'Vui lòng nhập tên đăng nhập.';
                          }
                          if (text.length > 20) {
                            return 'Tên đăng nhập không được vượt quá 20 ký tự.';
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          labelText: 'Tên đăng nhập',
                          prefixIcon: const Icon(Icons.person_outline),
                          errorText: loginError?.fieldMessage('userName'),
                          counterText: '',
                        ),
                      ),
                      const SizedBox(height: 16),
                      PasswordField(
                        controller: _passwordController,
                        label: 'Mật khẩu',
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        onSubmitted: (_) => _submit(),
                        errorText: loginError?.fieldMessage('password'),
                        validator: (value) => (value == null || value.isEmpty)
                            ? 'Vui lòng nhập mật khẩu.'
                            : null,
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: controller.isLoginSubmitting
                            ? null
                            : _submit,
                        icon: controller.isLoginSubmitting
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.login),
                        label: Text(
                          controller.isLoginSubmitting
                              ? 'Đang đăng nhập...'
                              : 'Đăng nhập',
                        ),
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
