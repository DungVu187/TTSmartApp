import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/app_scope.dart';
import '../../../../core/widgets/error_panel.dart';
import '../../../access_management/data/models/permission_models.dart';
import '../../../shell/presentation/screens/no_access_screen.dart';
import '../../data/models/company_models.dart';
import '../../data/repositories/company_repository.dart';
import '../controllers/companies_controller.dart';
import '../widgets/company_widgets.dart';
import 'company_detail_screen.dart';
import 'company_form_screen.dart';

class CompaniesScreen extends StatefulWidget {
  const CompaniesScreen({super.key, required this.repository});

  final CompanyRepository repository;

  @override
  State<CompaniesScreen> createState() => _CompaniesScreenState();
}

class _CompaniesScreenState extends State<CompaniesScreen> {
  late final CompaniesController _controller;
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _controller = CompaniesController(widget.repository);
    WidgetsBinding.instance.addPostFrameCallback((_) => _controller.load());
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      _controller.setSearch(value);
      _controller.load();
    });
  }

  void _onStatusChanged(int value) {
    _controller.setStatus(value);
    _controller.load();
  }

  void _onLockChanged(bool? value) {
    _controller.setLocked(value);
    _controller.load();
  }

  Future<void> _openCreate() async {
    final created = await Navigator.of(context).push<CompanyResponse>(
      MaterialPageRoute(
        builder: (_) => CompanyFormScreen(controller: _controller),
      ),
    );
    if (created != null && mounted) await _controller.load();
  }

  Future<void> _openDetail(CompanyResponse company) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            CompanyDetailScreen(companyId: company.id, controller: _controller),
      ),
    );
    if (changed == true && mounted) await _controller.load();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    if (!app.hasPermission(
      AccessFunctionCodes.companies,
      AccessPermission.dSach,
    )) {
      return const NoAccessScreen();
    }
    final canCreate = app.hasPermission(
      AccessFunctionCodes.companies,
      AccessPermission.create,
    );
    final canView = app.hasPermission(
      AccessFunctionCodes.companies,
      AccessPermission.view,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Quản lý công ty')),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Column(
          children: [
            _buildFilters(),
            if (_controller.isRefreshing) const LinearProgressIndicator(),
            Expanded(child: _buildList(canView: canView)),
          ],
        ),
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: _openCreate,
              icon: const Icon(Icons.add_business_outlined),
              label: const Text('Thêm công ty'),
            )
          : null,
    );
  }

  Widget _buildFilters() {
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
                    hintText: 'Tìm theo tên, mã, email hoặc số điện thoại',
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
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChoice(
                      label: 'Đang hoạt động',
                      selected: _controller.status == CompanyDataStatus.active,
                      onSelected: () =>
                          _onStatusChanged(CompanyDataStatus.active),
                    ),
                    const SizedBox(width: 8),
                    _FilterChoice(
                      label: 'Đã xóa',
                      selected: _controller.status == CompanyDataStatus.deleted,
                      onSelected: () =>
                          _onStatusChanged(CompanyDataStatus.deleted),
                    ),
                    const SizedBox(width: 8),
                    _FilterChoice(
                      label: 'Tất cả khóa',
                      selected: _controller.isLocked == null,
                      onSelected: () => _onLockChanged(null),
                    ),
                    const SizedBox(width: 8),
                    _FilterChoice(
                      label: 'Không khóa',
                      selected: _controller.isLocked == false,
                      onSelected: () => _onLockChanged(false),
                    ),
                    const SizedBox(width: 8),
                    _FilterChoice(
                      label: 'Đang khóa',
                      selected: _controller.isLocked == true,
                      onSelected: () => _onLockChanged(true),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tổng ${_controller.totalCount} công ty',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList({required bool canView}) {
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
            SizedBox(height: 120),
            Icon(Icons.apartment_outlined, size: 52),
            SizedBox(height: 12),
            Center(child: Text('Chưa có công ty phù hợp.')),
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
            final company = _controller.items[index];
            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: CompanyListCard(
                  company: company,
                  onTap: canView ? () => _openDetail(company) : null,
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
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_controller.loadMoreError != null) {
      return Center(
        child: TextButton.icon(
          onPressed: _controller.loadMore,
          icon: const Icon(Icons.refresh),
          label: Text(_controller.loadMoreError!.message),
        ),
      );
    }
    if (_controller.canLoadMore) {
      return TextButton(
        onPressed: _controller.loadMore,
        child: const Text('Tải thêm'),
      );
    }
    return const SizedBox(height: 12);
  }
}

class _FilterChoice extends StatelessWidget {
  const _FilterChoice({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
    );
  }
}
