import 'package:flutter/material.dart';

enum MoreModuleGroup { operations, organization, administration }

abstract final class PreviewModuleKeys {
  static const String mixDesign = 'preview.mix-design';
  static const String vehicleScale = 'preview.vehicle-scale';
  static const String fleet = 'preview.fleet';
  static const String camera = 'preview.camera';
  static const String materials = 'preview.materials';
  static const String stations = 'preview.stations';
}

class MoreModuleDefinition {
  const MoreModuleDefinition({
    required this.keyName,
    required this.group,
    required this.label,
    required this.description,
    required this.icon,
  });

  final String keyName;
  final MoreModuleGroup group;
  final String label;
  final String description;
  final IconData icon;
}

const previewModules = <MoreModuleDefinition>[
  MoreModuleDefinition(
    keyName: PreviewModuleKeys.mixDesign,
    group: MoreModuleGroup.operations,
    label: 'Cấp phối',
    description: 'Theo dõi và quản lý thông tin cấp phối bê tông.',
    icon: Icons.science_outlined,
  ),
  MoreModuleDefinition(
    keyName: PreviewModuleKeys.vehicleScale,
    group: MoreModuleGroup.operations,
    label: 'Cân ô tô',
    description: 'Theo dõi lượt cân và khối lượng phương tiện.',
    icon: Icons.scale_outlined,
  ),
  MoreModuleDefinition(
    keyName: PreviewModuleKeys.fleet,
    group: MoreModuleGroup.operations,
    label: 'Quản lý xe',
    description: 'Theo dõi phương tiện và trạng thái vận hành.',
    icon: Icons.local_shipping_outlined,
  ),
  MoreModuleDefinition(
    keyName: PreviewModuleKeys.camera,
    group: MoreModuleGroup.operations,
    label: 'Camera',
    description: 'Truy cập khu vực giám sát camera theo quyền.',
    icon: Icons.videocam_outlined,
  ),
  MoreModuleDefinition(
    keyName: PreviewModuleKeys.materials,
    group: MoreModuleGroup.operations,
    label: 'Vật liệu',
    description: 'Theo dõi nguyên vật liệu và tồn kho vận hành.',
    icon: Icons.inventory_2_outlined,
  ),
  MoreModuleDefinition(
    keyName: PreviewModuleKeys.stations,
    group: MoreModuleGroup.organization,
    label: 'Trạm',
    description: 'Thông tin các trạm thuộc phạm vi được cấp.',
    icon: Icons.factory_outlined,
  ),
];
