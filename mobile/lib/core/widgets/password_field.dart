import 'package:flutter/material.dart';

import '../ui/app_palette.dart';
import '../ui/ui_controls.dart';

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
    this.labelAbove = false,
    this.helperText,
  });

  final TextEditingController controller;
  final String label;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final FormFieldValidator<String>? validator;

  /// Server-side error; shown when the validator has nothing to say.
  final String? errorText;
  final Iterable<String>? autofillHints;
  final bool labelAbove;
  final String? helperText;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return FormField<String>(
      validator: widget.validator == null
          ? null
          : (_) => widget.validator!(widget.controller.text),
      builder: (field) {
        final error = field.errorText ?? widget.errorText;
        final errorBorder = Theme.of(context).inputDecorationTheme.errorBorder;
        final input = TextField(
          controller: widget.controller,
          obscureText: _obscureText,
          enableSuggestions: false,
          autocorrect: false,
          textInputAction: widget.textInputAction,
          autofillHints: widget.autofillHints,
          onSubmitted: widget.onSubmitted,
          onChanged: field.didChange,
          style: TextStyle(
            color: p.text1,
            fontSize: 16,
            fontWeight: FontWeight.w500,
            letterSpacing: _obscureText ? 1.5 : null,
          ),
          decoration: InputDecoration(
            labelText: widget.labelAbove ? null : widget.label,
            enabledBorder: error == null ? null : errorBorder,
            focusedBorder: error == null ? null : errorBorder,
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 13, right: 10),
              child: Icon(Icons.lock_outline_rounded, size: 18, color: p.text3),
            ),
            prefixIconConstraints: const BoxConstraints(),
            suffixIcon: Padding(
              padding: const EdgeInsets.only(right: 2),
              child: IconButton(
                tooltip: _obscureText ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                onPressed: () => setState(() => _obscureText = !_obscureText),
                constraints: const BoxConstraints.tightFor(
                  width: 44,
                  height: 44,
                ),
                padding: EdgeInsets.zero,
                icon: Icon(
                  _obscureText
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                  color: p.text3,
                ),
              ),
            ),
            suffixIconConstraints: const BoxConstraints(),
          ),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.labelAbove) ...[
              FieldLabel(widget.label),
              const SizedBox(height: 6),
            ],
            input,
            if (error != null) ...[
              const SizedBox(height: 6),
              FieldError(error),
            ] else if (widget.helperText != null) ...[
              const SizedBox(height: 6),
              Text(
                widget.helperText!,
                style: TextStyle(
                  color: p.text3,
                  fontSize: 13,
                  height: 17 / 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
