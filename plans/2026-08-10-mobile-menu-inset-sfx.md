# Mobile Menu + GUI Inset + SFX Pass — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Three independent polish fixes reported after a real mobile playtest (10 ส.ค. 2569): (A) main menu unusable on phone, (B) full-screen dim overlays leave an uncovered strip under the Roblox topbar, (C) several interactions are silent.

**Architecture:** Three disjoint file groups, safe to work in parallel. A = `src/client/UI/MenuUI.luau`. B = `src/client/StarterGui/UI/SavePanel.luau` + `src/client/InteractBinder.luau`. C = `src/client/RecordQTE.luau` + `src/client/RecordTool.luau` + `src/client/StarterGui/UI/PCScreen.luau`.

**Tech Stack:** Luau, native Roblox layout (`UIListLayout`/`UISizeConstraint`/`UIScale`), existing `AudioService` (`src/client/AudioService.luau`).

**User decisions (locked via brainstorm 10 ส.ค.):**
- "has to inset" = **dim ไม่คลุมขอบบน** → fix is `IgnoreGuiInset = true`, not panel resizing.
- SFX: **wire the call sites only.** The team uploads Sound objects afterward. A missing Sound already warns once and stays silent — never crashes (`AudioService.sfx` → `findSound`). Do NOT source audio from Toolbox.
- SFX spots wanted: RecordQTE skillcheck, RecordTool purple `+Bonus` text, all of RecordTool (camera), PC app open/close.

---

## Task A: MenuUI responsive on phone

**Files:**
- Modify: `src/client/UI/MenuUI.luau`
- Test: `tests/RunTests.luau`

**The bug.** `MenuUI.open` builds `Gui_MainMenu` entirely from fixed pixel offsets:
`homePanel` is `UDim2.new(0, 420, 1, 0)`; buttons sit at hardcoded `y = 210, 284, 358, 432` at `340×62` each; `title` is at `(0,40,0,70)` sized `(1,-40,0,110)`; `back` is at `(0,40,1,-80)`.
On a phone in landscape (~390px tall) the stack needs `432 + 62 = 494px` and the last button ("เครดิต") is cut off below the screen edge — confirmed in the user's screenshot. The title also collides with the Roblox topbar icons because the ScreenGui sets `IgnoreGuiInset = true` (line 467) but nothing re-adds that padding.

**Constraints:**
- Keep `IgnoreGuiInset = true` on `Gui_MainMenu` — the white `flash` frame must cover the entire screen during the launch transition. Compensate with padding on `homePanel` instead, using `GuiService:GetGuiInset()`.
- Preserve the deliberate per-button rotations (`-1.4, 1.0, -0.7, 1.3`) — they're the notebook aesthetic. `Rotation` is visual only and does not affect `UIListLayout` ordering, so a list layout is compatible.
- `textButton(parent, text, pos, size, _color, rot)` is shared with the book/settings SurfaceGui code (`bookGui`, `setGui`), which passes **scale-based** UDim2s and must keep working unchanged. If you make `pos` optional for list-layout children, keep the existing positional signature working for every current caller.
- Don't touch `MenuUI.openFallback`'s layout (Task B adds one line there); it is the no-MenuScene safety path.

- [ ] **Step 1: Write a failing test for a pure layout helper**

Add to `tests/RunTests.luau` (follow the file's existing test style — read it first and match how other cases are registered):

```lua
-- MenuUI.layout: ต้องหดให้พอดีจอเตี้ย (มือถือแนวนอน) ไม่ให้ปุ่มล้นจอ
local MenuUI = require(...)  -- match how RunTests requires other client modules
local phone = MenuUI.layout(Vector2.new(844, 390))
local desktop = MenuUI.layout(Vector2.new(1920, 1080))
assert(phone.scale < desktop.scale, "จอเตี้ยต้อง scale เล็กกว่าจอใหญ่")
assert(phone.panelWidth <= 844 * 0.5, "แผงเมนูต้องไม่กินเกินครึ่งจอกว้าง")
assert(phone.scale * (phone.stackHeight + phone.topPad) <= 390, "ปุ่มทั้งกองต้องอยู่ในจอ")
assert(desktop.scale <= 1, "จอใหญ่ไม่ต้องขยายเกิน 1")
```

- [ ] **Step 2: Run it, confirm it fails** (`MenuUI.layout` doesn't exist yet).

- [ ] **Step 3: Implement `MenuUI.layout(viewport)` in the pure section** (above the `if not isStudio then return MenuUI end` line at 52, next to `camFor`/`slotLine`/`latestSlot`). It takes a `Vector2`-like with `.X`/`.Y` and returns a table of numbers — no Roblox instances, so `lune` can test it. Derive `scale` from viewport height against the design height the current pixel values assume, clamp it to a sane floor so text stays legible, and cap it at 1 so desktop is unchanged from today.

- [ ] **Step 4: Run the test, confirm it passes.**

- [ ] **Step 5: Apply the layout in `MenuUI.open`'s glue section.** Replace the hardcoded `homePanel`/`title`/button/`back` geometry with:
  - `homePanel` width from `layout.panelWidth`, plus a `UIPadding` whose `PaddingTop` includes `GuiService:GetGuiInset()` so the title clears the topbar.
  - A `UIListLayout` (with `Padding`) for the four stacked buttons so they can never overflow; `continueBtn` stays first, then `navBtn` book/setting/credit in the current order.
  - A `UIScale` on `homePanel` set to `layout.scale`.
  - Re-run the layout on `workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize")` so rotating the phone re-fits. Disconnect it when the menu closes (`launch`'s teardown destroys `gui` — clean up there too, don't leak a connection per menu open).
  - Keep `back` bottom-anchored but inside the safe area.

- [ ] **Step 6: Verify in Studio.** Use the Roblox Studio MCP (`mcp__Roblox_Studio__execute_luau`, `datamodel_type: "Edit"`) to call `MenuUI.layout` with several viewport sizes and print the results; confirm the phone case fits. Report the numbers. Do **not** try to click through the real menu — ask the controller to have the user playtest.

- [ ] **Step 7: Commit.**

```bash
git add src/client/UI/MenuUI.luau tests/RunTests.luau
git commit -m "fix(menu): responsive main menu so phone screens stop cutting off buttons"
```

---

## Task B: `IgnoreGuiInset` on full-screen dim overlays

**Files:**
- Modify: `src/client/StarterGui/UI/SavePanel.luau`
- Modify: `src/client/InteractBinder.luau`
- Modify: `src/client/UI/MenuUI.luau` (two one-line additions only — see the coordination note)

**The bug.** A `ScreenGui` without `IgnoreGuiInset` starts *below* the ~36px Roblox topbar. Any child sized `UDim2.fromScale(1, 1)` meant as a dimming backdrop therefore leaves the top strip undimmed — the panel floats over a bright, unclipped band. An audit of all 13 code-created ScreenGuis found exactly four with a full-screen dim but no `IgnoreGuiInset`:

| ScreenGui | File:line of the `Instance.new("ScreenGui")` |
|---|---|
| `Gui_SavePanel` | `src/client/StarterGui/UI/SavePanel.luau:39` |
| `Gui_BedMenu` | `src/client/InteractBinder.luau:77` |
| (second gui in same file) | `src/client/InteractBinder.luau:104` |
| `Gui_SnapPicker` | `src/client/UI/MenuUI.luau:750` |

**Do NOT add it to `Gui_HUD`** (`src/client/StarterGui/UI/HUD.luau:123`). The HUD has no dim layer and its top row is positioned assuming the inset exists; setting the flag would slide it under the topbar icons. Leaving it off is correct.

- [ ] **Step 1: Confirm each of the four actually has a full-screen dim child before editing it.** Read each site. If one of them turns out to have no `fromScale(1,1)` backdrop, do not add the flag — report it instead.

- [ ] **Step 2: Add `gui.IgnoreGuiInset = true` at each confirmed site,** next to where the other ScreenGui properties are set, matching each file's existing property-assignment style. Add a short Thai comment on the first one explaining why (dim ต้องคลุมถึงขอบบนสุด ไม่งั้นเหลือแถบสว่างใต้ topbar), mirroring the wording already used at `CutscenePlayer.luau:149` and `EditQTE.luau:375`.

- [ ] **Step 3: Also add it to `MenuUI.openFallback`'s ScreenGui** (`src/client/UI/MenuUI.luau:904`) — it draws a full-screen `bg` Frame with the same problem.

- [ ] **Step 4: Verify.** Via Studio MCP `execute_luau` (`datamodel_type: "Edit"`), confirm no syntax errors were introduced by requiring/loading the changed modules. Visual confirmation is a user playtest — report that as a handoff, don't attempt it.

- [ ] **Step 5: Commit.**

```bash
git add src/client/StarterGui/UI/SavePanel.luau src/client/InteractBinder.luau src/client/UI/MenuUI.luau
git commit -m "fix(gui): dim overlays cover the topbar strip (IgnoreGuiInset)"
```

**Coordination note:** Task A also edits `src/client/UI/MenuUI.luau`. Whoever runs second must re-read the file before editing — do not apply a stale diff. The two changes are in different functions (`open`'s homePanel geometry vs. `openSnapshotPicker`/`openFallback` one-liners) so they don't conflict semantically.

---

## Task C: SFX wiring

**Files:**
- Modify: `src/client/RecordQTE.luau`, `src/client/RecordTool.luau`, `src/client/StarterGui/UI/PCScreen.luau`
- Modify: `src/client/AudioService.luau` (header comment table only)

**Context.** `AudioService.sfx(name, pitchVary?, volumeScale?)` clones a `Sound` out of `SoundService.SFX`, plays it through the SFX `SoundGroup`, and cleans up after itself. A name with no matching Sound object warns **once** and is otherwise silent — so wiring a call site for audio that doesn't exist yet is safe and is exactly what the user asked for. There is also a central binder in `Main.client.luau:121` that plays `Audio.sfx(key)` for any GUI object with an `Sfx` attribute; prefer that attribute for plain buttons instead of adding manual calls.

**Sound names to introduce** (the team uploads these into `SoundService.SFX` later):

| name | fires when |
|---|---|
| `qte_tick` | needle crosses into the good/perfect band during the skillcheck |
| `qte_hit_perfect` / `qte_hit_good` / `qte_hit_miss` | each individual press is graded |
| `qte_jackpot` | round ends all-perfect (`jackpot` is already computed at `RecordQTE.luau:184`) |
| `camera_shutter` | camera Tool activated (a real recording click) |
| `record_bonus` | `floatGain` fires with `bonus == true` (the purple `+N Bonus!` text) |
| `record_gain` | `floatGain` fires without bonus |
| `notebook_place` | `PlaceNotebook` action fires |
| `zone_enter` / `zone_exit` | player crosses into/out of the film zone ring |
| `app_open` / `app_close` | a PC app opens / closes |
| `pc_off` | the whole PC screen closes |

- [ ] **Step 1: `RecordQTE.luau`.** Keep the existing end-of-round `Audio.sfx(...)` at line 185 as the summary sound, and add `qte_jackpot` when `jackpot` is true. Add a per-press sound at the grading site (`RecordQTE.gradeFor` is called at line 204) using the three `qte_hit_*` names. Add `qte_tick` when the sweeping needle first enters the good band on each pass — it must fire on the *transition* into the zone, not every frame while inside (track the previous in/out state). Use a small `pitchVary` on the per-press sounds so repeats don't sound machine-gunned.

- [ ] **Step 2: `RecordTool.luau`.** This file currently has **zero** audio. Add:
  - `Audio.sfx("camera_shutter")` in the Tool `Activated` handler (`:74`) on the recording branch — the `else` at `:86`, not the Notebook branch.
  - `Audio.sfx("notebook_place")` on the `PlaceNotebook` branch (`:77-85`).
  - In `floatGain` (`:121`), `record_bonus` when `bonus` is true, else `record_gain`. Play it at a reduced `volumeScale` (this fires on every click — it must not drown out `camera_shutter`).
  - In the zone-watch loop (`:171-185`), `zone_enter` / `zone_exit` on transitions only — that loop runs every 0.5s, so track previous state and fire on change, never every tick. Note the loop currently only tracks whether a spot *exists*; you need whether the **player** is inside it — `RecordTool.inZone` already computes exactly that and is the pure helper to reuse.
  - You must add the `Audio` require to this file; copy the require style used by a sibling in the same folder (`RecordQTE.luau` requires it — match that, don't invent a new path).

- [ ] **Step 3: `PCScreen.luau`.** `openApp` (`:189`), `closeApp` (`:195`), and `closeScreen` (called at `:247`) are the three hooks — `app_open`, `app_close`, `pc_off` respectively. Check whether the app buttons already carry an `Sfx` attribute handled by the central binder; if they do, don't double-play (a comment at `DialogueUI.luau:411` documents that exact trap — "ไม่เรียก Audio.sfx เองกันดัง 2 ที"). Prefer whichever single mechanism the file already uses.

- [ ] **Step 4: Document the new names** in the header comment of `src/client/AudioService.luau` (which already tells the team "วาง Sound object ตามโครงข้างล่าง → ตั้งชื่อ → จบ ไม่ต้องแตะโค้ด"). Add the table above so the team knows exactly what to record. Keep it terse and in the file's existing Thai comment voice.

- [ ] **Step 5: Verify.** Via Studio MCP `execute_luau` (`datamodel_type: "Edit"`), require each modified module to confirm it still loads without syntax/require errors, and call `AudioService.sfx("qte_tick")` once to confirm the missing-sound path warns instead of erroring. Report the actual console output.

- [ ] **Step 6: Commit.**

```bash
git add src/client/RecordQTE.luau src/client/RecordTool.luau src/client/StarterGui/UI/PCScreen.luau src/client/AudioService.luau
git commit -m "feat(audio): wire sfx hooks for skillcheck, camera tool, and PC apps"
```

---

## Definition of done

- [ ] Menu fits a 844×390 viewport with no button clipped
- [ ] Four dim overlays cover the full screen including the topbar strip
- [ ] Every SFX hook above fires, and missing Sounds warn-once instead of erroring
- [ ] New sound names documented in `AudioService.luau`'s header for the team
- [ ] `git pull --rebase` then push (repo has concurrent editors — CLAUDE.md rule 12)
- [ ] User playtests on a phone to confirm A and B visually (agents cannot verify this)
