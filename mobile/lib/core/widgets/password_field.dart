import 'package:flutter/material.dart';

class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    required this.label,
    this.textInputAction,
    this.onSubmitted,
    this.validator,
    this.errorText,
    this.autofillHints,
  });

  final TextEditingController controller;
  final String label;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final FormFieldValidator<String>? validator;
  final String? errorText;
  final Iterable<String>? autofillHints;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _obscureText,
      enableSuggestions: false,
      autocorrect: false,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      onFieldSubmitted: widget.onSubmitted,
      validator: widget.validator,
      decoration: InputDecoration(
        labelText: widget.label,
        errorText: widget.errorText,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          tooltip: _obscureText ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
          onPressed: () => setState(() => _obscureText = !_obscureText),
          icon: Icon(
            _obscureText
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
        ),
      ),
    );
  }
}
