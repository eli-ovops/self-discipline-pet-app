# Milo Identity Anchor Contract

## Scope and authority

This is a **planning-only, non-runtime** contract for a future, separately-authorized image-edit production pass. It does not approve generation, import, asset replacement, animation playback, or any SwiftUI/App change. Milo identity may be derived only from the files in `Design/CharacterAssets/VintageShojo/Approved/Milo/` listed below. Concept art is used only for page placement, never as character reference.

Authority, in order:

1. `Docs/Focumi_v0.6_Milo_Only_Core_Experience_PRD_Final.md` — v0.6 uses Approved Milo static poses and prohibits new Milo animation assets.
2. The Approved Milo PNG files themselves — sole visual identity source.
3. Current `FriendMVP` presentation routing — page/state context only.
4. Current stable Simulator screenshots — proportion and page-safe-area context only.

## Production master canvas

| Item | Contract |
| --- | --- |
| Master canvas | **1254 × 1254 px, RGBA, transparent background**. This is selected because the five P0 source images are native 1254² RGBA files. |
| Root anchor | `canvas_root = (627, 1254)`: the master canvas horizontal centre and bottom edge. It is a coordinate-system anchor, **not** a claim about Milo's anatomical contact point. |
| Page baseline | `y = 1254` in master coordinates. Runtime page placement remains owned by SwiftUI; this package does not prescribe a new layout. |
| Placement | Every 1254² source enters the master at `(x:0, y:0, scale:1.0, rotation:0°)` — non-destructive, no resample, no crop, no alpha-bbox centering. |
| Camera | Front/three-quarter view exactly inherited per chosen source. No new camera, focal length, crop, perspective, or global scale between adjacent frames. |
| Transparent result | Alpha outside the painted subject/approved prop must stay transparent. No cream plate, shadow card, opaque square, color key, or matte halo. |
| Physical contacts | `UNKNOWN / production blocker` until an artist marks per-action contact points on the source: paws to book/page/stamp, book/page to ground, and tail clearance. Do not infer them from alpha bbox. |

### Source placement audit

The following facts are pixel-audited from the source files. `alpha bbox` is `Pillow`'s non-zero-alpha bounding box `(left, top, right, bottom)`; it is descriptive only and must never drive auto-centering.

| Approved source | Native canvas / alpha bbox | Visual pose / prop | Production use |
| --- | --- | --- | --- |
| `milo_idle_v1.png` | 1254² RGBA / `(128,66,1033,1205)` | seated, upward attentive gaze, closed notebook at lower left | P0 Idle/Waiting source; current formal Meet/launch static via `FocumiMiloIdle`. |
| `milo_pact_v1.png` | 1254² RGBA / `(212,174,965,1147)` | seated over open spiral notebook, one forepaw near pencil | P0 Goal Notice/Pact source; catalog candidate, not current formal `MiloStaticPoseView` mapping. |
| `milo_focus_v2.png` | 1254² RGBA / `(39,181,1200,1075)` | low reading posture, both forepaws on open book | P0 Focus source; current formal Focus static via `FocumiMiloFocus`. |
| `milo_return_v1.png` | 1254² RGBA / `(187,120,1067,1162)` | seated, turning a book page, bookmark at lower right | P0 Return source; current formal Waiting/Return static via `FocumiMiloReturn`. |
| `milo_complete_v1.png` | 1254² RGBA / `(198,180,1049,1080)` | seated, stamp on paper with paw-print mark | P0 Completion source; current formal Completion static via `FocumiMiloComplete`. |
| `milo_waiting_v1.png` | 1254² RGBA / `(206,129,1012,1120)` | seated, both paws on ribboned closed book | Approved candidate; no current formal `MiloStaticPoseView` mapping. |
| `milo_start_v1.png` | 1254² RGBA / `(322,101,966,1131)` | seated, forepaw lifts a book page, pencil at right | P1 backlog candidate; no current formal mapping. |
| `milo_tap_v1.png` | 1254² RGBA / `(164,105,1044,1150)` | seated, forepaw holds turned page, pencil at right | P1 backlog candidate; no current formal mapping. |
| `milo_cancel_v1.png` | 1254² RGBA / `(338,153,959,1113)` | seated, forepaw rests on a closed notebook | P2 backlog candidate; no current formal mapping. |
| `milo_la_focus_v1.png` | 512² RGBA / full opaque canvas | stamp-framed head and book | **Not eligible** for transparent P0 keyframes; formal core use not found, broader use `UNKNOWN`. |
| `milo_la_returning_v1.png` | 512² RGBA / full opaque canvas | stamp-framed page-turn pose | **Not eligible** for transparent P0 keyframes; formal core use not found, broader use `UNKNOWN`. |
| `milo_la_waiting_v1.png` | 512² RGBA / full opaque canvas | stamp-framed portrait holding closed book | **Not eligible** for transparent P0 keyframes; formal core use not found, broader use `UNKNOWN`. |
| `milo_shield_portrait_v1.png` | 512² RGBA / full opaque canvas | oval portrait | **Not eligible** for transparent P0 keyframes; formal core use not found, broader use `UNKNOWN`. |

## Per-source non-destructive placement

For each 1254² source above: place the untouched original at `0,0` in the 1254² master. Preserve its original transparent margins, object placement, visible-book position and alpha edge exactly. The sources intentionally have different visible extents; normalizing them by bbox, head height, or bottom alpha edge would create root drift and book/paw drift.

The 512² opaque Live Activity/shield sources are excluded from this package's transparent master. They require a separately-approved opaque-card contract, not a scale-up or alpha-key conversion.

## Milo Identity Lock

Every proposed frame must retain, with no substitution or redrawing into another character:

- orange tabby face shape, soft round head, head-to-body proportion, eye spacing, amber eye scale, pink nose and small mouth;
- forehead tabby `M`/stripes, cheek/body stripes, white muzzle/chest/paw areas;
- upright triangular ears with the same inner-ear treatment;
- sage-green neckerchief, knot and leaf-like ends;
- hand-drawn dark linework, colored-pencil/hatching texture and warm paper-like rendering already visible in the approved source;
- source camera/view, lighting direction, palette and overall scale;
- the source-specific book, notebook, pencil, bookmark, stamp and paper relationship when that prop is present.

Never use an alpha bbox to centre a frame; never scale a character per frame; never move the canvas root; never let a paw detach from its approved prop without an explicit action contact plan; never change head/body ratio, stripes, scarf, eye placement, linework, palette, or lighting. Prohibit key-color pollution, opaque background plates, cutout fringes, extra limbs/tails, unapproved accessories, text, logos, other characters, and any reference outside the Approved Milo folder.

## Motion and Reduce Motion contract

The future animation may not fake performance through global scale, floating, bouncing, fades, or camera motion. A readable performance must instead use ordered eye/eyelid, ear, head, chest/weight, paw, hindquarter, tail and prop-contact changes specified in the manifest.

For Reduce Motion, each action has one named **static Approved landing pose** in the manifest. Render that source image unchanged and hold it; do not replace it with an omitted character, global fade, or unrelated decorative motion. Production remains blocked until the named landing source is confirmed to fit the exact runtime page at its existing SwiftUI size.

## Required production checks before any future generation

1. Artist marks the real ground/book/paw/tail contact points for the five P0 sources; this package deliberately leaves them `UNKNOWN` rather than inventing coordinates.
2. A human compares every image-edit output against the adjacent prior frame at 100% alpha compositing, including root `(627,1254)`, subject scale, book/paw distance and transparent edge.
3. A human confirms that no output is added to `Approved/`, the asset catalog, or runtime without a new authorization and a separate PRD change gate.
