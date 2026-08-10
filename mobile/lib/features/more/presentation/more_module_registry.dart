import 'package:flutter/material.dart';

enum MoreModuleGroup { operations, organization, administration }

abstract final class PreviewModuleKeys {
  static const String materials = 'preview.materials';
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
    keyName: PreviewModuleKeys.materials,
    group: MoreModuleGroup.operations,
    label: 'Vật liệu',
    description: 'Theo dõi nguyên vật liệu và tồn kho vận hành.',
    icon: Icons.inventory_2_outlined,
  ),
];
