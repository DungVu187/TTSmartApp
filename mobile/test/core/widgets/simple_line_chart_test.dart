import 'package:flutter_test/flutter_test.dart';
import 'package:ttsmart_mobile/core/widgets/simple_line_chart.dart';

void main() {
  test('trục Y làm tròn 1470 lên 1600 với bước 200', () {
    final scale = calculateLineChartAxisScale(const <double>[790, 1470, 720]);

    expect(scale.maximum, 1600);
    expect(scale.step, 200);
    expect(scale.divisions, 8);
  });

  test('trục Y giữ đỉnh 12000 khi chia đẹp theo bước 2000', () {
    final scale = calculateLineChartAxisScale(const <double>[
      4200,
      12000,
      9800,
    ]);

    expect(scale.maximum, 12000);
    expect(scale.step, 2000);
    expect(scale.divisions, 6);
  });

  test('trục Y tiếp tục tăng khi dữ liệu vượt mốc hiện tại', () {
    final scale = calculateLineChartAxisScale(const <double>[12001]);

    expect(scale.maximum, 14000);
    expect(scale.step, 2000);
    expect(scale.divisions, 7);
  });
}
