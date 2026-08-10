import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/app_scope.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/error_panel.dart';
import '../../../access_management/data/models/permission_models.dart';
import '../../../company_management/data/models/company_models.dart';
import '../../../company_management/data/repositories/company_repository.dart';
import '../../../company_management/presentation/widgets/company_autocomplete_field.dart';
import '../../../shell/presentation/screens/no_access_screen.dart';
import '../../data/models/station_models.dart';
import '../../data/repositories/station_repository.dart';
import '../controllers/stations_controller.dart';
import '../widgets/station_widgets.dart';
import 'station_detail_screen.dart';
import 'station_form_screen.dart';

class StationsScreen extends StatefulWidget {
  const StationsScreen({
    super.key,
    required this.repository,
    required this.companyRepository,
  });

  final StationRepository repository;
  final CompanyRepository companyRepository;

  @override
  State<StationsScreen> createState() => _StationsScreenState();
}

class _StationsScreenState extends State<StationsScreen> {
  late final StationsController _controller;
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  List<CompanyResponse> _companies = const <CompanyResponse>[];
  bool _isLoadingCompanies = false;
  ApiException? _companiesError;

  @override
  void initState() {
    super.initState();
    _controller = StationsController(widget.repository);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.load();
      if (_isAdmin) _loadCompanies();
    });
  }

  bool get _isAdmin => AppScope.read(context).hasRole('ADMIN');

  bool get _isCompanyRole => AppScope.read(context).hasRole('CONGTY');

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadCompanies() async {
    if (_isLoadingCompanies) return;
    setState(() {
      _isLoadingCompanies = true;
      _companiesError = null;
    });
    try {
      final result = <CompanyResponse>[];
      var pageNumber = 1;
      var totalPages = 1;
      do {
        final page = await widget.companyRepository.getCompanies(
          pageNumber: pageNumber,
          pageSize: 100,
          status: CompanyDataStatus.active,
        );
        result.addAll(page.items);
        totalPages = page.totalPages;
        pageNumber++;
      } while (pageNumber <= totalPages);
      if (!mounted) return;
      setState(() => _companies = result);
    } on ApiException catch (caught) {
      if (mounted) setState(() => _companiesError = caught);
    } finally {
      if (mounted) setState(() => _isLoadingCompanies = false);
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      _controller.setSearch(value);
      _controller.load();
    });
  }

  void _setType(int? value) {
    _controller.setTypeTram(value);
    _controller.load();
  }

  void _setCompany(int? value) {
    _controller.setCompanyId(value);
    _controller.load();
  }

  void _setStatus(int value) {
    _controller.setStatus(value);
    _controller.load();
  }

  Future<void> _openFilterSheet(bool isAdmin) async {
    var selectedType = _controller.typeTram;
    var selectedCompany = _controller.companyId;
    var selectedStatus = _controller.status;
    final applied = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
          final companyItems = _companies;
          final hasSelectedCompany = companyItems.any(
            (company) => company.id == selectedCompany,
          );
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, bottomInset + 16),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bộ lọc trạm',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Thu hẹp danh sách theo loại, công ty và trạng thái.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<int>(
                      isExpanded: true,
                      key: ValueKey('station-type-$selectedType'),
                      initialValue: selectedType,
                      decoration: const InputDecoration(
                        labelText: 'Loại trạm',
                        prefixIcon: Icon(Icons.category_outlined),
                      ),
                      hint: const Text('Tất cả loại'),
                      items: const [
                        DropdownMenuItem<int>(
                          value: 1,
                          child: Text('Trạm trộn'),
                        ),
                        DropdownMenuItem<int>(
                          value: 2,
                          child: Text('Trạm cân'),
                        ),
                      ],
                      onChanged: (value) =>
                          setSheetState(() => selectedType = value),
                    ),
                    if (isAdmin) ...[
                      const SizedBox(height: 14),
                      CompanyAutocompleteField(
                        key: ValueKey('station-company-$selectedCompany'),
                        companies: companyItems,
                        selectedCompanyId: hasSelectedCompany
                            ? selectedCompany
                            : null,
                        enabled: !_isLoadingCompanies,
                        hintText: companyItems.isEmpty
                            ? 'Không có dữ liệu'
                            : 'Tất cả công ty',
                        onSelected: (company) =>
                            setSheetState(() => selectedCompany = company.id),
                        onCleared: () =>
                            setSheetState(() => selectedCompany = null),
                      ),
                    ],
                    const SizedBox(height: 14),
                    DropdownButtonFormField<int>(
                      isExpanded: true,
                      key: ValueKey('station-status-$selectedStatus'),
                      initialValue: selectedStatus,
                      decoration: const InputDecoration(
                        labelText: 'Trạng thái',
                        prefixIcon: Icon(Icons.toggle_on_outlined),
                      ),
                      items: [
                        const DropdownMenuItem<int>(
                          value: StationDataStatus.active,
                          child: Text('Đang hoạt động'),
                        ),
                        if (isAdmin)
                          const DropdownMenuItem<int>(
                            value: StationDataStatus.deleted,
                            child: Text('Đã xóa mềm'),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setSheetState(() => selectedStatus = value);
                        }
                      },
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => setSheetState(() {
                              selectedType = null;
                              selectedCompany = null;
                              selectedStatus = StationDataStatus.active;
                            }),
                            child: const Text('Đặt lại'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: FilledButton.icon(
                            onPressed: () =>
                                Navigator.of(sheetContext).pop(true),
                            icon: const Icon(Icons.check_outlined),
                            label: const Text('Áp dụng'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    if (applied != true || !mounted) return;
    _controller.setTypeTram(selectedType);
    _controller.setCompanyId(selectedCompany);
    _controller.setStatus(selectedStatus);
    await _controller.load();
  }

  Future<void> _openCreate() async {
    final created = await Navigator.of(context).push<StationResponse>(
      MaterialPageRoute(
        builder: (_) => StationFormScreen(
          controller: _controller,
          companyRepository: widget.companyRepository,
          isAdmin: _isAdmin,
        ),
      ),
    );
    if (created != null && mounted) await _controller.load();
  }

  Future<void> _openDetail(StationListItem station) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => StationDetailScreen(
          stationId: station.id,
          controller: _controller,
          companyRepository: widget.companyRepository,
          isAdmin: _isAdmin,
          isCompanyRole: _isCompanyRole,
        ),
      ),
    );
    if (changed == true && mounted) await _controller.load();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final isAdmin = app.hasRole('ADMIN');
    final canList =
        isAdmin ||
        app.hasPermission(AccessFunctionCodes.branches, AccessPermission.dSach);
    if (!canList) return const NoAccessScreen();
    final canView =
        isAdmin ||
        app.hasPermission(AccessFunctionCodes.branches, AccessPermission.view);
    return Scaffold(
      appBar: AppBar(title: const Text('Quản lý trạm')),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Column(
          children: [
            _buildFilters(isAdmin),
            if (!canView) _buildListOnlyNotice(),
            if (_controller.isRefreshing) const LinearProgressIndicator(),
            Expanded(child: _buildList(canView)),
          ],
        ),
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: _openCreate,
              icon: const Icon(Icons.add_business_outlined),
              label: const Text('Thêm trạm'),
            )
          : null,
    );
  }

  Widget _buildFilters(bool isAdmin) {
    final activeFilters = _activeFilterLabels();
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _searchController,
                builder: (context, value, _) => TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Tìm theo tên hoặc mã trạm',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: value.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Xóa nội dung tìm kiếm',
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                            icon: const Icon(Icons.close),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _buildScopeSummary(isAdmin),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      activeFilters.isEmpty
                          ? 'Không áp dụng bộ lọc bổ sung'
                          : 'Bộ lọc đang áp dụng',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _openFilterSheet(isAdmin),
                    icon: const Icon(Icons.tune_outlined, size: 18),
                    label: Text(
                      activeFilters.isEmpty
                          ? 'Bộ lọc'
                          : 'Bộ lọc (${activeFilters.length})',
                    ),
                  ),
                ],
              ),
              if (activeFilters.isNotEmpty) ...[
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: activeFilters
                        .map(
                          (filter) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: InputChip(
                              label: Text(filter.label),
                              avatar: Icon(filter.icon, size: 17),
                              onDeleted: filter.onDeleted,
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
              ],
              if (_companiesError != null) ...[
                const SizedBox(height: 8),
                ErrorPanel(
                  message: _companiesError!.message,
                  onRetry: _loadCompanies,
                  retryLabel: 'Tải lại công ty',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListOnlyNotice() {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.lock_outline, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Phiên hiện tại chỉ được xem danh sách, chưa được cấp quyền xem chi tiết trạm.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScopeSummary(bool isAdmin) {
    final theme = Theme.of(context);
    final companyId = _controller.companyId;
    final company = companyId == null
        ? null
        : _companies.cast<CompanyResponse?>().firstWhere(
            (item) => item?.id == companyId,
            orElse: () => null,
          );
    final scopeLabel =
        company?.displayName ??
        (companyId == null
            ? (isAdmin ? 'Toàn bộ công ty' : 'Phạm vi được cấp')
            : 'Công ty #$companyId');
    final statusLabel = _controller.status == StationDataStatus.deleted
        ? 'Đã xóa mềm'
        : 'Đang hoạt động';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(
              Icons.account_tree_outlined,
              color: theme.colorScheme.onPrimaryContainer,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Phạm vi: $scopeLabel',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${_controller.totalCount} trạm • $statusLabel',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_ActiveFilter> _activeFilterLabels() {
    final filters = <_ActiveFilter>[];
    final type = _controller.typeTram;
    if (type != null) {
      final stationType = StationType.fromValue(type);
      filters.add(
        _ActiveFilter(
          label: stationType.label,
          icon: type == StationType.scale.value
              ? Icons.scale_outlined
              : Icons.factory_outlined,
          onDeleted: () => _setType(null),
        ),
      );
    }
    final companyId = _controller.companyId;
    if (companyId != null) {
      final company = _companies.cast<CompanyResponse?>().firstWhere(
        (item) => item?.id == companyId,
        orElse: () => null,
      );
      filters.add(
        _ActiveFilter(
          label: company?.displayName ?? 'Công ty #$companyId',
          icon: Icons.apartment_outlined,
          onDeleted: () => _setCompany(null),
        ),
      );
    }
    if (_controller.status == StationDataStatus.deleted) {
      filters.add(
        _ActiveFilter(
          label: 'Đã xóa mềm',
          icon: Icons.delete_outline,
          onDeleted: () => _setStatus(StationDataStatus.active),
        ),
      );
    }
    return filters;
  }

  Widget _buildList(bool canView) {
    if (_controller.isLoading && _controller.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_controller.error != null && _controller.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ErrorPanel(
              message: _controller.error!.message,
              onRetry: _controller.load,
            ),
          ),
        ),
      );
    }
    if (_controller.items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _controller.load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 110),
            AppEmptyState(
              icon: Icons.factory_outlined,
              title: 'Chưa có trạm phù hợp',
              message: 'Thử thay đổi từ khóa hoặc bộ lọc để tìm dữ liệu khác.',
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _controller.load,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.extentAfter < 320) {
            _controller.loadMore();
          }
          return false;
        },
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          itemCount: _controller.items.length + 1,
          separatorBuilder: (_, index) => index == _controller.items.length - 1
              ? const SizedBox(height: 8)
              : const SizedBox(height: 10),
          itemBuilder: (context, index) {
            if (index == _controller.items.length) {
              return _buildLoadMoreFooter();
            }
            final station = _controller.items[index];
            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: StationListCard(
                  station: station,
                  isDeleted: _controller.status == StationDataStatus.deleted,
                  onTap: canView ? () => _openDetail(station) : null,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLoadMoreFooter() {
    if (_controller.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_controller.loadMoreError != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: ErrorPanel(
          message: _controller.loadMoreError!.message,
          onRetry: _controller.loadMore,
        ),
      );
    }
    if (!_controller.canLoadMore) return const SizedBox(height: 16);
    return const SizedBox(height: 16);
  }
}

class _ActiveFilter {
  const _ActiveFilter({
    required this.label,
    required this.icon,
    required this.onDeleted,
  });

  final String label;
  final IconData icon;
  final VoidCallback onDeleted;
}
