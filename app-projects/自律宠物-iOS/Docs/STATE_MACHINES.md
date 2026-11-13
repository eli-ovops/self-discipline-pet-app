# STATE MACHINES — Current Core Flows

> **CURRENT** below is recovered from `FriendMVPReducer`, `P0CapabilityReducer`, `FriendMVPModel`, `P0CapabilityModel` and extension code on 2026-08-14. Effects describe local intent/dispatch, not confirmed iOS outcomes.

## 1. Focus lifecycle — `FriendMVPSnapshot.phase`

`FriendMVPPhase` is an explicit enum; `FriendMVPSnapshot` is persisted by `FriendMVPStore`. The `FriendMVPModel` is its runtime owner and runs reducer effects.

| Current state | Event / guard | Local side effect | Next | Recovery |
| --- | --- | --- | --- | --- |
| `onboarding` | adopt pet | persist | `setup` | reload persisted snapshot |
| `setup` | start; pet exists, valid goal/duration, Family Controls approved and selection nonempty (model guards) | request apply protection; schedule deadline; sync Live Activity; persist | `focusing` | model re-schedules future deadline on init |
| `focusing` | Shield intent received | persist | `requestingAccess` | intent first passes P0 session/generation/TTL checks |
| `requestingAccess` | cancel | persist | `focusing` | no protection command is dispatched |
| `requestingAccess` | submit reason | cancel deadline; request clear protection; schedule reminders; sync Live Activity; persist | `accessWindow` | reason enum is persisted; free-text remains draft-only |
| `accessWindow` | return | request reapply protection; new deadline; cancel reminders; sync Live Activity; persist | `focusing` | remaining focus duration is carried forward |
| `focusing` | reconcile at/after deadline | cancel deadline; request clear; cancel reminders; sync Live Activity; persist | `completed` | deadline is logical truth; monitor is an assist |
| `accessWindow` | reconcile at/after access deadline | request clear; cancel reminders; sync Live Activity; persist | `setup` | accumulated access time is updated |
| `focusing`/`requestingAccess`/`accessWindow` | user ends | cancel deadline; request clear; cancel reminders; sync Live Activity; persist | `setup` | idempotent reducer guard rejects other states |
| `completed` | dismiss | persist | `setup` | no automatic restart |

`requestProtection*` produces a `ShieldCommandReceipt` through `P0CapabilityModel`; it proves a local dispatch or local precondition rejection only. It does not transition the focus state based on a claimed system result.

## 2. Protection / capability lifecycle — `P0CapabilityState`

`P0CapabilityState` is explicit (`idle`, `configuring`, `localProtectionRequested`, `recoveryRequired`) and is persisted as a P0 App Group snapshot. `P0CapabilityModel` owns runtime mutation.

| State / event | Guard | Local effect | Next | Recovery |
| --- | --- | --- | --- | --- |
| any / authorization observed not approved | authorization absent/revoked | persist snapshot | `recoveryRequired` | new authorization creates a new session |
| idle/recovery / authorization restored | approved | reset generation/state; persist | `configuring` | previous session intent/receipt is not reused |
| configuring / selection updated | any | persist | `configuring` | selection resides in App Group store |
| configuring / apply command | approval + nonempty selection | dispatch `ManagedSettingsStore` command, persist receipt/snapshot | `localProtectionRequested` | receipt remains local evidence only |
| local requested / clear/reapply command | command guards in reducer | dispatch and persist | local requested/configuring per reducer | stale receipt/session/generation produces recovery state |
| any / App Group intent | matching session/generation/TTL/record ID | mark record consumed; persist | unchanged capability phase | unavailable/decode error becomes recovery-needed message |

## 3. Shield request and return seam

This is a **cross-process protocol**, not a single in-memory machine.

| Producer state/event | Guard | App Group effect | Consumer / next behavior |
| --- | --- | --- | --- |
| Shield Action secondary action | reads `P0SessionSnapshot` | writes `SharedEnvelope<PendingShieldIntent>` with 60-second TTL | returns `.openParentalControlsApp` |
| app activation / root `.task` | record matches session, generation, TTL and unconsumed ID | P0 model records consumed ID | `FriendMVPModel.routeLatestShieldIntent()` feeds `.shieldRequestReceived` |
| `FriendMVPPhase.focusing` | reducer guard | local persist | phase becomes `requestingAccess` |
| submit access request | phase must be requesting | local clear command + reminders | `accessWindow` |
| return request | phase must be access window | local reapply command + new logical deadline | `focusing` |

**CURRENT LIMIT:** a Shield action can reach the app and create an eligible intent, but source alone cannot prove the particular Shield is currently visible, has cleared, or has relocked.

## 4. Deadline / completion lifecycle

- `focusDeadline` and `accessDeadline` in `FriendMVPSnapshot` are the logical state machine deadlines.
- `FocusDeadlineMonitorClient` copies the focus deadline into App Group `focusDeadlineMonitor` and schedules `DeviceActivity`.
- Monitor interval end can clear its named `ManagedSettingsStore` and remove the copied context; the main app separately reconciles the persisted logical deadline on activation/timer ticks.
- Notifications at 10/30/60 minutes use `accessWindowID` only as reminders and are cancellable best effort.
- Live Activity is projected from snapshot phase/deadline and expires/ends based on projection; it is not persistence or completion authority.

## 5. Completion / reward

`reconcile` from a focused, expired snapshot increments `completedSessions`, adds 10 bond points, clears the focus deadline and enters `completed`. The UI then shows a presentation-only completion cue/one-shot stamp. `completionDismissed` returns to setup. No source evidence of economic inventory, penalties or negative reward is present.

## 6. Presentation-only implicit machines

These are intentionally separate from business state, but are Boolean/`@State` combinations rather than enums:

| Surface | Local owner | Interpretation |
| --- | --- | --- |
| settings, diagnostics, beta feedback | `FriendMVPView` | sheet routing |
| permission explanation, free-focus confirmation | setup subviews | modal routing |
| end confirmation | focus/access views | short-lived confirmation |
| pet change/clear-data/feedback | settings view | settings subflow |
| performance cue and completion moment | root/performance views | animation timing |

This is `BOOLEAN NAVIGATION SPRAWL` only at **P2 observation level**: the states are local/private and have no business writes until their explicit actions call the model. Keep new presentation flags local; if a flow spans app activation or changes reducer state, add an explicit owner instead.

## RECOMMENDED NORMALIZATION (not current fact)

Do not replace the existing reducers. Before a change that touches both focus and capability flow, add a small transition contract to the change record: triggering `FriendMVPPhase`, intended capability command, App Group record/key, expected local receipt, device evidence needed, and compensation/recovery. This reduces cross-model ambiguity without creating a third coordinator or enum hierarchy.
