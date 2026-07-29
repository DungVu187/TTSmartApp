import '../../../../core/network/json_helpers.dart';

abstract final class AccessStatus {
  static const int active = 1;
  static const int inactive = 99;

  static bool isSupported(int? value) =>
      value == null || value == active || value == inactive;
}

class PagedResponse<T> {
  const PagedResponse({
    required this.items,
    required this.pageNumber,
    required this.pageSize,
    required this.totalCount,
    required this.totalPages,
  });

  factory PagedResponse.fromJson(
    Object? value,
    T Function(Object? value) parseItem,
  ) {
    final json = requireJsonObject(value, 'response phân trang');
    return PagedResponse(
      items: requireJsonList(
        json['items'],
        'items',
      ).map(parseItem).toList(growable: false),
      pageNumber: requireInt(json, 'pageNumber'),
      pageSize: requireInt(json, 'pageSize'),
      totalCount: requireInt(json, 'totalCount'),
      totalPages: requireInt(json, 'totalPages'),
    );
  }

  final List<T> items;
  final int pageNumber;
  final int pageSize;
  final int totalCount;
  final int totalPages;
}
