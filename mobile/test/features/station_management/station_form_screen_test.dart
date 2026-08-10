import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttsmart_mobile/features/company_management/data/models/company_models.dart';
import 'package:ttsmart_mobile/features/company_management/data/repositories/company_repository.dart';
import 'package:ttsmart_mobile/features/station_management/data/repositories/station_repository.dart';
import 'package:ttsmart_mobile/features/station_management/presentation/controllers/stations_controller.dart';
import 'package:ttsmart_mobile/features/station_management/presentation/screens/station_form_screen.dart';

class _FakeCompanyRepository implements CompanyRepository {
  @override
  Future<CompanyPage> getCompanies({
    int pageNumber = 1,
    int pageSize = 20,
    String? search,
    int? status = CompanyDataStatus.active,
    bool? isLocked,
  }) async => CompanyPage(
    items: [_company(3, 'Công ty Alpha'), _company(4, 'Công ty Beta')],
    pageNumber: 1,
    pageSize: pageSize,
    totalCount: 2,
    totalPages: 1,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UnusedStationRepository implements StationRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

CompanyResponse _company(int id, String name) => CompanyResponse(
  id: id,
  code: 'CT$id',
  name: name,
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

void main() {
  testWidgets('admin can search and select company when adding station', (
    tester,
  ) async {
    final controller = StationsController(_UnusedStationRepository());
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: StationFormScreen(
          controller: controller,
          companyRepository: _FakeCompanyRepository(),
          isAdmin: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final companyAutocomplete = find.byKey(
      const ValueKey<String>('station-company-null-2'),
    );
    final companyInput = find.descendant(
      of: companyAutocomplete,
      matching: find.byType(TextFormField),
    );
    await tester.tap(companyInput);
    await tester.enterText(companyInput, 'Beta');
    await tester.pump();

    expect(find.text('Công ty Beta'), findsOneWidget);
    await tester.tap(find.text('Công ty Beta'));
    await tester.pumpAndSettle();

    expect(find.text('Công ty Beta'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('station-company-4-2')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
