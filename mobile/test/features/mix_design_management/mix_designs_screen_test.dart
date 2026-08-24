import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:ttsmart_mobile/core/app_scope.dart';
import 'package:ttsmart_mobile/core/network/api_client.dart';
import 'package:ttsmart_mobile/core/storage/token_storage.dart';
import 'package:ttsmart_mobile/core/theme/app_theme.dart';
import 'package:ttsmart_mobile/features/access_management/data/models/permission_models.dart';
import 'package:ttsmart_mobile/features/access_management/data/repositories/access_management_repository.dart';
import 'package:ttsmart_mobile/features/auth/data/models/auth_models.dart';
import 'package:ttsmart_mobile/features/auth/data/repositories/auth_repository.dart';
import 'package:ttsmart_mobile/features/auth/presentation/controllers/app_controller.dart';
import 'package:ttsmart_mobile/features/company_management/data/models/company_models.dart';
import 'package:ttsmart_mobile/features/company_management/data/repositories/company_repository.dart';
import 'package:ttsmart_mobile/features/mix_design_management/data/models/mix_design_models.dart';
import 'package:ttsmart_mobile/features/mix_design_management/data/repositories/mix_design_repository.dart';
import 'package:ttsmart_mobile/features/mix_design_management/presentation/screens/mix_designs_screen.dart';
import 'package:ttsmart_mobile/features/mix_design_management/presentation/widgets/mix_design_widgets.dart';

class _MemoryTokenStorage implements TokenStorage {
  @override
  Future<void> clear() async {}

  @override
  Future<StoredSession?> read() async => null;

  @override
  Future<void> write(StoredSession session) async {}
}

class _MixDesignAppController extends AppController {
  _MixDesignAppController(
    ApiClient apiClient, {
    required this.canList,
    this.isAdmin = false,
  }) : super(
         apiClient: apiClient,
         authRepository: AuthRepository(apiClient),
         accessManagementRepository: AccessManagementRepository(apiClient),
         tokenStorage: _MemoryTokenStorage(),
       );

  final bool canList;
  final bool isAdmin;

  @override
  CurrentSession? get session => const CurrentSession(
    user: AuthenticatedUser(
      id: 1,
      userName: 'company-user',
      fullName: 'Người xem cấp phối',
      email: null,
      code: null,
      phone: null,
      companyId: 3,
      departmentId: null,
      positionId: null,
      unitId: null,
      branchId: null,
      status: 1,
    ),
    roles: <AuthRole>[],
    functions: <GrantedFunction>[],
    roleFunctions: <AuthRoleFunction>[],
  );

  @override
  bool hasRole(String roleCode) => isAdmin && roleCode == 'ADMIN';

  @override
  bool hasPermission(String functionCode, AccessPermission permission) =>
      canList &&
      functionCode == AccessFunctionCodes.mixDesigns &&
      permission == AccessPermission.dSach;
}

class _FakeMixDesignRepository implements MixDesignRepository {
  final queries = <MixDesignQuery>[];

  @override
  Future<List<MixDesignStation>> getStations({int? companyId}) async => const [
    MixDesignStation(id: 10, name: 'Trạm Bình Chánh'),
  ];

  @override
  Future<MixDesignPage> getMixDesigns(MixDesignQuery query) async {
    queries.add(query);
    return MixDesignPage(
      items: [_item((query.pageNumber - 1) * 10 + 1)],
      pageNumber: query.pageNumber,
      pageSize: 10,
      totalCount: 12,
      totalPages: 2,
      materialColumns: _materialColumns,
    );
  }
}

class _FakeCompanyRepository implements CompanyRepository {
  @override
  Future<CompanyPage> getCompanies({
    int pageNumber = 1,
    int pageSize = 20,
    String? search,
    int? status = CompanyDataStatus.active,
    bool? isLocked,
  }) async => CompanyPage(
    items: [_company()],
    pageNumber: 1,
    pageSize: pageSize,
    totalCount: 1,
    totalPages: 1,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('renders responsive mix design table and paginates', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final apiClient = ApiClient(
      baseUri: Uri.parse('http://localhost:5052'),
      timeout: const Duration(seconds: 1),
      httpClient: MockClient(
        (_) async => throw StateError('Không được gọi API thật trong test.'),
      ),
    );
    final appController = _MixDesignAppController(apiClient, canList: true);
    final repository = _FakeMixDesignRepository();
    addTearDown(appController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AppScope(
          controller: appController,
          child: MixDesignsScreen(
            repository: repository,
            companyRepository: _FakeCompanyRepository(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cấp phối bê tông theo trạm'), findsNothing);
    expect(
      find.textContaining('Cột STT và Mác BT được giữ cố định'),
      findsNothing,
    );
    expect(find.text('Trạm Bình Chánh'), findsOneWidget);
    expect(find.text('Chưa tải danh sách cấp phối'), findsOneWidget);
    expect(
      tester
          .getRect(find.byKey(const ValueKey<String>('mix-design-search')))
          .left,
      lessThan(
        tester
            .getRect(find.byKey(const ValueKey<String>('mix-design-reset')))
            .left,
      ),
    );

    await tester.tap(find.byKey(const ValueKey<String>('mix-design-search')));
    await tester.pumpAndSettle();

    expect(repository.queries.single.companyId, isNull);
    expect(repository.queries.single.stationId, 10);
    expect(
      find.byKey(const ValueKey<String>('mix-design-results-table')),
      findsOneWidget,
    );
    expect(find.text('Mác BT'), findsOneWidget);
    expect(find.text('Phụ gia Sika Road'), findsOneWidget);
    expect(find.text('M300'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('mix-design-pagination')),
        matching: find.text('1 / 2'),
      ),
      findsOneWidget,
    );

    await tester.drag(
      find.byKey(const ValueKey<String>('mix-design-table-horizontal-scroll')),
      const Offset(-420, 0),
    );
    await tester.pumpAndSettle();

    final nextPage = find.byKey(const ValueKey<String>('mix-design-page-next'));
    await tester.ensureVisible(nextPage);
    await tester.pumpAndSettle();
    expect(tester.widget<IconButton>(nextPage).onPressed, isNotNull);
    await tester.tap(nextPage);
    await tester.pumpAndSettle();

    expect(repository.queries.last.pageNumber, 2);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('mix-design-pagination')),
        matching: find.text('2 / 2'),
      ),
      findsOneWidget,
    );
    expect(find.text('11'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'places company and station filters side by side on wide layout',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final apiClient = ApiClient(
        baseUri: Uri.parse('http://localhost:5052'),
        timeout: const Duration(seconds: 1),
        httpClient: MockClient(
          (_) async => throw StateError('Không được gọi API thật trong test.'),
        ),
      );
      final appController = _MixDesignAppController(
        apiClient,
        canList: true,
        isAdmin: true,
      );
      addTearDown(appController.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: AppScope(
            controller: appController,
            child: MixDesignsScreen(
              repository: _FakeMixDesignRepository(),
              companyRepository: _FakeCompanyRepository(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final companyField = find.byKey(
        const ValueKey<String>('mix-design-company-null-1'),
      );
      final stationField = find.byKey(
        const ValueKey<String>('mix-design-station-null-0'),
      );
      expect(companyField, findsOneWidget);
      expect(stationField, findsOneWidget);
      expect(
        tester.getRect(companyField).top,
        closeTo(tester.getRect(stationField).top, 0.01),
      );
      expect(
        tester.getRect(companyField).right,
        lessThan(tester.getRect(stationField).left),
      );
      expect(
        tester
            .getRect(find.byKey(const ValueKey<String>('mix-design-search')))
            .left,
        lessThan(
          tester
              .getRect(find.byKey(const ValueKey<String>('mix-design-reset')))
              .left,
        ),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('sizes Mác BT from the longest displayed grade', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    Future<double> pumpTable(String concreteGradeName) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: SizedBox(
              width: 800,
              child: MixDesignResultsTable(
                page: MixDesignPage(
                  items: [_item(1, concreteGradeName: concreteGradeName)],
                  pageNumber: 1,
                  pageSize: 10,
                  totalCount: 1,
                  totalPages: 1,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return tester
          .getSize(
            find.byKey(const ValueKey<String>('mix-design-grade-header')),
          )
          .width;
    }

    final shortWidth = await pumpTable('M300');
    final longWidth = await pumpTable('Mác bê tông chống thấm đặc biệt');

    expect(longWidth, greaterThan(shortWidth));
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows access state without loading repository', (tester) async {
    final apiClient = ApiClient(
      baseUri: Uri.parse('http://localhost:5052'),
      timeout: const Duration(seconds: 1),
      httpClient: MockClient(
        (_) async => throw StateError('Không được gọi API thật trong test.'),
      ),
    );
    final appController = _MixDesignAppController(apiClient, canList: false);
    addTearDown(appController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AppScope(
          controller: appController,
          child: MixDesignsScreen(
            repository: _FakeMixDesignRepository(),
            companyRepository: _FakeCompanyRepository(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Không có quyền xem cấp phối'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('mix-design-filters')),
      findsNothing,
    );
  });
}

MixDesignItem _item(int stt, {String concreteGradeName = 'M300'}) =>
    MixDesignItem(
      stt: stt,
      concreteGradeName: concreteGradeName,
      strength: 300,
      maxAggregate: 40,
      slump: '12±2',
      sand1: 400,
      sand2: 0,
      stone1: 500,
      stone2: 600,
      stone3: 0,
      cement1: 250,
      cement2: 150,
      cement3: 0,
      cement4: 0,
      water: 150,
      sika: 2,
      tulog: 0,
      sikaroad: 0,
      bifi: 0,
      materials: const [
        MixDesignMaterial(
          materialSlotId: 3,
          slotNumber: 3,
          columnKey: 'slot-3',
          quantity: 500,
        ),
        MixDesignMaterial(
          materialSlotId: 12,
          slotNumber: 12,
          columnKey: 'slot-12',
          quantity: 2,
        ),
      ],
    );

const _materialColumns = <MixDesignMaterialColumn>[
  MixDesignMaterialColumn(
    materialSlotId: 3,
    slotNumber: 3,
    materialName: 'Đá 1x2',
    category: 'Đá',
    categoryCode: 'stone',
    typePosition: 1,
    columnKey: 'slot-3',
  ),
  MixDesignMaterialColumn(
    materialSlotId: 12,
    slotNumber: 12,
    materialName: 'Phụ gia Sika Road',
    category: 'Phụ gia',
    categoryCode: 'additive',
    typePosition: 1,
    columnKey: 'slot-12',
  ),
];

CompanyResponse _company() => const CompanyResponse(
  id: 3,
  code: 'CT03',
  name: 'Công ty Alpha',
  email: null,
  phone: null,
  address: null,
  fax: null,
  representative: null,
  contactName: null,
  contactEmail: null,
  contactPhone: null,
  createdAtUtc: null,
  updatedAtUtc: null,
  userId: null,
  status: CompanyDataStatus.active,
  isActive: true,
  countUser: 1,
  plan: CompanyPlan.paid,
  isLocked: false,
  note: null,
  logo: null,
  expiredDate: null,
);
