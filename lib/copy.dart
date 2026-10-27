/// 所有面向用户的文案集中在这里，便于评审与替换。
class Copy {
  const Copy._();

  static const appName = 'DailyQ';

  static const filterAll = '所有';
  static const filterToday = '今日';
  static const filterArchived = '已归档';
  static const filterNew = '+ 新增';

  static const emptyHomeTitle = '还没有要记录的事';
  static const emptyHomeAction = '创建第一个事件';
  static const emptyArchived = '还没有归档的事件';
  static const emptyToday = '今日没有需要打卡的事件';
  static const emptyStats = '还没有记录，去首页开始第一次打卡';

  static const statTotalCount = '总次数';
  static const statTotalDays = '总天数';

  static const newEvent = '新增事件';
  static const editEvent = '编辑事件';

  static const recordTime = '记录时间';
  static const recordCount = '记录数量';
  static const recordDuration = '记录时长';
  static const recordValue = '记录数值';
  static const note = '备注';
  static const noteHint = '选填';
  static const submitRecord = '完成记录';

  static const fieldName = '事件名称';
  static const fieldDesc = '一句激励或事项备注';
  static const fieldType = '类型';
  static const fieldTarget = '目标';
  static const fieldStep = '每次记录';
  static const fieldCycle = '重置周期';
  static const fieldGroup = '分组';
  static const fieldStart = '开始时间';
  static const fieldEnd = '结束时间';
  static const noEndDate = '无结束日期';
  static const optional = '选填';

  static const swRemind = '定期提醒';
  static const swFollow = '跟进提醒';
  static const swQuick = '快速记录';
  static const swCheck = '显示对号';
  static const fieldLimit = '日打卡次数上限';
  static const noLimit = '不限';

  static const done = '已完成';
  static const undo = '撤销';
  static const save = '保存';
  static const cancel = '取消';
  static const delete = '删除';
  static const confirm = '确定';

  static String recorded(String value) => '已记录 · $value';
  static String completed(String name) => '已完成 · $name';
  static String backfilled(String md) => '已补记到 $md';
  static String limitReached(int n) => '今日记录已达上限（$n 次）';
  static const futureBlocked = '不能记录未来的时间';
  static const tooOldBlocked = '最多补记 30 天';
  static const typeLocked = '类型创建后不可修改';
  static const nameRequired = '请填写事件名称';
  static const targetPositive = '目标需大于 0';
  static const endBeforeStart = '结束时间不能早于开始时间';
  static const discardEdit = '放弃本次编辑？';
  static const discardRecord = '放弃本次记录？';
  static const attachUnavailable = '原型暂未开放附件';

  static String crossDay(String md) => '该记录将计入 $md';
  static String clearConfirm(int n) => '将删除全部 $n 条记录，事件本身保留。此操作不可恢复。';
  static String movedToArchive(String name) => '已归档 · $name';
  static String restored(String name) => '已恢复 · $name';
  static String created(String name) => '已创建「$name」';
  static String deletedEvent(String name) => '已删除 · $name';
  static const pinned = '已置顶';
  static const cleared = '已清空记录';
  static const resetDone = '已重置演示数据';
  static const clearedNoData = '还没有任何记录';
  static const cannotFuture = '不能查看未来';
}
