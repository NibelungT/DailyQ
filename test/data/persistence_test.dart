import 'package:dailyq/data/store.dart';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:dailyq/data/disk_store_io.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 复现「编辑/删除后重启又变回原样」：验证写入是否真的落盘、重启能否读回。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 每条用例都从干净状态开始：清掉 mock 存储和磁盘兜底文件
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final base = Directory.systemTemp.path;
    for (final name in ['dailyq/dailyq-state.json', 'fastlog/fastlog-state.json']) {
      final f = File('$base${Platform.pathSeparator}'
          '${name.replaceAll('/', Platform.pathSeparator)}');
      if (f.existsSync()) f.deleteSync();
    }
  });

  test('PERSIST-01 编辑事件后重启仍在', () async {
    final a = AppStore(useDisk: false);
    await a.init();
    expect(a.eventById('e1'), isNotNull, reason: '首次启动应有种子数据');

    a.upsertEvent(a.eventById('e1')!.copyWith(name: '改过的名字'));
    await pumpEventQueue();

    final raw = (await SharedPreferences.getInstance())
        .getString(AppStore.storageKey);
    expect(raw, isNotNull, reason: '编辑后必须真的写进存储');

    final b = AppStore(useDisk: false);
    await b.init();
    expect(b.eventById('e1')!.name, '改过的名字', reason: '重启后应读到新名字');
  });

  test('PERSIST-02 删除记录后重启仍是删除态', () async {
    final a = AppStore(useDisk: false);
    await a.init();
    final target = a.logsForEvent('e4').first;
    a.softDeleteLog(target.id);
    await pumpEventQueue();

    final b = AppStore(useDisk: false);
    await b.init();
    expect(b.logsForEvent('e4').length, a.logsForEvent('e4').length);
    expect(b.logsForEvent('e4').any((l) => l.id == target.id), isFalse);
  });

  test('PERSIST-03 删除事件后重启不复活', () async {
    final a = AppStore(useDisk: false);
    await a.init();
    a.removeEvent('e1');
    await pumpEventQueue();

    final b = AppStore(useDisk: false);
    await b.init();
    expect(b.eventById('e1'), isNull);
  });

  test('PERSIST-04 设置项同样保留', () async {
    final a = AppStore(useDisk: false);
    await a.init();
    a.setWeekStart(0);
    await pumpEventQueue();

    final b = AppStore(useDisk: false);
    await b.init();
    expect(b.weekStart, 0);
  });

  test('PERSIST-05 文件兜底能写能读（插件失效时的保命通道）', () async {
    const payload = '{"schemaVersion":1,"events":[],"logs":[]}';
    expect(await writeStateRaw(payload), isTrue, reason: '文件写入应成功');
    expect(await readStateRaw(), payload, reason: '读回的内容应与写入一致');
  });

  test('PERSIST-06 导出后导入可完整恢复', () async {
    final a = AppStore(useDisk: false);
    await a.init();
    a.upsertEvent(a.eventById('e1')!.copyWith(name: '改过的名字'));
    await a.flush();
    final backup = a.exportJson();

    final b = AppStore(useDisk: false);
    await b.init();
    b.removeEvent('e1');
    await b.flush();
    expect(b.eventById('e1'), isNull);

    final result = await b.importJson(backup);
    expect(result.ok, isTrue, reason: result.message);
    expect(b.eventById('e1')!.name, '改过的名字');
    expect(b.logs.length, a.logs.length);
  });

  test('PERSIST-07 非备份内容会被拒绝', () async {
    final a = AppStore(useDisk: false);
    await a.init();
    final bad = await a.importJson('{"foo":1}');
    expect(bad.ok, isFalse);
    final broken = await a.importJson('not json');
    expect(broken.ok, isFalse);
  });

  test('PERSIST-08 改名前的文件能迁移到新名字', () async {
    final base = Directory.systemTemp;
    final legacyDir = Directory('${base.path}${Platform.pathSeparator}fastlog');
    legacyDir.createSync(recursive: true);
    final legacy = File(
      '${legacyDir.path}${Platform.pathSeparator}fastlog-state.json',
    );
    legacy.writeAsStringSync(
      '{"schemaVersion":1,"events":[],"logs":[],"weekStart":0}',
    );

    final s = AppStore();
    await s.init();
    await s.flush();
    expect(s.weekStart, 0, reason: '应读到旧文件里的设置');

    final migrated = File(
      '${base.path}${Platform.pathSeparator}dailyq${Platform.pathSeparator}dailyq-state.json',
    );
    expect(migrated.existsSync(), isTrue, reason: '应立刻写出新文件');

    legacy.deleteSync();
    if (migrated.existsSync()) migrated.deleteSync();
  });
}
