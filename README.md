# Last Azlanti Preserver

Last Azlanti Preserver is a standalone Unity Mod Manager mod for **Pathfinder: Kingmaker 2.1.7b**. It keeps Kingmaker's one-save Last Azlanti discipline but prevents the game-over controller from deleting that one legitimate autosave.

The mod does not enable manual saving or quicksaving, add slots, change autosave timing, alter difficulty/death rules, or reload automatically. Ordinary campaigns and deliberate deletion from the load-game UI pass through unchanged.

## What it does

When `SettingsRoot.Instance.OnlyOneSave.CurrentValue` is true and the active save is `SaveInfo.SaveType.IronMan`, the mod opens a short-lived synchronous scope around `GameOverIronmanController.Activate()`. A prefix on `SaveManager.DeleteSave(SaveInfo)` suppresses only a fresh, same-thread, matching target within that scope and explicitly passes known load-game deletion entrypoints through. The rest of `Activate()`, including `LoadingProcess.ResetManualLoadingScreen()`, runs normally.

Before that operation, the optional recovery layer copies the exact save bytes to a mod-owned directory outside `Saved Games`. It retains one current snapshot per source identity, uses SHA-256 metadata and a pending game-over marker, and never presents the copy to Kingmaker as a save. Restoration never overwrites a live file.

## Settings and status

The UMM panel provides:

- **Preserve Last Azlanti save on game over** (enabled by default)
- **Maintain hidden recovery snapshot** (enabled by default)
- **Verbose diagnostics** (disabled by default)
- resolved-contract, recognition, interception, recovery, error, and compatibility status
- a confirmation-gated recovery action usable only for a missing recorded original with a valid pending marker

## Installation

Build/package installation:

```powershell
powershell -NoLogo -NoProfile -ExecutionPolicy Bypass `
  -File .\scripts\Install.ps1 -WhatIf

powershell -NoLogo -NoProfile -ExecutionPolicy Bypass `
  -File .\scripts\Install.ps1
```

Or install `KingmakerLastAzlantiPreserver-0.1.0.zip` with Unity Mod Manager. The archive has one top-level `KingmakerLastAzlantiPreserver` directory.

Disable/remove the original FirstAzlanti mod before using this mod. Do not test both together.

## Qualification

Create the ignored local game configuration, then run all automated non-runtime gates:

```powershell
powershell -NoLogo -NoProfile -ExecutionPolicy Bypass `
  -File .\scripts\Initialize-GamePath.ps1

powershell -NoLogo -NoProfile -ExecutionPolicy Bypass `
  -File .\scripts\Qualify.ps1 -Build -Test -VerifyContracts -Package
```

Automated checks qualify compilation, contracts, filesystem policy, and packaging only. This release is **not runtime-qualified** until the destructive disposable-campaign procedure in `docs/SMOKE-TEST.md` is completed. Steam Cloud is a separate, explicitly unqualified scenario until observed.

See `docs/RECONNAISSANCE.md` for the exact 2.1.7b call graph and `docs/RECOVERY.md` for recovery invariants.
