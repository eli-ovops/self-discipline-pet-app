# Focumi / DisciplinedPet — 项目执行入口

项目根：`/Users/USER/Documents/app/自律宠物-iOS`。本文件只路由项目事实；上级 `AGENTS.md`、当前用户授权与平台安全规则优先。

## 先确认，再改动

- 当前工程配置版本是 `0.5.0 (7)`；这只是配置事实，不是发布、设备验收或产品绿灯。
- `Docs/PROJECT.md` 是当前产品范围和状态导航；旧 PRD、Beta 报告、v0.4/v0.6 规格和视觉文档仍保留为有日期的决策/证据，不能以文件名或自述覆盖源码。
- `Docs/ARCHITECTURE.md`、`STATE_MACHINES.md`、`PLATFORM.md`、`ENGINEERING.md` 是当前工程事实的入口。它们把 **CURRENT**、**EVIDENCE** 与 **RECOMMENDED** 分开，不取代用户授权。
- 当前源码与工程配置优先于文档；冲突写为 `DOCUMENTATION DRIFT`，不要静默“修正”源码或把建议当事实。
- 不读取或输出 `.env`、证书、私钥、token、cookie 等敏感内容；发现疑似秘密文件只报告存在与人工检查需要。

## 任务路由

| 任务 | 必读 |
| --- | --- |
| 纯 UI、文案、视觉、无状态改动 | 本文件 → `PROJECT.md` → 对应 Feature/视觉规格与源码 |
| 专注、申请使用、返回、完成、奖励或业务状态 | 本文件 → `PROJECT.md` → `ARCHITECTURE.md` → `STATE_MACHINES.md` → 相关 reducer/model/tests |
| Family Controls、Shield、Device Activity、Live Activity、通知、生命周期、真机问题 | 本文件 → `PLATFORM.md` → `ARCHITECTURE.md` → 相关 Target/adapter；先分清 Simulator 与 Device 证据 |
| UserDefaults、App Group、恢复、清除数据、导出报告 | 本文件 → `ARCHITECTURE.md` → `ENGINEERING.md` → 相关 Store/shared DTO/tests |
| 架构、Target、Extension、依赖、并发或导航所有权变化 | 本文件 → 全部核心文档 → 当前用户明确授权后才实施 |
| 测试/验收报告 | 本文件 → `ENGINEERING.md` → `PLATFORM.md`；仅报告实际运行或现有证据 |

## 当前不可违反项

- 真实专注事实由 `FriendMVPSnapshot` 的 reducer 流程表达；展示层的动画、sheet、计时显示不能成为保护、deadline 或完成的真值。
- `P0CapabilityModel` 负责 Family Controls 选择、授权观察和本地 Shield 命令回执；`ManagedSettingsStore` 调用成功不等于系统 Shield 已生效。
- 主 App、Monitor、Shield Action、Shield Configuration 与 Live Activity 是独立 Target/进程。App Group 的值是协议数据，不能被 Actor 或内存单例当作跨进程锁。
- App Group 中的 `P0SessionSnapshot`、intent、monitor context/event、命令回执与宠物展示值都有各自 producer/consumer；不得新增第二个同 key writer 或绕过 `AppGroupStore`。
- deadline 是逻辑时间真值；通知、动画、Live Activity 和命令回执均不是 deadline/系统保护真值。
- persisted `.cat` / `.dog` 是兼容标识；展示层将 `.dog` 映射为 Max。改变该映射或存储格式属于迁移。
- Beta 验证日志只保存 allowlisted、去标识事件；不得写入目标正文、申请理由正文、所选 App、宠物名或账号/网络数据。
- UI 必须保持鼓励且诚实：不能把本地调用、模拟器、构建或截图说成真实 Shield/Return/Live Activity 成功。

## 范围与变更规则

- 默认最小改动、复用现有 Owner；不要为方便新建平行 Store、Manager、global singleton、持久化机制或通用框架。
- UI 状态可以在最近的 View 持有；跨页面或可恢复业务状态必须先定位 `FriendMVPModel` / `P0CapabilityModel` / 相应 Store 的既有所有权。
- 新 Target、Extension、App Group key、entitlement、background mode、第三方 SDK、persistence schema、核心 reducer state、navigation root 或依赖方向，先写最小方案、风险和验收方法，取得明确授权后才改。
- 不把 DEBUG preview 参数、静态 Preview、测试 fixture 或历史证据当生产/设备行为。
- 不修改工程/签名/entitlement/Apple 账户、上传、发布、支付、外联、真实用户数据或 Git 外写，除非当前用户对目标动作明确授权。

## Definition of Done 与证据标签

完成实现时报告下列独立标签，不得越级：

```text
Implementation: DONE | NOT DONE
Build: PASS | FAIL | NOT RUN
Tests: PASS | FAIL | NOT RUN
Simulator: PASS | FAIL | NOT RUN | N/A
Device: PASS | FAIL | BLOCKED | NOT TESTED | N/A
User Evidence: PASS | FAIL | NOT TESTED | N/A
```

- Family Controls、Shield、跨进程延迟、真实通知、Live Activity/Island/Lock Screen、后台/中断、VoiceOver 运行时行为，需要对应真实设备证据；build/test/simulator 不能替代。
- 先运行相关的最小测试，再扩大验证；不要用 `sleep` 作为业务验证。命令只可写入已由工程文件或可复核历史证据确认的形式。

## 每轮开工检查

1. 确认本轮是只读、代码、工程、真机、外部写入还是发布工作，并核对当前授权。
2. 确认当前产品/工程文档与源码没有已知冲突；冲突先标 `DOCUMENTATION DRIFT`。
3. 记录要修改的既有 Owner、状态、持久化键、Target 和证据类型。
4. 任何跨进程或系统能力改动先写 PASS/FAIL、恢复和设备证据条件。
5. dirty worktree、历史 Evidence、ReviewPackages 和 `Design/` 默认属于保留范围；不清理、不覆盖。

## 不可作出的推断

- `ManagedSettingsStore` 属性赋值 ≠ Shield 已生效或已恢复。
- intent 写入/读取 ≠ 用户完成了申请或返回。
- Live Activity 代码/预览 ≠ Lock Screen 或 Dynamic Island 正常。
- notification 已添加 ≠ 用户收到、点击或按时返回。
- 本地事件日志/问卷 ≠ 留存、付费、市场需求或用户验收。
- 源码/测试/构建的存在 ≠ 发布、TestFlight 或真实设备接受。

## 变更留痕

- 报告中注明当前代码/配置版本、实际 Target、所用文档版本与未验证边界。
- 若任务遇到历史文档与源码冲突，保留两者并写明依据，不删除或重写历史结论。

## 最终回报

用中文，结论先行，并写：范围与实际文件、未触及文件、上述证据标签、已知风险/UNKNOWN、下一步和所需授权。不得把本地构建、静态审查或旧证据包装成最终验收。

## Open Loops

- **状态：启用。** 从用户明确启用的那一轮开始，每个后续业务轮次都运行，直到用户明确说暂停或停止；不依赖用户再次提到 skill。无新增默认静默，但清单中的更新轮次仍会推进。
- **维护通道**：如果一轮主要是在询问、调试、修改或发布 Open Loops 本身，不把该轮或相邻维护回复写入业务项目的 `docs/open-loops-source.md`，也不让它改变业务清单。维护结束后从下一条业务消息续接。
- **每轮开始**：把上一轮往返和用户本轮消息逐字追加进 `docs/open-loops-source.md`，再派一个未参与主对话的子 agent；只给它两个文件路径，并使用 Open Loops Skill 的审查员指令。
- **审查模型：`gpt-5.6-sol`，effort `medium`。** 这是用户于 2026-08-15 明确选择；除非用户修改，不再询问。
- 只找四种掉点：用户提了但未答、助手说了但用户没接住、助手代选、助手该问未问。登记必须同时满足“忽略会默认定下来”和“不专门找就看不见”。
- 用户已经接住并下达下一步指令的，通常出表；但用户于 2026-08-15 明确要求将本次两项产品优化作为例外登记，须等用户明确说已实施或废弃后再核销。
- 每轮先核销旧条目，再检查新增；默认静默，只报告本轮新增。禁止按轮数自动归档或自行废弃；能问必须问。
- 对账时逐条读取 `docs/open-loops.md`，禁止靠对话记忆；结尾只放清单状态，不替用户排序下一步。
