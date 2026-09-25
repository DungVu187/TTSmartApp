import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Makes the test view report [size] (logical pixels) through [MediaQuery].
///
/// `binding.setSurfaceSize` only constrains layout and leaves
/// `MediaQuery.sizeOf` at the 800×600 default, so screens that branch on the
/// screen width would silently render their other layout.
void useViewport(WidgetTester tester, Size size) {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = size;
  addTearDown(tester.view.reset);
}

/// Phone-sized viewport (390×844 logical by default).
void usePhoneViewport(
  WidgetTester tester, {
  Size size = const Size(390, 844),
}) => useViewport(tester, size);
