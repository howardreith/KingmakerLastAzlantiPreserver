# Last Azlanti Preserver

Last Azlanti Preserver is a standalone Unity Mod Manager mod for **Pathfinder: Kingmaker 2.1.7b**. It keeps Kingmaker's one-save Last Azlanti discipline while preventing the game-over controller from deleting the one legitimate autosave.

Version 0.1.1 adds a separately gated enhancement for the standalone Beneath the Stolen Lands results screen: after this mod has verifiably preserved the live native save, Kingmaker's own **Load Last Save** and **Load Game** controls can be used without returning to the main menu.

The mod does not enable manual saving or quicksaving, add slots, change autosave timing or selection, alter difficulty or death rules, create a visible recovery save, skip the game-over screen, or reload automatically. Ordinary campaigns and deliberate deletion from the native load-game UI pass through unchanged.

## Core preservation

When `SettingsRoot.Instance.OnlyOneSave.CurrentValue` is true and the active save is `SaveInfo.SaveType.IronMan`, the mod opens a short-lived synchronous scope around `GameOverIronmanController.Activate()`. A prefix on `SaveManager.DeleteSave(SaveInfo)` suppresses only a fresh, same-thread, matching target within that scope and explicitly passes known load-game deletion entrypoints through. The rest of `Activate()`, including `LoadingProcess.ResetManualLoadingScreen()`, runs normally.

Before that operation, the optional recovery layer copies the exact save bytes to a mod-owned directory outside `Saved Games`. It retains one current snapshot per source identity, uses SHA-256 metadata and a pending game-over marker, and never presents the copy to Kingmaker as a save. Restoration never overwrites a live file.

## Scoped game-over loading controls

Core protection and the UI enhancement resolve and patch independently. A failure in the optional UI contract leaves Kingmaker's controls in their vanilla state without removing core preservation.

The UI grant is created only after the exact game-over deletion was suppressed and the live source was revalidated. Every bind and action then checks the mod/core/settings state, active Endless game-over mode, Only One Save, current IronMan `SaveInfo`, nonempty native folder, direct-child save-root containment, a live non-reparse source file, exact operation identity, and the exact save Kingmaker's native callback would select. A hidden recovery snapshot is never eligibility evidence.

Only the two native loading controls are elevated. Their labels, visibility, layout, sound, navigation, and callbacks remain Kingmaker-owned. **Load Last Save** still calls `Game.LoadGame(SaveInfo)` through the game's callback; **Load Game** still opens the native load window. Cancelling that window retains the same operation for live revalidation. Loading, Start Again, Main Menu, a subsequent game over, disabling the setting/mod, or contract failure revokes it.

## Settings and status

The UMM panel provides:

- **Preserve Last Azlanti save on game over** (enabled by default)
- **Allow loading the preserved save from the game-over screen** (enabled by default)
- **Maintain hidden recovery snapshot** (enabled by default)
- **Verbose diagnostics** (disabled by default)
- separate core-preservation and game-over-loading status, exact resolved hooks, the latest eligibility reason, compatibility information, and recovery state
- a confirmation-gated recovery action usable only for a missing recorded original with a valid pending marker

Disabling the game-over loading setting restores only control state owned by that enhancement; it does not disable preservation.

## Installation

Build/package installation:

```powershell
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass `
  -File .\scripts\Install.ps1 -WhatIf
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass `
  -File .\scripts\Install.ps1
```

Or install `KingmakerLastAzlantiPreserver-0.1.1.zip` with Unity Mod Manager. The archive has one top-level `KingmakerLastAzlantiPreserver` directory. Disable/remove the original FirstAzlanti mod before using this mod; do not test both together.

## Qualification and evidence boundary

Run all automated non-runtime gates through Windows PowerShell:

```powershell
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass `
  -File .\scripts\Qualify.ps1 -Build -Test -VerifyContracts -Package
```

The v0.1.0 core was owner-observed working in one disposable standalone Beneath the Stolen Lands Last Azlanti run: death reached the normal results screen, the retained save loaded successfully from Main Menu, and the game-over **Load Last Save**/**Load Game** controls remained disabled. That is positive evidence for the core in that scenario, not full runtime or Steam Cloud qualification.

The v0.1.1 UI enhancement remains **MANUAL RUNTIME TEST REQUIRED** until the disposable-campaign procedure in [docs/SMOKE-TEST.md](docs/SMOKE-TEST.md) is completed. Automated compilation, tests, exact contracts, Harmony ownership, packaging, managed assembly loading, or main-menu startup do not constitute that GUI result. Steam Cloud remains a separate scenario.

See [docs/RECONNAISSANCE.md](docs/RECONNAISSANCE.md) for the exact 2.1.7b call graph and [docs/RECOVERY.md](docs/RECOVERY.md) for recovery invariants.
