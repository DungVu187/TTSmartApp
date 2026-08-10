import 'package:flutter_test/flutter_test.dart';
import 'package:ttsmart_mobile/features/company_management/data/models/company_models.dart';
import 'package:ttsmart_mobile/features/company_management/data/repositories/company_repository.dart';
import 'package:ttsmart_mobile/features/mix_design_management/data/models/mix_design_models.dart';
import 'package:ttsmart_mobile/features/mix_design_management/data/repositories/mix_design_repository.dart';
import 'package:ttsmart_mobile/features/mix_design_management/presentation/controllers/mix_designs_controller.dart';

class _FakeMixDesignRepository implements MixDesignRepository {
  final stationCompanyIds = <int?>[];
  final queries = <MixDesignQuery>[];

  @override
  Future<List<MixDesignStation>> getStations({int? companyId}) async {
    stationCompanyIds.add(companyId);
    return const [MixDesignStation(id: 10, name: 'Trạm 10')];
  }

  @override
  Future<MixDesignPage> getMixDesigns(MixDesignQuery query) async {
    queries.add(query);
    return MixDesignPage(
      items: [_item((query.pageNumber - 1) * 10 + 1)],
      pageNumber: query.pageNumber,
      pageSize: 10,
      totalCount: 12,
      totalPages: 2,
    );
  }
}

class _FakeCompanyRepository implements CompanyRepository {
  int callCount = 0;

  @override
  Future<CompanyPage> getCompanies({
    int pageNumber = 1,
    int pageSize = 20,
    String? search,
    int? status = CompanyDataStatus.active,
    bool? isLocked,
  }) async {
    callCount++;
    return CompanyPage(
      items: [_company(3, 'Công ty Alpha')],
      pageNumber: 1,
      pageSize: pageSize,
      totalCount: 1,
      totalPages: 1,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('admin selects company before loading stations and searching', () async {
    final repository = _FakeMixDesignRepository();
    final companyRepository = _FakeCompanyRepository();
    final controller = MixDesignsController(
      repository,
      companyRepository,
      isAdmin: true,
      initialCompanyId: null,
    );

    await controller.initialize();
    expect(companyRepository.callCount, 1);
    expect(repository.stationCompanyIds, isEmpty);
    expect(controller.selectedCompanyId, isNull);

    await controller.search();
    expect(controller.validationMessage, 'Vui lòng chọn công ty');

    await controller.selectCompany(3);
    expect(repository.stationCompanyIds, [3]);
    expect(controller.selectedStationId, 10);

    await controller.search();
    expect(repository.queries.single.companyId, 3);
    expect(repository.queries.single.stationId, 10);
    expect(controller.result?.items.single.stt, 1);

    await controller.goToNextPage();
    expect(repository.queries.last.pageNumber, 2);
    expect(controller.result?.items.single.stt, 11);
    controller.dispose();
  });

  test('company-scoped user never sends companyId from mobile', () async {
    final repository = _FakeMixDesignRepository();
    final controller = MixDesignsController(
      repository,
      _FakeCompanyRepository(),
      isAdmin: false,
      initialCompanyId: 3,
    );

    await controller.initialize();
    expect(repository.stationCompanyIds, [null]);
    expect(controller.selectedCompanyId, 3);
    expect(controller.selectedStationId, 10);

    await controller.search();
    expect(repository.queries.single.companyId, isNull);
    expect(repository.queries.single.stationId, 10);
    controller.dispose();
  });
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

MixDesignItem _item(int stt) => MixDesignItem(
  stt: stt,
  concreteGradeName: 'M300',
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
);
