# DailyQ · 打卡记录 App（Flutter）

本地优先的打卡应用：建事件 → 点一下记录 → 首页看今日进度 → 统计看连续性。
数据存在设备本地，无账号、无网络依赖。

## 跑起来

```bash
flutter pub get
flutter run                # 选设备；Web / Android 均已配置
flutter test               # 68 个用例（39 领域 + 8 存储 + 21 界面）
flutter analyze            # 0 issue
```

国内网络注意两件事：
1. `pub get` 卡住 → `export PUB_HOSTED_URL=https://pub.flutter-io.cn`、`FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn`
2. `flutter test` 报 `WebSocketException` → 代理拦了本机连接，用 `NO_PROXY=127.0.0.1,localhost flutter test`

## 发布

仓库只放源码，安装包走 Releases，不打进 git 历史。

```bash
flutter build apk --release --target-platform android-arm64   # 本地出包
git tag v1.0.0 && git push origin v1.0.0                      # 触发 CI 发布
```

`.github/workflows/release.yml` 会构建 arm64 包并把 APK 与 SHA-256 附到对应 Release。

要让 CI 用正式签名，在仓库 Secrets 配置四项：`KEYSTORE_BASE64`（keystore 文件的 base64）、`KEYSTORE_PASSWORD`、`KEY_ALIAS`、`KEY_PASSWORD`。没配置时产出 debug 包，只能自测，**不能覆盖已安装的正式版**。

## 已实现

| 页面 | 能力 |
|---|---|
| 首页 | 默认「今日」，可与所有 / 已归档、以及按分组切换；卡片进度与计数；点圆圈快速记录；长按菜单（编辑 / 归档 / 置顶 / 删除）；3 秒撤销浮层 |
| 记录面板 | 日期与时间独立选择，跨天提示；次数步进器 / 时长计时器 / 数值键盘加快捷加量；备注；上限与未来时间拦截 |
| 新增 / 编辑 | 图标、名称、说明、主题色、分组；类型联动默认单位与步长，**单位可点开选预设或自己填**；类型创建后锁定；目标、每次记录、重置周期；**每天周期可指定重复星期**；三个开关；日上限；起止日期 |
| 统计 | 总次数 / 总天数全局累计；日 / 周 / 月 / 年切换；周期导航（禁止未来）；点阵热度；排序、分组筛选、清空记录；点行进入详情 |
| 事件详情 | 连续天数、本周期累计；月历热力图（今天描边、未来置灰、可翻上月）；规则摘要；记录流水（倒序、可删单条并撤销）；归档 / 记录一次 |
| 设置 | 周起始日（真正影响周视图与每周重置）；每日提醒开关与时间；导出 CSV/JSON、**从 JSON 导入**；存储自检；清空记录；重置演示数据 |

## 结构

```
lib/
  domain/     纯 Dart：周期、聚合、拦截、可见性、连续天数（无 UI 依赖，可直接测）
  data/       store.dart（状态 + 双通道存储 + 导入导出）、disk_store_io/stub（文件兜底）
  features/   home / record / event（表单 + 详情）/ stats / settings
  ui/         共用组件与浮层提示
  app/        主题与 StoreScope
test/
  domain/     39 条规则用例（编号对齐 docs/SPEC.md）
  data/       8 条持久化与迁移用例
  ui/         21 条进入式冒烟测试
```

设计约定见 `AGENTS.md`；交互规则见 `docs/SPEC.md`；数据模型见 `docs/DATA.md`。

## 图标

母版 `assets/branding/icon-1024.png`：白底 + 黑色 Q+ 标志，源图是 `assets/branding/icon-source.jpg`。

整套图标（Web favicon / PWA 192·512·maskable、Android 传统 5 档 + 自适应前景 5 档）由脚本生成。脚本不依赖 Pillow：用 Chrome 的 canvas 缩放，再用纯 Python 裁剪输出。换图后重跑：

```bash
python tool/gen_icon_q.py
```

生成物：

| 位置 | 用途 |
|---|---|
| `assets/branding/icon-1024.png` | 母版（商店素材 / 文档） |
| `assets/branding/icon-source.jpg` | 原始素材（换图时替换这一张） |
| `web/favicon.png`、`web/icons/*` | 浏览器标签、PWA 安装图标 |
| `android/.../mipmap-*/ic_launcher.png` | 传统图标（自带圆角） |
| `android/.../mipmap-*/ic_launcher_foreground.png` | 自适应图标前景 |
| `android/.../mipmap-anydpi-v26/ic_launcher.xml` | 自适应图标声明（背景取 `@color/ic_launcher_background`） |

启动背景也改成了深色 `#0E1116` 并居中显示图标，避免从深色 App 闪一下白屏。

## 已知边界（v1）

云同步 / 账号 / 分享 / 小组件 / 图片附件 / 浅色主题。
提醒是**应用内提醒条**（开关 + 时间 + 当天可关闭），没有接系统推送；附件按钮仍只留位。
"更多"页里的分组管理未做，分组目前只能在新建/编辑里选。
