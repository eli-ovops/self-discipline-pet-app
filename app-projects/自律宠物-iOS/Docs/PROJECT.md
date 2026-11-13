# PROJECT — Focumi / DisciplinedPet

> **Authority:** 当前产品范围与状态导航。工程事实以 `ARCHITECTURE.md` / `PLATFORM.md` 和源码为准；有日期的 PRD、实施报告与视觉规格保留其当时的决策/证据角色。最后源码审计：2026-08-14。

## 当前版本与承诺

- **工程配置事实：** `0.5.0 (7)`（`project.yml`）。这不表示已发布、真机验收或市场验证。
- **产品承诺：** 以宠物伙伴陪伴用户开始专注，借助 iOS 限制用户选择的干扰 App；必要使用后保留目标与返回入口，再共同收束一次专注。
- **首要用户：** 希望在学习/工作时减少社媒干扰的人。任何医疗、成瘾治疗或学习效果宣称均不在当前承诺内。
- **当前实现能证明：** 本地 SwiftUI 产品流程、两种宠物身份、专注/必要使用/返回/完成的 reducer 与本地存储、Family Controls/Managed Settings/Device Activity/Live Activity/通知适配代码均存在。

## 核心循环（CURRENT IMPLEMENTATION）

```text
认领 Milo 或 Max
→ 设置目标、时长和 iOS 选择的干扰 App
→ Focus Together（逻辑 deadline + 请求保护）
→ Shield intent 进入必要使用申请页
→ 临时访问窗口，或返回后重新请求保护
→ deadline 到达后完成，或用户主动结束
```

“请求保护”“请求恢复保护”是本地命令事实；系统实际 Shield 效果必须单独以真机证据确认。

## 当前范围

- 宠物：持久化标识为 `.cat` / `.dog`；呈现为 Milo / Max；一次更换与共同回忆在本地状态中实现。
- 专注：30/45/60/120 分钟、自由专注或目标专注、可选本地音乐、必要使用理由、10/30/60 分钟本地提醒、返回与结束。
- 系统能力：Family Controls 选择/授权、Managed Settings shield 命令、Device Activity deadline、Shield Action/Configuration、Live Activity 和本地通知均有代码/配置入口。
- 本地数据：主 App `UserDefaults`、App Group `UserDefaults` 协议数据、去标识化 Beta 验证日志；无账号、后端、云同步或运行时第三方 SDK 的源码证据。

## 非目标

- 账户、云同步、后端、广告、订阅、商店、社交 feed、排行榜、签到/惩罚循环。
- 以 Build、Simulator 或 UI 文案代替真实系统行为、用户复用或付费证据。
- 未获授权的 TestFlight、App Store、公开招募、支付、外联、Apple 账户或发布操作。
- 因“架构更漂亮”进行 Clean Architecture/TCA/Redux/模块化大重构。

## 已知产品未知项

| 事项 | 状态 | 证据边界 |
| --- | --- | --- |
| Shield/申请/解除/恢复的 P0-A 路径 | `DEVICE EVIDENCE FOUND` | `Evidence/P0-A-real-device-2026-08-10/README.md`；只覆盖所记载 P0-A 条件 |
| 当前 UI、Live Activity、Shield 外观与完整 Return loop | `DEVICE REQUIRED` | 现有 v0.6 Checkpoint A 文档只声明本地候选/等待用户审阅 |
| 留存、自然复用、付费与市场成立 | `UNKNOWN` | 本地 Beta 日志/问卷不是用户行为或真实支付绿灯 |
| v0.6 逐帧体验 | `PROPOSED / GATED` | v0.6 PRD 和 Checkpoint 文档存在；不得因已存在资产/代码推断 Gate 完成 |

## 现有文档角色

| Concern | 当前入口 | 说明 |
| --- | --- | --- |
| 产品范围与当前状态 | 本文 | 导航；不覆盖历史 PRD 的已冻结决策 |
| 当前工程事实 | `ARCHITECTURE.md` | 源码/工程配置优先 |
| 核心生命周期 | `STATE_MACHINES.md` | CURRENT 与建议规范化分开 |
| 平台与证据 | `PLATFORM.md` | Device/Simulator 不能互换 |
| 日常实现与验证 | `ENGINEERING.md` | 只列可复核命令和边界 |
| 历史 P0、Beta、v0.4、v0.6 规格 | `Docs/` 原文件 | 有日期的决策与审计证据；有冲突时按本文/源码标注漂移 |

## DOCUMENTATION DRIFT

旧 `Docs/README.md`、旧项目 `AGENTS.md` 与 P0 架构 v1.1 曾把 Beta v0.2/P0 的目标拓扑写为当前，且 P0 架构明确写“当前尚未创建”。实际工程已有 `0.5.0 (7)`、Live Activity Target 和 v0.4/v0.6 代码路径。历史文件不删除；新任务从本文和工程文档起读。
