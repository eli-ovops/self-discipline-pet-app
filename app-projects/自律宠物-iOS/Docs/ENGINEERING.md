# ENGINEERING — Safe, Local Development Contract

> This document is operational guidance for the current repository. It does not authorize account, signing, entitlement, deployment, Git or external actions.

## Feature development contract

1. Read `AGENTS.md` and route to the required core documents.
2. Identify the authoritative requirement and whether it is CURRENT, historical, `PROPOSED`, or `UNKNOWN`.
3. Locate the existing owner before editing: reducer/model for business state, Store for persistence, client for Apple APIs, nearest View for presentation state.
4. Reuse the existing abstraction and make the smallest coherent change. Do not create a second flow/store/client for the same state.
5. Add or adjust the smallest relevant deterministic test when reducer, store, projection or protocol behavior changes.
6. Run only a command already supported by project configuration or existing verifiable evidence, if the task is authorized to run it.
7. Report independent Implementation/Build/Tests/Simulator/Device/User Evidence labels and remaining `UNKNOWN`.

## Dependency and ownership rules

- Feature Views bind observable models and own only short-lived presentation state (`@State`, sheets, confirmations, animation cues).
- `FriendMVPModel` owns runtime focus snapshot/preferences orchestration; `FriendMVPReducer` owns legal state transitions/effect declarations.
- `P0CapabilityModel` owns Family Controls selection/authorization observation, intent consumption and local Shield-command coordination; `P0CapabilityReducer` owns its transition rules.
- Infrastructure wraps Apple APIs and storage. Views do not call `ManagedSettingsStore`, `DeviceActivityCenter`, `UNUserNotificationCenter` or `Activity.request` directly.
- Shared code contains cross-target DTOs, keys, envelope validation and the App Group storage wrapper. It must not import app Feature/UI code.
- Apple system state is external. Never add a Boolean that claims a Shield/notification/Live Activity is confirmed without a precise, supported observable and device evidence.

## Persistence and protocol rules

- Use `FriendMVPStore` for `FriendBetaPersistedState` and `BetaValidationStore` only for allowlisted validation data.
- Use `AppGroupStore` and existing DTOs/keys for the existing cross-target protocol. Each key’s writer/reader contract is in `PLATFORM.md`.
- On decode/schema failure, preserve the existing recovery behavior; do not overwrite unreadable user state to “fix” it.
- New key, new writer, schema migration, data reset scope, or an additional persistence mechanism is an architecture change trigger.

## Concurrency and lifecycle

- App models and Apple clients are `@MainActor` by current design. Preserve isolation; do not use `Task.detached` to escape it.
- Async client work must retain a clear owner and cancellation/late-result behavior. Existing `FocusLiveActivityClient` uses a generation to reject stale synchronization; retain that property when changing it.
- `NotificationCenter` is only the audio-interruption bridge today. Do not turn it into a business event bus.
- Reconciliation on root task/scene activation is a recovery path, not a substitute for Device testing of termination, background timing or App Group propagation.

## Error handling and truthful UI

- Propagate observable recovery state or a conservative user-facing message. Do not convert `try?`/local invocation into “iOS has completed the action.”
- Keep failure and interruption copy supportive; internal states may be technical, but never map them to punishment or shame.
- When a system client cannot establish its prerequisite, retain the current model’s recovery/disabled path rather than adding an unverified fallback.

## Mock/test injection

- Current model initializers support default injection for stores/clients; tests can supply isolated `UserDefaults`, dates and client closures/factories where already exposed.
- Prefer reducer and projection tests for state/effect contracts; `AppGroupStore` and `SharedEnvelope` tests cover serialisation/eligibility rules.
- Existing DEBUG launch arguments are screenshot/QA plumbing only. They must remain `#if DEBUG` and must never alter release protection/authorization truth.

## Disposable spike vs evolutionary skeleton

| Type | Allowed | Must not do |
| --- | --- | --- |
| Disposable spike | isolated target/file, hardcoded non-sensitive input, fixed PASS/FAIL, removable output | change current session/persistence/protocol/entitlement or become production by default |
| Evolutionary skeleton | simple UI, mock visual data, partial non-core polish | violate existing state ownership, dependency direction, platform boundary or evidence labels |

## Technical-debt triggers

Create an explicit issue/note before expanding when a change would create: a second source of truth; duplicate business rule; View-to-system API bypass; duplicate service/client; another global singleton; repeated cross-feature edits; uncertainty about which model owns a state; multiple unrelated screens changing together; new App Group writer; or a device-only claim without a device test. File length alone is not a trigger, although the current `FriendMVPView.swift` is a high-navigation-cost aggregation seam.

## Build and test commands (not run by this documentation audit)

The current shared scheme is `DisciplinedPet` and its test action names `DisciplinedPetCoreTests` in `project.yml`. A historical, concrete local command appears in `Focumi_v0.6_Checkpoint_A_Visual_QA_2026-08-13.md`:

```zsh
xcodebuild test -project DisciplinedPet.xcodeproj -scheme DisciplinedPet \
  -destination 'platform=iOS Simulator,id=<verified-simulator-id>' \
  -derivedDataPath <task-scoped-derived-data> -resultBundlePath <task-scoped-result>.xcresult
```

Replace placeholders only after a read-only check of the current available simulator/target and task authorization. The audit did not execute it. Do not claim that the cited historical result applies to future source revisions.

## Engineering non-goals

- No hypothetical Android/plugin architecture, generic networking framework, cloud sync, package/module split, or 100% coverage drive.
- No new runtime dependency without current ecosystem/licence/security review and authorization.
- No “cleanup” of historical evidence, assets, snapshots or build output without a separately authorized exact-path operation.

## Architecture change checklist

Before implementing a triggered change, write: why the current owner is insufficient; minimal alternative; affected target/data/permission boundary; migration/rollback or recovery behavior; deterministic tests; Device evidence needed; and exact scope. Obtain explicit approval before touching Target, entitlement, App Group, schema, background behavior or dependency direction.
