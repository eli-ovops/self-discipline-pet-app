# Milo Action Scene Plan

## Planning status

This package specifies potential future image-edit keyframes only. No image, animation, asset, runtime code, or Approved file has been created or changed. Final PRD v0.6 continues to use one existing Approved static Milo pose at a time; any production of these planned frames needs separate authorization.

## Authority and audit summary

| Input | Read-time finding | Planning use |
| --- | --- | --- |
| `Docs/Focumi_v0.6_Milo_Only_Core_Experience_PRD_Final.md` | Formal flow is launch → Meet Milo → setup → focus → necessary access/return → complete; v0.6 permits only existing Approved static Milo at runtime. | State/page intent, hard no-new-animation boundary. |
| `Approved/Milo/*.png` | 13 files: nine 1254² transparent RGBA illustrations and four 512² fully opaque card/portrait images. | Only character identity source. See Identity Anchor Contract. |
| `CompanionPresentation.swift` | Formal mood mapping: welcome → Idle, focusing → Focus, waiting → Return, celebrating → Complete. | Actual source-routing truth. |
| `FriendMVPView.swift` | Meet uses `.welcome`; Setup `.welcome`; Focus `.focusing`; Necessary Access/Waiting and presentation-only Return use `.waiting`; Completion `.celebrating`. | Page/action mapping; no code change proposed. |
| `Evidence/.../screenshots/final-current-*.png` | Stable layout evidence places Milo as a large central visual between copy/controls and primary CTA. | Page safe-area and relative occupancy only. |
| `VisualReview/.../focumi-v0.6-core-six-screens-concept-v1.png` | Composition reference only; it explicitly says official character assets replace the depicted characters. | Never an identity source. |

### Formal asset reference audit

| Current formal state/page | `MiloStaticPoseView` mood | Resolved catalog image | Approved source | Status |
| --- | --- | --- | --- | --- |
| Launch/Meet Milo, Task Setup | `.welcome` | `FocumiMiloIdle` | `milo_idle_v1.png` | formal use |
| Focus | `.focusing` | `FocumiMiloFocus` | `milo_focus_v2.png` | formal use |
| Necessary Access/Waiting and presentation-only Return acknowledgement | `.waiting` | `FocumiMiloReturn` | `milo_return_v1.png` | formal use |
| Completion | `.celebrating` | `FocumiMiloComplete` | `milo_complete_v1.png` | formal use |
| Pact/Start/Tap/Cancel/Waiting alternatives | none in current formal mapping | respective catalog candidates | matching Approved PNG | formal use not found; candidate only |
| `milo_la_*`, `milo_shield_portrait_v1` | none in current formal core mapping | `UNKNOWN` outside audited core | matching Approved PNG | formal use not found; broader status UNKNOWN |

## Core flow → proposed action mapping

| Formal flow context | P0 scene | Current static source / proposed static landing | Why it is P0 |
| --- | --- | --- | --- |
| Meet Milo and quiet waiting | P0-01 Idle / Waiting | `milo_idle_v1.png` / `milo_idle_v1.png` | Establishes companion presence without “choice” semantics. |
| Task Setup / pact notice | P0-02 Goal Notice / Pact | `milo_pact_v1.png` / `milo_pact_v1.png` | Directly supports the task card and duration commitment hierarchy. |
| Focusing | P0-03 Focus Ambient | `milo_focus_v2.png` / `milo_focus_v2.png` | Quiet reading posture supports time passage without a Pause claim. |
| Necessary Access / formal Waiting/Return | P0-04 Return | `milo_return_v1.png` / `milo_return_v1.png` | Honest “Milo is waiting” acknowledgement; not a Shield success assertion. |
| Completion | P0-05 Completion | `milo_complete_v1.png` / `milo_complete_v1.png` | Gives bounded, warm recognition while preserving single completion settlement. |

The requested five actions remain P0: audit did not require substitution. Start/Tap Response/Launch/Gentle End remain deferred because the formal PRD currently relies on static poses and expanding this manifest would produce unneeded animation scope.

## Shared keyframe notation

All timecodes are relative to an action. “Support” means the explicitly locked visual contact that must not slide on the master canvas. The physical contact coordinate remains `UNKNOWN` until marked by art; the descriptive support is still mandatory. Every frame is an image-edit request, not a text-to-image request. Root, camera, canvas and scale stay fixed under the Identity Anchor Contract.

## P0-01 — Idle / Waiting

- Trigger: Meet Milo shown, or a quiet non-session waiting beat.
- Emotion goal: calm availability; Milo notices the person, then rests.
- Source / landing / Reduce Motion: `milo_idle_v1.png` unchanged for frame 01 and the static landing.
- Duration / loop: 3.6 s; loop only from frame 05 back to frame 01 after a held beat.

| Frame / time | Performance design |
| --- | --- |
| 01 / 0.00s | **Gaze:** slightly up-left as source; **eyes:** open, soft; **ears:** neutral upright; **head:** source tilt; **chest/weight:** quiet seated balance; **forepaws:** planted together; **hind/hips:** seated; **tail:** curled at right; **prop contact:** closed notebook stays lower-left, untouched; **emotion:** patient; **delta:** start/source; **support:** both forepaws, hindquarters, tail curl and notebook position fixed. |
| 02 / 0.55s | **Gaze:** shifts toward centre; **eyes:** upper lids lower into a half blink; **ears:** near ear turns forward first; **head:** 1–2° toward centre; **chest/weight:** tiny forward attention, no scale; **forepaws:** still planted; **hind/hips:** unchanged; **tail:** tip relaxes one small curve; **prop contact:** notebook unmoved; **emotion:** “I noticed”; **delta:** eye/ear lead only; **support:** paws, hips, notebook fixed. |
| 03 / 1.20s | **Gaze:** centre/user-facing; **eyes:** blink completes then opens; **ears:** both forward; **head:** settles level; **chest/weight:** slight ribcage lift; **forepaws:** left paw presses imperceptibly, no travel; **hind/hips:** remain seated; **tail:** tip curls closer to body; **prop contact:** no contact added; **emotion:** attentive welcome; **delta:** main attention beat; **support:** paw bases, hips, tail root, notebook fixed. |
| 04 / 2.10s | **Gaze:** holds centre; **eyes:** warm open with a micro squint; **ears:** soften outward a fraction; **head:** returns source tilt; **chest/weight:** breath releases; **forepaws:** unchanged; **hind/hips:** unchanged; **tail:** rests; **prop contact:** notebook unchanged; **emotion:** gentle pause; **delta:** attention becomes reassurance; **support:** all source contacts fixed. |
| 05 / 3.10s | **Gaze:** returns slightly up-left; **eyes:** open, restful; **ears:** neutral; **head:** exact source tilt; **chest/weight:** stable; **forepaws:** exact source; **hind/hips:** exact source; **tail:** exact source curl; **prop contact:** exact source; **emotion:** natural settle; **delta:** returns to landing; **support:** all source contacts fixed. |

## P0-02 — Goal Notice / Pact

- Trigger: task input or duration selection becomes the focal reading task.
- Emotion goal: Milo quietly acknowledges the person's stated intention.
- Source / landing / Reduce Motion: `milo_pact_v1.png` unchanged for frame 01 and static landing.
- Duration / loop: 3.8 s; no autoplay loop in v0.6.

| Frame / time | Performance design |
| --- | --- |
| 01 / 0.00s | **Gaze:** down to open spiral notebook; **eyes:** calm open; **ears:** neutral; **head:** source downward angle; **chest/weight:** seated over book; **forepaws:** left near pencil, right on book edge; **hind/hips:** seated; **tail:** rests right; **prop contact:** notebook, pencil and both paws exactly source; **emotion:** listening; **delta:** start/source; **support:** notebook baseline and paw contacts fixed. |
| 02 / 0.60s | **Gaze:** moves from page toward the task card direction; **eyes:** lower lid softens; **ears:** left ear turns first; **head:** lifts 1–2°; **chest/weight:** subtle forward readiness; **forepaws:** remain on their book-side positions; **hind/hips:** fixed; **tail:** tip makes one shallow curve; **prop contact:** pencil distance unchanged; **emotion:** noticing the goal; **delta:** ear then gaze lead; **support:** notebook, pencil, paw bases fixed. |
| 03 / 1.35s | **Gaze:** centre-forward; **eyes:** one deliberate blink opens; **ears:** both attentive; **head:** slightly higher but no body translation; **chest/weight:** chest rises; **forepaws:** left paw adds gentle pressure near pencil without moving it; **hind/hips:** fixed; **tail:** quiet; **prop contact:** pencil remains exactly at source angle; **emotion:** pact acknowledgement; **delta:** main action is paw pressure plus look; **support:** notebook spine, pencil, right paw, hips fixed. |
| 04 / 2.35s | **Gaze:** holds person then returns halfway to notebook; **eyes:** softened; **ears:** relax; **head:** pauses halfway; **chest/weight:** releases; **forepaws:** stay anchored; **hind/hips:** fixed; **tail:** rests; **prop contact:** no page turn or new mark; **emotion:** “we can begin”; **delta:** emotional pause; **support:** all book/pencil contacts fixed. |
| 05 / 3.30s | **Gaze:** down to page; **eyes:** source-like calm; **ears:** source neutral; **head:** exact source; **chest/weight:** stable; **forepaws:** exact source; **hind/hips:** exact source; **tail:** exact source; **prop contact:** exact source notebook/pencil; **emotion:** settled commitment; **delta:** returns to landing; **support:** notebook, pencil and paws fixed. |

## P0-03 — Focus Ambient

- Trigger: active focus timer page.
- Emotion goal: present concentration, never a fake progress or Pause state.
- Source / landing / Reduce Motion: `milo_focus_v2.png` unchanged for frame 01 and static landing.
- Duration / loop: 4.0 s; a future loop may join frame 05 to frame 01 only after visual review.

| Frame / time | Performance design |
| --- | --- |
| 01 / 0.00s | **Gaze:** down at open book; **eyes:** focused open; **ears:** neutral-forward; **head:** low source angle; **chest/weight:** low reading rest; **forepaws:** both on book; **hind/hips:** tucked low; **tail:** wrapped at right; **prop contact:** book and paw contacts exactly source; **emotion:** absorbed; **delta:** start/source; **support:** book, forepaw bases, hips and tail root fixed. |
| 02 / 0.70s | **Gaze:** tracks a short line across page; **eyes:** lids narrow slightly; **ears:** far ear pivots back a fraction then returns; **head:** 1° follows gaze; **chest/weight:** one quiet inhale; **forepaws:** remain pressed on pages; **hind/hips:** fixed; **tail:** no travel; **prop contact:** page edges unmoved; **emotion:** reading; **delta:** eyes lead, head follows; **support:** all book/paw contacts fixed. |
| 03 / 1.55s | **Gaze:** pauses at page centre; **eyes:** single slow blink; **ears:** both return forward; **head:** dips a fraction; **chest/weight:** exhale settles toward book; **forepaws:** one toe flex implied without changing paw silhouette placement; **hind/hips:** fixed; **tail:** tip makes a small settle; **prop contact:** book has no page turn; **emotion:** quiet rhythm; **delta:** main action is blink/breath/toe flex; **support:** book, paws, hips fixed. |
| 04 / 2.55s | **Gaze:** briefly rises just above page; **eyes:** open softer; **ears:** alert then soften; **head:** 1° lift; **chest/weight:** tiny lift only; **forepaws:** fixed; **hind/hips:** fixed; **tail:** still; **prop contact:** page/book frozen; **emotion:** mindful pause; **delta:** small attention reset; **support:** book/paws/hips fixed. |
| 05 / 3.55s | **Gaze:** back to page; **eyes:** source focused; **ears:** source; **head:** exact source; **chest/weight:** source rest; **forepaws:** exact source; **hind/hips:** exact source; **tail:** exact source; **prop contact:** exact source; **emotion:** natural settle; **delta:** returns to landing; **support:** all source contacts fixed. |

## P0-04 — Return

- Trigger: formal Necessary Access/Waiting page; it recognizes a return opportunity but does not claim Shield/re-lock success.
- Emotion goal: patient, respectful acknowledgement.
- Source / landing / Reduce Motion: `milo_return_v1.png` unchanged for frame 01 and static landing.
- Duration / loop: 3.8 s; no automatic repeated “welcome back” loop.

| Frame / time | Performance design |
| --- | --- |
| 01 / 0.00s | **Gaze:** up and slightly right as source; **eyes:** open, hopeful; **ears:** upright; **head:** source lift; **chest/weight:** seated; **forepaws:** left supports raised page, right rests by book; **hind/hips:** seated; **tail:** rises at right; **prop contact:** page, book and bookmark exact source; **emotion:** waiting; **delta:** start/source; **support:** book base, page-holding paw, hips fixed. |
| 02 / 0.55s | **Gaze:** moves toward person; **eyes:** half blink; **ears:** near ear turns first; **head:** 1–2° toward centre; **chest/weight:** gentle forward acknowledgement; **forepaws:** page-holding paw stays at exact contact; **hind/hips:** fixed; **tail:** tip relaxes slightly; **prop contact:** page bend, bookmark and book unchanged; **emotion:** “you are here”; **delta:** eyes/ear lead; **support:** page-hand, book, hips fixed. |
| 03 / 1.30s | **Gaze:** centre; **eyes:** blink opens warmly; **ears:** both forward; **head:** pauses level; **chest/weight:** a small chest lift, no translation; **forepaws:** right paw gently firms at book edge; **hind/hips:** fixed; **tail:** holds; **prop contact:** no page turn; **emotion:** return recognition; **delta:** main look and weight beat; **support:** raised-page paw, book, bookmark, hips fixed. |
| 04 / 2.30s | **Gaze:** holds for a calm beat; **eyes:** soft; **ears:** ease neutral; **head:** source-like tilt resumes; **chest/weight:** releases; **forepaws:** unchanged; **hind/hips:** unchanged; **tail:** settles; **prop contact:** all props unchanged; **emotion:** non-demanding invitation; **delta:** emotional pause; **support:** page, book and paws fixed. |
| 05 / 3.25s | **Gaze:** returns source up-right; **eyes:** exact source; **ears:** exact source; **head:** exact source; **chest/weight:** exact source; **forepaws:** exact source; **hind/hips:** exact source; **tail:** exact source; **prop contact:** exact source; **emotion:** patient settle; **delta:** returns to landing; **support:** all source contacts fixed. |

## P0-05 — Completion

- Trigger: completed screen after the existing reducer has settled completion once.
- Emotion goal: a small, grounded acknowledgement — not a floating celebration.
- Source / landing / Reduce Motion: `milo_complete_v1.png` unchanged for frame 01 and static landing.
- Duration / loop: 3.5 s; play once only.

| Frame / time | Performance design |
| --- | --- |
| 01 / 0.00s | **Gaze:** down to stamp/paper; **eyes:** calm open; **ears:** neutral; **head:** source tilt; **chest/weight:** seated over paper; **forepaws:** left on stamp, right supports; **hind/hips:** seated; **tail:** curved right; **prop contact:** stamp, paw-print paper and paws exact source; **emotion:** finishing touch; **delta:** start/source; **support:** paper, stamp base, paws, hips fixed. |
| 02 / 0.45s | **Gaze:** begins toward viewer; **eyes:** lids lower into a pleased blink; **ears:** both lift a fraction; **head:** 1° lifts; **chest/weight:** chest rises; **forepaws:** stamp paw remains vertically seated, no stamp travel; **hind/hips:** fixed; **tail:** tip lifts a fraction; **prop contact:** stamp remains pressed to same paper point; **emotion:** recognition begins; **delta:** eyes/ears lead; **support:** stamp/paper/paw contacts fixed. |
| 03 / 1.05s | **Gaze:** centre; **eyes:** blink opens bright but same size; **ears:** attentive; **head:** small proud lift; **chest/weight:** gentle lift without scale; **forepaws:** stamp paw eases pressure but keeps alignment; **hind/hips:** fixed; **tail:** small positive curve; **prop contact:** no new paw print, stamp stays registered; **emotion:** “we did it”; **delta:** main action is release of stamp pressure; **support:** stamp centre, paper, paws, hips fixed. |
| 04 / 1.95s | **Gaze:** holds viewer; **eyes:** soft warm squint; **ears:** relax; **head:** source-side tilt returns; **chest/weight:** settles; **forepaws:** unchanged; **hind/hips:** unchanged; **tail:** rests; **prop contact:** stamp and paper unchanged; **emotion:** affectionate pause; **delta:** completion emotion holds; **support:** all paper/stamp contacts fixed. |
| 05 / 2.95s | **Gaze:** returns source down-centre; **eyes:** exact source; **ears:** exact source; **head:** exact source; **chest/weight:** exact source; **forepaws:** exact source; **hind/hips:** exact source; **tail:** exact source; **prop contact:** exact source stamp/paper; **emotion:** grounded settle; **delta:** returns to landing; **support:** all source contacts fixed. |

## Deferred backlog only

| Priority | Deferred action | Why not a P0 manifest now |
| --- | --- | --- |
| P1 | Launch poster micro-attention | v0.6 launch is a short static brand transition; separate timing/runtime authorization needed. |
| P1 | Start / Tap response | Current formal route intentionally avoids tap reactions and timeline transforms. |
| P2 | Gentle end / early-exit acknowledgement | Current danger/end copy must remain honest and is not a visual-performance expansion target. |

No deferred item has keyframes or a generation request in this package.
