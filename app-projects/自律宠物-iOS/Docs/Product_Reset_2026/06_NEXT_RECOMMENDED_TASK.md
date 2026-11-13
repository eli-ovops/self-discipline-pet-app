# 下一项最值得开始的具体任务

## 唯一建议

**冻结一个当前 Focumi 候选，并在一台物理 iPhone 上执行“开始→Shield→必要访问→Return→重新保护→自然完成/提前结束”的 P0 真机闭环矩阵。**

这是下一项，而不是先做双宠物 UI 或清理动画，因为当前最大未知不是静态图是否齐全，而是 App Blocker 的系统闭环是否真的可靠。现有源码与测试只能证明意图和 reducer 合同；2026-08-21 真机截图只证明 App UI 曾显示，不能证明 Shield/relock。

## 任务边界

允许：在另行明确授权后冻结候选指纹、构建/安装到指定真机、执行测试矩阵、记录录屏与逐步结果；若发现 FAIL，只定位到最小失败路径并回报，不顺手扩功能。

禁止：账户/上传/发布、动画/Image Edit/Rig/补间/视频、第三宠物/Pet Library/养成/Habit Tracker、复杂 Dashboard、无关重构。

## 固定输入

- 唯一源码状态：commit + dirty diff/allowlist 指纹。
- 唯一 App 版本/build；先解决 `project.yml 0.6.0 (9)` 与 Xcode project `0.6.0 (10)` 的候选标识歧义，但不把改版本当发布。
- 指定物理 iPhone、iOS 版本、Family Controls 授权初态、一个明确的受限 App 和一个未受限 App。
- 录像、屏幕时间戳、操作步骤、观察结果、PASS/FAIL/NOT TESTED。

## 必测顺序

1. 首次拒绝→重试→批准→选择 App。
2. 开始专注→打开受限 App→观察真实 Shield。
3. 前后台与杀进程恢复。
4. Shield 必要访问→Focumi requestingAccess→clear 后可访问。
5. Focumi Return→重新打开受限 App→观察 Shield 再次出现。
6. 正常到期→只结算一次。
7. 新会话提前结束→不增加完成计数且 Shield 清除。
8. 专注中撤权→诚实 recovery→重新授权，不复用旧 intent/receipt。

## 完成定义

- 每项都有可检查证据，缺证据写 `NOT TESTED`。
- Return PASS 必须由“重新打开受限 App 后 Shield 出现”证明，不能由 focusing 页面或 local receipt 证明。
- 自然完成与提前结束分别验证，且重复激活/重开不二次结算。
- iOS 17–26.4 与 26.5+ 的 Return 差异被明确记录；若旧系统路径不可用，立即把支持范围决策列为下一阻断，不用动画或 UI 润色掩盖。
- 结束时只回报矩阵、失败点、证据路径和最小修复建议；不上传、不发布。

