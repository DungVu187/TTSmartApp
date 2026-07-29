import '../../../../core/models/data_scope.dart';
import '../models/order_models.dart';

abstract interface class OrdersRepository {
  Future<List<DataScopeOption>> getAvailableScopes();

  Future<List<OrderSummary>> searchOrders(OrdersQuery query);

  Future<OrderDetails> getOrderDetails(String id);
}

class MockOrdersRepository implements OrdersRepository {
  MockOrdersRepository() : _orders = _createOrders();

  static const _scopes = <DataScopeOption>[
    DataScopeOption(
      keyName: 'all-company',
      label: 'Toàn công ty',
      type: DataScopeType.company,
    ),
    DataScopeOption(
      keyName: 'station-tan-phu',
      label: 'Trạm Tân Phú',
      type: DataScopeType.station,
    ),
    DataScopeOption(
      keyName: 'station-binh-chanh',
      label: 'Trạm Bình Chánh',
      type: DataScopeType.station,
    ),
  ];

  final List<OrderSummary> _orders;

  @override
  Future<List<DataScopeOption>> getAvailableScopes() async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    return _scopes;
  }

  @override
  Future<List<OrderSummary>> searchOrders(OrdersQuery query) async {
    await Future<void>.delayed(const Duration(milliseconds: 220));
    final keyword = query.searchText.trim().toLowerCase();
    final stationName = query.scope.type == DataScopeType.station
        ? query.scope.label.toLowerCase()
        : null;
    return _orders
        .where((order) {
          final matchesKeyword =
              keyword.isEmpty ||
              order.code.toLowerCase().contains(keyword) ||
              order.customerName.toLowerCase().contains(keyword) ||
              order.concreteGrade.toLowerCase().contains(keyword);
          final matchesStatus =
              query.status == null || order.status == query.status;
          final matchesScope =
              stationName == null ||
              order.stationName.toLowerCase() == stationName;
          return matchesKeyword && matchesStatus && matchesScope;
        })
        .toList(growable: false);
  }

  @override
  Future<OrderDetails> getOrderDetails(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    final summary = _orders.firstWhere((order) => order.id == id);
    return OrderDetails(
      summary: summary,
      deliveryAddress: 'Khu công nghiệp Tân Bình, TP. Hồ Chí Minh',
      contactName: 'Nguyễn Minh Khang',
      contactPhone: '0900 000 000',
      slump: '12 ± 2 cm',
      pumpType: 'Bơm cần',
      note: 'Dữ liệu minh họa. Nội dung chính thức sẽ lấy từ API đơn hàng.',
    );
  }

  static List<OrderSummary> _createOrders() {
    final today = DateTime.now();
    DateTime at(int hour, int minute) =>
        DateTime(today.year, today.month, today.day, hour, minute);

    return <OrderSummary>[
      OrderSummary(
        id: '1028',
        code: 'DH-1028',
        customerName: 'Công ty Xây dựng An Phát',
        stationName: 'Trạm Tân Phú',
        concreteGrade: 'M300',
        quantity: 42,
        deliveredQuantity: 42,
        scheduledAt: at(8, 30),
        status: OrderStatus.completed,
      ),
      OrderSummary(
        id: '1031',
        code: 'DH-1031',
        customerName: 'Công ty Thành Công',
        stationName: 'Trạm Bình Chánh',
        concreteGrade: 'M300',
        quantity: 65,
        deliveredQuantity: 28,
        scheduledAt: at(9, 15),
        status: OrderStatus.mixing,
      ),
      OrderSummary(
        id: '1032',
        code: 'DH-1032',
        customerName: 'Dự án Green Residence',
        stationName: 'Trạm Tân Phú',
        concreteGrade: 'M250',
        quantity: 80,
        deliveredQuantity: 36,
        scheduledAt: at(10, 0),
        status: OrderStatus.delivering,
      ),
      OrderSummary(
        id: '1034',
        code: 'DH-1034',
        customerName: 'Công ty Minh Long',
        stationName: 'Trạm Bình Chánh',
        concreteGrade: 'M350',
        quantity: 56,
        deliveredQuantity: 0,
        scheduledAt: at(13, 30),
        status: OrderStatus.pending,
      ),
      OrderSummary(
        id: '1035',
        code: 'DH-1035',
        customerName: 'Dự án Riverside',
        stationName: 'Trạm Tân Phú',
        concreteGrade: 'M400',
        quantity: 120,
        deliveredQuantity: 18,
        scheduledAt: at(14, 0),
        status: OrderStatus.delivering,
      ),
      OrderSummary(
        id: '1036',
        code: 'DH-1036',
        customerName: 'Công ty Đông Nam',
        stationName: 'Trạm Bình Chánh',
        concreteGrade: 'M200',
        quantity: 34,
        deliveredQuantity: 0,
        scheduledAt: at(15, 15),
        status: OrderStatus.canceled,
      ),
    ];
  }
}
