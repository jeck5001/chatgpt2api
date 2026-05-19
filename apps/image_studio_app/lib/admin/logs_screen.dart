import 'package:flutter/material.dart';

import '../app/tokens.dart';
import '../app/typography.dart';
import '../shared/components/section_header.dart';
import '../shared/empty_state.dart';
import 'logs_controller.dart';
import 'logs_models.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key, required this.controller});

  final SystemLogsController controller;

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  late final TextEditingController _qInput;
  late final ScrollController _scrollController;
  bool _initialLoadStarted = false;

  @override
  void initState() {
    super.initState();
    _qInput = TextEditingController(text: widget.controller.state.filter.q);
    _scrollController = ScrollController()..addListener(_onScroll);
    widget.controller.addListener(_onControllerChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_initialLoadStarted) {
        _initialLoadStarted = true;
        widget.controller.refresh();
      }
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _qInput.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted) return;
    final state = widget.controller.state;
    if (state.errorMessage != null) {
      final message = state.errorMessage!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _toast(message);
      });
    }
    final controllerQ = state.filter.q;
    if (_qInput.text != controllerQ) {
      _qInput.value = TextEditingValue(
        text: controllerQ,
        selection: TextSelection.collapsed(offset: controllerQ.length),
      );
    }
    setState(() {});
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 240) {
      final state = widget.controller.state;
      if (state.hasMore && !state.isLoadingMore && !state.isLoading) {
        widget.controller.loadMore();
      }
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _applyTypeFilter(String type) {
    final current = widget.controller.state.filter;
    if (current.type == type) return;
    widget.controller.applyFilter(current.copyWith(type: type));
  }

  void _submitQuery() {
    final current = widget.controller.state.filter;
    final next = _qInput.text.trim();
    if (current.q == next) return;
    widget.controller.applyFilter(current.copyWith(q: next));
  }

  Future<void> _pickDateRange() async {
    final state = widget.controller.state;
    final now = DateTime.now();
    final initial =
        state.filter.startDate != null && state.filter.endDate != null
        ? DateTimeRange(
            start: state.filter.startDate!,
            end: state.filter.endDate!,
          )
        : null;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      initialDateRange: initial,
      helpText: '选择日期范围',
    );
    if (picked == null) return;
    await widget.controller.applyFilter(
      state.filter.copyWith(startDate: picked.start, endDate: picked.end),
    );
  }

  void _clearDateRange() {
    final current = widget.controller.state.filter;
    if (current.startDate == null && current.endDate == null) return;
    widget.controller.applyFilter(
      current.copyWith(clearStartDate: true, clearEndDate: true),
    );
  }

  Future<void> _confirmDeleteSelected() async {
    final state = widget.controller.state;
    final count = state.selectedIds.length;
    if (count == 0) return;
    final ok = await _confirm(
      title: '删除所选日志',
      message: '确认删除 $count 条日志？删除后无法恢复。',
    );
    if (ok != true) return;
    try {
      final removed = await widget.controller.deleteSelected();
      if (!mounted) return;
      _toast('已删除 $removed 条日志');
    } catch (_) {
      // error toast already triggered via controller listener
    }
  }

  Future<void> _confirmDeleteAllMatching() async {
    final state = widget.controller.state;
    final filterDescription = _describeFilter(state.filter);
    final ok = await _confirm(
      title: '删除全部匹配日志',
      message: state.total > 0
          ? '将删除符合当前筛选的 ${state.total} 条日志（$filterDescription），删除后无法恢复。'
          : '将删除符合当前筛选的全部日志（$filterDescription），删除后无法恢复。',
    );
    if (ok != true) return;
    try {
      final removed = await widget.controller.deleteAllMatching();
      if (!mounted) return;
      _toast('已删除 $removed 条日志');
    } catch (_) {
      // error toast already triggered via controller listener
    }
  }

  Future<bool?> _confirm({required String title, required String message}) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: KilnColors.danger,
                foregroundColor: KilnColors.ink100,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
  }

  String _describeFilter(SystemLogFilter filter) {
    final parts = <String>[];
    parts.add(_typeLabel(filter.type));
    if (filter.q.isNotEmpty) parts.add('搜索"${filter.q}"');
    if (filter.startDate != null || filter.endDate != null) {
      parts.add(
        '${_formatDate(filter.startDate) ?? '…'}~${_formatDate(filter.endDate) ?? '…'}',
      );
    }
    return parts.join(' · ');
  }

  static String _typeLabel(String type) {
    switch (type) {
      case 'call':
        return '调用日志';
      case 'account':
        return '账号日志';
      default:
        return '全部类型';
    }
  }

  static String? _formatDate(DateTime? value) {
    if (value == null) return null;
    final y = value.year.toString().padLeft(4, '0');
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.controller.state;
    return Scaffold(
      backgroundColor: KilnColors.ink900,
      appBar: AppBar(
        backgroundColor: KilnColors.ink900,
        foregroundColor: KilnColors.ink100,
        elevation: 0,
        title: const Text('服务器调用日志'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
            onPressed: state.isLoading
                ? null
                : () => widget.controller.refresh(),
          ),
          PopupMenuButton<String>(
            tooltip: '更多',
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'delete_all_matching') {
                _confirmDeleteAllMatching();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                value: 'delete_all_matching',
                enabled: !state.isDeleting,
                child: Row(
                  children: const [
                    Icon(Icons.delete_sweep, color: KilnColors.danger),
                    SizedBox(width: KilnSpacing.sm),
                    Text('删除全部匹配筛选'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Stack(
          children: [
            CustomScrollView(
              controller: _scrollController,
              slivers: [
                SliverToBoxAdapter(child: _buildFilterRow(state)),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    KilnSpacing.lg,
                    0,
                    KilnSpacing.lg,
                    KilnSpacing.xxxl + 80,
                  ),
                  sliver: _buildBodySliver(state),
                ),
              ],
            ),
            _buildSelectionBar(state),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterRow(SystemLogsState state) {
    final filter = state.filter;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        KilnSpacing.lg,
        KilnSpacing.md,
        KilnSpacing.lg,
        KilnSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader.inline(title: '筛选 · 共 ${state.total} 条'),
          const SizedBox(height: KilnSpacing.sm),
          Wrap(
            spacing: KilnSpacing.xs,
            runSpacing: KilnSpacing.xs,
            children: [
              _filterChip(
                label: '全部类型',
                active: filter.type.isEmpty,
                onTap: () => _applyTypeFilter(''),
              ),
              _filterChip(
                label: '调用',
                active: filter.type == 'call',
                onTap: () => _applyTypeFilter('call'),
              ),
              _filterChip(
                label: '账号',
                active: filter.type == 'account',
                onTap: () => _applyTypeFilter('account'),
              ),
            ],
          ),
          const SizedBox(height: KilnSpacing.sm),
          TextField(
            controller: _qInput,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _submitQuery(),
            style: KilnTypography.bodyM.copyWith(color: KilnColors.ink100),
            decoration: InputDecoration(
              hintText: '搜索摘要或详情',
              hintStyle: KilnTypography.bodyM.copyWith(
                color: KilnColors.ink500,
              ),
              prefixIcon: const Icon(
                Icons.search,
                color: KilnColors.ink400,
                size: 18,
              ),
              suffixIcon: _qInput.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(
                        Icons.close,
                        size: 18,
                        color: KilnColors.ink400,
                      ),
                      onPressed: () {
                        _qInput.clear();
                        _submitQuery();
                      },
                    )
                  : null,
              filled: true,
              fillColor: KilnColors.ink800,
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(KilnRadii.input),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: KilnSpacing.sm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickDateRange,
                  icon: const Icon(Icons.event_outlined, size: 16),
                  label: Text(_dateRangeLabel(filter)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: KilnColors.ink200,
                    side: const BorderSide(color: KilnColors.hairlineStrong),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(KilnRadii.button),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: KilnSpacing.md,
                      vertical: KilnSpacing.sm + 2,
                    ),
                  ),
                ),
              ),
              if (filter.startDate != null || filter.endDate != null) ...[
                const SizedBox(width: KilnSpacing.xs),
                IconButton(
                  tooltip: '清除日期',
                  icon: const Icon(Icons.close, size: 18),
                  color: KilnColors.ink400,
                  onPressed: _clearDateRange,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _dateRangeLabel(SystemLogFilter filter) {
    final start = _formatDate(filter.startDate);
    final end = _formatDate(filter.endDate);
    if (start == null && end == null) return '日期范围（不限）';
    return '${start ?? '…'} ~ ${end ?? '…'}';
  }

  Widget _filterChip({
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(KilnRadii.chip),
        onTap: onTap,
        child: Container(
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: KilnSpacing.md),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active
                ? KilnColors.ember500.withValues(alpha: 0.12)
                : KilnColors.ink800,
            borderRadius: BorderRadius.circular(KilnRadii.chip),
            border: Border.all(
              color: active
                  ? KilnColors.ember500.withValues(alpha: 0.30)
                  : KilnColors.hairlineStrong,
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: KilnTypography.ui(
              size: 12,
              color: active ? KilnColors.ember400 : KilnColors.ink200,
              weight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBodySliver(SystemLogsState state) {
    if (state.isLoading && state.items.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: KilnSpacing.xxxl),
            child: CircularProgressIndicator(color: KilnColors.ember500),
          ),
        ),
      );
    }
    if (!state.isLoading && state.items.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: EmptyState(
          title: '没有匹配的',
          accent: '日志',
          message: '调整筛选条件后再试，或者后端还没有产生这一类记录。',
          icon: Icons.history,
          showLogo: false,
        ),
      );
    }
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        if (index == state.items.length) {
          return _buildFooterSliver(state);
        }
        final entry = state.items[index];
        return _LogRow(
          entry: entry,
          selected: state.selectedIds.contains(entry.id),
          onToggle: () => widget.controller.toggleSelected(entry.id),
        );
      }, childCount: state.items.length + 1),
    );
  }

  Widget _buildFooterSliver(SystemLogsState state) {
    if (state.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: KilnSpacing.lg),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: KilnColors.ember500,
            ),
          ),
        ),
      );
    }
    if (state.hasMore) {
      return const SizedBox(height: KilnSpacing.lg);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: KilnSpacing.lg),
      child: Center(
        child: Text(
          '已加载全部',
          style: KilnTypography.ui(size: 12, color: KilnColors.ink400),
        ),
      ),
    );
  }

  Widget _buildSelectionBar(SystemLogsState state) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: AnimatedSlide(
        offset: state.selectedIds.isEmpty ? const Offset(0, 1) : Offset.zero,
        duration: KilnMotion.base,
        curve: KilnMotion.easeOut,
        child: AnimatedOpacity(
          opacity: state.selectedIds.isEmpty ? 0 : 1,
          duration: KilnMotion.base,
          child: SafeArea(
            top: false,
            child: Container(
              margin: const EdgeInsets.all(KilnSpacing.lg),
              padding: const EdgeInsets.symmetric(
                horizontal: KilnSpacing.md,
                vertical: KilnSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: KilnColors.ink800,
                borderRadius: BorderRadius.circular(KilnRadii.card),
                border: Border.all(color: KilnColors.hairlineStrong),
                boxShadow: KilnShadows.float,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '已选 ${state.selectedIds.length} 条',
                      style: KilnTypography.ui(
                        size: 14,
                        color: KilnColors.ink100,
                        weight: FontWeight.w500,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: state.isDeleting
                        ? null
                        : widget.controller.clearSelection,
                    child: Text(
                      '取消',
                      style: KilnTypography.ui(
                        size: 13,
                        color: KilnColors.ink300,
                      ),
                    ),
                  ),
                  const SizedBox(width: KilnSpacing.xs),
                  FilledButton.icon(
                    onPressed: state.isDeleting ? null : _confirmDeleteSelected,
                    icon: state.isDeleting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.delete_outline, size: 16),
                    label: const Text('删除'),
                    style: FilledButton.styleFrom(
                      backgroundColor: KilnColors.danger,
                      foregroundColor: KilnColors.ink100,
                      padding: const EdgeInsets.symmetric(
                        horizontal: KilnSpacing.md,
                        vertical: KilnSpacing.sm,
                      ),
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
}

class _LogRow extends StatelessWidget {
  const _LogRow({
    required this.entry,
    required this.selected,
    required this.onToggle,
  });

  final SystemLogEntry entry;
  final bool selected;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final isCallType = entry.type == 'call';
    final statusValue = entry.detail['status'];
    final isFailed = statusValue == 'failed';
    final typeLabel = isCallType
        ? '调用'
        : entry.type == 'account'
        ? '账号'
        : entry.type;
    final typeColor = isCallType
        ? (isFailed ? KilnColors.danger : KilnColors.success)
        : KilnColors.info;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(KilnRadii.md),
        child: Container(
          margin: const EdgeInsets.only(bottom: KilnSpacing.xs),
          padding: const EdgeInsets.symmetric(
            horizontal: KilnSpacing.md,
            vertical: KilnSpacing.sm + 2,
          ),
          decoration: BoxDecoration(
            color: selected
                ? KilnColors.ember500.withValues(alpha: 0.08)
                : KilnColors.ink850,
            borderRadius: BorderRadius.circular(KilnRadii.md),
            border: Border.all(
              color: selected
                  ? KilnColors.ember500.withValues(alpha: 0.32)
                  : KilnColors.hairline,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: Checkbox(
                  value: selected,
                  onChanged: (_) => onToggle(),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(width: KilnSpacing.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: KilnSpacing.xs,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: typeColor.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            typeLabel,
                            style: KilnTypography.ui(
                              size: 10,
                              color: typeColor,
                              weight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: KilnSpacing.xs),
                        Expanded(
                          child: Text(
                            entry.time,
                            style: KilnTypography.metaMono.copyWith(
                              fontSize: 11,
                              color: KilnColors.ink400,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entry.summary.isEmpty ? '（无摘要）' : entry.summary,
                      style: KilnTypography.bodyM.copyWith(
                        color: KilnColors.ink100,
                      ),
                    ),
                    if (entry.detail['error'] is String &&
                        (entry.detail['error'] as String).isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        entry.detail['error'] as String,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: KilnTypography.bodyS.copyWith(
                          color: KilnColors.danger,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
