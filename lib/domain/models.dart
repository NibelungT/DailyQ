/// 领域模型。字段与 `docs/DATA.md` 一一对应，不得擅自增删。
library;

enum MetricType { count, duration, value }

enum ResetCycle { none, daily, weekly, monthly }

enum Achievement { none, partial, done, over }

enum HomeFilter { all, today, archived }

enum LogBlock { future, tooOld, limit }

extension MetricTypeX on MetricType {
  String get label => switch (this) {
        MetricType.count => '次数',
        MetricType.duration => '时间',
        MetricType.value => '数值',
      };

  String get defaultUnit => switch (this) {
        MetricType.count => '次',
        MetricType.duration => '分钟',
        MetricType.value => '毫升',
      };

  double get defaultStep => switch (this) {
        MetricType.count => 1,
        MetricType.duration => 5,
        MetricType.value => 250,
      };
}

extension ResetCycleX on ResetCycle {
  String get label => switch (this) {
        ResetCycle.none => '无',
        ResetCycle.daily => '每天',
        ResetCycle.weekly => '每周',
        ResetCycle.monthly => '每月',
      };
}

class HabitEvent {
  const HabitEvent({
    required this.id,
    required this.name,
    required this.emoji,
    required this.colorValue,
    required this.metricType,
    required this.resetCycle,
    required this.startDate,
    this.groupId,
    this.desc = '',
    this.target,
    this.step = 1,
    this.unit = '次',
    this.endDate,
    this.quickLog = false,
    this.dailyLimit = 0,
    this.showCheck = true,
    this.archived = false,
    this.remind = false,
    this.follow = false,
    this.weekdays = const [],
    this.createdAt,
  });

  final String id;
  final String name;
  final String emoji;
  final int colorValue;
  final String desc;
  final String? groupId;
  final MetricType metricType;
  final ResetCycle resetCycle;
  final double? target;
  final double step;
  final String unit;
  final DateTime startDate;
  final DateTime? endDate;
  final bool quickLog;
  final int dailyLimit;
  final bool showCheck;
  final bool archived;
  final bool remind;
  final bool follow;

  /// 只在「每天」周期下生效：需要触发的星期（1=周一 … 7=周日）。
  /// 空列表表示每天，不做限制。
  final List<int> weekdays;

  final DateTime? createdAt;

  bool get hasTarget => target != null && target! > 0;

  /// 指定星期是否包含这一天（未指定时视为每天）。
  bool isScheduledOn(DateTime day) =>
      weekdays.isEmpty || weekdays.contains(day.weekday);

  /// 「周一、周三」这样的短标签，未指定时返回「每天」。
  String get weekdayLabel {
    if (weekdays.isEmpty) return '每天';
    const names = ['一', '二', '三', '四', '五', '六', '日'];
    final sorted = [...weekdays]..sort();
    return sorted.map((w) => '周${names[(w - 1).clamp(0, 6)]}').join('、');
  }

  HabitEvent copyWith({
    String? name,
    String? emoji,
    int? colorValue,
    String? desc,
    String? groupId,
    bool clearGroup = false,
    ResetCycle? resetCycle,
    double? target,
    bool clearTarget = false,
    double? step,
    String? unit,
    DateTime? startDate,
    DateTime? endDate,
    bool clearEndDate = false,
    bool? quickLog,
    int? dailyLimit,
    bool? showCheck,
    bool? archived,
    bool? remind,
    bool? follow,
    List<int>? weekdays,
  }) {
    return HabitEvent(
      id: id,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      colorValue: colorValue ?? this.colorValue,
      desc: desc ?? this.desc,
      groupId: clearGroup ? null : (groupId ?? this.groupId),
      metricType: metricType,
      resetCycle: resetCycle ?? this.resetCycle,
      target: clearTarget ? null : (target ?? this.target),
      step: step ?? this.step,
      unit: unit ?? this.unit,
      startDate: startDate ?? this.startDate,
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      quickLog: quickLog ?? this.quickLog,
      dailyLimit: dailyLimit ?? this.dailyLimit,
      showCheck: showCheck ?? this.showCheck,
      archived: archived ?? this.archived,
      remind: remind ?? this.remind,
      follow: follow ?? this.follow,
      weekdays: weekdays ?? this.weekdays,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'emoji': emoji,
        'color': colorValue,
        'desc': desc,
        'groupId': groupId,
        'metricType': metricType.name,
        'resetCycle': resetCycle.name,
        'target': target,
        'step': step,
        'unit': unit,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate?.toIso8601String(),
        'quickLog': quickLog,
        'dailyLimit': dailyLimit,
        'showCheck': showCheck,
        'archived': archived,
        'remind': remind,
        'follow': follow,
        'weekdays': weekdays,
        'createdAt': createdAt?.toIso8601String(),
      };

  static HabitEvent fromJson(Map<String, dynamic> j) => HabitEvent(
        id: j['id'] as String,
        name: j['name'] as String,
        emoji: j['emoji'] as String? ?? '💪',
        colorValue: (j['color'] as num).toInt(),
        desc: j['desc'] as String? ?? '',
        groupId: j['groupId'] as String?,
        metricType: MetricType.values.byName(j['metricType'] as String),
        resetCycle: ResetCycle.values.byName(j['resetCycle'] as String),
        target: (j['target'] as num?)?.toDouble(),
        step: (j['step'] as num?)?.toDouble() ?? 1,
        unit: j['unit'] as String? ?? '次',
        startDate: DateTime.parse(j['startDate'] as String),
        endDate: j['endDate'] == null ? null : DateTime.parse(j['endDate'] as String),
        quickLog: j['quickLog'] as bool? ?? false,
        dailyLimit: (j['dailyLimit'] as num?)?.toInt() ?? 0,
        showCheck: j['showCheck'] as bool? ?? true,
        archived: j['archived'] as bool? ?? false,
        remind: j['remind'] as bool? ?? false,
        follow: j['follow'] as bool? ?? false,
        weekdays: ((j['weekdays'] as List?) ?? const [])
            .map((e) => (e as num).toInt())
            .toList(),
        createdAt: j['createdAt'] == null ? null : DateTime.parse(j['createdAt'] as String),
      );
}

class LogEntry {
  const LogEntry({
    required this.id,
    required this.eventId,
    required this.occurredAt,
    required this.dayKey,
    required this.value,
    this.note = '',
    this.deletedAt,
  });

  final String id;
  final String eventId;
  final DateTime occurredAt;

  /// 归属日，写入时按设备本地时区定格（SYS-R-01）。
  final String dayKey;
  final double value;
  final String note;
  final DateTime? deletedAt;

  LogEntry copyWith({DateTime? deletedAt, bool clearDeleted = false}) => LogEntry(
        id: id,
        eventId: eventId,
        occurredAt: occurredAt,
        dayKey: dayKey,
        value: value,
        note: note,
        deletedAt: clearDeleted ? null : (deletedAt ?? this.deletedAt),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'eventId': eventId,
        'occurredAt': occurredAt.toIso8601String(),
        'dayKey': dayKey,
        'value': value,
        'note': note,
        'deletedAt': deletedAt?.toIso8601String(),
      };

  static LogEntry fromJson(Map<String, dynamic> j) => LogEntry(
        id: j['id'] as String,
        eventId: j['eventId'] as String,
        occurredAt: DateTime.parse(j['occurredAt'] as String),
        dayKey: j['dayKey'] as String,
        value: (j['value'] as num).toDouble(),
        note: j['note'] as String? ?? '',
        deletedAt: j['deletedAt'] == null ? null : DateTime.parse(j['deletedAt'] as String),
      );
}

class LogOutcome {
  const LogOutcome.ok(this.logId) : block = null;
  const LogOutcome.blocked(this.block) : logId = null;

  final String? logId;
  final LogBlock? block;

  bool get ok => logId != null;
}
