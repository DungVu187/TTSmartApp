import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ttsmart_mobile/core/network/api_client.dart';
import 'package:ttsmart_mobile/features/company_management/data/models/company_models.dart';
import 'package:ttsmart_mobile/features/company_management/data/repositories/company_repository.dart';

http.Response jsonResponse(Object value, [int statusCode = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(value)), statusCode);

Map<String, Object?> companyResponseJson({int id = 12}) => <String, Object?>{
  'id': id,
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
  'createdAtUtc': null,
  'updatedAtUtc': null,
  'userId': null,
  'status': 1,
  'isActive': true,
  'countUser': 0,
  'active': 0,
  'isLocked': false,
  'note': null,
  'logo': null,
  'expiredDate': null,
};

void main() {
  test(
    'getCompanies sends pagination, search, status and lock filters',
    () async {
      final client = ApiClient(
        baseUri: Uri.parse('http://localhost:5052'),
        timeout: const Duration(seconds: 1),
        httpClient: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/api/companies');
          expect(request.url.queryParameters, {
            'pageNumber': '2',
            'pageSize': '20',
            'search': 'lamson',
            'status': '99',
            'isLocked': 'true',
          });
          return jsonResponse({
            'items': [companyResponseJson()],
            'pageNumber': 2,
            'pageSize': 20,
            'totalCount': 21,
            'totalPages': 2,
          });
        }),
      )..accessToken = 'token';
      final repository = ApiCompanyRepository(client);

      final page = await repository.getCompanies(
        pageNumber: 2,
        search: ' lamson ',
        status: CompanyDataStatus.deleted,
        isLocked: true,
      );

      expect(page.items.single.id, 12);
      expect(page.totalPages, 2);
    },
  );

  test('createCompany sends API field names and active plan value', () async {
    final client = ApiClient(
      baseUri: Uri.parse('http://localhost:5052'),
      timeout: const Duration(seconds: 1),
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/companies');
        expect(jsonDecode(request.body), {
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
          'countUser': 10,
          'active': 1,
          'note': null,
        });
        return jsonResponse(companyResponseJson(), 201);
      }),
    )..accessToken = 'token';
    final repository = ApiCompanyRepository(client);

    final company = await repository.createCompany(
      const CompanyUpsertRequest(
        code: 'lamson',
        name: 'Công ty Lam Sơn',
        email: 'lamson@example.com',
        phone: '0900000000',
        countUser: 10,
        plan: CompanyPlan.paid,
      ),
    );

    expect(company.id, 12);
  });

  test('setCompanyExpiration sends a date-only payload', () async {
    final client = ApiClient(
      baseUri: Uri.parse('http://localhost:5052'),
      timeout: const Duration(seconds: 1),
      httpClient: MockClient((request) async {
        expect(request.method, 'PUT');
        expect(request.url.path, '/api/companies/12/expiration');
        expect(jsonDecode(request.body), {'expiredDate': '2027-01-01'});
        return jsonResponse(companyResponseJson());
      }),
    )..accessToken = 'token';
    final repository = ApiCompanyRepository(client);

    await repository.setCompanyExpiration(12, DateTime(2027, 1, 1));
  });
}
