import '../../../../core/network/json_helpers.dart';

abstract final class AccessFunctionCodes {
  static const String users = 'QLND';
  static const String roles = 'QLQ';
  static const String functions = 'QLCN';
  static const String companies = 'QLCT';
  static const String branches = 'QLTT';
  static const String orderReports = 'BCDH';
  static const String orderStatistics = 'TKĐH';
  static const String mixDesigns = 'QLCP';
  static const String weighStations = 'TKTC';
}

enum AccessPermission {
  view,
  create,
  update,
  delete,
  importData,
  exportData,
  print,
  other,
  dSach,
}

class PermissionDefinition {
  const PermissionDefinition({
    required this.permission,
    required this.label,
    required this.index,
  });

  final AccessPermission permission;
  final String label;
  final int index;
}

class PermissionSet {
  const PermissionSet({
    required this.view,
    required this.create,
    required this.update,
    required this.delete,
    required this.importData,
    required this.exportData,
    required this.print,
    required this.other,
    required this.dSach,
  });

  const PermissionSet.none()
    : view = false,
      create = false,
      update = false,
      delete = false,
      importData = false,
      exportData = false,
      print = false,
      other = false,
      dSach = false;

  const PermissionSet.full()
    : view = true,
      create = true,
      update = true,
      delete = true,
      importData = true,
      exportData = true,
      print = true,
      other = true,
      dSach = true;

  factory PermissionSet.fromJson(Object? value) {
    if (value == null) {
      return const PermissionSet.none();
    }
    final json = requireJsonObject(value, 'permissions');
    return PermissionSet(
      view: json['view'] == true,
      create: json['create'] == true,
      update: json['update'] == true,
      delete: json['delete'] == true,
      importData: json['import'] == true,
      exportData: json['export'] == true,
      print: json['print'] == true,
      other: json['other'] == true,
      dSach: json['dSach'] == true,
    );
  }

  factory PermissionSet.fromActiveKey(String? value) {
    if (!isValidActiveKey(value)) {
      return const PermissionSet.none();
    }
    final activeKey = value!;
    return PermissionSet(
      view: activeKey[0] == '1',
      create: activeKey[1] == '1',
      update: activeKey[2] == '1',
      delete: activeKey[3] == '1',
      importData: activeKey[4] == '1',
      exportData: activeKey[5] == '1',
      print: activeKey[6] == '1',
      other: activeKey[7] == '1',
      dSach: activeKey[8] == '1',
    );
  }

  factory PermissionSet.fromContract({
    required Object? activeKey,
    required Object? permissions,
  }) {
    if (activeKey is! String || !isValidActiveKey(activeKey)) {
      return const PermissionSet.none();
    }
    final fromActiveKey = PermissionSet.fromActiveKey(activeKey);
    final fromResponse = PermissionSet.fromJson(permissions);
    return fromResponse.activeKey == fromActiveKey.activeKey
        ? fromResponse
        : fromActiveKey;
  }

  static const int activeKeyLength = 9;
  static const String emptyActiveKey = '000000000';
  static const String fullActiveKey = '111111111';

  static const List<PermissionDefinition> definitions = <PermissionDefinition>[
    PermissionDefinition(
      permission: AccessPermission.view,
      label: 'Xem',
      index: 0,
    ),
    PermissionDefinition(
      permission: AccessPermission.create,
      label: 'Tạo mới',
      index: 1,
    ),
    PermissionDefinition(
      permission: AccessPermission.update,
      label: 'Cập nhật',
      index: 2,
    ),
    PermissionDefinition(
      permission: AccessPermission.delete,
      label: 'Xóa',
      index: 3,
    ),
    PermissionDefinition(
      permission: AccessPermission.importData,
      label: 'Nhập',
      index: 4,
    ),
    PermissionDefinition(
      permission: AccessPermission.exportData,
      label: 'Xuất',
      index: 5,
    ),
    PermissionDefinition(
      permission: AccessPermission.print,
      label: 'In',
      index: 6,
    ),
    PermissionDefinition(
      permission: AccessPermission.other,
      label: 'Khác',
      index: 7,
    ),
    PermissionDefinition(
      permission: AccessPermission.dSach,
      label: 'D.Sách',
      index: 8,
    ),
  ];

  final bool view;
  final bool create;
  final bool update;
  final bool delete;
  final bool importData;
  final bool exportData;
  final bool print;
  final bool other;
  final bool dSach;

  bool get full => definitions.every((item) => allows(item.permission));

  bool get isEmpty => definitions.every((item) => !allows(item.permission));

  String get activeKey =>
      definitions.map((item) => allows(item.permission) ? '1' : '0').join();

  bool allows(AccessPermission permission) => switch (permission) {
    AccessPermission.view => view,
    AccessPermission.create => create,
    AccessPermission.update => update,
    AccessPermission.delete => delete,
    AccessPermission.importData => importData,
    AccessPermission.exportData => exportData,
    AccessPermission.print => print,
    AccessPermission.other => other,
    AccessPermission.dSach => dSach,
  };

  PermissionSet withPermission(AccessPermission permission, bool enabled) =>
      PermissionSet(
        view: permission == AccessPermission.view ? enabled : view,
        create: permission == AccessPermission.create ? enabled : create,
        update: permission == AccessPermission.update ? enabled : update,
        delete: permission == AccessPermission.delete ? enabled : delete,
        importData: permission == AccessPermission.importData
            ? enabled
            : importData,
        exportData: permission == AccessPermission.exportData
            ? enabled
            : exportData,
        print: permission == AccessPermission.print ? enabled : print,
        other: permission == AccessPermission.other ? enabled : other,
        dSach: permission == AccessPermission.dSach ? enabled : dSach,
      );

  PermissionSet withFull(bool enabled) =>
      enabled ? const PermissionSet.full() : const PermissionSet.none();

  static bool isValidActiveKey(String? value) =>
      value != null && RegExp(r'^[01]{9}$').hasMatch(value);

  static String normalizeActiveKey(String? value) =>
      isValidActiveKey(value) ? value! : emptyActiveKey;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PermissionSet && other.activeKey == activeKey;

  @override
  int get hashCode => activeKey.hashCode;
}
