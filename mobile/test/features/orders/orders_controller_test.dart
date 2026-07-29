import 'package:flutter_test/flutter_test.dart';
import 'package:ttsmart_mobile/core/models/data_scope.dart';
import 'package:ttsmart_mobile/core/models/time_range_preset.dart';
import 'package:ttsmart_mobile/features/orders/data/models/order_models.dart';
import 'package:ttsmart_mobile/features/orders/data/repositories/orders_repository.dart';
import 'package:ttsmart_mobile/features/orders/presentation/controllers/orders_controller.dart';

class _FakeOrdersRepository implements OrdersRepository {
  static const scope = DataScopeOption(
    keyName: 'company',
    label: 'Toàn công ty',
    type: DataScopeType.company,
  );

  final queries = <OrdersQuery>[];

  @override
  Future<List<DataScopeOption>> getAvailableScopes() async => const [scope];

  @override
  Future<OrderDetails> getOrderDetails(String id) async => OrderDetails(
    summary: OrderSummary(
      id: id,
      code: 'DH-TEST',
      customerName: 'Khách hàng thử nghiệm',
      stationName: 'Trạm A',
      concreteGrade: 'M300',
      quantity: 10,
      deliveredQuantity: 0,
      scheduledAt: DateTime.utc(2026, 7, 27),
      status: OrderStatus.pending,
    ),
    deliveryAddress: 'Địa chỉ thử nghiệm',
    contactName: 'Người liên hệ',
    contactPhone: '0000000000',
    slump: '12 ± 2 cm',
    pumpType: 'Bơm cần',
    note: '',
  );

  @override
  Future<List<OrderSummary>> searchOrders(OrdersQuery query) async {
    queries.add(query);
    return const <OrderSummary>[];
  }
}

void main() {
  test('OrdersController debounce tìm kiếm trước khi gọi repository', () async {
    final repository = _FakeOrdersRepository();
    final controller = OrdersController(repository);
    await controller.initialize();

    controller.updateSearch('DH-1');
    controller.updateSearch('DH-10');
    await Future<void>.delayed(const Duration(milliseconds: 450));

    expect(repository.queries.length, 2);
    expect(repository.queries.last.searchText, 'DH-10');
    expect(repository.queries.last.timeRange, TimeRangePreset.today);

    controller.dispose();
  });
}
