// Visual review harness: renders real screens with Figma-like sample data to
// PNG files so they can be compared side by side with the Figma frames.
//
// Not part of `flutter test`. Run explicitly:
//   flutter test --update-goldens test_visual
// Output: test_visual/out/*.png (git-ignored).
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:ttsmart_mobile/core/app_scope.dart';
import 'package:ttsmart_mobile/core/network/api_client.dart';
import 'package:ttsmart_mobile/core/network/api_exception.dart';
import 'package:ttsmart_mobile/core/storage/token_storage.dart';
import 'package:ttsmart_mobile/core/theme/app_theme.dart';
import 'package:ttsmart_mobile/features/access_management/data/models/permission_models.dart';
import 'package:ttsmart_mobile/features/access_management/data/repositories/access_management_repository.dart';
import 'package:ttsmart_mobile/features/auth/data/models/auth_models.dart';
import 'package:ttsmart_mobile/features/auth/data/repositories/auth_repository.dart';
import 'package:ttsmart_mobile/features/auth/presentation/controllers/app_controller.dart';

final visualRootKey = GlobalKey(debugLabel: 'visual-root');

/// `VISUAL_DARK=1 flutter test --update-goldens test_visual` captures the
/// Figma "Dark" frames instead (files end with `_dark`).
final visualDark = Platform.environment['VISUAL_DARK'] == '1';

/// Loads the bundled Inter + Material Icons (from the Flutter SDK) so text
/// and icons are drawn for real instead of the test font's boxes.
Future<void> loadVisualFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'] ?? r'D:\flutter';
  Future<ByteData> read(String path) async =>
      ByteData.sublistView(File(path).readAsBytesSync());
  final inter = FontLoader('Inter');
  for (final weight in const [
    'Regular',
    'Medium',
    'SemiBold',
    'Bold',
    'ExtraBold',
    'Black',
  ]) {
    inter.addFont(read('assets/fonts/inter/Inter-$weight.ttf'));
  }
  await inter.load();
  // Text styles without a family fall back to the test box font; the theme
  // family covers the ones built by the theme. Anything still drawn as boxes
  // is a hard-coded style that would also ignore the bundled font.
  AppTheme.fontFamily = 'Inter';
  final icons = FontLoader('MaterialIcons')
    ..addFont(
      read(
        '$root/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
      ),
    );
  await icons.load();
  // Lucide (the Figma icon set) from the pub cache, found through the
  // package config so the harness works on any machine.
  final config =
      jsonDecode(File('.dart_tool/package_config.json').readAsStringSync())
          as Map<String, dynamic>;
  final lucide = (config['packages'] as List<dynamic>)
      .cast<Map<String, dynamic>>()
      .firstWhere((entry) => entry['name'] == 'lucide_icons_flutter');
  final lucideRoot = Uri.parse('${lucide['rootUri']}/');
  final lucideFont = FontLoader('packages/lucide_icons_flutter/Lucide')
    ..addFont(read(lucideRoot.resolve('assets/lucide.ttf').toFilePath()));
  await lucideFont.load();
}

/// iPhone 13/14 frame of the Figma file: 390×844 pt, notch 47, home bar 34.
void usePhoneFrame(WidgetTester tester) {
  _currentTester = tester;
  const ratio = 2.0;
  tester.view
    ..devicePixelRatio = ratio
    ..physicalSize = const Size(390 * ratio, 844 * ratio)
    ..padding = const FakeViewPadding(top: 47 * ratio, bottom: 34 * ratio)
    ..viewPadding = const FakeViewPadding(top: 47 * ratio, bottom: 34 * ratio);
  addTearDown(tester.view.reset);
}

/// Decodes every on-screen image for real (outside fake async) first, so
/// assets such as the logo appear in the capture.
Future<void> snap(String name) async {
  final tester = _currentTester;
  if (tester != null) {
    final images = find.byType(Image).evaluate().toList();
    await tester.runAsync(() async {
      for (final element in images) {
        final widget = element.widget as Image;
        await precacheImage(widget.image, element);
      }
    });
    await tester.pump();
  }
  // flutter_test draws shadows as solid outlines; paint real ones for the
  // capture only (the flag must be restored before the test ends).
  debugDisableShadows = false;
  void repaint(RenderObject object) {
    object.markNeedsPaint();
    object.visitChildren(repaint);
  }

  for (final view in RendererBinding.instance.renderViews) {
    repaint(view);
  }
  await tester?.pump();
  // Report every text cut by maxLines ("…") so font changes are easy to spot.
  void clipped(RenderObject object) {
    if (object is RenderParagraph && object.hasSize) {
      final text = object.text.toPlainText();
      if (object.didExceedMaxLines) {
        // ignore: avoid_print
        print('[clipped] $name: "$text"');
      } else if (text.length < 24 &&
          object.getMaxIntrinsicWidth(double.infinity) >
              object.size.width + 0.5) {
        // Short labels (times, numbers, chips) should never wrap.
        // ignore: avoid_print
        print('[wrapped] $name: "$text"');
      }
    }
    object.visitChildren(clipped);
  }

  for (final view in RendererBinding.instance.renderViews) {
    clipped(view);
  }
  try {
    await expectLater(
      find.byKey(visualRootKey),
      matchesGoldenFile('out/$name${visualDark ? '_dark' : ''}.png'),
    );
  } finally {
    debugDisableShadows = true;
    for (final view in RendererBinding.instance.renderViews) {
      repaint(view);
    }
    await tester?.pump();
  }
}

WidgetTester? _currentTester;

class _MemoryTokenStorage implements TokenStorage {
  @override
  Future<void> clear() async {}

  @override
  Future<StoredSession?> read() async => null;

  @override
  Future<void> write(StoredSession session) async {}
}

ApiClient offlineApiClient() => ApiClient(
  baseUri: Uri.parse('http://localhost:5052'),
  timeout: const Duration(seconds: 1),
  httpClient: MockClient(
    (request) async => throw StateError('Unexpected request: ${request.url}'),
  ),
);

/// Signed-in "Vũ Đức Dũng" with every permission.
class VisualAppController extends AppController {
  VisualAppController(
    ApiClient apiClient, {
    this.isAdmin = true,
    this.userName = 'dungvd',
    this.code = 'NV001',
    this.roleOverride,
    this.startupErrorOverride,
  }) : super(
         apiClient: apiClient,
         authRepository: AuthRepository(apiClient),
         accessManagementRepository: AccessManagementRepository(apiClient),
         tokenStorage: _MemoryTokenStorage(),
       );

  final bool isAdmin;
  final String userName;
  final String code;
  final List<AuthRole>? roleOverride;
  final ApiException? startupErrorOverride;

  @override
  ApiException? get startupError => startupErrorOverride;

  @override
  CurrentSession? get session => CurrentSession(
    user: AuthenticatedUser(
      id: 1,
      userName: userName,
      fullName: 'Vũ Đức Dũng',
      email: 'dung.vu@ttsmart.vn',
      code: code,
      phone: '0912 345 678',
      companyId: 3,
      departmentId: null,
      positionId: null,
      unitId: null,
      branchId: null,
      status: 1,
    ),
    roles:
        roleOverride ??
        (isAdmin
            ? const <AuthRole>[
                AuthRole(
                  id: 1,
                  code: 'ADMIN',
                  name: 'Quản trị hệ thống',
                  levelRole: 1,
                ),
              ]
            : const <AuthRole>[]),
    functions: const <GrantedFunction>[],
    roleFunctions: const <AuthRoleFunction>[],
  );

  @override
  bool hasPermission(String functionCode, AccessPermission permission) => true;

  @override
  bool hasRole(String roleCode) => isAdmin && roleCode == 'ADMIN';

  @override
  Future<void> refreshCurrentSession() async {}
}

/// App chrome used by every capture: theme + scope + capture boundary.
Widget visualApp(AppController controller, Widget home) => RepaintBoundary(
  key: visualRootKey,
  child: AppScope(
    controller: controller,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: visualDark ? AppTheme.dark : AppTheme.light,
      home: home,
    ),
  ),
);
