import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/app_info.dart';
import '../../../../core/app_scope.dart';
import '../../../../core/ui/app_ui.dart';

/// Figma "01 Login".
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userNameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

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

  /// White + primary border while focused, muted fill otherwise.
  InputDecoration _decoration(
    AppPalette p, {
    required IconData icon,
    String? errorText,
    Widget? suffix,
  }) {
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: color, width: width),
    );
    return InputDecoration(
      filled: true,
      fillColor: WidgetStateColor.resolveWith(
        (states) =>
            states.contains(WidgetState.focused) ||
                states.contains(WidgetState.error)
            ? p.surface
            : p.surfaceMuted,
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 16),
      prefixIcon: Icon(icon, size: 20, color: p.text3),
      prefixIconConstraints: const BoxConstraints(minWidth: 46),
      suffixIcon: suffix,
      errorText: errorText,
      errorMaxLines: 2,
      counterText: '',
      border: border(Colors.transparent, 1),
      enabledBorder: border(Colors.transparent, 1),
      focusedBorder: border(p.primary, 1.5),
      errorBorder: border(p.danger, 1.5),
      focusedErrorBorder: border(p.danger, 1.5),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final loginError = controller.loginError;
    final p = context.palette;
    final fieldText = TextStyle(
      color: p.text1,
      fontSize: 15,
      fontWeight: FontWeight.w500,
    );
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            // 28 on phones; wider screens keep the form 440px wide.
            padding: EdgeInsets.symmetric(
              horizontal: math.max(28, (constraints.maxWidth - 440) / 2),
            ),
            child: ConstrainedBox(
              // At least one screen tall so the version sits at the bottom.
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AutofillGroup(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 40),
                          Center(
                            child: Image.asset(
                              'assets/images/ttsmart_logo_transparent.png',
                              width: 200,
                              height: 43,
                              fit: BoxFit.contain,
                              semanticLabel: 'Logo TTSmart',
                            ),
                          ),
                          const SizedBox(height: 28),
                          Text(
                            'Chào mừng trở lại',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: p.text1,
                              fontSize: 28,
                              height: 34 / 28,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.6,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Đăng nhập để truy cập hệ thống quản lý nội bộ '
                            'TTSmart.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: p.text2,
                              fontSize: 15,
                              height: 22 / 15,
                            ),
                          ),
                          if (controller.notice != null) ...[
                            const SizedBox(height: 20),
                            ErrorBanner(message: controller.notice!),
                          ],
                          if (loginError != null) ...[
                            const SizedBox(height: 20),
                            ErrorBanner(message: loginError.message),
                          ],
                          const SizedBox(height: 30),
                          _Label('Tên đăng nhập', palette: p),
                          TextFormField(
                            key: const ValueKey<String>('login-user-name'),
                            controller: _userNameController,
                            autofocus: true,
                            maxLength: 20,
                            style: fieldText,
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
                            decoration: _decoration(
                              p,
                              icon: Icons.person_outline_rounded,
                              errorText: loginError?.fieldMessage('userName'),
                            ),
                          ),
                          const SizedBox(height: 14),
                          _Label('Mật khẩu', palette: p),
                          TextFormField(
                            key: const ValueKey<String>('login-password'),
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            enableSuggestions: false,
                            autocorrect: false,
                            style: fieldText,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.password],
                            onFieldSubmitted: (_) => _submit(),
                            validator: (value) =>
                                (value == null || value.isEmpty)
                                ? 'Vui lòng nhập mật khẩu.'
                                : null,
                            decoration: _decoration(
                              p,
                              icon: Icons.lock_outline_rounded,
                              errorText: loginError?.fieldMessage('password'),
                              suffix: IconButton(
                                tooltip: _obscurePassword
                                    ? 'Hiện mật khẩu'
                                    : 'Ẩn mật khẩu',
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  size: 20,
                                  color: p.text3,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: p.primary.withValues(alpha: 0.28),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: FilledButton.icon(
                              key: const ValueKey<String>('login-submit'),
                              onPressed: controller.isLoginSubmitting
                                  ? null
                                  : _submit,
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(52),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              icon: controller.isLoginSubmitting
                                  ? SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: p.onPrimary,
                                      ),
                                    )
                                  : const Icon(Icons.login_rounded, size: 20),
                              label: Text(
                                controller.isLoginSubmitting
                                    ? 'Đang đăng nhập...'
                                    : 'Đăng nhập',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text.rich(
                            TextSpan(
                              style: TextStyle(
                                color: p.text2,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                              children: [
                                const TextSpan(text: 'Quên mật khẩu? Liên hệ '),
                                TextSpan(
                                  text: 'quản trị viên',
                                  style: TextStyle(
                                    color: p.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 32, bottom: 16),
                    child: Text(
                      'TTsmart · Phiên bản $kAppVersion',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: p.text3,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text, {required this.palette});

  final String text;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: TextStyle(
        color: palette.text2,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}
