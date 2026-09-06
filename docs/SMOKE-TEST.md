# Human runtime smoke test

Compilation and installation are not runtime qualification. Use only a disposable standalone Beneath the Stolen Lands campaign; never use a valued save for destructive checks.

## Safety prerequisites

Do not launch Kingmaker for this procedure unless all of these are true:

1. GUI interaction is available through an existing repository-authorized mechanism.
2. Kingmaker is closed before installation and the qualified v0.1.1 package is the only intended mod payload change.
3. Steam Cloud behavior is known safe for this local-only pass; otherwise keep Cloud qualification separate and do not silently change account settings.
4. A disposable standalone campaign can be created or explicitly identified by name and identity. Do not use Continue/latest-save to choose it.
5. Any independent backup remains outside the Owlcat save directory and outside Git.
6. FirstAzlanti and duplicate preservation mods are disabled; do not delete an unexpected mod without owner direction.

Record Kingmaker version, UMM version, mod/package/DLL hashes, enabled mods, Cloud state, disposable run identity, test timestamp, available input devices, and every observed result. Keep saves, logs, screenshots, and recovery data outside Git. A failed or unobserved required step means runtime qualification has not passed.

## 1. Main-menu startup boundary

1. Exit Kingmaker and confirm no `Kingmaker` process remains.
2. Run `scripts/Install.ps1 -WhatIf` and confirm it names only `<KINGMAKER_INSTALL>/Mods/KingmakerLastAzlantiPreserver`.
3. Install the qualified candidate and verify UMM reports version 0.1.1. Do not load a valued save.
4. Launch only to the main menu and open the UMM panel.
5. Confirm core preservation reports **AVAILABLE** separately from game-over loading controls **AVAILABLE**. Record the exact desktop/controller targets and latest eligibility reason; at the main menu, ineligibility is expected.
6. Confirm both preservation settings and hidden recovery are enabled, no red status appears, and no FirstAzlanti conflict is reported.

This startup check proves only that the candidate loaded. It does not qualify preservation or game-over controls.

## 2. Disposable run and native autosave

1. Create a new standalone Beneath the Stolen Lands / Tenebrous Depths run with Last Azlanti / Only One Save enabled, or explicitly select a pre-authorized disposable run. Do not use Continue as a shortcut.
2. Reach a legitimate native autosave and wait until saving completes.
3. Confirm manual saving and quicksaving remain unavailable.
4. Record that exactly one native game-visible slot exists. If external file evidence is part of the authorized fixture, record its filename, length, timestamp, and SHA-256 without copying it into Git.
5. Confirm UMM recognizes the live IronMan save. A hidden snapshot must not appear in Kingmaker's load list.

## 3. Load Last Save from game over

1. Intentionally die with the disposable party and reach the normal results screen.
2. Confirm Start Again remains enabled and unchanged.
3. Confirm Load Last Save is visibly enabled, navigable, and selectable.
4. Confirm Load Game is visibly enabled, navigable, and selectable.
5. Confirm Main Menu remains enabled and unchanged, and that no other button or save slot appeared.
6. Select Load Last Save.
7. Confirm Kingmaker immediately uses its native loading flow and loads the preserved one-slot save without visiting Main Menu or showing a custom recovery entry.
8. Confirm no automatic load occurred before the explicit action and no second game-visible save exists.

## 4. Load Game, cancel, and return

1. Repeat the death scenario and select Load Game.
2. Confirm Kingmaker's native load-game window opens and the current Last Azlanti save is visible and loadable.
3. Use the native cancel/back action. Merely opening the window is not a successful load.
4. Confirm the same results screen remains valid and both loading controls revalidate correctly.
5. Open Load Game again and load the disposable save through the native flow.
6. Confirm cancellation did not create a save, leave a custom slot, or steal focus.

## 5. Repetition and input paths

1. Complete a second death/load cycle to prove a prior operation neither blocks nor grants the next operation.
2. Verify mouse selection for both controls.
3. Verify normal keyboard navigation and confirm for both controls.
4. If a controller is available, verify controller navigation and confirm for both controls. Otherwise record controller behavior as **UNTESTED**, not passed.

## 6. Setting and core-disable boundaries

1. On a fresh disposable death, disable only **Allow loading the preserved save from the game-over screen** before reaching the results screen. Confirm both controls retain vanilla Last Azlanti disabled behavior while core preservation still leaves the save loadable from Main Menu.
2. Re-enable the setting, reach another disposable results screen, confirm the controls elevate, then disable that setting while the screen is still open. Confirm only the two owned loading controls return to vanilla state and neither action remains usable.
3. Confirm core preservation remains **AVAILABLE** throughout those UI-setting changes.
4. On a separate disposable run, disable core preservation or the mod and confirm vanilla Last Azlanti game-over behavior is unchanged. Never perform this step against a save that matters.

## 7. Explicit deletion from the game-over load window

1. Use another explicitly identified disposable save and reach Load Game from its game-over screen.
2. Explicitly delete that save through the native confirmation UI.
3. Confirm deletion remains destructive: the live entry disappears and is not restored from the hidden snapshot.
4. Cancel back to results and confirm no stale permission can load the deleted save; the feature-owned loading state must be revoked.
5. Refresh/reopen the load screen and confirm no pending marker or recovery action resurrects the explicit deletion.

## 8. Non-Last-Azlanti regression

1. Create or load a separate ordinary disposable campaign.
2. Reach its ordinary game-over screen and confirm it is unchanged.
3. Confirm manual saves, quicksaves, autosaves, loading, overwrite, and explicit deletion retain native behavior.
4. Confirm no preservation operation, UI grant, marker, or snapshot is created by an ordinary deletion.

## 9. Diagnostics and recovery discipline

1. Confirm no new exceptions, repeated per-frame log spam, focus stealing, save-list corruption, extra save, or stale enabled control occurs across all cycles.
2. Confirm the recovery directory retains at most one current `snapshot.bin` and `metadata.json` for the disposable identity, with no stage/previous history.
3. Do not manufacture recovery markers. The guarded fallback procedure in `docs/RECOVERY.md` is a separate destructive test against a copied disposable fixture only.

## 10. Steam Cloud

Steam Cloud remains a separate qualification scenario. Only after the local disposable checks pass may the owner deliberately enable/test Cloud with a new disposable run, repeated death/load cycles, and a full restart while recording local/cloud behavior. Report Cloud as **UNQUALIFIED** unless that exact scenario is observed.

## Qualification outcome

Version 0.1.1 is runtime-qualified only after every applicable non-optional step above passes with recorded disposable-campaign evidence. A main-menu startup, managed assembly load, automated contract pass, package installation, publication, or the prior v0.1.0 owner observation cannot substitute for this test. Until then, report **MANUAL RUNTIME TEST REQUIRED**. The owner authorized v0.1.1 publication before personally performing this checklist on 2026-09-06; that release disposition does not change the qualification result.
