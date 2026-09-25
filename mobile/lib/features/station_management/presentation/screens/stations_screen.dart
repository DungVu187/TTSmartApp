import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/app_scope.dart';
import '../../../../core/ui/app_ui.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/error_panel.dart';
import '../../../access_management/data/models/permission_models.dart';
import '../../../company_management/data/models/company_models.dart';
import '../../../company_management/data/repositories/company_repository.dart';
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
  bool _showSearch = false;
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

  /// Figma B04: type / company / status drafts, applied with "Áp dụng".
  Future<void> _openFilterSheet(bool isAdmin) async {
    var selectedType = _controller.typeTram;
    var selectedCompany = _controller.companyId;
    var selectedStatus = _controller.status;
    final applied = await showAppModalSheet<bool>(
      context: context,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          String? companyName;
          for (final company in _companies) {
            if (company.id == selectedCompany) {
              companyName = company.displayName;
            }
          }
          return AppSheetFrame(
            title: 'Bộ lọc trạm',
            subtitle: 'Thu hẹp danh sách theo loại, công ty và trạng thái.',
            showClose: false,
            footer: Row(
              children: [
                Expanded(
                  child: AppButton(
                    key: const ValueKey<String>('station-filter-reset'),
                    variant: AppButtonVariant.ghost,
                    onPressed: () => setSheetState(() {
                      selectedType = null;
                      selectedCompany = null;
                      selectedStatus = StationDataStatus.active;
                    }),
                    label: 'Đặt lại',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: AppButton(
                    key: const ValueKey<String>('station-filter-apply'),
                    onPressed: () => Navigator.of(sheetContext).pop(true),
                    icon: LucideIcons.check,
                    label: 'Áp dụng',
                  ),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const GroupLabel('Loại trạm'),
                const SizedBox(height: 8),
                OptionChipGroup<int?>(
                  options: const [
                    (null, 'Tất cả'),
                    (1, 'Trạm trộn'),
                    (2, 'Trạm cân'),
                  ],
                  selected: selectedType,
                  onChanged: (value) =>
                      setSheetState(() => selectedType = value),
                ),
                if (isAdmin) ...[
                  const SizedBox(height: 20),
                  SelectFieldButton(
                    key: const ValueKey<String>('station-filter-company'),
                    label: 'CÔNG TY',
                    placeholder: _isLoadingCompanies
                        ? 'Đang tải công ty…'
                        : 'Tất cả công ty',
                    value:
                        companyName ??
                        (selectedCompany == null
                            ? 'Tất cả công ty'
                            : 'Công ty #$selectedCompany'),
                    enabled: !_isLoadingCompanies,
                    onTap: () async {
                      final picked = await showPickerSheet<int>(
                        context: context,
                        title: 'Chọn công ty',
                        searchHint: 'Tìm công ty',
                        icon: LucideIcons.building,
                        clearLabel: 'Tất cả công ty',
                        selected: selectedCompany,
                        options: [
                          for (final company in _companies)
                            PickerOption(
                              value: company.id,
                              title: company.displayName,
                              subtitle: company.code,
                            ),
                        ],
                      );
                      if (picked != null) {
                        setSheetState(() => selectedCompany = picked.value);
                      }
                    },
                    onClear: selectedCompany == null
                        ? null
                        : () => setSheetState(() => selectedCompany = null),
                  ),
                ],
                const SizedBox(height: 20),
                const GroupLabel('Trạng thái'),
                const SizedBox(height: 8),
                OptionChipGroup<int>(
                  options: [
                    const (StationDataStatus.active, 'Đang hoạt động'),
                    if (isAdmin)
                      const (StationDataStatus.deleted, 'Đã xóa mềm'),
                  ],
                  selected: selectedStatus,
                  onChanged: (value) =>
                      setSheetState(() => selectedStatus = value),
                ),
              ],
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

  // ignore: unused_element, retained for the web/admin flow.
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
    final filterCount = _activeFilterLabels().length;
    return Scaffold(
      // Figma B03: search + filter live in the app bar.
      appBar: AppBar(
        title: const Text('Quản lý trạm'),
        actions: [
          IconButton(
            tooltip: 'Tìm kiếm',
            onPressed: () => setState(() => _showSearch = !_showSearch),
            icon: const Icon(LucideIcons.search),
          ),
          IconButton(
            tooltip: 'Bộ lọc',
            onPressed: () => _openFilterSheet(isAdmin),
            icon: Badge(
              isLabelVisible: filterCount > 0,
              label: Text('$filterCount'),
              child: const Icon(LucideIcons.slidersHorizontal),
            ),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Column(
          children: [
            _buildFilters(isAdmin),
            if (!canView) _buildListOnlyNotice(),
            if (_controller.isRefreshing) const LinearProgressIndicator(),
            Expanded(child: _buildList(canView, isAdmin)),
          ],
        ),
      ),
    );
  }

  /// Search field (when opened), active filter chips and company errors.
  Widget _buildFilters(bool isAdmin) {
    final activeFilters = _activeFilterLabels();
    final children = <Widget>[
      if (_showSearch)
        AppSearchField(
          controller: _searchController,
          hintText: 'Tìm theo tên hoặc mã trạm',
          autofocus: true,
          onChanged: _onSearchChanged,
        ),
      if (activeFilters.isNotEmpty)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final filter in activeFilters)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InputChip(
                    label: Text(filter.label),
                    avatar: Icon(filter.icon, size: 17),
                    onDeleted: filter.onDeleted,
                  ),
                ),
            ],
          ),
        ),
      if (_companiesError != null)
        ErrorBanner(
          message: _companiesError!.message,
          onRetry: _loadCompanies,
          retryLabel: 'Tải lại công ty',
        ),
    ];
    if (children.isEmpty) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < children.length; index++) ...[
                if (index > 0) const SizedBox(height: 8),
                children[index],
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// "TOÀN BỘ CÔNG TY · 12 TRẠM" (or the company picked in the filter).
  String _scopeLabel(bool isAdmin) {
    final companyId = _controller.companyId;
    String? company;
    for (final item in _companies) {
      if (item.id == companyId) company = item.displayName;
    }
    final scope =
        company ??
        (companyId == null
            ? (isAdmin ? 'Toàn bộ công ty' : 'Phạm vi được cấp')
            : 'Công ty #$companyId');
    final deleted = _controller.status == StationDataStatus.deleted
        ? ' · đã xóa mềm'
        : '';
    return '$scope · ${_controller.totalCount} trạm$deleted';
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
                  Icon(LucideIcons.lock, color: theme.colorScheme.primary),
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

  List<_ActiveFilter> _activeFilterLabels() {
    final filters = <_ActiveFilter>[];
    final type = _controller.typeTram;
    if (type != null) {
      final stationType = StationType.fromValue(type);
      filters.add(
        _ActiveFilter(
          label: stationType.label,
          icon: type == StationType.scale.value
              ? LucideIcons.scale
              : LucideIcons.factory,
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
          icon: LucideIcons.building,
          onDeleted: () => _setCompany(null),
        ),
      );
    }
    if (_controller.status == StationDataStatus.deleted) {
      filters.add(
        _ActiveFilter(
          label: 'Đã xóa mềm',
          icon: LucideIcons.trash2,
          onDeleted: () => _setStatus(StationDataStatus.active),
        ),
      );
    }
    return filters;
  }

  Widget _buildList(bool canView, bool isAdmin) {
    if (_controller.isLoading && _controller.items.isEmpty) {
      return const SkeletonList();
    }
    if (_controller.error != null && _controller.items.isEmpty) {
      return LoadErrorView(
        message: _controller.error!.message,
        onRetry: _controller.load,
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
              icon: LucideIcons.factory,
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
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          itemCount: ((_controller.items.length + 19) ~/ 20) + 2,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GroupLabel(_scopeLabel(isAdmin)),
              );
            }
            index -= 1;
            final groupCount = (_controller.items.length + 19) ~/ 20;
            if (index == groupCount) {
              return _buildLoadMoreFooter();
            }
            final start = index * 20;
            final end = (start + 20).clamp(0, _controller.items.length);
            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InsetCard(
                    dividerIndent: kLeadingDividerIndent,
                    children: [
                      for (final station in _controller.items.sublist(
                        start,
                        end,
                      ))
                        NavRow(
                          leading: IconTile(
                            icon: stationTypeIcon(station.type),
                            tone: station.type == StationType.scale
                                ? AppTone.violet
                                : AppTone.primary,
                          ),
                          title: station.displayName,
                          subtitle: [
                            station.type?.label ?? 'Trạm',
                            if (station.phone?.trim().isNotEmpty == true)
                              station.phone!.trim(),
                          ].join(' · '),
                          onTap: canView ? () => _openDetail(station) : null,
                        ),
                    ],
                  ),
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
