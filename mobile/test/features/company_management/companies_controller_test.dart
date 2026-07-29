import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ttsmart_mobile/features/company_management/data/models/company_models.dart';
import 'package:ttsmart_mobile/features/company_management/data/repositories/company_repository.dart';
import 'package:ttsmart_mobile/features/company_management/presentation/controllers/companies_controller.dart';

class _FakeCompanyRepository implements CompanyRepository {
  final List<int?> statuses = <int?>[];
  final List<bool?> locks = <bool?>[];

  @override
  Future<CompanyPage> getCompanies({
    int pageNumber = 1,
    int pageSize = 20,
    String? search,
    int? status = CompanyDataStatus.active,
    bool? isLocked,
  }) async {
    statuses.add(status);
    locks.add(isLocked);
    final id = pageNumber == 1 ? 1 : 2;
    return CompanyPage(
      items: [
        CompanyResponse(
          id: id,
          code: 'company$id',
          name: 'Company $id',
          email: 'company$id@example.com',
          phone: '090000000$id',
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
          countUser: 0,
          plan: CompanyPlan.free,
          isLocked: false,
          note: null,
          logo: null,
          expiredDate: null,
        ),
      ],
      pageNumber: pageNumber,
      pageSize: pageSize,
      totalCount: 2,
      totalPages: 2,
    );
  }

  @override
  Future<CompanyResponse> getCompany(int id) => throw UnimplementedError();

  @override
  Future<CompanyResponse> createCompany(CompanyUpsertRequest request) =>
      throw UnimplementedError();

  @override
  Future<CompanyResponse> updateCompany(int id, CompanyUpsertRequest request) =>
      throw UnimplementedError();

  @override
  Future<CompanyResponse> setCompanyLock(int id, bool isLocked) =>
      throw UnimplementedError();

  @override
  Future<CompanyResponse> setCompanyExpiration(int id, DateTime? expiredDate) =>
      throw UnimplementedError();

  @override
  Future<CompanyResponse> uploadCompanyLogo({
    required int id,
    required List<int> bytes,
    required String fileName,
    required String contentType,
  }) => throw UnimplementedError();

  @override
  Future<Uint8List> getCompanyLogo(int id) => throw UnimplementedError();

  @override
  Future<CompanyResponse> deleteCompany(int id) => throw UnimplementedError();

  @override
  Future<CompanyResponse> restoreCompany(int id) => throw UnimplementedError();
}

void main() {
  test('loads first page, appends next page and preserves filters', () async {
    final repository = _FakeCompanyRepository();
    final controller = CompaniesController(repository);
    controller.setStatus(CompanyDataStatus.deleted);
    controller.setLocked(true);

    await controller.load();
    await controller.loadMore();

    expect(controller.items.map((item) => item.id), [1, 2]);
    expect(controller.totalCount, 2);
    expect(repository.statuses, [
      CompanyDataStatus.deleted,
      CompanyDataStatus.deleted,
    ]);
    expect(repository.locks, [true, true]);

    controller.dispose();
  });
}
