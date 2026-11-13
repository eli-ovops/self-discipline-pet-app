# Focumi 当前产品状态审计

审计日期：2026-08-23  
性质：只读源码、配置与既有本地证据审计；本轮未构建、未运行、未连接设备、未访问 Apple 账户。

## 结论

Focumi 已有一条结构完整的本地专注状态机和 Family Controls / Shield / Device Activity 多 Target 骨架，但“可靠 App Blocking 闭环”仍不能判定通过。当前最高证据是：源码存在、历史单元测试/模拟器记录存在、2026-08-21 有物理 iPhone 外观的 App UI 截图；没有当前候选版本的可检查真机证据证明 Shield 生效、权限撤销恢复、杀进程恢复、临时访问后重新保护或完成只结算一次。

当前生产 UI 仍被硬编码为 Milo-only，和本轮冻结的 Milo/Max 二选一不一致。Approved Milo/Max 静态资产齐全且与 Runtime Asset Catalog 中对应六类资产逐文件 SHA-256 一致，但 Max 没有接入当前正式页面。动画不是 P0，也不是 Beta/TestFlight/App Store 阻断；所有动画实验统一按 `DEFERRED_RESEARCH_ASSETS / NOT_APPROVED_FOR_RUNTIME / NOT_A_BETA_BLOCKER` 处理。

## 当前可确认事实

| 层级 | 状态 | 证据与边界 |
| --- | --- | --- |
| 产品状态机 | `SOURCE CONFIRMED` | `FriendMVPPhase` 有 onboarding/setup/focusing/requestingAccess/accessWindow/completed 六态（`DisciplinedPet/Domain/FriendMVPDomain.swift:24-31`）。 |
| 开始专注 | `SOURCE CONFIRMED` | 开始时生成 deadline、请求 apply、安排 Device Activity、同步 Live Activity、持久化（同文件 `258-292`）。 |
| 必要访问与返回 | `SOURCE CONFIRMED` | 申请时清保护并进入 60 分钟窗口；Return 生成新 deadline 并请求 reapply（同文件 `310-363`）。 |
| 自然完成/提前结束 | `SOURCE CONFIRMED` | 自然完成进入 completed 并加一次计数；提前结束回 setup 且不加完成计数（同文件 `365-437`）。 |
| Family Controls 授权/选择 | `SOURCE + CONFIG CONFIRMED` | 授权 client、picker、四个 Family Controls entitlement 文件存在（`FamilyControlsAuthorizationClient.swift:4-27`；`FriendMVPView.swift:109-115`；`Config/*.entitlements:5-10`）。 |
| Shield apply/clear/reapply | `SOURCE CONFIRMED` | `ManagedSettingsStore` 对 application/category/web domain 写入与清除存在（`ShieldProtectionClient.swift:7-44`）。本地 receipt 只证明调用。 |
| Shield Action → App intent | `SOURCE CONFIRMED` | secondary action 写 60 秒 TTL intent；iOS 26.5+ 请求打开 App，旧系统只保留 intent（`DisciplinedPetShieldActionExtension.swift:34-78`）。 |
| Device Activity | `SOURCE CONFIRMED` | Monitor 到期后尝试清除命名 store，失败时依赖主 App reconcile（`DisciplinedPetMonitorExtension.swift:11-38`）。 |
| Tests | `HISTORICAL EVIDENCE` | 2026-08-21 日志记录 78 tests / 6 suites PASS；本轮未运行，且当前 dirty worktree 不能自动继承该结论。路径：`Evidence/Focumi-v0.6-Milo-Only-2026-08-20/logs/coretests-settings-ui-20260821-final.log`。 |
| Build/Simulator | `HISTORICAL EVIDENCE` | 既有日志与截图只证明当时构建/模拟器 UI；本轮 `NOT RUN`。 |
| 真机 App UI | `HISTORICAL EVIDENCE` | 2026-08-21：`Evidence/Focumi-v0.6-Milo-Only-2026-08-20/screenshots/device-iPhone17-ui-correction-stable-clean-20260821.png`、`device-iPhone17-return-button-setup-20260821.png`。仅证明当时某个 App UI 在物理 iPhone 外观环境显示，不证明当前源码、Shield、Return/relock 或分发。 |
| 真机 Shield 闭环 | `NOT TESTED` | 没有当前候选的可检查行为矩阵/录屏/逐步日志。 |
| TestFlight / App Store | `UNKNOWN` | 本轮禁止账户访问；任何旧状态都是历史，不是实时分发状态。 |

## Family Controls / Shield 当前状态

1. 工程配置包含主 App、Monitor、Shield Configuration、Shield Action、Live Activity 和 CoreTests；`project.yml:47-175` 可确认 Target 拓扑。
2. 主 App 与三个 Family Controls 扩展均声明 `com.apple.developer.family-controls = true` 和同一个 App Group；这只是本地配置，不证明 Apple 的 Family Controls Distribution entitlement 已批准。
3. 授权拒绝/撤销会让 capability 状态进入或保持 recovery，且不会保留“本地保护已请求”的可信声明（`P0CapabilityReducer.swift:58-74`；`82-118`）。
4. 主专注状态与 capability 状态是两个相关状态机。撤权后 capability 可进入 recovery，但主专注 snapshot 并不会自动退出 focusing；当前 UI只显示“无法确认 iPhone 保护状态”的警告（`FriendMVPView.swift:4114-4116`）。真实可理解性与恢复行为需要真机验收。
5. `ShieldCommandReceipt.localDispatch == invoked` 是本地调用回执，不是系统 Shield 可见状态（`ShieldProtectionClient.swift:36-44`）。

## 配置与文档漂移

- `project.yml` 是 `0.6.0 (9)`（`project.yml:20-21`），当前生成的 Xcode project 显示 `0.6.0 (10)`（`DisciplinedPet.xcodeproj/project.pbxproj:968-983,1053-1073`）。候选 build number 的权威来源未冻结，状态为 `DOCUMENTATION/CONFIG DRIFT`。
- `Docs/PROJECT.md:7` 仍写 `0.5.0 (7)`，已不符合当前工程配置。
- `Docs/PROJECT.md:43`、`Docs/PLATFORM.md:61` 引用 `Evidence/P0-A-real-device-2026-08-10/README.md`；实际可定位目录是 `自律宠物-iOS/Evidence/P0-A-real-device-2026-08-10/` 且为空。该 P0-A 结论当前不可检查，降级为 `HISTORICAL CLAIM / EVIDENCE MISSING`。

## 当前 P0 阻断

1. 当前候选版本没有完整真机闭环证据：Shield 生效、拒绝/撤权、前后台与杀进程恢复、临时访问→Return→重新保护、自然完成/提前结束只结算一次均未通过。
2. iOS 最低目标是 17.0（`project.yml:5-6`），但 Shield Action 自动打开主 App 仅在 iOS 26.5+使用；17.0–26.4 的手动返回路径、文案和行为尚未形成可验收闭环。
3. 权限撤销时 capability 恢复态与主专注态的用户可见处理未有真机证据，不能称为可靠/清楚。
4. Family Controls Distribution entitlement、当前 TestFlight/App Store 状态为 `UNKNOWN`，发布前必须另行账户核验。

## 明确非目标

- 不启动、返工或接入动画、Image Edit、Rig、补间、视频。
- 不扩展第三宠物、Pet Library、养成或 Habit Tracker 全家桶。
- 不把 Pause、复杂记录 Dashboard、动画帧或概念图元素带入新主线实现。
- 不把 Build、Simulator、真机安装截图或旧 TestFlight 状态越级称为当前 Shield 通过。

