import '../core/api/api_client.dart';
import 'logs_models.dart';

abstract interface class SystemLogsRepositoryContract {
  Future<SystemLogPage> fetchPage({
    required int page,
    int pageSize,
    required SystemLogFilter filter,
  });

  Future<int> deleteByIds(List<String> ids);

  Future<int> deleteByFilter(SystemLogFilter filter);
}

class SystemLogsRepository implements SystemLogsRepositoryContract {
  const SystemLogsRepository(this._client);

  final ApiClient _client;

  @override
  Future<SystemLogPage> fetchPage({
    required int page,
    int pageSize = 30,
    required SystemLogFilter filter,
  }) async {
    final query = <String, Object?>{
      'page': '$page',
      'page_size': '$pageSize',
    };
    _applyFilter(query, filter);
    final payload = await _client.getJson('/api/logs', query: query);
    return SystemLogPage.fromJson(payload);
  }

  @override
  Future<int> deleteByIds(List<String> ids) async {
    if (ids.isEmpty) return 0;
    final payload = await _client.postJson(
      '/api/logs/delete',
      body: <String, Object?>{'ids': ids},
    );
    return (payload['removed'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<int> deleteByFilter(SystemLogFilter filter) async {
    final body = <String, Object?>{'all_matching': true};
    if (filter.type.isNotEmpty) body['type'] = filter.type;
    if (filter.q.isNotEmpty) body['q'] = filter.q;
    final start = _formatDate(filter.startDate);
    if (start != null) body['start_date'] = start;
    final end = _formatDate(filter.endDate);
    if (end != null) body['end_date'] = end;
    final payload = await _client.postJson('/api/logs/delete', body: body);
    return (payload['removed'] as num?)?.toInt() ?? 0;
  }

  void _applyFilter(Map<String, Object?> query, SystemLogFilter filter) {
    if (filter.type.isNotEmpty) query['type'] = filter.type;
    if (filter.q.isNotEmpty) query['q'] = filter.q;
    final start = _formatDate(filter.startDate);
    if (start != null) query['start_date'] = start;
    final end = _formatDate(filter.endDate);
    if (end != null) query['end_date'] = end;
  }

  static String? _formatDate(DateTime? value) {
    if (value == null) return null;
    final y = value.year.toString().padLeft(4, '0');
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
