import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttsmart_mobile/core/theme/app_theme.dart';
import 'package:ttsmart_mobile/features/access_management/data/models/permission_models.dart';
import 'package:ttsmart_mobile/features/access_management/data/models/role_models.dart';
import 'package:ttsmart_mobile/features/access_management/presentation/screens/function_permission_screen.dart';

void main() {
  testWidgets('đổi một quyền và cấp đủ 9 quyền trong bản nháp', (tester) async {
    final changes = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: FunctionPermissionScreen(
          item: const RoleFunctionMatrixItemResponse(
            functionId: 1,
            parentFunctionId: null,
            code: 'QLND',
            name: 'Quản lý người dùng',
            url: null,
            location: 1,
            icon: null,
            functionRoleId: null,
            isAssigned: false,
            activeKey: PermissionSet.emptyActiveKey,
            permissions: PermissionSet.none(),
          ),
          canEdit: true,
          onChanged: (permissions) => changes.add(permissions.activeKey),
        ),
      ),
    );

    await tester.tap(find.text('Xem'));
    await tester.pump();
    expect(changes.last, '100000000');

    await tester.tap(find.text('Cấp toàn bộ quyền'));
    await tester.pump();
    expect(changes.last, PermissionSet.fullActiveKey);
  });
}
