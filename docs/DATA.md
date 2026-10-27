# DATA.md — 数据模型与纯函数

> 本文件是**唯一真相源**。字段名、类型、校验规则不得擅自更改。
> `src/domain/` 下的函数签名照抄这里，测试用例照抄第 4 节的表。

## 1. 类型定义

```ts
export type MetricType = 'count' | 'duration' | 'value';
export type ResetCycle = 'none' | 'daily' | 'weekly' | 'monthly';
export type WeekStart = 0 | 1; // 0=周日, 1=周一（默认 1）

export interface HabitEvent {
  id: string;              // 'e_xxxxxxxx'
  name: string;            // 1..20 字符
  emoji: string;           // 单个 emoji 字符
  color: string;           // '#RRGGBB'，只能取 theme 调色板中的值
  groupId: string | null;  // null = 未分组
  metricType: MetricType;  // 创建后不可变
  target: number | null;   // null = 只累计不判定；> 0
  step: number;            // 每次记录默认值，>= 0
  unit: string;            // '次' | '分钟' | '毫升' | 自定义
  resetCycle: ResetCycle;
  startDate: string;       // 'YYYY-MM-DD'，本地日
  endDate: string | null;  // 'YYYY-MM-DD'
  quickLog: boolean;       // 点圆圈直接记录
  dailyLimit: number;      // 0 = 不限；1..99
  showCheck: boolean;      // 达成后显示对勾
  archived: boolean;
  sortIndex: number;       // 越小越靠前；置顶时设为 min-1
  createdAt: string;       // ISO8601
  updatedAt: string;
}

export interface LogEntry {
  id: string;              // 客户端 UUID，幂等键
  eventId: string;
  occurredAt: string;      // ISO8601，带本地偏移，如 2026-10-21T13:38:00+08:00
  dayKey: string;          // 'YYYY-MM-DD'，写入时由 occurredAt 派生并落库
  value: number;           // > 0
  note: string;            // '' 或 1..500
  attachments: string[];   // v1 恒为 []
  deletedAt: string | null;// 软删除时间
  createdAt: string;
}

export interface AppState {
  schemaVersion: 1;
  events: HabitEvent[];
  logs: LogEntry[];
  settings: { weekStart: WeekStart };
}
```

**为什么存 `dayKey`**：归属日要在写入时用设备时区定格，之后用户改时区或跨时区旅行，历史统计不漂移（SYS-R-01）。查询一律用 `dayKey`，不要现算。

## 2. 纯函数（`src/domain/`）

```ts
// period.ts
periodStart(cycle: ResetCycle, now: Date, weekStart?: WeekStart): Date | null;
// 返回 null 表示 none（不重置）

// stats.ts
sumValue(logs: LogEntry[], eventId: string, from: Date | null, to: Date): number;
currentValue(event: HabitEvent, logs: LogEntry[], now: Date): number;
progressRatio(event: HabitEvent, current: number): number; // 0..1
achievement(event: HabitEvent, current: number): 'none' | 'partial' | 'done' | 'over';

// rules.ts
canLog(event: HabitEvent, logs: LogEntry[], at: Date, now?: Date): { ok: boolean; reason?: 'LIMIT' | 'FUTURE' | 'TOO_OLD' };
countOnDay(logs: LogEntry[], eventId: string, dayKey: string): number;
toDayKey(d: Date): string;                    // 本地时区的 YYYY-MM-DD
isVisibleOnHome(event: HabitEvent, filter: 'all' | 'today' | 'archived', now: Date): boolean;
```

要求：
- 全部**纯函数**，不读 `Date.now()`、不读写 store、不发请求。时间一律作为参数传入。
- 有副作用的部分（写日志、去重、撤销）放在 `src/store/`，但必须调用上面的函数做判定。

## 3. 存储

- 实现：`shared_preferences`（Flutter 侧已落地于 `lib/data/store.dart`；Web 走 localStorage）
- 键：`dailyq.state.v1`
- 值：`AppState` 的 JSON 快照（v1 数据量小，整存整取足够）
- 写入策略：**每次状态变更后整包落盘**；写失败不阻塞交互，下一次变更重试
- 首次启动：写入种子数据（4 个事件 + 最近 6 天示例记录，今天的记录为空）
- 迁移：`schemaVersion` 不等于 1 时，丢弃旧数据并重新种子（v1 允许粗暴迁移）

种子事件（照抄，便于对照原型）：

| id | emoji | name | type | target | step | unit | cycle | quickLog | showCheck | group |
|---|---|---|---|---|---|---|---|---|---|---|
| e1 | 📚 | 读十页书 | count | 1 | 1 | 次 | none | false | true | 学习 |
| e2 | 🧘 | 做一组拉伸 | count | 1 | 1 | 次 | daily | true | true | 健康 |
| e3 | 📖 | 阅读三十分钟 | duration | 30 | 5 | 分钟 | daily | false | true | 习惯 |
| e4 | 💧 | 喝水 | value | 2000 | 250 | 毫升 | daily | true | false | 健康 |

种子记录：e2 在近 6 天中的 5 天各 1 次；e3 在 4 天各 25–35 分钟；e4 在 7 天各 750–2250 毫升。**今天一律为空**，方便验证"首屏 0 状态"。

## 4. 测试向量（照抄成用例，这是最容易写错的地方）

### 4.1 periodStart

| # | cycle | now | 期望 |
|---|---|---|---|
| 1 | daily | 2026-10-21 13:00 | 2026-10-21 00:00 |
| 2 | weekly | 2026-10-21（周三） | 2026-10-19 00:00（周一） |
| 3 | weekly | 2026-10-19（周一）00:00 | 2026-10-19 00:00 |
| 4 | weekly | 2026-10-18（周日）23:59 | 2026-10-12 00:00 |
| 5 | weekly, weekStart=0 | 2026-10-21（周三） | 2026-10-18 00:00（周日） |
| 6 | monthly | 2026-10-21 | 2026-10-01 00:00 |
| 7 | none | 任意 | null |
| 8 | daily | 2026-03-01（跨月） | 2026-03-01 00:00 |

### 4.2 归属与聚合

| # | 场景 | 期望 |
|---|---|---|
| 9 | 记录 occurredAt=2026-10-20T23:50，now=2026-10-21T00:10 | dayKey=2026-10-20；daily 的今日计数**不含**它 |
| 10 | 同上，用户把日期改到 10-20 后再改回 10-21 | dayKey 随最终值变，只有一条记录 |
| 11 | weekly 周期内 3 条记录，值 1/1/2 | currentValue=4 |
| 12 | 周期起点前 1 分钟有一条记录 | 不计入 |
| 13 | 两条记录 id 相同（重复提交） | 只保留一条（幂等） |

### 4.3 达成态

| # | target | current | 期望 |
|---|---|---|---|
| 14 | 1 | 0 | ratio=0, state=partial 之前 → 'none'（无任何记录） |
| 15 | 30 | 25 | ratio=0.83, state='partial' |
| 16 | 1 | 1 | ratio=1, state='done' |
| 17 | 1 | 3 | ratio=1（封顶）, state='over' |
| 18 | null | 7 | ratio=0, state='none'（无目标，不判定） |

### 4.4 拦截

| # | 场景 | 期望 |
|---|---|---|
| 19 | dailyLimit=1，当日已有 1 条 | canLog → {ok:false, reason:'LIMIT'} |
| 20 | dailyLimit=0 | 永不因上限拦截 |
| 21 | at 比 now 晚 2 分钟 | {ok:false, reason:'FUTURE'} |
| 22 | at 比 now 早 31 天 | {ok:false, reason:'TOO_OLD'} |
| 23 | dailyLimit=1，昨日已有 1 条，今天 0 条 | 允许（按归属日计） |

### 4.5 首页可见性

| # | 条件 | all | today | archived |
|---|---|---|---|---|
| 24 | 普通未归档事件 | ✅ | 仅 daily/none | ❌ |
| 25 | archived=true | ❌ | ❌ | ✅ |
| 26 | startDate 在明天 | ✅ | ❌ | ❌ |

## 5. 字段校验表（表单与 store 双层校验）

| 字段 | 规则 | 违反时 |
|---|---|---|
| name | trim 后 1..20 | 阻止保存，抖动提示 |
| emoji | 长度 1..4 的字符串 | 回退默认 💪 |
| unit | trim 后 1..6 字符；为空则回退该类型默认单位 | 回退默认单位 |
| color | 必须命中调色板 8 色之一 | 回退第 1 色 |
| target | null 或 > 0 的数字 | 阻止保存 |
| step | >= 0，且 `count` 类型 >= 1 | 阻止保存 |
| dailyLimit | 0..99 的整数 | 归 0 |
| startDate | 合法日期，≤ endDate | 阻止保存 |
| endDate | null 或 ≥ startDate | 清空并提示 |
| note | 0..500 字符 | 截断到 500 |
| value | `count` ≥ 1；其它 > 0 | 阻止提交 |

## 6. 主题 token（`src/theme/tokens.ts`）

```ts
export const colors = {
  bg: '#090A0D',
  card: '#14161B',
  cardAlt: '#191C22',
  line: '#23262E',
  text: '#F1F3F7',
  muted: '#8B93A1',
  dim: '#5A6270',
  accent: '#A3C644',
  teal: '#4FB286',
  cyan: '#38CFE0',
  danger: '#F07167',
};
export const palette = ['#4FB286','#A3C644','#38CFE0','#5C93E8','#F2C14E','#E86FA0','#E8735A','#9B7BE0'];
export const radius = { card: 24, panel: 20, control: 16, pill: 999 };
export const space = { xs: 4, sm: 8, md: 12, lg: 16, xl: 20, xxl: 28 };
```

圆圈文字色按背景亮度取 `#0B1206` 或 `#FFFFFF`，阈值 0.62（亮度公式 `0.2126R + 0.7152G + 0.0722B`，输入需归一化）。
