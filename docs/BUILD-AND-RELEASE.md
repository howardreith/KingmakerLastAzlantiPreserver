# Build and release

## Prerequisites

- Windows PowerShell 5.1+
- .NET SDK/MSBuild with the .NET Framework 4.7.2 targeting pack
- locally installed Pathfinder: Kingmaker 2.1.7b
- Unity Mod Manager 0.32.x installed for that game

Discover the Steam app manifest or configure a non-Steam installation explicitly:

```powershell
powershell -NoLogo -NoProfile -ExecutionPolicy Bypass `
  -File .\scripts\Initialize-GamePath.ps1

# Non-Steam example:
powershell -NoLogo -NoProfile -ExecutionPolicy Bypass `
  -File .\scripts\Initialize-GamePath.ps1 `
  -KingmakerInstallDir 'D:\Games\Pathfinder Kingmaker'
```

`GamePath.props` is local and ignored. All game/UMM references use `Private=False`; no referenced game binary may enter output or the package.

## Commands

```powershell
.\scripts\Build-Local.ps1 -Configuration Release
.\scripts\Test.ps1 -Configuration Release
.\scripts\Verify-KingmakerContracts.ps1
.\scripts\Package.ps1 -Configuration Release
.\scripts\Validate-Package.ps1 `
  -PackagePath .\artifacts\packages\KingmakerLastAzlantiPreserver-0.1.0.zip
```

One non-runtime qualification command:

```powershell
powershell -NoLogo -NoProfile -ExecutionPolicy Bypass `
  -File .\scripts\Qualify.ps1 -Build -Test -VerifyContracts -Package
```

Generated JSON evidence is under `artifacts/qualification/` and intentionally ignored because it contains local paths. `Qualify.ps1` reports Git identity/state, game assembly hash/MVID, selected targets, tests, compiler diagnostics, DLL/package paths and hashes, validation, any install target, and the explicit runtime-qualification status.

## Package and install

The one permitted archive is:

```text
artifacts/packages/KingmakerLastAzlantiPreserver-0.1.0.zip
```

It contains exactly one top-level `KingmakerLastAzlantiPreserver/` directory and six allowlisted files. It excludes PDBs, game/UMM/Harmony DLLs, source, settings, saves, logs, paths, and recovery data.

Always preview, then install:

```powershell
powershell -NoLogo -NoProfile -ExecutionPolicy Bypass `
  -File .\scripts\Install.ps1 -WhatIf

powershell -NoLogo -NoProfile -ExecutionPolicy Bypass `
  -File .\scripts\Install.ps1
```

The installer validates the archive, refuses to run while Kingmaker is active, extracts to a system temporary directory, moves only `<KINGMAKER_INSTALL>/Mods/KingmakerLastAzlantiPreserver`, verifies the installed DLL hash, and rolls back from the temporary copy on failure.

Do not publish a GitHub release until `docs/SMOKE-TEST.md` is completed with a disposable campaign. A draft PR is appropriate while runtime qualification remains pending.
