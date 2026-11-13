# Focumi 核心流程审计

## 总判定

代码层的核心流程是连贯的；系统行为层未闭环。以下“已实现”仅表示源码路径存在，不能替代真机。

## 1. Welcome / Setup

### 当前实现

- persisted pet 支持 `.cat/.dog`，默认名分别为 Milo/Max（`DisciplinedPet/Domain/FriendMVPDomain.swift:3-15`）。
- 当前生产 onboarding 只显示 Milo，并固定调用 `adopt(.cat)`（`DisciplinedPet/Features/FriendMVP/FriendMVPView.swift:927-964`）。
- Milo/Max 二选一组件仍在源码中（同文件 `1087-1164`），但不在生产 route 上。
- Setup 的开始前门禁要求 Family Controls approved、至少一个选择、有效目标/自由专注和支持时长（`FriendMVPModel.swift:228-270`）。

### 状态

`PARTIAL / PRODUCT DECISION DRIFT`：功能门禁存在，宠物二选一未按冻结决策接入。

## 2. 权限申请与拒绝

### 申请路径

Setup → 权限说明 sheet → “Continue to Screen Time” → `requestAuthorization(for: .individual)`（`FriendMVPView.swift:1552-1613,1713-1774`；`FamilyControlsAuthorizationClient.swift:11-13`）。批准后进入新的 capability session；未批准则继续显示需要权限（`P0CapabilityModel.swift:88-109`）。

### 拒绝/失败路径

- 授权状态映射为 notDetermined/denied/approved（`P0CapabilityModel.swift:137-143`）。
- request 抛错会写 `authorization_request_failed` 并进入 recovery（同文件 `88-108`）。
- Setup 开始按钮不可用，且 `startSession` 再次守卫 approved 和非空 selection（`FriendMVPModel.swift:228-238`）。
- 用户可以在说明页选择 “Not now” 返回 Setup（`FriendMVPView.swift:1760-1773`）。

### 撤销路径

诊断页存在 revoke 操作；revoke 后重新读取系统授权，未观察到撤销或失败时进入 recovery（`P0CapabilityModel.swift:111-126`；`P0CapabilityView.swift:72-104`）。授权丢失的 reducer 测试存在（`P0CapabilityReducerTests.swift:82-95`），但本轮未运行。

### 缺口

`NOT TESTED ON DEVICE`：系统弹窗拒绝、设置中撤销、正在专注时撤销、重新授权后的选择/旧 intent 隔离，均没有当前候选的真机证据。正在专注时主状态不会自动离开 focusing，只出现保护不确定警告；需验证是否足够清楚且不会误导。

## 3. 开始专注与 Shield 生效

1. reducer 将 phase 设为 focusing，冻结 deadline 和 monitor ID；发出 apply/schedule/sync/persist（`FriendMVPDomain.swift:258-292`）。
2. model 把 apply 转给 capability（`FriendMVPModel.swift:550-575`）。
3. capability 验证 approved + selection，递增 generation，再调用 `ManagedSettingsStore`（`P0CapabilityReducer.swift:82-113`；`ShieldProtectionClient.swift:9-44`）。
4. 主 UI立即进入 focusing；系统 Shield 是否已经可见不可从源码或 receipt 得知。

状态：`SOURCE CONFIRMED / DEVICE NOT TESTED`。

## 4. 离开、必要访问与打开 App

- 用户触发 Shield secondary action 时，扩展写入 60 秒 TTL 的 `PendingShieldIntent`（`DisciplinedPetShieldActionExtension.swift:34-78`）。
- iOS 26.5+ 返回 `.openParentalControlsApp`；iOS 17–26.4 返回 `.none`，用户必须自行打开 Focumi，且 intent 必须在 60 秒内被消费（同文件 `46-53,70-78`）。
- App 激活或首次 `.task` 会 reconcile、读取可消费 intent 并 route 为 `.shieldRequestReceived`（`FriendMVPView.swift:116-135`；`FriendMVPModel.swift:474-533`）。
- focusing 才能进入 requestingAccess；其他 phase 的 intent 不改变主状态（`FriendMVPDomain.swift:294-300`）。

状态：`SOURCE CONFIRMED / CROSS-PROCESS DEVICE NOT TESTED`。旧系统手动打开与 60 秒 TTL 的可用性是 P0 风险。

## 5. 必要访问申请

- 用户选择结构化原因；自由文本只决定 `.custom`，正文不持久化（`FriendMVPModel.swift:346-359`）。
- 提交后保存剩余专注时长、取消 focus deadline、请求 clear、安排 10/30/60 分钟提醒、进入 accessWindow（`FriendMVPDomain.swift:310-336`）。
- 取消申请只返回 focusing，不发 clear/reapply（同文件 `302-308`；测试契约见 `FriendMVPReducerTests.swift:180-201`）。

状态：`SOURCE CONFIRMED / SHIELD CLEAR NOT TESTED`。

## 6. Return → 重新保护

- Return 按钮调用 `returnToFocus()`（`FriendMVPView.swift:4183-4192`）。
- reducer 累加临时访问时长、创建新 focus deadline、清 access window、请求 reapply、取消提醒（`FriendMVPDomain.swift:338-363`）。
- 测试源码断言 reapply 只请求一次（`FriendMVPReducerTests.swift:244-267`），但本轮未运行。

状态：`SOURCE CONFIRMED / RELOCK NOT TESTED`。UI 返回 focusing 只证明本地状态；必须在真机重新打开受限 App，观察 Shield 再次出现。

## 7. 前后台、杀进程与恢复

- root `.task` 与 scene 变为 active 时调用 `reconcile()`（`FriendMVPView.swift:119-135`）。
- model 从持久化 snapshot 恢复；future deadline 的调度恢复和系统跨进程时序必须依赖真机（`FriendMVPModel.swift:37-76,474-489`）。
- Monitor 到期尝试清除 Shield；失败不向用户伪称成功，主 App 激活时按逻辑 deadline 收束（`DisciplinedPetMonitorExtension.swift:11-38`）。

状态：`SOURCE CONFIRMED / BACKGROUND AND FORCE-QUIT NOT TESTED`。

## 8. 自然完成与提前结束

### 自然完成

deadline 后 reconcile：phase → completed，completedSessions +1，bondPoints +10，清 protection，结束 deadline/提醒并持久化（`FriendMVPDomain.swift:399-417`）。重复 reconcile 因 phase 已不是 focusing 不再增加；测试源码覆盖一次结算（`FriendMVPReducerTests.swift:269-290`）。

### 提前结束

focusing/requestingAccess/accessWindow 均可显式结束：回 setup、清 deadline/access window、请求 clear、取消提醒，不增加 completedSessions（`FriendMVPDomain.swift:365-387`）。重复结束无效，测试源码覆盖幂等（`FriendMVPReducerTests.swift:350-365`）。

状态：`REDUCER CONTRACT CONFIRMED / CURRENT TEST NOT RUN / DEVICE NOT TESTED`。

## 概念图清理边界

- 生产主线使用“现在结束/先到这里”，不新增 Pause 业务状态；源码中的旧 `Pause for now` 仅视为遗留 presentation，不作为新 PRD 输入。
- 不新增复杂历史 Dashboard。完成次数、bond、归档伙伴等现存字段不自动升级为主线产品承诺。
- 动画帧、Return Signature、Blink、performance manifest 均不作为核心流程验收条件；不接入新的动画资产。

