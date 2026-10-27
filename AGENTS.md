# AGENTS.md — DailyQ（Flutter）

> 仓库级指令，AI 编码助手开工前先读这一份，再看 `docs/`。

## 1. 一句话

本地优先的打卡 App：建事件 → 点一下记录 → 首页看今日进度 → 统计看连续性。
v1 只有本地存储，不做账号、同步、分享。

## 2. 技术栈（已落地，勿替换）

- Flutter 3.47 / Dart 3.13，Material 3，深色主题唯一
- 状态：`ChangeNotifier` + `InheritedNotifier`（`lib/app/scope.dart` 的 `StoreScope`），没有引入 Riverpod/Bloc
- 路由：`Navigator` + `MaterialPageRoute`，四个页面，不引入 go_router
- 持久化：`shared_preferences` 存 JSON 快照（key = `dailyq.state.v1`）
- 国际化：`flutter_localizations` + `intl`，日期选择器需 `Locale('zh','CN')`

```bash
flutter pub get
flutter run
flutter test
flutter analyze
dart format lib test
```

> 国内网络若 `pub get` 卡住：`export PUB_HOSTED_URL=https://pub.flutter-io.cn` 与 `FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn`。
> `flutter test` 报 `WebSocketException` 多半是代理拦截了本机连接：`NO_PROXY=127.0.0.1,localhost flutter test`。

## 3. 目录

```
lib/
  main.dart                  # 初始化 store → 注入 → MaterialApp
  app/theme.dart             # AppColors / AppRadius / AppSpace / AppDuration / inkFor
  app/scope.dart             # StoreScope（InheritedNotifier）
  copy.dart                  # 所有面向用户的文案
  domain/                    # 纯 Dart：无 flutter import、无 IO、无 DateTime.now()
    models.dart              # HabitEvent / LogEntry / 枚举 / LogOutcome
    period.dart              # periodStart / periodEnd / dateOnly
    stats.dart               # sumValue / currentValue / achievement / 进度 / 数字格式
    rules.dart               # toDayKey / countOnDay / checkCanLog / isVisibleOnHome
  data/store.dart            # AppStore：状态 + 持久化 + 用例 + 种子
  features/
    home/home_page.dart      # 首页 + EventCard + CountCircle + 操作菜单 + 提醒条
    record/record_sheet.dart # 记录弹层（三种计量类型）
    event/event_form_page.dart    # 新建 / 编辑
    event/event_detail_page.dart  # 详情：连续天数、月历热力图、记录流水
    stats/stats_page.dart
    settings/settings_page.dart   # 周起始日、提醒、导出、清空/重置
  ui/widgets.dart            # AppChip / AppSegmented / AppSwitch / PrimaryButton / SheetShell
test/domain/domain_test.dart # 37 条用例，测试名带规则编号
test/ui/smoke_test.dart      # 14 条进入式冒烟测试
```

## 4. 不可违反的十条

1. **归属日只由 `occurredAt` 决定**，绝不用 `createdAt` 或"现在"反推。
2. **周期清零是惰性计算**：读时按 `periodStart` 求和，禁止用 Timer 改数据。
3. **`metricType` 创建后不可变**：表单置灰 + `AppStore.upsertEvent` 二次强制。
4. **累加不覆盖**：同一事件多条记录求和。
5. **记录 id 客户端生成**，`dedupeLogs` 按 id 幂等。
6. **颜色只能来自 `AppColors` 或事件自身颜色**，widget 里不许出现 `Color(0xFF...)` 字面量（`theme.dart` 除外）。
7. **删除可逆**：快速记录/提交后 3 秒撤销；清空记录需二次确认并显示条数。
8. **列表四态**：空、加载、正常、错误。当前实现里本地读取是同步的，加载态由 `store.ready` 兜底，新增异步数据源时必须补齐。
9. **业务规则只写在 `lib/domain/`**，widget 里出现 `if (cycle == ResetCycle.weekly)` = 返工。
10. **提交前 `flutter test` + `flutter analyze` 双绿**，红了不许提交，不许注释测试。

## 5. Flutter 约定

- `lib/domain/` 禁止 `import 'package:flutter/...'`、`DateTime.now()`、`SharedPreferences`；时间与数据一律传参。
- 不在 `build()` 里做重计算或 IO；派生值从 `AppStore` 读。
- 长按用 `GestureDetector(onLongPress:)`；长按菜单里的点击不会再触发 `onTap`。
- 触感只用 `HapticFeedback`，不引第三方震动包。
- 底部弹层统一 `showModalBottomSheet(isScrollControlled: true, backgroundColor: transparent)` + `SheetShell`，圆角与最大高度由 `SheetShell` 控制。
- 键盘避让用 `MediaQuery.viewInsetsOf(context)`，不写死高度。
- 列表用 `ListView.builder`；一屏内不要出现 30 个非懒加载卡片。
- 动效时长取 `AppDuration`（panel 320ms / progress 450ms / pop 420ms），不要各处自定。
- 弹层内的提示用**弹层自己的** `_hint` 状态，不要用 `showToast`——`SnackBar` 会被弹层遮住。
- 提醒是**应用内**的（首页一条可关闭的提示条），不要引入 `flutter_local_notifications` 做系统推送，v1 不承诺后台提醒。
- `weekStart` 影响三处：统计周视图区间、每周重置窗口、详情页日历列顺序。改任何一处都要对齐另外两处。

## 6. 数据是唯一真相源

`lib/domain/models.dart` 与 `docs/DATA.md` 的字段必须一一对应。加字段要同时改：
模型 → `toJson/fromJson` → 种子数据 → `docs/DATA.md` → 迁移说明。少一步就会在读旧数据时崩。

## 7. 视觉基线

`../handoff/参考/原型.html` 与 `../handoff/参考/截图/` 是交互参照。色值以 `lib/app/theme.dart` 为准。

## 8. v1 不做

账号与同步 / 分享 / 小组件 / 系统推送（提醒只做应用内提示条）/ 图片附件（只留 UI 位）/ 分组管理页（分组在表单里选）/ 浅色主题 / 多语言。
