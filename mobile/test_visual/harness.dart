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
import 'package:ttsmart_mobile/core/theme/app_system_ui.dart';
import 'package:ttsmart_mobile/core/theme/app_theme.dart';
import 'package:ttsmart_mobile/core/theme/theme_controller.dart';
import 'package:ttsmart_mobile/features/access_management/data/models/permission_models.dart';
import 'package:ttsmart_mobile/features/access_management/data/repositories/access_management_repository.dart';
import 'package:ttsmart_mobile/features/auth/data/models/auth_models.dart';
import 'package:ttsmart_mobile/features/auth/data/repositories/auth_repository.dart';
import 'package:ttsmart_mobile/features/auth/presentation/controllers/app_controller.dart';

final visualRootKey = GlobalKey(debugLabel: 'visual-root');

/// `VISUAL_DARK=1 flutter test --update-goldens test_visual` captures the
/// Figma "Dark" frames instead (files end with `_dark`).
final visualDark = Platform.environment['VISUAL_DARK'] == '1';

/// Phone the captures are drawn on (`VISUAL_DEVICE`):
/// - `iphone` (default): iPhone 13/14, 390×844, notch 47, home indicator 34
///   — the Figma frame size.
/// - `android`: small Android, 360×800, status bar 24, 3-button bar 48.
/// - `android-l`: large Android, 412×915, status bar 24, gesture bar 24.
class VisualDevice {
  const VisualDevice(
    this.id,
    this.size,
    this.top,
    this.bottom, {
    this.android = true,
  });

  final String id;
  final Size size;
  final double top;
  final double bottom;
  final bool android;

  String get suffix => id == 'iphone' ? '' : '_$id';
}

final visualDevice = switch (Platform.environment['VISUAL_DEVICE']) {
  'android' => const VisualDevice('a360', Size(360, 800), 24, 48),
  'android-l' => const VisualDevice('a412', Size(412, 915), 24, 24),
  _ => const VisualDevice('iphone', Size(390, 844), 47, 34, android: false),
};

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

/// Sizes the test view like [visualDevice].
void usePhoneFrame(WidgetTester tester) {
  _currentTester = tester;
  const ratio = 2.0;
  final d = visualDevice;
  tester.view
    ..devicePixelRatio = ratio
    ..physicalSize = d.size * ratio
    ..padding = FakeViewPadding(top: d.top * ratio, bottom: d.bottom * ratio)
    ..viewPadding = FakeViewPadding(
      top: d.top * ratio,
      bottom: d.bottom * ratio,
    );
  addTearDown(tester.view.reset);
}

/// Bumped before each capture so the fake system bars re-read the style the
/// app last asked for.
final _systemBars = ValueNotifier<int>(0);

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
  final file = 'out/$name${visualDevice.suffix}${visualDark ? '_dark' : ''}';
  // Every visible text, for the copy check against the Figma frames.
  final texts = <String>{
    for (final element in find.byType(RichText).evaluate())
      (element.widget as RichText).text.toPlainText().trim(),
    for (final element in find.byType(EditableText).evaluate())
      (element.widget as EditableText).controller.text.trim(),
  }..removeWhere((text) => text.isEmpty);
  File('test_visual/$file.txt').writeAsStringSync(texts.join('\n'));
  _systemBars.value++;
  await tester?.pump();
  try {
    await expectLater(
      find.byKey(visualRootKey),
      matchesGoldenFile('$file.png'),
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
    functions: visualFunctions,
    roleFunctions: const <AuthRoleFunction>[],
  );

  @override
  bool hasPermission(String functionCode, AccessPermission permission) => true;

  @override
  bool hasRole(String roleCode) => isAdmin && roleCode == 'ADMIN';

  @override
  Future<void> refreshCurrentSession() async {}
}

/// Functions as the server names them ("Báo cáo đơn hàng"…), so labels that
/// come from the session look like on a real phone.
final visualFunctions = <GrantedFunction>[
  for (final (index, code, name) in const [
    (1, 'QLND', 'Người dùng'),
    (2, 'QLQ', 'Phân quyền'),
    (3, 'QLCN', 'Chức năng'),
    (4, 'QLCT', 'Quản lý công ty'),
    (5, 'QLTT', 'Quản lý trạm'),
    (6, 'BCDH', 'Báo cáo đơn hàng'),
    (7, 'TKĐH', 'Thống kê đơn hàng'),
    (8, 'QLCP', 'Quản lý cấp phối'),
    (9, 'TKTC', 'Quản lý cân ô tô'),
    (10, 'QLKHO', 'Quản lý vật liệu'),
  ])
    GrantedFunction(
      id: index,
      parentFunctionId: null,
      code: code,
      name: name,
      url: null,
      location: index,
      icon: null,
      activeKey: '111111111',
      permissions: const PermissionSet.full(),
    ),
];

/// App chrome used by every capture: theme + scope + capture boundary, with
/// fake system bars drawn in the colours the app requested.
Widget visualApp(AppController controller, Widget home) => RepaintBoundary(
  key: visualRootKey,
  child: Stack(
    textDirection: TextDirection.ltr,
    children: [
      AppScope(
        controller: controller,
        child: ThemeScope(
          controller: _visualTheme,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: visualDark ? ThemeMode.dark : ThemeMode.light,
            builder: (context, child) =>
                AppSystemUi(child: child ?? const SizedBox.shrink()),
            home: home,
          ),
        ),
      ),
      const Positioned.fill(
        child: IgnorePointer(
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: _FakeSystemBars(),
          ),
        ),
      ),
    ],
  ),
);

final _visualTheme = ThemeController(
  initialMode: visualDark ? ThemeMode.dark : ThemeMode.light,
);

/// Status bar (time + icons) and the Android 3-button / gesture bar or the
/// iPhone home indicator, coloured from [SystemChrome.latestStyle] the way the
/// phone would draw them. Unset colours fall back to the platform defaults
/// (Android: grey status scrim, black navigation bar).
class _FakeSystemBars extends StatelessWidget {
  const _FakeSystemBars();

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
    valueListenable: _systemBars,
    builder: (context, _, _) {
      final d = visualDevice;
      // ignore: invalid_use_of_visible_for_testing_member
      final style = SystemChrome.latestStyle;
      final statusBg = d.android
          ? (style?.statusBarColor ?? const Color(0x33000000))
          : Colors.transparent;
      final statusDark = d.android
          ? style?.statusBarIconBrightness != Brightness.light
          : style?.statusBarBrightness != Brightness.dark;
      final statusFg = statusDark ? const Color(0xFF0F172A) : Colors.white;
      final navBg = d.android
          ? (style?.systemNavigationBarColor ?? Colors.black)
          : Colors.transparent;
      final navDark =
          style?.systemNavigationBarIconBrightness == Brightness.dark;
      final navFg = navDark ? const Color(0xFF334155) : Colors.white;
      final text = TextStyle(
        fontFamily: 'Inter',
        fontSize: d.android ? 13 : 15,
        fontWeight: FontWeight.w600,
        color: statusFg,
      );
      return Column(
        children: [
          Container(
            height: d.top,
            color: statusBg,
            padding: EdgeInsets.fromLTRB(
              d.android ? 16 : 32,
              d.android ? 0 : 14,
              d.android ? 14 : 26,
              0,
            ),
            alignment: d.android ? Alignment.centerLeft : Alignment.topLeft,
            child: Row(
              children: [
                Text(d.android ? '10:03' : '9:41', style: text),
                const Spacer(),
                Icon(Icons.signal_cellular_alt, size: 15, color: statusFg),
                const SizedBox(width: 4),
                Icon(Icons.wifi, size: 15, color: statusFg),
                const SizedBox(width: 4),
                Icon(Icons.battery_full, size: 15, color: statusFg),
              ],
            ),
          ),
          const Spacer(),
          Container(
            height: d.bottom,
            color: navBg,
            alignment: Alignment.center,
            child: !d.android
                ? Container(
                    width: 134,
                    height: 5,
                    margin: const EdgeInsets.only(top: 12),
                    decoration: BoxDecoration(
                      color: statusFg,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  )
                : d.bottom < 40
                ? Container(
                    width: 108,
                    height: 4,
                    decoration: BoxDecoration(
                      color: navFg,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Icon(Icons.menu, size: 22, color: navFg),
                      Icon(Icons.crop_square_rounded, size: 22, color: navFg),
                      Icon(Icons.arrow_back_ios_new, size: 18, color: navFg),
                    ],
                  ),
          ),
        ],
      );
    },
  );
}
