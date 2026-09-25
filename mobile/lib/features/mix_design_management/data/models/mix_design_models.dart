import '../../../../core/network/json_helpers.dart';

class MixDesignStation {
  const MixDesignStation({required this.id, required this.name});

  factory MixDesignStation.fromJson(Object? value) {
    final json = requireJsonObject(value, 'trạm quản lý cấp phối');
    return MixDesignStation(
      id: requireInt(json, 'stationId'),
      name: optionalString(json, 'stationName'),
    );
  }

  final int id;
  final String? name;

  String get displayName {
    final normalized = name?.trim();
    return normalized == null || normalized.isEmpty ? 'Trạm #$id' : normalized;
  }
}

class MixDesignQuery {
  const MixDesignQuery({
    required this.stationId,
    required this.pageNumber,
    this.companyId,
  });

  final int? companyId;
  final int stationId;
  final int pageNumber;

  Map<String, Object?> toQueryParameters() => <String, Object?>{
    'companyId': companyId,
    'stationId': stationId,
    'pageNumber': pageNumber,
  };
}

class MixDesignItem {
  const MixDesignItem({
    required this.stt,
    required this.concreteGradeName,
    required this.strength,
    required this.maxAggregate,
    required this.slump,
    required this.sand1,
    required this.sand2,
    required this.stone1,
    required this.stone2,
    required this.stone3,
    required this.cement1,
    required this.cement2,
    required this.cement3,
    required this.cement4,
    required this.water,
    required this.sika,
    required this.tulog,
    required this.sikaroad,
    required this.bifi,
    this.materials = const <MixDesignMaterial>[],
  });

  factory MixDesignItem.fromJson(Object? value) {
    final json = requireJsonObject(value, 'dòng cấp phối');
    return MixDesignItem(
      stt: requireInt(json, 'stt'),
      concreteGradeName: optionalString(json, 'concreteGradeName'),
      strength: requireInt(json, 'strength'),
      maxAggregate: requireInt(json, 'maxAggregate'),
      slump: requireString(json, 'slump'),
      sand1: _requireNumber(json, 'sand1'),
      sand2: _requireNumber(json, 'sand2'),
      stone1: _requireNumber(json, 'stone1'),
      stone2: _requireNumber(json, 'stone2'),
      stone3: _requireNumber(json, 'stone3'),
      cement1: _requireNumber(json, 'cement1'),
      cement2: _requireNumber(json, 'cement2'),
      cement3: _requireNumber(json, 'cement3'),
      cement4: _requireNumber(json, 'cement4'),
      water: _requireNumber(json, 'water'),
      sika: _requireNumber(json, 'sika'),
      tulog: _requireNumber(json, 'tulog'),
      sikaroad: _requireNumber(json, 'sikaroad'),
      bifi: _requireNumber(json, 'bifi'),
      materials: json['materials'] == null
          ? const <MixDesignMaterial>[]
          : requireJsonList(
              json['materials'],
              'vật liệu cấp phối',
            ).map(MixDesignMaterial.fromJson).toList(growable: false),
    );
  }

  final int stt;
  final String? concreteGradeName;
  final int strength;
  final int maxAggregate;
  final String slump;
  final double sand1;
  final double sand2;
  final double stone1;
  final double stone2;
  final double stone3;
  final double cement1;
  final double cement2;
  final double cement3;
  final double cement4;
  final double water;
  final double sika;
  final double tulog;
  final double sikaroad;
  final double bifi;
  final List<MixDesignMaterial> materials;

  double quantityForColumn(String columnKey) {
    for (final material in materials) {
      if (material.columnKey == columnKey) return material.quantity;
    }
    return 0;
  }

  String get displayConcreteGradeName {
    final normalized = concreteGradeName?.trim();
    return normalized == null || normalized.isEmpty
        ? 'Chưa đặt tên'
        : normalized;
  }
}

class MixDesignMaterialColumn {
  const MixDesignMaterialColumn({
    required this.materialSlotId,
    required this.slotNumber,
    required this.materialName,
    required this.category,
    required this.categoryCode,
    required this.typePosition,
    required this.columnKey,
  });

  factory MixDesignMaterialColumn.fromJson(Object? value) {
    final json = requireJsonObject(value, 'cột vật liệu');
    return MixDesignMaterialColumn(
      materialSlotId: requireInt(json, 'materialSlotId'),
      slotNumber: requireInt(json, 'slotNumber'),
      materialName: requireString(json, 'materialName'),
      category: requireString(json, 'category'),
      categoryCode: requireString(json, 'categoryCode'),
      typePosition: requireInt(json, 'typePosition'),
      columnKey: requireString(json, 'columnKey'),
    );
  }

  final int materialSlotId;
  final int slotNumber;
  final String materialName;
  final String category;
  final String categoryCode;
  final int typePosition;
  final String columnKey;
}

class MixDesignMaterial {
  const MixDesignMaterial({
    required this.materialSlotId,
    required this.slotNumber,
    required this.columnKey,
    required this.quantity,
  });

  factory MixDesignMaterial.fromJson(Object? value) {
    final json = requireJsonObject(value, 'giá trị vật liệu');
    return MixDesignMaterial(
      materialSlotId: requireInt(json, 'materialSlotId'),
      slotNumber: requireInt(json, 'slotNumber'),
      columnKey: requireString(json, 'columnKey'),
      quantity: _requireNumber(json, 'quantity'),
    );
  }

  final int materialSlotId;
  final int slotNumber;
  final String columnKey;
  final double quantity;
}

class MixDesignPage {
  const MixDesignPage({
    required this.items,
    required this.pageNumber,
    required this.pageSize,
    required this.totalCount,
    required this.totalPages,
    this.materialColumns = const <MixDesignMaterialColumn>[],
  });

  factory MixDesignPage.fromJson(Object? value) {
    final json = requireJsonObject(value, 'trang cấp phối');
    return MixDesignPage(
      items: requireJsonList(
        json['items'],
        'items cấp phối',
      ).map(MixDesignItem.fromJson).toList(growable: false),
      pageNumber: requireInt(json, 'pageNumber'),
      pageSize: requireInt(json, 'pageSize'),
      totalCount: requireInt(json, 'totalCount'),
      totalPages: requireInt(json, 'totalPages'),
      materialColumns: json['materialColumns'] == null
          ? const <MixDesignMaterialColumn>[]
          : requireJsonList(
              json['materialColumns'],
              'cột vật liệu',
            ).map(MixDesignMaterialColumn.fromJson).toList(growable: false),
    );
  }

  final List<MixDesignItem> items;
  final int pageNumber;
  final int pageSize;
  final int totalCount;
  final int totalPages;
  final List<MixDesignMaterialColumn> materialColumns;
}

double _requireNumber(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is num && value.isFinite) return value.toDouble();
  throw FormatException('$key phải là số.');
}
