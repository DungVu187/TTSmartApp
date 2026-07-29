import 'package:flutter/widgets.dart';

import '../features/auth/presentation/controllers/app_controller.dart';

class AppScope extends InheritedNotifier<AppController> {
  const AppScope({
    super.key,
    required AppController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'Không tìm thấy AppScope trong widget tree.');
    return scope!.notifier!;
  }

  static AppController read(BuildContext context) {
    final element = context.getElementForInheritedWidgetOfExactType<AppScope>();
    final scope = element?.widget as AppScope?;
    assert(scope != null, 'Không tìm thấy AppScope trong widget tree.');
    return scope!.notifier!;
  }
}
