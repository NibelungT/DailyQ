import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dailyq/data/store.dart';
import 'package:dailyq/domain/models.dart';
import 'package:dailyq/features/record/record_sheet.dart';
import 'package:dailyq/main.dart';
import 'package:dailyq/ui/widgets.dart';

Future<AppStore> _boot(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final store = AppStore(useDisk: false);
  await store.init();
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(DailyQApp(store: store));
  await tester.pumpAndSettle();
  return store;
}

void main() {
  testWidgets('分组筛选只显示该分组的事件', (tester) async {
    await _boot(tester);

    // 分组 chip 在横向滚动条靠后位置，先滚到可见
    await tester.scrollUntilVisible(
      find.text('学习'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('学习'));
    await tester.pumpAndSettle();

    expect(find.text('读十页书'), findsOneWidget);
    expect(find.text('做一组拉伸'), findsNothing);
    expect(find.text('阅读三十分钟'), findsNothing);
    expect(find.text('喝水'), findsNothing);
  });

  testWidgets('首页渲染种子数据与三个筛选', (tester) async {
    await _boot(tester);

    expect(find.text('DailyQ'), findsOneWidget);
    expect(find.text('读十页书'), findsOneWidget);
    expect(find.text('做一组拉伸'), findsOneWidget);
    expect(find.text('阅读三十分钟'), findsOneWidget);
    expect(find.text('喝水'), findsOneWidget);

    // 副标题格式：类型 · 重置：周期 · 当前/目标
    expect(find.text('次数 · 重置：每天 · 0/1'), findsOneWidget);
    expect(find.text('时间 · 重置：每天 · 0/30'), findsOneWidget);
    expect(find.text('数值 · 重置：每天 · 0/2,000'), findsOneWidget);

    await tester.tap(find.text('已归档'));
    await tester.pumpAndSettle();
    expect(find.text('还没有归档的事件'), findsOneWidget);
  });

  testWidgets('点圆圈快速记录，3 秒内可撤销', (tester) async {
    final store = await _boot(tester);
    final before = store.totalLogs;
    expect(before, 14);

    await tester.tap(find.byKey(const ValueKey('circle_e2')));
    await tester.pumpAndSettle();

    expect(store.totalLogs, before + 1);
    expect(store.currentOf(store.eventById('e2')!), 1);
    expect(find.text('撤销'), findsOneWidget);

    await tester.tap(find.text('撤销'));
    await tester.pumpAndSettle();

    expect(store.totalLogs, before);
    expect(store.currentOf(store.eventById('e2')!), 0);
  });

  testWidgets('进入首页默认选中今日', (tester) async {
    await _boot(tester);

    final today = tester.widget<AppChip>(find.widgetWithText(AppChip, '今日'));
    final all = tester.widget<AppChip>(find.widgetWithText(AppChip, '所有'));
    expect(today.selected, isTrue, reason: '今日应默认高亮');
    expect(all.selected, isFalse);
  });

  testWidgets('撤销条 3 秒后自动消失', (tester) async {
    await _boot(tester);

    await tester.tap(find.byKey(const ValueKey('circle_e2')));
    await tester.pumpAndSettle();
    expect(find.text('撤销'), findsOneWidget);

    // 3 秒后应自行收起，不需要用户操作
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.text('撤销'), findsNothing);
  });

  testWidgets('撤销条文字不带调试下划线', (tester) async {
    await _boot(tester);

    await tester.tap(find.byKey(const ValueKey('circle_e2')));
    await tester.pumpAndSettle();

    // 浮层若缺 Material 祖先，文字会被套上黄色双下划线
    final paragraph = tester.renderObject<RenderParagraph>(find.text('撤销'));
    expect(
      paragraph.text.style?.decoration,
      isNot(TextDecoration.underline),
      reason: 'Overlay 里必须补 Material 祖先',
    );
  });

  testWidgets('点卡片正文打开记录面板并可关闭', (tester) async {
    await _boot(tester);

    await tester.tap(find.text('做一组拉伸'));
    await tester.pumpAndSettle();

    expect(find.text('记录时间'), findsOneWidget);
    await tester.tap(find.descendant(
      of: find.byType(RecordSheet),
      matching: find.byIcon(Icons.close_rounded),
    ));
    await tester.pumpAndSettle();
    expect(find.text('记录时间'), findsNothing);
  });

  testWidgets('记录面板可提交一次时长记录', (tester) async {
    final store = await _boot(tester);
    final before = store.totalLogs;

    await tester.tap(find.text('阅读三十分钟'));
    await tester.pumpAndSettle();
    expect(find.text('记录时长'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add_rounded).last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('完成记录'));
    await tester.pumpAndSettle();

    expect(store.totalLogs, before + 1);
    expect(find.text('记录时间'), findsNothing);
  });

  testWidgets('新建事件页可打开并保存', (tester) async {
    final store = await _boot(tester);
    final before = store.events.length;

    await tester.tap(find.byIcon(Icons.add_rounded).first);
    await tester.pumpAndSettle();
    expect(find.text('新增事件'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '晨间拉伸');
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.check_rounded).first);
    await tester.pumpAndSettle();

    expect(store.events.length, before + 1);
    expect(find.text('晨间拉伸'), findsOneWidget);
  });

  testWidgets('统计页展示汇总与点阵', (tester) async {
    final store = await _boot(tester);

    await tester.tap(find.byIcon(Icons.bar_chart_rounded));
    await tester.pumpAndSettle();

    expect(find.text('总次数'), findsOneWidget);
    expect(find.text('总天数'), findsOneWidget);
    expect(find.text('${store.totalLogs}'), findsWidgets);

    await tester.tap(find.text('月'));
    await tester.pumpAndSettle();
    expect(find.text('总次数'), findsOneWidget);
  });

  testWidgets('长按卡片弹出操作菜单', (tester) async {
    await _boot(tester);

    await tester.longPress(find.text('喝水'));
    await tester.pumpAndSettle();

    expect(find.text('编辑事件'), findsOneWidget);
    expect(find.text('归档到「已归档」'), findsOneWidget);
    expect(find.text('删除事件'), findsOneWidget);
  });

  testWidgets('归档后从首页消失', (tester) async {
    final store = await _boot(tester);

    await tester.longPress(find.text('喝水'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('归档到「已归档」'));
    await tester.pumpAndSettle();

    expect(find.text('喝水'), findsNothing);
    expect(store.eventById('e4')!.archived, isTrue);

    await tester.tap(find.text('已归档'));
    await tester.pumpAndSettle();
    expect(find.text('喝水'), findsOneWidget);
  });

  testWidgets('达到日上限时拦截记录', (tester) async {
    final store = await _boot(tester);
    final e2 = store.eventById('e2')!;
    store.upsertEvent(e2.copyWith(dailyLimit: 1));
    await tester.pumpAndSettle();

    final outcome = store.quickLog('e2');
    expect(outcome.ok, isTrue);
    final second = store.quickLog('e2');
    expect(second.ok, isFalse);
    expect(second.block, LogBlock.limit);
  });

  testWidgets('首页提醒条显示并可当天关闭', (tester) async {
    final store = await _boot(tester);
    expect(store.pendingTodayCount, 4);
    expect(find.textContaining('件事没完成'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close_rounded).first);
    await tester.pumpAndSettle();

    expect(find.textContaining('件事没完成'), findsNothing);
    expect(store.reminderVisible, isFalse);
  });

  testWidgets('长按进入事件详情：日历与流水', (tester) async {
    await _boot(tester);

    await tester.longPress(find.text('喝水'));
    await tester.pumpAndSettle();
    expect(find.text('查看详情'), findsOneWidget);

    await tester.tap(find.text('查看详情'));
    await tester.pumpAndSettle();

    expect(find.text('事件详情'), findsOneWidget);
    expect(find.text('打卡日历'), findsOneWidget);
    expect(find.text('连续'), findsOneWidget);
    expect(find.text('记录一次'), findsOneWidget);

    await tester.drag(find.byType(ListView).first, const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(find.text('记录流水'), findsOneWidget);
  });

  testWidgets('从统计行进入事件详情', (tester) async {
    await _boot(tester);

    await tester.tap(find.byIcon(Icons.bar_chart_rounded));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('阅读三十分钟'));
    await tester.pumpAndSettle();

    expect(find.text('事件详情'), findsOneWidget);
    expect(find.text('打卡日历'), findsOneWidget);
  });

  testWidgets('设置页可改周起始日并切换提醒', (tester) async {
    final store = await _boot(tester);

    await tester.tap(find.byIcon(Icons.grid_view_rounded));
    await tester.pumpAndSettle();
    expect(find.text('设置'), findsOneWidget);

    await tester.tap(find.text('每周从'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('周日开始'));
    await tester.pumpAndSettle();
    expect(store.weekStart, 0);
    expect(find.text('周日开始'), findsOneWidget);

    await tester.tap(find.byType(AppSwitch).first);
    await tester.pumpAndSettle();
    expect(store.reminderOn, isFalse);
  });

  testWidgets('每天周期可以指定重复星期', (tester) async {
    final store = await _boot(tester);

    await tester.tap(find.byIcon(Icons.add_rounded).first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '晨跑');
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('重复星期'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('重复星期'), findsOneWidget);

    await tester.tap(find.text('三'));
    await tester.pumpAndSettle();
    expect(find.text('每周 1 天'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.check_rounded).first);
    await tester.pumpAndSettle();

    expect(store.events.first.name, '晨跑');
    expect(store.events.first.weekdays, [DateTime.wednesday]);
  });

  testWidgets('新建事件可改单位并保存', (tester) async {
    final store = await _boot(tester);

    await tester.tap(find.byIcon(Icons.add_rounded).first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '背单词');
    await tester.pumpAndSettle();

    // 点目标后面的单位胶囊（默认「次」）
    await tester.tap(find.text('次').first);
    await tester.pumpAndSettle();
    expect(find.text('单位'), findsOneWidget);

    await tester.tap(find.text('个'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.check_rounded).first);
    await tester.pumpAndSettle();

    expect(store.events.first.name, '背单词');
    expect(store.events.first.unit, '个');
  });

  testWidgets('自定义单位可用', (tester) async {
    final store = await _boot(tester);

    await tester.tap(find.byIcon(Icons.add_rounded).first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '刷题');
    await tester.pumpAndSettle();

    await tester.tap(find.text('次').first);
    await tester.pumpAndSettle();

    final unitField = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.byType(TextField),
    );
    await tester.enterText(unitField.first, '套');
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.check_rounded).first);
    await tester.pumpAndSettle();

    expect(store.events.first.unit, '套');
  });

  testWidgets('详情页删除单条记录后可撤销', (tester) async {
    final store = await _boot(tester);
    final before = store.logsForEvent('e4');
    expect(before, isNotEmpty);

    await tester.longPress(find.text('喝水'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('查看详情'));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView).first, const Offset(0, -700));
    await tester.pumpAndSettle();

    final target = before.first;
    await tester.tap(find.byKey(ValueKey('del_${target.id}')));
    await tester.pumpAndSettle();

    expect(store.logsForEvent('e4').length, before.length - 1);
    expect(find.text('撤销'), findsOneWidget);

    await tester.tap(find.text('撤销'));
    await tester.pumpAndSettle();
    expect(store.logsForEvent('e4').length, before.length);
  });
}
