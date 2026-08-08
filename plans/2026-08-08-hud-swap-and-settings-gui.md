# Plan — HUD swap + in-game Settings GUI (2026-08-08)

Requested by Boss. Decisions locked via AskUserQuestion:
- Settings palette: Boss restyles it later → build functional, neutral; keep editable Studio instance.
- MusicButton = mute toggle (music only).
- Settings content = Volume + Shadow + graphics options (shadows + graphics quality).

## Task 1 — replace Gui_HUD with HUD_myver (Boss's finished HUD)

Convention fix (CLAUDE.md rule 8): rename Boss's labels to match the driver's
`BINDINGS`, don't rewrite the driver. Driver `HUD.init` already uses an existing
`Gui_HUD` if present.

Edit-time (execute_luau, Edit datamodel):
1. Rename inner value labels in `StarterGui.HUD_myver`:
   - `FollowerBox.TextLabel` → `FollowerLabel`
   - `MoneyBox.TextLabel` → `MoneyLabel`
   - `StorageBox.TextLabel` → `StorageLabel`
   - `CameraBox.TextLabel` → `CameraLabel`
   - root `date` → `DayLabel`
2. Verify present (already correct names): `ProgressTrack.PhaseLabel`,
   `ProgressTrack.ProgressFill`, `ClockLabel`, `MentalTrack.MentalFill`.
   Confirm `MentalFill.AnchorPoint.Y == 1` (fill grows from bottom).
3. `HUD_myver.Enabled = false` (menu opens HUD; avoid flash).
4. Delete old `Gui_HUD`, rename `HUD_myver` → `Gui_HUD`.

Code (src/client/UI/HUD.luau):
5. BINDINGS: `dayLabel` path `{"CalendarBox","DayLabel"}` → `{"DayLabel"}`.
6. `update()` mental fill: keep the GUI's existing X (don't clobber Boss's width) —
   set only the height scale.

## Task 2 — in-game Settings GUI (stolen structure from Cafe Settings System)

Steal Cafe's layout only (title bar + X + scrolling list + section headers + rows),
not its coffee palette or its Music/SFX/Overheads content (not our systems).

Structure (real instance in StarterGui `SettingsGui`, Enabled=false, so Boss restyles;
code `SettingsUI.build()` fallback mirrors it for git — same pattern as HUD):
- Panel (centered) > TitleBar(Title "ตั้งค่า", CloseButton "X") > List(ScrollingFrame)
  - Section "เสียง": VolumeRow (Label, Value %, BarFill, Minus ⊖, Plus ⊕)
  - Section "ภาพ": ShadowRow (Label, Toggle On/Off), QualityRow (Label, Value, Cycle)

Controller `src/client/UI/SettingsUI.luau`: init(playerGui, deps) binds by name,
wires open/close, volume ⊖/⊕ (Audio.setVolume + fireAction SetSetting volume),
shadow toggle (Lighting.GlobalShadows + SetSetting shadow), quality cycle
(UserGameSettings.SavedQualityLevel — platform-persisted).

Wiring (Main.client): require SettingsUI; init after HUD; grab
`Gui_HUD.SettingButton` → SettingsUI.open, `Gui_HUD.MusicButton` → Audio mute toggle.
Apply saved shadow + musicMuted in the StateChanged settings block.

Music mute (AudioService): add `Music` SoundGroup nested under Master, route BGM
clones to it; `setMusicMuted(on)` toggles its Volume. duckBGM still tweens the
sound's own Volume (independent) — unaffected.

Persistence (Main.server SetSetting + GameState defaults): add keys `shadow` (bool),
`musicMuted` (bool). Quality not persisted server-side (platform handles it).

## Verify
Play in Studio: HUD values populate; SettingButton opens panel; ⊖/⊕ changes volume +
saves; shadow + quality toggle; MusicButton mutes/unmutes music only; reload keeps
volume/shadow/mute. Mirror all code to src/. Do NOT commit until Boss says.
