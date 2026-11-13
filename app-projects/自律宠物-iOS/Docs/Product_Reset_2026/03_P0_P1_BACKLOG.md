# Focumi P0 / P1 Backlog

排序原则：先证明 App Blocking 真闭环，再处理宠物呈现与整理；动画不列 P0。

## P0

| 顺序 | 项目 | 当前状态 | 最小交付 | 停止条件 |
| --- | --- | --- | --- | --- |
| P0-1 | 冻结一个当前候选并完成真机 Blocking 闭环矩阵 | `NOT TESTED` | 唯一 commit/diff 指纹、build/version、设备/iOS、逐步录屏/时间戳/结果；覆盖 Shield、撤权、前后台/杀进程、临时访问→Return→relock、自然/提前结束一次结算 | 任一关键步骤 FAIL；保留证据，不以本地 receipt 或安装替代 |
| P0-2 | 支持系统范围与 Return 策略 | `BLOCKED BY PRODUCT/PLATFORM DECISION` | 明确最低支持 OS；iOS 26.5+ 自动打开路径与旧系统手动打开路径均有诚实文案、TTL 策略和真机验收，或正式收窄支持范围 | 旧系统无法形成不误导的可达返回路径 |
| P0-3 | 权限拒绝/撤销/恢复闭环 | `PARTIAL SOURCE / DEVICE NOT TESTED` | 首次拒绝、设置中撤销、专注中撤销、重新授权均有单一清楚状态与恢复动作；不继续声称保护可靠 | capability 与主专注状态出现矛盾、旧 intent/receipt 被复用或用户无恢复出口 |
| P0-4 | Family Controls Distribution 与实时分发门禁 | `UNKNOWN / ACCOUNT REQUIRED LATER` | 在另行授权下核验四个 Family Controls 相关 bundle 的 Distribution 能力、profile、候选 build 与 TestFlight/App Store 实时状态 | 任一 entitlement/profile 不匹配；不得上传/提交来“试” |

## P1

| 顺序 | 项目 | 当前状态 | 最小交付 |
| --- | --- | --- | --- |
| P1-1 | 恢复 Milo/Max 二选一并统一 Approved 静态映射 | `PRODUCT DECISION DRIFT` | Welcome、Pact、Focus、Waiting/Return、Completion 全部按 persisted `.cat/.dog` 映射；不迁移存储，不新增宠物 |
| P1-2 | 移除正式页面对动画实验的 Runtime 依赖 | `SCOPE DRIFT` | 正式 Setup 使用 Approved 静态图；Blink/Return Signature/performance/旧 frame 代码与资产保留为 deferred，不删除、不返工、不成为 Beta 阻断 |
| P1-3 | 清理主线信息架构概念污染 | `PARTIAL` | 新实现不出现 Pause 状态、复杂记录 Dashboard、养成/奖励扩张或动画帧控制；遗留私有 View 可后续最小删除/隔离，但不得顺手重构 |
| P1-4 | 配置与文档版本真值对齐 | `DRIFT` | `project.yml`、生成 project、候选 provenance 和核心文档只保留一个明确版本来源；不把版本号当发布状态 |
| P1-5 | 可访问性与诚实文案回归 | `HISTORICAL/PARTIAL` | Dynamic Type、VoiceOver、Reduce Motion 和警告文案在当前静态双宠物流程通过；不声称系统动作已完成 |

## 明确排除

- 第三宠物、Pet Library、养成系统、Habit Tracker、复杂统计 Dashboard。
- 任何动画、Image Edit、Rig、补间、视频的启动/修复/接入。
- 把历史 TestFlight、真机安装、模拟器截图或 `ManagedSettingsStore` 调用当作 Shield PASS。

## 建议执行顺序

1. P0-1：先用当前候选跑真机矩阵，找出真实失败点。
2. P0-2 与 P0-3：只修矩阵暴露的 Return/权限硬问题，再重复最小失败用例。
3. P0-4：功能真机通过后，另行授权做账户/Distribution 核验。
4. P1-1：恢复双宠物静态映射。
5. P1-2/P1-3：隔离动画与概念污染，不扩大架构。
6. P1-4/P1-5：冻结候选真值并完成可访问性/文案回归。

