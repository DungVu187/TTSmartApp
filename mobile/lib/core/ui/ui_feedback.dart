import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'app_palette.dart';
import 'ui_controls.dart';
import 'ui_list.dart';
import '../theme/app_system_ui.dart';

/// Centred empty / error / no-access state: tinted ring, title, message and
/// optional actions.
class StateView extends StatelessWidget {
  const StateView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.tone = AppTone.neutral,
    this.actions = const [],
  });

  final IconData icon;
  final String title;
  final String message;
  final AppTone tone;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final (fg, bg) = tone == AppTone.neutral
        ? (p.text3, p.surfaceMuted)
        : p.tone(tone);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                child: Icon(icon, size: 33, color: fg),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: p.text1,
                  fontSize: 18,
                  height: 24 / 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: p.text2,
                  fontSize: 16,
                  height: 22 / 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 24),
                for (var index = 0; index < actions.length; index++) ...[
                  if (index > 0) const SizedBox(height: 4),
                  actions[index],
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Amber notice listing data caveats.
/// Full-page error of a first load (Figma S14): danger icon, the reason and
/// an outlined "Thử lại".
class LoadErrorView extends StatelessWidget {
  const LoadErrorView({
    super.key,
    required this.message,
    required this.onRetry,
    this.title = 'Không tải được danh sách',
  });

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: StateView(
            icon: LucideIcons.triangleAlert,
            tone: AppTone.danger,
            title: title,
            message: message,
            actions: [
              AppButton(
                label: 'Thử lại',
                icon: LucideIcons.refreshCw,
                variant: AppButtonVariant.outline,
                expand: false,
                onPressed: onRetry,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Grey placeholder rows while a list loads for the first time (Figma S13).
/// Static on purpose: no endless animation to drain battery or block tests.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.rows = 7});

  final int rows;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    Widget bar(double widthFactor, double height) => FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: widthFactor,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: p.surfaceMuted,
          borderRadius: BorderRadius.circular(height / 2),
        ),
      ),
    );
    return Semantics(
      label: 'Đang tải',
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(kPagePadding, 12, kPagePadding, 16),
        children: [
          SizedBox(width: 120, child: bar(0.28, 12)),
          const SizedBox(height: 10),
          InsetCard(
            dividerIndent: kLeadingDividerIndent,
            children: [
              for (var index = 0; index < rows; index++)
                Padding(
                  padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: p.surfaceMuted,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            bar(0.62, 12),
                            const SizedBox(height: 8),
                            bar(0.36, 10),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class WarningBanner extends StatelessWidget {
  const WarningBanner({super.key, required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
      decoration: BoxDecoration(
        color: p.warningBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.triangleAlert, size: 18, color: p.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: p.warning,
                    fontSize: 14,
                    height: 18 / 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                for (final item in items)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '• $item',
                      style: TextStyle(
                        color: p.text1,
                        fontSize: 13,
                        height: 18 / 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Inline red notice for request failures, with an optional retry.
class ErrorBanner extends StatelessWidget {
  const ErrorBanner({
    super.key,
    required this.message,
    this.onRetry,
    this.retryLabel = 'Thử lại',
  });

  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(14, 12, onRetry == null ? 14 : 4, 12),
        decoration: BoxDecoration(
          color: p.dangerBg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(LucideIcons.triangleAlert, size: 18, color: p.danger),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: p.danger,
                  fontSize: 15,
                  height: 20 / 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (onRetry != null)
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(foregroundColor: p.danger),
                child: Text(
                  retryLabel,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Footer at the end of an infinite list.
class LoadMoreFooter extends StatelessWidget {
  const LoadMoreFooter({
    super.key,
    required this.loading,
    this.errorMessage,
    this.onRetry,
  });

  final bool loading;
  final String? errorMessage;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    if (errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: ErrorBanner(message: errorMessage!, onRetry: onRetry),
      );
    }
    if (!loading) return const SizedBox(height: 12);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: p.primary),
          ),
          const SizedBox(width: 10),
          Text(
            'Đang tải thêm…',
            style: TextStyle(
              color: p.text3,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Vertical list that asks for the next page when its end comes near.
///
/// Also checks after every frame, so a first page that is too short to
/// scroll still pulls the next one, and it ignores horizontal scrollers inside
/// the list (e.g. a [FilterChipBar]).
class InfiniteListView extends StatefulWidget {
  const InfiniteListView({
    super.key,
    required this.children,
    required this.onLoadMore,
    this.onRefresh,
    this.padding,
    this.storageKey,
    this.threshold = 300,
  });

  final List<Widget> children;
  final VoidCallback onLoadMore;
  final Future<void> Function()? onRefresh;
  final EdgeInsetsGeometry? padding;
  final String? storageKey;
  final double threshold;

  @override
  State<InfiniteListView> createState() => _InfiniteListViewState();
}

class _InfiniteListViewState extends State<InfiniteListView> {
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _checkExtent() {
    if (!mounted || !_scroll.hasClients) return;
    final position = _scroll.position;
    if (!position.hasContentDimensions) return;
    if (position.extentAfter < widget.threshold) widget.onLoadMore();
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkExtent());
    final list = NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.depth == 0 &&
            notification.metrics.axis == Axis.vertical &&
            notification.metrics.extentAfter < widget.threshold) {
          widget.onLoadMore();
        }
        return false;
      },
      child: ListView(
        key: widget.storageKey == null
            ? null
            : PageStorageKey<String>(widget.storageKey!),
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: widget.padding,
        children: widget.children,
      ),
    );
    if (widget.onRefresh == null) return list;
    return RefreshIndicator(onRefresh: widget.onRefresh!, child: list);
  }
}

/// Confirmation dialog of the redesign. Resolves to `true` when confirmed.
Future<bool> showAppConfirmDialog(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Hủy',
  bool destructive = true,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final p = dialogContext.palette;
      final (fg, bg) = destructive
          ? p.tone(AppTone.danger)
          : p.tone(AppTone.primary);
      return Dialog(
        insetPadding: EdgeInsets.symmetric(
          horizontal: math.max(
            20,
            (MediaQuery.sizeOf(context).width - 314) / 2,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                child: Icon(icon, size: 22, color: fg),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: p.text1,
                  fontSize: 18,
                  height: 24 / 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: p.text2,
                  fontSize: 16,
                  height: 22 / 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: cancelLabel,
                      variant: AppButtonVariant.ghost,
                      onPressed: () => Navigator.pop(dialogContext, false),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppButton(
                      label: confirmLabel,
                      variant: destructive
                          ? AppButtonVariant.danger
                          : AppButtonVariant.primary,
                      onPressed: () => Navigator.pop(dialogContext, true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
  return result ?? false;
}

/// Opens a modal bottom sheet with the redesign defaults. Pair with
/// [AppSheetFrame] when the sheet keeps its own state.
Future<T?> showAppModalSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: builder,
);

/// Bottom sheet with drag handle, title row and close button.
/// [footer] stays pinned below the scrollable [builder] content.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required String title,
  required WidgetBuilder builder,
  WidgetBuilder? footer,
  double maxHeightFactor = 0.9,
}) => showAppModalSheet<T>(
  context: context,
  builder: (sheetContext) => AppSheetFrame(
    title: title,
    footer: footer?.call(sheetContext),
    maxHeightFactor: maxHeightFactor,
    child: builder(sheetContext),
  ),
);

/// Layout of every sheet: handle, title + close, scrollable body and an
/// optional pinned footer.
class AppSheetFrame extends StatelessWidget {
  const AppSheetFrame({
    super.key,
    required this.title,
    required this.child,
    this.footer,
    this.maxHeightFactor = 0.9,
    this.closeKey,
    this.scrollKey,
    this.subtitle,
    this.showClose = true,
  });

  final String title;

  /// Grey line under the title (Figma B04).
  final String? subtitle;
  final bool showClose;
  final Widget child;
  final Widget? footer;
  final double maxHeightFactor;

  /// Optional keys for the close button and the scrollable body (tests).
  final Key? closeKey;
  final Key? scrollKey;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final media = MediaQuery.of(context);
    // Keep controls clear of the iPhone home indicator / Android 3-button bar
    // (the modal route only avoids the top and the sides).
    final systemBottom = media.viewInsets.bottom > 0
        ? 0.0
        : media.viewPadding.bottom;
    return AppSystemUi(
      navigationBar: p.surface,
      child: Padding(
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: media.size.height * maxHeightFactor,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: p.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: showClose
                    ? const EdgeInsets.fromLTRB(16, 6, 6, 0)
                    : const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          color: p.text1,
                          fontSize: 19,
                          height: 24 / 19,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    if (showClose)
                      AppIconButton(
                        key: closeKey,
                        icon: LucideIcons.x,
                        tooltip: 'Đóng',
                        color: p.text2,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                  ],
                ),
              ),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: Text(
                    subtitle!,
                    style: TextStyle(
                      color: p.text2,
                      fontSize: 14,
                      height: 19 / 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              SizedBox(height: subtitle != null ? 20 : 8),
              Flexible(
                child: SingleChildScrollView(
                  key: scrollKey,
                  padding: EdgeInsets.fromLTRB(
                    16,
                    0,
                    16,
                    footer == null ? 28 + systemBottom : 16,
                  ),
                  child: child,
                ),
              ),
              if (footer != null)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    4,
                    16,
                    systemBottom > 12 ? systemBottom + 8 : 20,
                  ),
                  child: footer,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
