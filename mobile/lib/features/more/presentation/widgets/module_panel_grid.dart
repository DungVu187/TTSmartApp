import 'package:flutter/material.dart';

class ModulePanelItem {
  const ModulePanelItem({
    required this.label,
    required this.icon,
    required this.accent,
    required this.backgroundColor,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color accent;
  final Color backgroundColor;
  final VoidCallback onTap;
}

class ModulePanelGrid extends StatelessWidget {
  const ModulePanelGrid({
    super.key,
    required this.items,
    required this.compactColumnCount,
  }) : assert(compactColumnCount > 0);

  final List<ModulePanelItem> items;
  final int compactColumnCount;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return GridView.builder(
      key: const ValueKey<String>('module-panel-grid-scroll'),
      primary: false,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      itemCount: items.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: compactColumnCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        mainAxisExtent: 76,
      ),
      itemBuilder: (context, index) =>
          _ModulePanelTile(index: index, item: items[index]),
    );
  }
}

class _ModulePanelTile extends StatelessWidget {
  const _ModulePanelTile({required this.index, required this.item});

  final int index;
  final ModulePanelItem item;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: item.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey<String>('module-panel-tile-$index'),
          borderRadius: BorderRadius.circular(12),
          onTap: item.onTap,
          child: Column(
            children: [
              Container(
                key: ValueKey<String>('module-panel-icon-background-$index'),
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: item.backgroundColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(item.icon, size: 18, color: item.accent),
              ),
              const SizedBox(height: 6),
              Text(
                item.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF1D1F2C),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
