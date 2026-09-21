import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ttsmart_mobile/core/app_scope.dart';
import 'package:ttsmart_mobile/core/network/api_client.dart';
import 'package:ttsmart_mobile/core/storage/token_storage.dart';
import 'package:ttsmart_mobile/core/theme/app_theme.dart';
import 'package:ttsmart_mobile/features/access_management/data/models/permission_models.dart';
import 'package:ttsmart_mobile/features/access_management/data/repositories/access_management_repository.dart';
import 'package:ttsmart_mobile/features/access_management/presentation/screens/users_screen.dart';
import 'package:ttsmart_mobile/features/auth/data/models/auth_models.dart';
import 'package:ttsmart_mobile/features/auth/data/repositories/auth_repository.dart';
import 'package:ttsmart_mobile/features/auth/presentation/controllers/app_controller.dart';
import 'package:ttsmart_mobile/features/company_management/data/repositories/company_repository.dart';
import 'package:ttsmart_mobile/features/station_management/data/repositories/station_repository.dart';

class _MemoryTokenStorage implements TokenStorage {
  @override
  Future<void> clear() async {}

  @override
  Future<StoredSession?> read() async => null;

  @override
  Future<void> write(StoredSession session) async {}
}

class _CompanyAccountController extends AppController {
  _CompanyAccountController(ApiClient apiClient)
    : super(
        apiClient: apiClient,
        authRepository: AuthRepository(apiClient),
        accessManagementRepository: AccessManagementRepository(apiClient),
        tokenStorage: _MemoryTokenStorage(),
      );

  @override
  CurrentSession? get session => const CurrentSession(
    user: AuthenticatedUser(
      id: 7,
      userName: 'company-owner',
      fullName: 'Company Owner',
      email: null,
      code: null,
      phone: null,
      companyId: 10,
      departmentId: null,
      positionId: null,
      unitId: null,
      branchId: '20',
      status: 1,
    ),
    roles: <AuthRole>[],
    functions: <GrantedFunction>[],
    roleFunctions: <AuthRoleFunction>[],
  );

  @override
  bool hasPermission(String functionCode, AccessPermission permission) =>
      functionCode == AccessFunctionCodes.users &&
      permission == AccessPermission.dSach;

  @override
  bool hasRole(String roleCode) => false;
}

void main() {
  testWidgets('company account filter fixes company scope and hides selector', (
    tester,
  ) async {
    final requestedPaths = <String>[];
    final apiClient = ApiClient(
      baseUri: Uri.parse('http://localhost:5052'),
      timeout: const Duration(seconds: 1),
      httpClient: MockClient((request) async {
        requestedPaths.add(request.url.path);
        final body = switch (request.url.path) {
          '/api/users' => <String, Object?>{
            'items': <Object?>[],
            'pageNumber': 1,
            'pageSize': 20,
            'totalCount': 0,
            'totalPages': 0,
          },
          '/api/users/assignable-roles' => <Object?>[],
          '/api/branches' => <String, Object?>{
            'items': <Object?>[],
            'pageNumber': 1,
            'pageSize': 100,
            'totalCount': 0,
            'totalPages': 0,
          },
          _ => throw StateError('Unexpected request: ${request.url}'),
        };
        return http.Response.bytes(utf8.encode(jsonEncode(body)), 200);
      }),
    )..accessToken = 'test-token';
    final controller = _CompanyAccountController(apiClient);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AppScope(
          controller: controller,
          child: UsersScreen(
            companyRepository: ApiCompanyRepository(apiClient),
            stationRepository: ApiStationRepository(apiClient),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Bộ lọc'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    expect(find.text('Công ty'), findsNothing);
    expect(find.text('Trạm'), findsOneWidget);
    expect(requestedPaths, isNot(contains('/api/companies')));
  });
}
