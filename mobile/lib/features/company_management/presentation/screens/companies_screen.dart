import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/app_scope.dart';
import '../../../../core/ui/app_ui.dart';
import '../../../../core/widgets/error_panel.dart';
import '../../../access_management/data/models/permission_models.dart';
import '../../../shell/presentation/screens/no_access_screen.dart';
import '../../data/models/company_models.dart';
import '../../data/repositories/company_repository.dart';
import '../controllers/companies_controller.dart';
import 'company_detail_screen.dart';

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
  bool _showSearch = false;

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
    final canView = app.hasPermission(
      AccessFunctionCodes.companies,
      AccessPermission.view,
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý công ty'),
        actions: [
          IconButton(
            tooltip: 'Tìm kiếm',
            onPressed: () => setState(() => _showSearch = !_showSearch),
            icon: const Icon(LucideIcons.search),
          ),
        ],
      ),
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
              if (_showSearch)
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _searchController,
                  builder: (context, value, _) => TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Tìm theo tên, mã, email hoặc số điện thoại',
                      prefixIcon: const Icon(LucideIcons.search),
                      suffixIcon: value.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Xóa nội dung tìm kiếm',
                              onPressed: () {
                                _searchController.clear();
                                _onSearchChanged('');
                              },
                              icon: const Icon(LucideIcons.x),
                            ),
                    ),
                  ),
                ),
              if (_showSearch) const SizedBox(height: 10),
              SegmentedTabs<int>(
                segments: const [
                  (CompanyDataStatus.active, 'Đang hoạt động'),
                  (CompanyDataStatus.deleted, 'Đã xóa'),
                ],
                selected: _controller.status,
                onChanged: _onStatusChanged,
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: GroupLabel('${_controller.totalCount} công ty'),
                  ),
                  PopupMenuButton<bool?>(
                    tooltip: 'Lọc trạng thái khóa',
                    onSelected: _onLockChanged,
                    itemBuilder: (_) => const [
                      PopupMenuItem<bool?>(value: null, child: Text('Tất cả')),
                      PopupMenuItem<bool?>(
                        value: false,
                        child: Text('Không khóa'),
                      ),
                      PopupMenuItem<bool?>(
                        value: true,
                        child: Text('Đang khóa'),
                      ),
                    ],
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Khóa: ${_controller.isLocked == null
                              ? 'Tất cả'
                              : _controller.isLocked!
                              ? 'Đang khóa'
                              : 'Không khóa'}',
                          style: TextStyle(
                            color: context.palette.text2,
                            fontSize: 13,
                          ),
                        ),
                        const Icon(LucideIcons.chevronDown, size: 18),
                      ],
                    ),
                  ),
                ],
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
            Icon(LucideIcons.building, size: 52),
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
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          itemCount: ((_controller.items.length + 19) ~/ 20) + 1,
          itemBuilder: (context, index) {
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
                      for (final company in _controller.items.sublist(
                        start,
                        end,
                      ))
                        NavRow(
                          leading: const IconTile(
                            icon: LucideIcons.building,
                            tone: AppTone.info,
                          ),
                          title: company.displayName,
                          subtitle: [
                            if (company.code?.trim().isNotEmpty == true)
                              company.code!.trim(),
                            company.plan.label,
                          ].join(' · '),
                          subtitleWidget: company.isLocked
                              ? _LockedSubtitle(company: company)
                              : null,
                          onTap: canView ? () => _openDetail(company) : null,
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
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_controller.loadMoreError != null) {
      return Center(
        child: TextButton.icon(
          onPressed: _controller.loadMore,
          icon: const Icon(LucideIcons.refreshCw),
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

/// "BTHN · Trả phí · Đang khóa" with the lock state in bold red (Figma B01).
class _LockedSubtitle extends StatelessWidget {
  const _LockedSubtitle({required this.company});

  final CompanyResponse company;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final base = [
      if (company.code?.trim().isNotEmpty == true) company.code!.trim(),
      company.plan.label,
    ].join(' · ');
    return Text.rich(
      TextSpan(
        style: TextStyle(
          color: p.text2,
          fontSize: 13,
          height: 17 / 13,
          fontWeight: FontWeight.w500,
        ),
        children: [
          TextSpan(text: '$base · '),
          TextSpan(
            text: 'Đang khóa',
            style: TextStyle(color: p.danger, fontWeight: FontWeight.w700),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
