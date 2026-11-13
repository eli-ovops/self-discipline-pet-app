# PLATFORM — Capability and Evidence Boundaries

> Source/config audit date: 2026-08-14. A capability can be source/config confirmed while its runtime behavior remains `DEVICE REQUIRED`.

| Capability | Current owner / adapter | Target + shared state | Status | Failure/fallback/evidence boundary |
| --- | --- | --- | --- | --- |
| Family Controls authorization/selection | `P0CapabilityModel`, `FamilyControlsAuthorizationClient`, `ActivitySelectionStore` | main app + App Group selection | `SOURCE CONFIRMED`, `CONFIG CONFIRMED` | failed/revoked authorization moves capability model toward recovery; actual picker/account behavior is `DEVICE REQUIRED` |
| Managed Settings shield | `ShieldProtectionClient`; Monitor can clear its named store | main app + Monitor; Family Controls entitlement | `SOURCE CONFIRMED`, `CONFIG CONFIRMED`, `DEVICE EVIDENCE FOUND` for dated P0-A scope | local `ShieldCommandReceipt` is not system status; P0-A evidence is narrow and does not prove current UI/complete loop |
| Shield Action | `DisciplinedPetShieldActionExtension` | extension + App Group intent envelope | `SOURCE CONFIRMED`, `CONFIG CONFIRMED`, `DEVICE EVIDENCE FOUND` for P0-A hot/cold intent scope | store/session/TTL failure returns `.defer`; app must consume eligible intent |
| Shield Configuration | `DisciplinedPetShieldConfigurationExtension` | extension + derived species App Group key | `SOURCE CONFIRMED`, `CONFIG CONFIRMED`, `DEVICE REQUIRED` | Apple owns Shield layout; icon key is presentation only |
| Device Activity | `FocusDeadlineMonitorClient`, `DisciplinedPetMonitorExtension` | main app + Monitor + copied App Group context | `SOURCE CONFIRMED`, `CONFIG CONFIRMED`, `DEVICE REQUIRED` | app logical deadline reconciles on activation; monitor scheduling/end timing is not proven by source |
| Live Activity / WidgetKit | `FocusLiveActivityClient`, `DisciplinedPetLiveActivity` | app + Widget extension, attributes shared in source | `SOURCE CONFIRMED`, `CONFIG CONFIRMED`, `DEVICE REQUIRED` | build/test mapping does not prove Island, Lock Screen, expiry or system authorization behavior |
| Local notifications | `LocalNotificationClient` | main app / UserNotifications | `SOURCE CONFIRMED`, `DEVICE REQUIRED` | disabled permission leaves user-directed return path; notifications are reminders, never deadline truth |
| App Groups | `AppGroupStore` with JSON DTOs | main app, Monitor, Shield Action; Shield Configuration reads species | `SOURCE CONFIRMED`, `CONFIG CONFIRMED` | multi-process propagation, corrupt data and atomic cross-key behavior remain protocol/device risks |
| Audio / interruption | `FocusAudioClient` | main app / AVFoundation | `SOURCE CONFIRMED`, `CONFIG CONFIRMED` audio background mode | client stops while inactive yet configuration declares audio background mode; intended runtime policy is `UNKNOWN` pending explicit decision/device check |
| Scene lifecycle / cold launch | root `scenePhase`, `.task`, `reconcile()` | main app | `SOURCE CONFIRMED` | source re-runs reconciliation on active and initial task; system launch/termination races are `DEVICE REQUIRED` |

## Target and entitlement facts

`project.yml` and the generated project define:

```text
DisciplinedPet                         application
DisciplinedPetMonitor                  Device Activity Monitor extension
DisciplinedPetShieldConfiguration      Managed Settings UI extension
DisciplinedPetShieldAction             Managed Settings action extension
DisciplinedPetLiveActivity             WidgetKit extension
DisciplinedPetCoreTests                unit-test bundle
```

- Main app and the three Family Controls extensions carry Family Controls and App Group configuration in `Config/*.entitlements` / `project.yml`.
- Main app declares `NSSupportsLiveActivities`; the Live Activity extension is a separate WidgetKit target.
- Current app configuration lists `UIBackgroundModes: audio`. This is a configuration fact, not evidence that background playback is desired or works.
- No push notification, network, account, cloud, database, Core Data or SwiftData integration was found in current source/config scope.

## App Group protocol inventory

| Key | Writer(s) | Reader(s) | Role |
| --- | --- | --- | --- |
| `p0.activity-selection` | main app | main app | selected restriction scope |
| `p0.session-snapshot` | P0 capability model | Shield Action, main app | capability session/generation |
| `p0.pending-shield-intent` | Shield Action | main app | TTL-bound request intent |
| `p0.monitor-event` | Monitor | diagnostics/main app path | diagnostic event |
| `friend-beta.focus-deadline-monitor.v1` | main app; Monitor removes | Monitor/main app | deadline coordination |
| `p0.command-receipt` | main app | diagnostics/main app | local dispatch evidence |
| `friend-beta.shield-companion-species.v1` | Friend MVP model | Shield Configuration | presentation-only species |

Do not reuse a key, change a DTO, add another writer, or infer system behavior from any value without a separately authorized protocol migration and device validation.

## Evidence policy

```text
Implementation: source exists
Build: Xcode produced a binary
Tests: automated assertions ran
Simulator: app-level rendering/state evidence
Device: physical iPhone/system-surface evidence
User Evidence: completed action/reuse/payment evidence
```

Existing `Evidence/P0-A-real-device-2026-08-10/README.md` records limited P0-A Device evidence (authorization/selection, Shield display, official app open, intent hot/cold visibility, clear/reapply and listed propagation/revocation checks). It does **not** certify the later visual implementation, Live Activity surfaces, full P0-B/P0-C loop, user retention, payment or release.

## Required device checks before any corresponding claim

- Apple-owned Shield appearance and secondary action under the current build.
- focus deadline monitor behavior after backgrounding, force termination, clock changes and cold launch.
- notification permission/delivery and late/duplicate response behavior.
- Live Activity authorization, Lock Screen, Dynamic Island, expiry and cleanup.
- audio interruption, route changes, inactive behavior and the intended relationship to the configured background-audio mode.
- accessibility runtime hierarchy, Reduce Motion, large Dynamic Type and FamilyActivityPicker.

## Platform change triggers

New entitlement, App Group, extension, background mode, system permission, Device Activity rule, notification action, external SDK, shared-store key/schema or system API claim requires an explicit change note, target/owner table, fallback, test plan and Device evidence plan before implementation.
