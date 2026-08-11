# PC app phase gate — Bank/Message hidden until Phase 2

**Date:** 2026-08-12 · **User request:** เฟส 1 มีแอปแค่ 4 ตัว (Shop, Editor, Upload, Feedback) · Bank กับ Message (Inbox) ซ่อนไว้ก่อน โผล่ตอนเฟส 2

## Decisions (confirmed with user)

1. **Bank/Message hidden in Phase 1**, all 6 apps visible from Phase 2 onward. Shop/Editor/Upload/Feedback always visible (no gate needed — feedback stays in Phase 1 per correction).
2. **Server-side gate too** (defense-in-depth), not just client icon hide — matches existing `MentalService`/`SponsorService` phase-check pattern.
3. Manage (employee hiring) is reached only via a button inside Bank — already independently phase-gated by `StaffService.hire` checking `state.phase < r.phase` (every roster entry requires phase ≥ 2) — **no new gate needed there**, hiding Bank's icon is sufficient since Manage has no other entry point.
4. Message/Inbox has no server-side action routing at all (`Message.luau` never calls `deps.fireAction`) — nothing to gate server-side, icon hide is fully sufficient.

## Root mechanism (reuse, don't invent)

`PCScreen.open`'s icon loop already reads a static `app.hidden` boolean per entry in `PC_APPS` (used today only to permanently hide `manage`). Extending this to be phase-aware — recomputed each time the PC is opened — is a data change, not a new system, matching CLAUDE.md rule 8/9 (fix within the existing system, don't build a resolver).

## Changes

1. **`src/shared/Config.luau`** — add `Config.AppMinPhase = { bank = 2, message = 2 }` (near `PhaseGates`). Apps not listed = always unlocked.
2. **`src/shared/Formulas.luau`** — add pure `Formulas.appUnlocked(phase, appId): boolean` (returns `true` if no entry in `AppMinPhase`, else `phase >= AppMinPhase[appId]`). Testable via lune, no Roblox API.
3. **`src/server/Services/MoneyService.luau`** — `adjustSpending` gains a guard: `if not Formulas.appUnlocked(state.phase, "bank") then return false end`. Defense-in-depth for `AdjustSpending` action.
4. **`src/client/Main.client.luau`** — right before each `PCScreen.open(...)` call, loop `PC_APPS` and set `app.hidden = not Formulas.appUnlocked(latestState.phase, app.id)` **only for entries with an `AppMinPhase` mapping** (bank, message) — must not touch `manage`'s static `hidden = true`.
5. **`tests/RunTests.luau`** — pure-function coverage: `Formulas.appUnlocked` phase boundaries for bank/message/shop/feedback; `MoneyService.adjustSpending` rejected at phase 1, allowed at phase 2 (existing behavior unaffected for phase ≥ 2).
6. **Docs** — `docs/02-game-design-locked.md` §1 (Phase Gate) gets a short new subsection stating the app-unlock rule (this is a brand-new rule, not previously documented anywhere per the codebase audit) + a cross-reference note in §9.7 (Bank). `docs/09-app-ui-spec.md` §8/§9 get a one-line note each.

## Verification

`require()`-based check against the live modules in Studio Edit mode (same pattern established last session — proof-of-typing via grep is not enough): assert `Formulas.appUnlocked` boundaries directly and `MoneyService.adjustSpending` phase gate, then hand-sync the touched files into Studio via `multi_edit` (Rojo still disconnected) and re-run.

## Out of scope (flagged, not fixed)

- `CommentService.generate` is not phase-gated — moot now since Feedback stays visible in Phase 1 (comments generate and are answerable immediately, no pileup).
- No live Play-mode visual check of the icon bar — this session verifies logic only, same caveat as the previous Shop-levels change; user should Stop→Play and open the PC to confirm the icon bar visually shrinks to 4 in a fresh Phase-1 save.
