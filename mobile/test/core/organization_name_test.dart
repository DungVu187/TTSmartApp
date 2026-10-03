import 'package:flutter_test/flutter_test.dart';
import 'package:ttsmart_mobile/core/utils/organization_name.dart';

void main() {
  test('drops the legal form so the distinctive part shows in chips', () {
    const cases = {
      'Công ty CP Xây dựng Hòa Bình': 'Xây dựng Hòa Bình',
      'Công ty Cổ phần Đầu tư và Xây dựng Bê tông Thịnh Phát':
          'Đầu tư và Xây dựng Bê tông Thịnh Phát',
      'Cty TNHH Thương mại Minh Phát': 'Thương mại Minh Phát',
      'Công ty TNHH MTV Bê tông Sông Đáy': 'Bê tông Sông Đáy',
      'Công ty TNHH Một Thành Viên Vật liệu Ninh Bình': 'Vật liệu Ninh Bình',
      'CÔNG TY CỔ PHẦN BÊ TÔNG TTSMART': 'BÊ TÔNG TTSMART',
      'Công ty Xây lắp Sông Đà': 'Xây lắp Sông Đà',
      'Tổng công ty Xây dựng Hà Nội': 'Xây dựng Hà Nội',
      'Doanh nghiệp tư nhân Phú Cường': 'Phú Cường',
    };
    cases.forEach((input, expected) {
      expect(compactOrganizationName(input), expected, reason: input);
    });
  });

  test('leaves other labels alone', () {
    for (final label in [
      'Tất cả công ty',
      'Trạm Hà Nam',
      '25/09 – 25/09',
      'Công ty',
      'Công ty CP A',
    ]) {
      expect(compactOrganizationName(label), label);
    }
  });
}
