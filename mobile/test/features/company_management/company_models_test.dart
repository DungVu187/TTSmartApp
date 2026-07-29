import 'package:flutter_test/flutter_test.dart';
import 'package:ttsmart_mobile/features/company_management/data/models/company_models.dart';

Map<String, Object?> companyJson({int id = 12}) => <String, Object?>{
  'id': id,
  'code': 'lamson',
  'name': 'Công ty Lam Sơn',
  'email': 'lamson@example.com',
  'phone': '0900000000',
  'address': 'Hà Nội',
  'fax': null,
  'representative': 'Nguyễn Văn A',
  'contactName': 'Trần Văn B',
  'contactEmail': 'contact@example.com',
  'contactPhone': '0911111111',
  'createdAtUtc': '2026-07-28T08:00:00Z',
  'updatedAtUtc': null,
  'userId': 1,
  'status': 1,
  'isActive': true,
  'countUser': 25,
  'active': 1,
  'isLocked': false,
  'note': 'Ghi chú',
  'logo': 'logo.png',
  'expiredDate': '2027-01-01',
};

void main() {
  test('parses company response and separates plan/status fields', () {
    final company = CompanyResponse.fromJson(companyJson());

    expect(company.id, 12);
    expect(company.plan, CompanyPlan.paid);
    expect(company.isDeleted, isFalse);
    expect(company.isLocked, isFalse);
    expect(company.expiredDate, DateTime(2027, 1, 1));
    expect(company.displayName, 'Công ty Lam Sơn');
  });

  test('serializes upsert and expiration payloads using API contract', () {
    const request = CompanyUpsertRequest(
      code: 'lamson',
      name: 'Công ty Lam Sơn',
      email: 'lamson@example.com',
      phone: '0900000000',
      countUser: 25,
      plan: CompanyPlan.free,
    );

    expect(request.toJson(), {
      'code': 'lamson',
      'name': 'Công ty Lam Sơn',
      'email': 'lamson@example.com',
      'phone': '0900000000',
      'address': null,
      'fax': null,
      'representative': null,
      'contactName': null,
      'contactEmail': null,
      'contactPhone': null,
      'countUser': 25,
      'active': 0,
      'note': null,
    });
    expect(
      SetCompanyExpirationRequest(expiredDate: DateTime(2027, 1, 1)).toJson(),
      {'expiredDate': '2027-01-01'},
    );
  });

  test('rejects unsupported company plan', () {
    final json = companyJson()..['active'] = 2;
    expect(
      () => CompanyResponse.fromJson(json),
      throwsA(isA<FormatException>()),
    );
  });
}
