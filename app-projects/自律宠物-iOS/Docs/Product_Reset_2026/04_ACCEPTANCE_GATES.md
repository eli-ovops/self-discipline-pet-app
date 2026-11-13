# Focumi 验收门

## 通用证据标签

每轮必须分别报告，不得互相替代：

```text
Implementation: DONE | NOT DONE
Build: PASS | FAIL | NOT RUN
Tests: PASS | FAIL | NOT RUN
Simulator: PASS | FAIL | NOT RUN | N/A
Device: PASS | FAIL | BLOCKED | NOT TESTED
Distribution: PASS | FAIL | UNKNOWN | NOT CHECKED
User Evidence: PASS | FAIL | NOT TESTED | N/A
```

当前本轮：Implementation `SOURCE AUDITED`；Build/Tests/Simulator `NOT RUN`；Device `NOT TESTED`（只有历史 UI 截图）；Distribution `UNKNOWN`；User Evidence `NOT TESTED`。

## P0-1 真机 Blocking 闭环

前置：冻结唯一候选 commit + dirty diff 指纹、App 版本/build、设备型号/iOS、测试 App 清单、权限初态、录像与逐步时间戳。

PASS 必须全部满足：

1. 首次授权批准并选择至少一个 App 后开始专注；打开被选 App，Apple Shield 真实出现。
2. 未选 App 不被误挡；本地 UI 不使用“已保护成功”替代系统观察。
3. 前台→后台→回前台，剩余时间与 phase 连续；受限 App 仍被 Shield。
4. 杀掉 Focumi 后，被选 App 的保护和 deadline 行为符合冻结规则；重开 Focumi 恢复到唯一正确 phase，无重复 session。
5. Shield 上必要访问动作可达 Focumi；intent 不重复消费、不过期复用。
6. 提交必要访问后，目标与返回入口保留；被选 App 真实可访问。
7. 点击 Return 后回 focusing；再次打开被选 App，Shield 重新出现。仅看到 focusing UI 不算 PASS。
8. 自然到期：Shield 清除、进入 Completion、`completedSessions`/结算只增加一次；重复激活/重开不重复结算。
9. 提前结束：Shield 清除、回 Setup、完成计数不增加；重复点击/重开不二次处理。

任一行为无录屏/逐步记录时为 `NOT TESTED`，不是 PASS。

## P0-2 OS 与 Return

PASS：

- 对每个声明支持的 OS，记录 Shield secondary action 的真实结果。
- iOS 26.5+ 验证系统打开 Focumi、intent 路由和 requestingAccess 页面。
- 若继续支持 iOS 17–26.4，Shield 文案必须明确“手动打开 Focumi”的真实步骤，且 60 秒 TTL 不制造死路；真机验证手动打开后仍可申请。
- 若无法提供可靠旧系统路径，必须明确收窄支持范围，而不是保留不可兑现承诺。

## P0-3 权限生命周期

PASS：

1. 首次选择 Not now/系统拒绝：留在 Setup，开始按钮不可用，用户知道为何需要权限及如何重试。
2. 已批准后在系统设置撤销：回到 App 后立即进入可理解 recovery；不得继续声称 Shield 可靠。
3. 正在 focusing 时撤销：显示明确状态与单一恢复/结束路径；实测受限 App 行为并记录，不猜测。
4. 重新授权：创建新 capability session，旧 generation/intent/receipt 不复用；重新选择/确认后才能开始或恢复保护。
5. 撤权与恢复经过前后台和杀进程后仍一致。

## P0-4 Distribution

仅在用户另行授权账户核验后执行。PASS 需要：

- 主 App、Monitor、Shield Configuration、Shield Action 的 Family Controls Distribution entitlement/profile 均与候选一致。
- 候选版本/build 与上传物唯一对应。
- TestFlight/App Store Connect 实时状态有账户侧证据。
- “已上传/处理中/等待审核/正在测试/已上线”分别报告；任何一个都不能由旧截图或本地 entitlement 文件推断。

## P1 静态宠物验收

- onboarding 可明确二选一 Milo/Max；persisted `.cat/.dog` 保持兼容。
- 五类页面均只调用 Approved 静态资产；Milo/Max 文案、VoiceOver、Shield、Live Activity 物种一致。
- 缺失态采用最近语义静态图降级，不生成图、不调用动画帧。
- Reduce Motion 下无额外变化，因为核心路径本身是静态。
- 动画实验保留在原位但不接 Runtime；不删、不覆盖、不返工。

## 概念边界验收

- 不新增 Pause 状态；只有“继续专注”或“结束本次”的明确动作。
- 不新增复杂记录 Dashboard；主线只保留完成当次闭环所需信息。
- 不出现第三宠物、Pet Library、养成/XP/货币/签到/惩罚或 Habit Tracker 套件。
- 概念图中的动画帧、播放控制、假 Shield 成功效果不进入实现。

