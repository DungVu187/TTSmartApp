import 'package:flutter/material.dart';

import '../ui/app_palette.dart';
import '../ui/ui_feedback.dart';

/// Empty / informational state. Kept as the app-wide entry point; renders the
/// redesign's [StateView].
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.tone = AppTone.neutral,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  final AppTone tone;

  @override
  Widget build(BuildContext context) => StateView(
    icon: icon,
    title: title,
    message: message,
    tone: tone,
    actions: [?action],
  );
}
