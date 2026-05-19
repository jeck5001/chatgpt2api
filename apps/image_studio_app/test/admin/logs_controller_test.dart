import 'package:flutter_test/flutter_test.dart';
import 'package:image_studio_app/admin/logs_controller.dart';
import 'package:image_studio_app/admin/logs_models.dart';
import 'package:image_studio_app/admin/logs_repository.dart';

class _StubLogsRepository implements SystemLogsRepositoryContract {
  _StubLogsRepository({this.pages = const {}});

  /// Pre-baked responses keyed by page number.
  final Map<int, SystemLogPage> pages;

  final List<Map<String, Object?>> fetchCalls = [];
  final List<List<String>> deleteByIdsCalls = [];
  final List<SystemLogFilter> deleteByFilterCalls = [];
  int deletedByIdsReturn = 0;
  int deletedByFilterReturn = 0;

  @override
  Future<SystemLogPage> fetchPage({
    required int page,
    int pageSize = 30,
    required SystemLogFilter filter,
  }) async {
    fetchCalls.add({'page': page, 'pageSize': pageSize, 'filter': filter});
    return pages[page] ??
        SystemLogPage(
          items: const [],
          total: 0,
          page: page,
          pageSize: pageSize,
          hasMore: false,
        );
  }

  @override
  Future<int> deleteByIds(List<String> ids) async {
    deleteByIdsCalls.add(List<String>.from(ids));
    return deletedByIdsReturn;
  }

  @override
  Future<int> deleteByFilter(SystemLogFilter filter) async {
    deleteByFilterCalls.add(filter);
    return deletedByFilterReturn;
  }
}

SystemLogEntry _entry(String id, {String summary = ''}) {
  return SystemLogEntry(
    id: id,
    time: '2026-05-12 10:00:00',
    type: 'call',
    summary: summary,
  );
}

SystemLogPage _page({
  required List<SystemLogEntry> items,
  required int total,
  required int page,
  required bool hasMore,
  int pageSize = 30,
}) {
  return SystemLogPage(
    items: items,
    total: total,
    page: page,
    pageSize: pageSize,
    hasMore: hasMore,
  );
}

void main() {
  test('refresh populates state from the repository', () async {
    final repo = _StubLogsRepository(
      pages: {
        1: _page(
          items: [_entry('a'), _entry('b')],
          total: 5,
          page: 1,
          hasMore: true,
        ),
      },
    );
    final controller = SystemLogsController(repo, pageSize: 2);

    await controller.refresh();

    expect(controller.state.items.map((e) => e.id), ['a', 'b']);
    expect(controller.state.total, 5);
    expect(controller.state.page, 1);
    expect(controller.state.hasMore, isTrue);
    expect(controller.state.isLoading, isFalse);
    expect(repo.fetchCalls.single['page'], 1);
  });

  test('loadMore appends items and advances page', () async {
    final repo = _StubLogsRepository(
      pages: {
        1: _page(
          items: [_entry('a'), _entry('b')],
          total: 4,
          page: 1,
          hasMore: true,
        ),
        2: _page(
          items: [_entry('c'), _entry('d')],
          total: 4,
          page: 2,
          hasMore: false,
        ),
      },
    );
    final controller = SystemLogsController(repo, pageSize: 2);
    await controller.refresh();

    await controller.loadMore();

    expect(controller.state.items.map((e) => e.id), ['a', 'b', 'c', 'd']);
    expect(controller.state.page, 2);
    expect(controller.state.hasMore, isFalse);
    expect(controller.state.isLoadingMore, isFalse);
  });

  test('loadMore is a no-op when hasMore is false', () async {
    final repo = _StubLogsRepository(
      pages: {
        1: _page(items: [_entry('a')], total: 1, page: 1, hasMore: false),
      },
    );
    final controller = SystemLogsController(repo);
    await controller.refresh();

    await controller.loadMore();

    expect(repo.fetchCalls.length, 1);
  });

  test('applyFilter resets page to 1 and refetches', () async {
    final repo = _StubLogsRepository(
      pages: {
        1: _page(
          items: [_entry('a'), _entry('b')],
          total: 4,
          page: 1,
          hasMore: true,
        ),
        2: _page(items: [_entry('c')], total: 4, page: 2, hasMore: false),
      },
    );
    final controller = SystemLogsController(repo, pageSize: 2);
    await controller.refresh();
    await controller.loadMore();
    expect(controller.state.page, 2);

    repo.pages[1] = _page(
      items: [_entry('z', summary: '失败')],
      total: 1,
      page: 1,
      hasMore: false,
    );
    await controller.applyFilter(const SystemLogFilter(q: '失败'));

    expect(controller.state.filter.q, '失败');
    expect(controller.state.items.map((e) => e.id), ['z']);
    expect(controller.state.page, 1);
    expect(controller.state.selectedIds, isEmpty);
    expect(repo.fetchCalls.last['page'], 1);
  });

  test('toggleSelected adds and removes ids', () async {
    final controller = SystemLogsController(_StubLogsRepository());
    controller.toggleSelected('a');
    controller.toggleSelected('b');
    expect(controller.state.selectedIds, {'a', 'b'});
    controller.toggleSelected('a');
    expect(controller.state.selectedIds, {'b'});
  });

  test('deleteSelected calls repository with ids and refreshes', () async {
    final repo = _StubLogsRepository(
      pages: {
        1: _page(
          items: [_entry('a'), _entry('b'), _entry('c')],
          total: 3,
          page: 1,
          hasMore: false,
        ),
      },
    )..deletedByIdsReturn = 2;
    final controller = SystemLogsController(repo);
    await controller.refresh();
    controller.toggleSelected('a');
    controller.toggleSelected('b');

    repo.pages[1] = _page(
      items: [_entry('c')],
      total: 1,
      page: 1,
      hasMore: false,
    );
    final removed = await controller.deleteSelected();

    expect(removed, 2);
    expect(repo.deleteByIdsCalls.single, containsAll(['a', 'b']));
    expect(controller.state.selectedIds, isEmpty);
    expect(controller.state.items.single.id, 'c');
  });

  test(
    'deleteAllMatching calls repository with filter and refreshes',
    () async {
      final repo = _StubLogsRepository(
        pages: {
          1: _page(
            items: [_entry('a'), _entry('b')],
            total: 2,
            page: 1,
            hasMore: false,
          ),
        },
      )..deletedByFilterReturn = 2;
      final controller = SystemLogsController(repo);
      await controller.applyFilter(const SystemLogFilter(type: 'call'));

      repo.pages[1] = _page(items: const [], total: 0, page: 1, hasMore: false);
      final removed = await controller.deleteAllMatching();

      expect(removed, 2);
      expect(repo.deleteByFilterCalls.single.type, 'call');
      expect(controller.state.items, isEmpty);
      expect(controller.state.total, 0);
    },
  );
}
