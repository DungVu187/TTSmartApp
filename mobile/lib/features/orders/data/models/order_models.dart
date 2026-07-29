import '../../../../core/models/data_scope.dart';
import '../../../../core/models/time_range_preset.dart';

enum OrderStatus { pending, mixing, delivering, completed, canceled }

extension OrderStatusLabel on OrderStatus {
  String get label => switch (this) {
    OrderStatus.pending => 'Chờ xử lý',
    OrderStatus.mixing => 'Đang trộn',
    OrderStatus.delivering => 'Đang giao',
    OrderStatus.completed => 'Hoàn thành',
    OrderStatus.canceled => 'Đã hủy',
  };
}

class OrderSummary {
  const OrderSummary({
    required this.id,
    required this.code,
    required this.customerName,
    required this.stationName,
    required this.concreteGrade,
    required this.quantity,
    required this.deliveredQuantity,
    required this.scheduledAt,
    required this.status,
  });

  final String id;
  final String code;
  final String customerName;
  final String stationName;
  final String concreteGrade;
  final double quantity;
  final double deliveredQuantity;
  final DateTime scheduledAt;
  final OrderStatus status;
}

class OrderDetails {
  const OrderDetails({
    required this.summary,
    required this.deliveryAddress,
    required this.contactName,
    required this.contactPhone,
    required this.slump,
    required this.pumpType,
    required this.note,
  });

  final OrderSummary summary;
  final String deliveryAddress;
  final String contactName;
  final String contactPhone;
  final String slump;
  final String pumpType;
  final String note;
}

class OrdersQuery {
  const OrdersQuery({
    required this.searchText,
    required this.scope,
    required this.timeRange,
    required this.status,
  });

  final String searchText;
  final DataScopeOption scope;
  final TimeRangePreset timeRange;
  final OrderStatus? status;
}
