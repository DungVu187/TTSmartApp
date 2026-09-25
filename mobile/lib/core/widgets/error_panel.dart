import 'package:flutter/material.dart';

import '../ui/ui_feedback.dart';

/// Inline error notice. Kept as the app-wide entry point; renders the
/// redesign's [ErrorBanner].
class ErrorPanel extends StatelessWidget {
  const ErrorPanel({
    super.key,
    required this.message,
    this.onRetry,
    this.retryLabel = 'Thử lại',
  });

  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) =>
      ErrorBanner(message: message, onRetry: onRetry, retryLabel: retryLabel);
}
