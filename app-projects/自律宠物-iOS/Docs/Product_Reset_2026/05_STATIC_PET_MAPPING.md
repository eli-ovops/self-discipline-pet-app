# Milo / Max Approved 静态素材映射

审计方法：只读检查 `Design/CharacterAssets/VintageShojo/Approved/` 与 Runtime Asset Catalog；对下列 12 个核心 PNG 做 SHA-256 对比，全部 `MATCH`。未修改任何资产。

## 映射原则

- persisted `.cat` → Milo；`.dog` → Max（`FriendMVPDomain.swift:3-15`）。
- 每个页面按物种选择同语义 Approved 静态图。
- 缺图时只降级到同宠物的最近语义 Approved 静态图；禁止跨宠物、禁止生成新图、禁止动画帧替代。
- Shield/Live Activity 是独立 Target，使用各自 Approved 资源，不从主 App 假定可见性。

## Milo

| 页面状态 | Approved 源 / Runtime asset | 当前实际调用点 | 缺口 | 建议降级 |
| --- | --- | --- | --- | --- |
| Welcome / Setup | `Approved/Milo/milo_idle_v1.png` → `FocumiMiloIdle` | Welcome：`FriendMVPView.swift:949-960` 经 `MiloStaticPoseView`；Setup：`4020-4023` 实际调用 `MiloBlinkView` | Setup 依赖未冻结为静态的闭眼图；本轮产品决策要求静态 | 固定 `FocumiMiloIdle` |
| Goal / Pact | `milo_pact_v1.png` → `FocumiMiloPact` | 通用静态映射存在：`PetAvatarView.swift:337-353`；当前正式 Setup 未调用 | `FocumiMiloPact` 未接正式 Pact 页面 | 暂用 `FocumiMiloIdle`，不启动画 |
| Focus | `milo_focus_v2.png` → `FocumiMiloFocus` | `FriendMVPView.swift:4103-4109` | 无 Milo 静态缺口 | 无需降级 |
| Return / Waiting | `milo_return_v1.png` → `FocumiMiloReturn`；`milo_waiting_v1.png` → `FocumiMiloWaiting` | requestingAccess/waiting 均经 `MiloStaticPoseView(.waiting)`，而 `CompanionPresentation.swift:12-18` 把 waiting 统一映射为 Return（`FriendMVPView.swift:4145-4150,4176-4181`） | Waiting 与 Return 语义未分开；Return recognition 仅 DEBUG preview 可见 | 等待页用 `FocumiMiloWaiting`；用户点击 Return 后的短确认可用 `FocumiMiloReturn`，若不做确认则直接 Focus |
| Completion | `milo_complete_v1.png` → `FocumiMiloComplete` | `FriendMVPView.swift:4274-4280` | 无 Milo 静态缺口 | 无需降级 |

## Max

| 页面状态 | Approved 源 / Runtime asset | 当前实际调用点 | 缺口 | 建议降级 |
| --- | --- | --- | --- | --- |
| Welcome / Setup | `Approved/Max/max_idle_v1.png` → `FocumiMaxIdle` | 二选一遗留组件可调用 `PetAvatarView`（`FriendMVPView.swift:1087-1164`）；当前生产 onboarding 未调用 | 当前生产 route 固定 Milo | 固定 `FocumiMaxIdle` |
| Goal / Pact | `max_pact_v1.png` → `FocumiMaxPact` | 通用映射存在：`PetAvatarView.swift:337-353` | 当前正式 Pact 页面硬编码 Milo | 暂用 `FocumiMaxIdle` |
| Focus | `max_focus_v2.png` → `FocumiMaxFocus` | 通用映射存在；当前正式 Focus 使用 `MiloStaticPoseView` | Max 未接生产 Focus | 若 wiring 未完成，用 `FocumiMaxIdle`，不得错误显示 Milo |
| Return / Waiting | `max_return_v1.png` → `FocumiMaxReturn`；`max_waiting_v1.png` → `FocumiMaxWaiting` | 通用映射存在；Shield/Live Activity 也有独立 Max 资源 | 当前正式 requesting/waiting/return 全硬编码 Milo | Waiting 用 `FocumiMaxWaiting`；Return 确认用 `FocumiMaxReturn`；无确认则直接 Focus |
| Completion | `max_complete_v1.png` → `FocumiMaxComplete` | 通用映射存在；当前正式 Completion 硬编码 Milo | Max 未接生产 Completion | 若 wiring 未完成，用 `FocumiMaxIdle`，不得显示 Milo |

## Shield 与 Live Activity 附加映射

- Shield：`milo_shield_portrait_v1.png` / `max_shield_portrait_v1.png` 已在独立 catalog；当前配置按 App Group species 选择（`DisciplinedPetShieldConfigurationExtension.swift:53-65`）。
- Live Activity：Milo/Max 的 focus/waiting/returning 静态资源均存在；测试源码列出映射（`FriendMVPReducerTests.swift:511-519`），本轮未运行且真机未测。

## 动画与概念资产处理

- `MiloBlinkView`、Return Signature、多帧/transform/performance manifest、`Design/Milo_Animation_Pilot/` 统一视为 `DEFERRED_RESEARCH_ASSETS / NOT_APPROVED_FOR_RUNTIME / NOT_A_BETA_BLOCKER`。
- 保留、不删、不移动、不覆盖、不返工；后续静态映射任务只解除正式页面引用。
- 不把 Pause、Dashboard、动画帧、播放状态或概念图控件带入静态页面。

