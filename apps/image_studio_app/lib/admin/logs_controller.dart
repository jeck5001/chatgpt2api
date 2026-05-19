import 'package:flutter/foundation.dart';

import 'logs_models.dart';
import 'logs_repository.dart';

class SystemLogsState {
  const SystemLogsState({
    this.items = const [],
    this.total = 0,
    this.page = 1,
    this.pageSize = 30,
    this.hasMore = false,
    this.filter = const SystemLogFilter(),
    this.selectedIds = const <String>{},
    this.isLoading = false,
    this.isLoadingMore = false,
    this.isDeleting = false,
    this.errorMessage,
  });

  final List<SystemLogEntry> items;
  final int total;
  final int page;
  final int pageSize;
  final bool hasMore;
  final SystemLogFilter filter;
  final Set<String> selectedIds;
  final bool isLoading;
  final bool isLoadingMore;
  final bool isDeleting;
  final String? errorMessage;

  SystemLogsState copyWith({
    List<SystemLogEntry>? items,
    int? total,
    int? page,
    int? pageSize,
    bool? hasMore,
    SystemLogFilter? filter,
    Set<String>? selectedIds,
    bool? isLoading,
    bool? isLoadingMore,
    bool? isDeleting,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SystemLogsState(
      items: items ?? this.items,
      total: total ?? this.total,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      hasMore: hasMore ?? this.hasMore,
      filter: filter ?? this.filter,
      selectedIds: selectedIds ?? this.selectedIds,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isDeleting: isDeleting ?? this.isDeleting,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class SystemLogsController extends ChangeNotifier {
  SystemLogsController(this._repository, {int pageSize = 30})
    : _state = SystemLogsState(pageSize: pageSize);

  final SystemLogsRepositoryContract _repository;

  SystemLogsState _state;
  SystemLogsState get state => _state;

  void _update(SystemLogsState next) {
    _state = next;
    notifyListeners();
  }

  Future<void> refresh() async {
    if (_state.isLoading) return;
    _update(
      _state.copyWith(isLoading: true, clearError: true, page: 1, items: const []),
    );
    try {
      final page = await _repository.fetchPage(
        page: 1,
        pageSize: _state.pageSize,
        filter: _state.filter,
      );
      _update(
        _state.copyWith(
          items: page.items,
          total: page.total,
          page: page.page,
          pageSize: page.pageSize,
          hasMore: page.hasMore,
          isLoading: false,
          selectedIds: _state.selectedIds
              .where((id) => page.items.any((item) => item.id == id))
              .toSet(),
        ),
      );
    } catch (error) {
      _update(
        _state.copyWith(isLoading: false, errorMessage: error.toString()),
      );
    }
  }

  Future<void> loadMore() async {
    if (_state.isLoadingMore || _state.isLoading || !_state.hasMore) return;
    final nextPage = _state.page + 1;
    _update(_state.copyWith(isLoadingMore: true, clearError: true));
    try {
      final page = await _repository.fetchPage(
        page: nextPage,
        pageSize: _state.pageSize,
        filter: _state.filter,
      );
      _update(
        _state.copyWith(
          items: [..._state.items, ...page.items],
          total: page.total,
          page: page.page,
          hasMore: page.hasMore,
          isLoadingMore: false,
        ),
      );
    } catch (error) {
      _update(
        _state.copyWith(isLoadingMore: false, errorMessage: error.toString()),
      );
    }
  }

  Future<void> applyFilter(SystemLogFilter filter) async {
    _update(_state.copyWith(filter: filter, selectedIds: const <String>{}));
    await refresh();
  }

  void toggleSelected(String id) {
    final next = Set<String>.from(_state.selectedIds);
    if (!next.add(id)) {
      next.remove(id);
    }
    _update(_state.copyWith(selectedIds: next));
  }

  void clearSelection() {
    if (_state.selectedIds.isEmpty) return;
    _update(_state.copyWith(selectedIds: const <String>{}));
  }

  Future<int> deleteSelected() async {
    if (_state.isDeleting || _state.selectedIds.isEmpty) return 0;
    final ids = _state.selectedIds.toList(growable: false);
    _update(_state.copyWith(isDeleting: true, clearError: true));
    try {
      final removed = await _repository.deleteByIds(ids);
      _update(_state.copyWith(isDeleting: false, selectedIds: const <String>{}));
      await refresh();
      return removed;
    } catch (error) {
      _update(
        _state.copyWith(isDeleting: false, errorMessage: error.toString()),
      );
      rethrow;
    }
  }

  Future<int> deleteAllMatching() async {
    if (_state.isDeleting) return 0;
    _update(_state.copyWith(isDeleting: true, clearError: true));
    try {
      final removed = await _repository.deleteByFilter(_state.filter);
      _update(_state.copyWith(isDeleting: false, selectedIds: const <String>{}));
      await refresh();
      return removed;
    } catch (error) {
      _update(
        _state.copyWith(isDeleting: false, errorMessage: error.toString()),
      );
      rethrow;
    }
  }
}
