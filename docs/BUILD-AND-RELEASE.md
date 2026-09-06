# Build and release

## Prerequisites

- Windows PowerShell 5.1 (`powershell.exe`)
- .NET SDK/MSBuild with the .NET Framework 4.7.2 targeting pack
- locally installed Pathfinder: Kingmaker 2.1.7b
- owner-approved Unity Mod Manager 0.33.0 with the installed legacy `0Harmony12, Version=1.2.0.1` surface

The v0.1.1 candidate is measured against UMM 0.33.0. Historical v0.1.0 qualification recorded UMM 0.32.4; that record is retained as history and is not a request to downgrade or a compatibility claim for untested loaders.

Discover the Steam app manifest or configure a non-Steam installation explicitly:

```powershell
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass `
  -File .\scripts\Initialize-GamePath.ps1
```

`GamePath.props` is local and ignored. All game/UMM references use `Private=False`; no referenced game binary may enter output or the package.

## Commands

Run the legacy scripts through Windows PowerShell:

```powershell
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass `
  -File .\scripts\Build-Local.ps1 -Configuration Release
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass `
  -File .\scripts\Test.ps1 -Configuration Release
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass `
  -File .\scripts\Verify-KingmakerContracts.ps1
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass `
  -File .\scripts\Package.ps1 -Configuration Release
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass `
  -File .\scripts\Validate-Package.ps1 `
  -PackagePath .\artifacts\packages\KingmakerLastAzlantiPreserver-0.1.1.zip
```

One non-runtime qualification command:

```powershell
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass `
  -File .\scripts\Qualify.ps1 -Build -Test -VerifyContracts -Package
```

The core verifier writes `contracts.json`. The chained optional verifier writes `game-over-load-contracts.json` and requires the exact desktop/controller signatures, metadata tokens, fields, callbacks, material IL relationships, UMM/Harmony identities and hashes, all core/optional Harmony ownership, and proof that unpatching the optional owner leaves every core patch owned. Generated JSON evidence stays under ignored `artifacts/qualification/` because it contains local paths.

`Qualify.ps1` reports Git identity/state, game assembly hash/MVID, loader identities, core and UI targets, ownership isolation, tests, compiler diagnostics, DLL/package hashes, validation, installation state, and the explicit runtime boundary.

## Package and install

The one permitted candidate archive is:

```text
artifacts/packages/KingmakerLastAzlantiPreserver-0.1.1.zip
```

It contains exactly one top-level `KingmakerLastAzlantiPreserver/` directory and six allowlisted files. It excludes PDBs, game/UMM/Harmony DLLs, source, settings, saves, logs, paths, and recovery data.

Always preview, then install:

```powershell
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass `
  -File .\scripts\Install.ps1 -WhatIf
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass `
  -File .\scripts\Install.ps1
```

The installer validates the archive, refuses to run while Kingmaker is active, rejects a reparse/non-directory target, extracts to a system temporary directory, replaces only `<KINGMAKER_INSTALL>/Mods/KingmakerLastAzlantiPreserver`, hash-preserves an existing ordinary `Settings.xml`, verifies the installed DLL hash, and rolls back the complete prior mod directory on failure. A separate lab rollback copy may be retained privately; it must contain only the installed Preserver payload/settings, never player saves.

## Pull request and publication

Feature work belongs on `codex/game-over-load-controls-v0.1.1` and reaches `main` through its pull request. Automated qualification or installation alone never authorizes a merge, tag, or publication.

The guarded publisher requires clean, fully pushed `main`, two identical complete qualifications, both contract reports, and package validation. Prepare artifacts without a tag or GitHub release:

```powershell
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass `
  -File .\scripts\Publish-Release.ps1 -PrepareOnly
```

The normal publication path additionally requires accepted disposable-campaign runtime evidence and the deliberate runtime confirmation:

```powershell
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass `
  -File .\scripts\Publish-Release.ps1 `
  -Publish -ConfirmRuntimeQualifiedRelease
```

On 2026-09-06, the owner explicitly authorized v0.1.1 merge, tag, and stable publication before personally installing and running the GUI checklist. That one-version disposition uses a separate deliberate switch:

```powershell
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass `
  -File .\scripts\Publish-Release.ps1 `
  -Publish -ConfirmOwnerAuthorizedPreRuntimeRelease
```

This path requires the committed release notes and project state to retain both the owner authorization and **MANUAL RUNTIME TEST REQUIRED** status. It records `runtime_qualified: false` and `owner_authorized_release_before_runtime_test: true` in the release manifest. It does not transfer to a future version. Steam Cloud remains separately qualified even after the required local GUI pass.
