// Companies / stations sample data (Figma "Tổ chức" B01–B05).
import 'dart:typed_data';

import 'package:ttsmart_mobile/features/company_management/data/models/company_models.dart';
import 'package:ttsmart_mobile/features/company_management/data/repositories/company_repository.dart';
import 'package:ttsmart_mobile/features/station_management/data/models/station_models.dart';
import 'package:ttsmart_mobile/features/station_management/data/repositories/station_repository.dart';

CompanyResponse visualCompany(
  int id,
  String code,
  String name, {
  bool locked = false,
  int users = 12,
  CompanyPlan plan = CompanyPlan.paid,
  DateTime? expiredDate,
  String? phone = '0226 3851 234',
  String? email,
  String? address = 'Phủ Lý, Hà Nam',
  String? representative = 'Nguyễn Hoàng Nam',
  String? contactName,
  String? contactPhone,
  String? contactEmail,
  String? fax,
  String? note,
}) => CompanyResponse(
  id: id,
  code: code,
  name: name,
  email: email ?? 'lienhe@${code.toLowerCase()}.vn',
  phone: phone,
  address: address,
  fax: fax,
  representative: representative,
  contactName: contactName ?? representative,
  contactEmail: contactEmail ?? email ?? 'lienhe@${code.toLowerCase()}.vn',
  contactPhone: contactPhone ?? phone,
  createdAtUtc: DateTime.utc(2024, 3, 12, 2, 15),
  updatedAtUtc: DateTime.utc(2026, 9, 20, 7, 2),
  userId: 1,
  status: CompanyDataStatus.active,
  isActive: true,
  countUser: users,
  plan: plan,
  isLocked: locked,
  note: note,
  logo: null,
  expiredDate: expiredDate ?? DateTime(2027, 3, 31),
);

final visualCompanies = <CompanyResponse>[
  visualCompany(3, 'TTS', 'Công ty Cổ phần Đầu tư và Xây dựng Bê tông TTSmart Hà Nam', users: 24),
  visualCompany(
    4,
    'HBC',
    'Công ty CP Xây dựng Hòa Bình',
    users: 42,
    phone: '024 3825 6789',
    email: 'lienhe@hoabinh.vn',
    contactName: 'Trần Minh Quân',
    contactPhone: '0903 456 789',
    contactEmail: 'quan.tm@hoabinh.vn',
    address: '235 Võ Thị Sáu, Phường 7, Quận 3, TP. Hồ Chí Minh',
    representative: 'Lê Viết Hải',
    fax: '024 3825 6790',
    expiredDate: DateTime(2026, 12, 31),
    note: 'Khách hàng chiến lược, ưu tiên hỗ trợ khi đồng bộ dữ liệu trạm.',
  ),
  visualCompany(
    5,
    'MPT',
    'Cty TNHH Thương mại Minh Phát',
    users: 5,
    plan: CompanyPlan.free,
  ),
  visualCompany(6, 'BTHN', 'Công ty Bê tông Hà Nam', locked: true, users: 3),
  visualCompany(
    7,
    'VLNB',
    'Công ty CP Vật liệu Ninh Bình',
    plan: CompanyPlan.free,
  ),
  visualCompany(8, 'SDY', 'Công ty TNHH Sông Đáy'),
  visualCompany(9, 'PLX', 'Công ty CP Phủ Lý Xanh', plan: CompanyPlan.free),
];

class VisualCompanyRepository implements CompanyRepository {
  @override
  Future<CompanyPage> getCompanies({
    int pageNumber = 1,
    int pageSize = 20,
    String? search,
    int? status = CompanyDataStatus.active,
    bool? isLocked,
  }) async {
    final items = visualCompanies
        .where((company) => isLocked == null || company.isLocked == isLocked)
        .toList(growable: false);
    return CompanyPage(
      items: items,
      pageNumber: 1,
      pageSize: pageSize,
      totalCount: isLocked == null ? 24 : items.length,
      totalPages: 1,
    );
  }

  @override
  Future<CompanyResponse> getCompany(int id) async =>
      visualCompanies.firstWhere(
        (company) => company.id == id,
        orElse: () => visualCompanies[1],
      );

  @override
  Future<Uint8List> getCompanyLogo(int id) async => Uint8List(0);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _stations = <StationListItem>[
  StationListItem(
    id: 10,
    name: 'Trạm Hà Nam',
    phone: '0226 385 1234',
    typeTram: 1,
  ),
  StationListItem(
    id: 11,
    name: 'Trạm Ninh Bình',
    phone: '0229 387 5566',
    typeTram: 1,
  ),
  StationListItem(
    id: 20,
    name: 'Trạm cân Phủ Lý',
    phone: '0226 388 7788',
    typeTram: 2,
  ),
  StationListItem(
    id: 31,
    name: 'Trạm Long Biên',
    phone: '024 3872 1122',
    typeTram: 1,
  ),
  StationListItem(
    id: 21,
    name: 'Trạm cân Gia Lâm',
    phone: '024 3827 3344',
    typeTram: 2,
  ),
  StationListItem(
    id: 33,
    name: 'Trạm Đông Anh',
    phone: '024 3883 9900',
    typeTram: 1,
  ),
  StationListItem(
    id: 34,
    name: 'Trạm Hoài Đức',
    phone: '024 3366 2211',
    typeTram: 1,
  ),
];

class VisualStationRepository implements StationRepository {
  @override
  Future<StationPage> getStations({
    int pageNumber = 1,
    int pageSize = 20,
    String? search,
    int? companyId,
    int? typeTram,
    int? status = StationDataStatus.active,
  }) async => StationPage(
    items: _stations,
    pageNumber: 1,
    pageSize: pageSize,
    totalCount: 12,
    totalPages: 1,
  );

  @override
  Future<StationResponse> getStation(int id) async => StationResponse(
    id: id,
    companyId: 3,
    companyName: 'Công ty Cổ phần Đầu tư và Xây dựng Bê tông TTSmart Hà Nam',
    code: 'THN-01',
    name: 'Trạm Hà Nam',
    avatar: null,
    email: 'tramhanam@ttsmart.vn',
    phone: '0226 385 1234',
    address: 'Km 3, QL1A, Thanh Liêm, Hà Nam',
    typeTram: 1,
    username: 'tram.hanam',
    password: '********',
    pmqlXe: 'VietMap Fleet',
    qlCamera: 'Hikvision iVMS-4200',
    status: StationDataStatus.active,
    isActive: true,
    createdAtUtc: DateTime.utc(2025, 1, 5, 1, 30),
    updatedAtUtc: DateTime.utc(2026, 9, 18, 9, 45),
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
