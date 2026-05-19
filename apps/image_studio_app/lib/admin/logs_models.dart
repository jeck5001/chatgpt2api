class SystemLogEntry {
  const SystemLogEntry({
    required this.id,
    required this.time,
    required this.type,
    this.summary = '',
    this.detail = const <String, Object?>{},
  });

  final String id;
  final String time;
  final String type;
  final String summary;
  final Map<String, Object?> detail;

  factory SystemLogEntry.fromJson(Map<String, Object?> json) {
    final detail = json['detail'];
    return SystemLogEntry(
      id: (json['id'] ?? '').toString(),
      time: (json['time'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      summary: (json['summary'] ?? '').toString(),
      detail: detail is Map
          ? Map<String, Object?>.from(detail)
          : const <String, Object?>{},
    );
  }
}

class SystemLogPage {
  const SystemLogPage({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.hasMore,
  });

  final List<SystemLogEntry> items;
  final int total;
  final int page;
  final int pageSize;
  final bool hasMore;

  factory SystemLogPage.fromJson(Map<String, Object?> json) {
    final rawItems = json['items'];
    final items = <SystemLogEntry>[];
    if (rawItems is List) {
      for (final item in rawItems) {
        if (item is Map) {
          items.add(SystemLogEntry.fromJson(Map<String, Object?>.from(item)));
        }
      }
    }
    return SystemLogPage(
      items: items,
      total: (json['total'] as num?)?.toInt() ?? 0,
      page: (json['page'] as num?)?.toInt() ?? 1,
      pageSize: (json['page_size'] as num?)?.toInt() ?? items.length,
      hasMore: json['has_more'] == true,
    );
  }
}

class SystemLogFilter {
  const SystemLogFilter({
    this.type = '',
    this.q = '',
    this.startDate,
    this.endDate,
  });

  final String type;
  final String q;
  final DateTime? startDate;
  final DateTime? endDate;

  SystemLogFilter copyWith({
    String? type,
    String? q,
    DateTime? startDate,
    DateTime? endDate,
    bool clearStartDate = false,
    bool clearEndDate = false,
  }) {
    return SystemLogFilter(
      type: type ?? this.type,
      q: q ?? this.q,
      startDate: clearStartDate ? null : startDate ?? this.startDate,
      endDate: clearEndDate ? null : endDate ?? this.endDate,
    );
  }

  bool get isEmpty =>
      type.isEmpty && q.isEmpty && startDate == null && endDate == null;
}
