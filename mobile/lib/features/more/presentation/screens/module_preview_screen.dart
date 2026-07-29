import 'package:flutter/material.dart';

import '../../../../core/widgets/app_content.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../more_module_registry.dart';

class ModulePreviewScreen extends StatelessWidget {
  const ModulePreviewScreen({super.key, required this.module});

  final MoreModuleDefinition module;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(module.label)),
      body: SafeArea(
        child: AppContent(
          maxWidth: 720,
          child: Card(
            child: AppEmptyState(
              icon: module.icon,
              title: '${module.label} đang được chuẩn bị',
              message:
                  '${module.description} Giao diện này là điểm nối sẵn để '
                  'bổ sung API và nghiệp vụ ở giai đoạn tiếp theo.',
            ),
          ),
        ),
      ),
    );
  }
}
