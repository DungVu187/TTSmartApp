import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ttsmart_mobile/features/company_management/data/models/company_models.dart';
import 'package:ttsmart_mobile/features/company_management/presentation/widgets/company_widgets.dart';

void main() {
  testWidgets('company card displays identity and separate states', (
    tester,
  ) async {
    const company = CompanyResponse(
      id: 12,
      code: 'lamson',
      name: 'Công ty Lam Sơn',
      email: 'lamson@example.com',
      phone: '0900000000',
      address: 'Hà Nội',
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
      countUser: 10,
      plan: CompanyPlan.paid,
      isLocked: true,
      note: null,
      logo: null,
      expiredDate: null,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: CompanyListCard(company: company)),
      ),
    );

    expect(find.text('Công ty Lam Sơn'), findsOneWidget);
    expect(find.text('lamson'), findsOneWidget);
    expect(find.text('Trả phí'), findsOneWidget);
    expect(find.text('Đang hoạt động'), findsOneWidget);
    expect(find.text('Đang khóa'), findsOneWidget);
  });
}
