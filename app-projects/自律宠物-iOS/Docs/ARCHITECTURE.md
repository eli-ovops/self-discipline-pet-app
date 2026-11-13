# ARCHITECTURE — Current Repository Truth

> **Evidence:** source and `project.yml` / generated Xcode project inspected 2026-08-14. `CURRENT` describes observed code; `RECOMMENDED` is not implementation authorization.

## Current overview

`DisciplinedPetApp` owns one `@State FriendMVPModel` and injects it into one `NavigationStack`. `FriendMVPModel` coordinates the user-visible focus loop; it embeds `P0CapabilityModel` for selection, authorization and local shield-command coordination. Pure domain reducers (`FriendMVPReducer`, `P0CapabilityReducer`) produce effects; the models execute effects through infrastructure clients.

The Xcode project contains one app, four app extensions and one unit-test bundle:

```text
DisciplinedPet app
 ├─ DisciplinedPetMonitor (DeviceActivity + App Group)
 ├─ DisciplinedPetShieldConfiguration (ManagedSettingsUI + App Group)
 ├─ DisciplinedPetShieldAction (ManagedSettings + App Group)
 ├─ DisciplinedPetLiveActivity (ActivityKit / WidgetKit)
 └─ DisciplinedPetCoreTests
```

This is **not** the four-product-target topology in historical P0 documents. The Live Activity target exists in current configuration and source.

## Repository map

| Path | Actual responsibility | Status |
| --- | --- | --- |
| `DisciplinedPet/App` | SwiftUI app composition root | `CLEAR` |
| `DisciplinedPet/Application` | observable coordinators, effect execution, deadline/audio helpers, report builder | `MIXED RESPONSIBILITY` — `FriendMVPModel.swift` contains several adapters |
| `DisciplinedPet/Domain` | Codable state/DTOs and pure reducers | `CLEAR` |
| `DisciplinedPet/Infrastructure` | Family Controls, shield, notifications, ActivityKit, `UserDefaults` stores | `CLEAR` |
| `DisciplinedPet/Features/FriendMVP` | all user screens plus presentation-only animation/copy | `MIXED RESPONSIBILITY` — one 3,287-line UI file owns many private screens |
| `DisciplinedPet/Features/P0Capability` | diagnostics UI for `P0CapabilityModel` | `CLEAR` |
| `Shared` | App Group DTO/store/keys and ActivityKit attributes | `CLEAR` |
| `DisciplinedPetMonitor` | deadline monitor and monitor-event writer | `CLEAR` |
| `DisciplinedPetShield*` | Apple-owned Shield appearance/action bridges | `CLEAR` |
| `DisciplinedPetLiveActivity` | WidgetKit presentation of shared attributes | `CLEAR` |
| `DisciplinedPetCoreTests` | reducer, App Group envelope/store and Beta validation tests | `CLEAR` |
| `Docs`, `Evidence`, `Design`, `ReviewPackages` | specifications, historical evidence/assets and review snapshots | `LEGACY / MIXED` for discovery; do not treat snapshots as runtime source |

## Current dependency direction

```text
SwiftUI Feature Views
  → FriendMVPModel / P0CapabilityModel
  → Domain Reducers ───────────────→ Domain state/effects
  → Infrastructure clients/stores ─→ Apple APIs, UserDefaults, App Group

Extensions → Shared App Group DTO/store ← Main App
Live Activity ← Shared ActivityKit attributes ← Main App client
```

- **Composition root/DI:** `DisciplinedPetApp` constructs `FriendMVPModel`; that model uses default initializer injection for stores/clients. There is no service locator or `EnvironmentObject`.
- **Singletons:** Apple singletons are called within adapters (`AuthorizationCenter.shared`, `UNUserNotificationCenter.current`, `Activity<...>.activities`, `AVAudioSession.sharedInstance`, `DeviceActivityCenter`). No application-defined global singleton was found.
- **Hidden bus:** `NotificationCenter` is used only for `AVAudioSession.interruptionNotification`, not as a business-event bus.
- **Direct View platform access:** `FriendMVPView` owns `familyActivityPicker` binding and settings opens `UIApplication.openSettingsURLString`; `P0CapabilityView` calls model methods. This is a small presentation/platform seam, not an unbounded service locator.

## State ownership matrix (CURRENT)

| State | Runtime owner / writers | Persistence | Cross-target | Notes |
| --- | --- | --- | --- | --- |
| focus phase, goal, deadlines, pet, counters | `FriendMVPModel` → `FriendMVPReducer` | `FriendMVPStore` / standard `UserDefaults` | no | model memory is the loaded runtime copy; store is recovery source |
| preferences / memories | `FriendMVPModel` | same `FriendMVPStore` | no | centralized writes through `persistCurrentState()` |
| selection, authorization, P0 command lifecycle | `P0CapabilityModel` → `P0CapabilityReducer` | selection + `P0SessionSnapshot` | App Group for snapshot | system authorization remains Apple-owned |
| actual shield enforcement | iOS `ManagedSettingsStore` | Apple system | app + monitor extension issue commands | `UNKNOWN` as an observable app state; receipt only says local dispatch |
| shield intent | Shield Action writes; P0 capability reads/deduplicates | App Group `pendingShieldIntent` envelope | yes | producer/consumer protocol, not a main-app store |
| monitor deadline/context | main app writes/schedules; monitor reads/removes | App Group `focusDeadlineMonitor` | yes | coordination copy of app logical deadline |
| monitor event | monitor writes; P0 diagnostics can read | App Group `monitorEvent` | yes | diagnostic event, not focus truth |
| Shield companion artwork | Friend model writes derived species | App Group `shieldCompanionSpecies` | Shield Configuration | presentation-only derived value |
| Live Activity content | `FocusLiveActivityClient` derives from snapshot | ActivityKit system | Live Activity target | not a session truth source |
| local notifications | `LocalNotificationClient` schedules/cancels | UserNotifications system | no | reminders, not deadline truth |
| Beta validation | `FriendMVPModel` | `BetaValidationStore` / standard `UserDefaults` | no | separate allowlisted measurement state |
| sheets/overlays/animation cues | nearest SwiftUI `@State` | none | no | presentation-only by code comments and usage |

### SSOT assessment

No source-proven second writer was found for `FriendMVPSnapshot` or `BetaValidationState`. However, **P1 correlated-state risk** exists: `FriendMVPPhase` and `P0CapabilityState.phase` are separate reducers connected by imperative effects/intent routing, while the actual iOS shield state is not readable as an app truth. Changes spanning these models need explicit transition/evidence review. App Group deadline/context is an intentional coordination copy, but is a multi-process seam and must not be promoted to an independent focus state machine.

## Persistence and navigation

- `FriendMVPStore` migrates legacy `friend-mvp.snapshot.v1` into `friend-beta.state.v2`; unreadable data becomes `recoveryRequired`, not silent overwrite.
- `BetaValidationStore` uses a separate versioned local record and stops new measurement on decode/schema failure.
- `AppGroupStore` JSON-encodes individual keys. `SharedEnvelope` provides schema/version/record/session/generation/TTL checks for intent consumption; it does not provide a global transactional lock.
- Root navigation is phase-driven (`FriendMVPPhase` switch). Setup, settings, diagnostics, permission explanation, beta feedback and confirmation screens are Boolean-driven sheets/overlays. Owner is local View state; this is contained, but it is a navigation seam in the 3,287-line file.

## Architecture boundary findings

| Priority | Finding | Evidence and cost |
| --- | --- | --- |
| P1 | Two correlated lifecycle models | `FriendMVPModel` drives `P0CapabilityModel` imperatively; cross-cutting changes require readers to reconstruct both reducers, intent routing and system uncertainty. Regression/agent navigation cost is high. |
| P1 | Main feature view is the UI aggregation boundary | `FriendMVPView.swift` contains root routing, sheets, settings, feedback, setup/focus/access/completion screens and visual primitives. Change locality is poor even though private types limit external coupling. |
| P1 | App Group protocol is distributed but docs formerly describe a simpler single-writer story | extension and main-app keys have distinct writers/readers; no atomic cross-key transaction. New writers or key reuse could cause cross-process regressions. |
| P1 | Background-audio intent is ambiguous | `project.yml` declares `UIBackgroundModes: audio`; `FocusAudioClient` comments that Focumi does not declare background audio and stops when inactive. This is a config/source intent conflict, not observed runtime failure. |
| P2 | P0 diagnostics path is an embedded secondary capability flow | the root app uses Friend MVP; P0 capability UI is reached in a sheet. This raises discovery cost but does not prove a functional defect. |
| P2 | DEBUG preview plumbing is distributed | launch arguments occur in store/model/views. It is guarded by `#if DEBUG`, but should remain documented as test-only. |

## Non-goals

- Do not introduce packages, layers, protocols or modules solely to resemble a canonical architecture.
- Do not merge system-owned shield truth into app state without device-verifiable semantics.
- Do not move historical `Docs`, evidence or review snapshots to make the runtime tree appear cleaner.

## Change triggers

Require an architecture note and explicit authorization before: new global singleton; another focus/protection Store; a second persistent source for existing state; persistence schema/key migration; App Group protocol/key/consumer change; new target/extension/entitlement; third-party SDK; navigation-root change; background execution change; or changed dependency direction.

## RECOMMENDED (minimal, not approved)

1. Keep the reducers and existing clients. For any cross-loop change, document the paired `FriendMVPPhase`/`P0CapabilityState` transition and the system evidence boundary before coding.
2. Split `FriendMVPView` only when a feature changes one of its local screen seams; retain the same model injection and local presentation ownership. Do not do a file-size-only rewrite.
3. Before any background-audio or App Group change, reconcile intended configuration with device evidence and write one owner/protocol table.
