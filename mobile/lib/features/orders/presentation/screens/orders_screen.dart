import 'package:flutter/material.dart';

import '../../../../core/models/data_scope.dart';
import '../../../../core/models/time_range_preset.dart';
import '../../../../core/widgets/app_content.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/error_panel.dart';
import '../../data/models/order_models.dart';
import '../controllers/orders_controller.dart';
import '../widgets/order_widgets.dart';
import 'order_detail_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key, required this.controller});

  final OrdersController controller;

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: widget.controller.searchText,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.initialize();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openFilters() async {
    final currentScope = widget.controller.selectedScope;
    if (currentScope == null) return;
    var scope = currentScope;
    var timeRange = widget.controller.timeRange;
    var status = widget.controller.status;

    final applied = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              0,
              16,
              20 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lọc đơn hàng',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 18),
                DropdownButtonFormField<DataScopeOption>(
                  initialValue: scope,
                  decoration: const InputDecoration(
                    labelText: 'Công ty hoặc trạm',
                    prefixIcon: Icon(Icons.factory_outlined),
                  ),
                  items: widget.controller.scopes
                      .map(
                        (item) => DropdownMenuItem<DataScopeOption>(
                          value: item,
                          child: Text(item.label),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value != null) setModalState(() => scope = value);
                  },
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<TimeRangePreset>(
                  initialValue: timeRange,
                  decoration: const InputDecoration(
                    labelText: 'Khoảng thời gian',
                    prefixIcon: Icon(Icons.date_range_outlined),
                  ),
                  items: TimeRangePreset.values
                      .map(
                        (item) => DropdownMenuItem<TimeRangePreset>(
                          value: item,
                          child: Text(item.label),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value != null) setModalState(() => timeRange = value);
                  },
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<OrderStatus?>(
                  initialValue: status,
                  decoration: const InputDecoration(
                    labelText: 'Trạng thái',
                    prefixIcon: Icon(Icons.tune_outlined),
                  ),
                  items: <DropdownMenuItem<OrderStatus?>>[
                    const DropdownMenuItem<OrderStatus?>(
                      child: Text('Tất cả trạng thái'),
                    ),
                    ...OrderStatus.values.map(
                      (item) => DropdownMenuItem<OrderStatus?>(
                        value: item,
                        child: Text(item.label),
                      ),
                    ),
                  ],
                  onChanged: (value) => setModalState(() => status = value),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          scope = widget.controller.scopes.first;
                          timeRange = TimeRangePreset.today;
                          status = null;
                          setModalState(() {});
                        },
                        child: const Text('Đặt lại'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Áp dụng'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (applied == true) {
      await widget.controller.applyFilters(
        scope: scope,
        timeRange: timeRange,
        status: status,
      );
    }
  }

  void _openOrder(OrderSummary order) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OrderDetailScreen(
          order: order,
          loadDetails: widget.controller.getDetails,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) => RefreshIndicator(
        onRefresh: widget.controller.refresh,
        child: ListView(
          key: const PageStorageKey<String>('orders-scroll'),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            AppContent(
              maxWidth: 920,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppSectionHeader(
                    title: 'Đơn hàng',
                    subtitle: 'Tra cứu và theo dõi tiến độ giao bê tông',
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          textInputAction: TextInputAction.search,
                          onChanged: widget.controller.updateSearch,
                          decoration: const InputDecoration(
                            hintText: 'Mã đơn, khách hàng hoặc mác bê tông',
                            prefixIcon: Icon(Icons.search),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Badge(
                        isLabelVisible: widget.controller.activeFilterCount > 0,
                        label: Text('${widget.controller.activeFilterCount}'),
                        child: IconButton.filledTonal(
                          tooltip: 'Lọc đơn hàng',
                          onPressed: widget.controller.scopes.isEmpty
                              ? null
                              : _openFilters,
                          icon: const Icon(Icons.tune),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.controller.selectedScope?.label ??
                              'Đang tải phạm vi...',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text(
                        '${widget.controller.orders.length} đơn',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (widget.controller.errorMessage != null) ...[
                    ErrorPanel(
                      message: widget.controller.errorMessage!,
                      onRetry: widget.controller.refresh,
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (widget.controller.isLoading &&
                      widget.controller.orders.isEmpty)
                    const SizedBox(
                      height: 360,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (widget.controller.orders.isEmpty)
                    AppEmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: 'Không tìm thấy đơn hàng',
                      message:
                          'Thử thay đổi từ khóa, phạm vi hoặc bộ lọc trạng thái.',
                      action: OutlinedButton.icon(
                        onPressed: widget.controller.clearFilters,
                        icon: const Icon(Icons.filter_alt_off_outlined),
                        label: const Text('Xóa bộ lọc'),
                      ),
                    )
                  else
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = constraints.maxWidth >= 760 ? 2 : 1;
                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: widget.controller.orders.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                mainAxisExtent: 220,
                              ),
                          itemBuilder: (context, index) {
                            final order = widget.controller.orders[index];
                            return OrderCard(
                              order: order,
                              onTap: () => _openOrder(order),
                            );
                          },
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
