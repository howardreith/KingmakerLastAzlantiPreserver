# UMM compatibility baseline

## Contract

As requested on 2026-11-23, `Info.json` declares UMM **0.31.1** and the production
DLL is compiled against **UnityModManager 0.31.1.0** and **0Harmony12 1.2.0.1**,
whatever loader is installed on the build machine.

- `scripts/loader-reference-pins.json` pins both references (the same upstream
  bytes Kingmaker Cutscene Skip already pins) and must define exactly these two,
  under their canonical file names:
  - UnityModManager 0.31.1.0 from
    `https://api.nuget.org/v3-flatcontainer/unitymodmanager/0.31.1/unitymodmanager.0.31.1.nupkg`
    (package SHA-256 `05a82b66bc44d56d1246f146d16e9fa8f9a42c450c5bc334bcfa9efddbdb53c9`,
    entry `lib/net35/UnityModManager.dll`, DLL SHA-256
    `2e038ff23ab01d538dfef792096e1f5c04802d1edac3660db20d0d54c167c2c4`);
  - 0Harmony12 1.2.0.1 from newman55/unity-mod-manager commit `10cfb1cc`
    (`lib/Harmony/1.2/0Harmony12.dll`, SHA-256
    `aa1cd48317254985d8b700cc74953477d1b40c3022ce9aa4c95ed2b8327e1292`).
- `scripts/Build-Local.ps1` downloads them into the ignored `artifacts/references`
  cache, verifies SHA-256 and assembly identity, and writes
  `artifacts/qualification/build.json` with the DLL hash, configuration, loader
  identities, the source commit/dirty state (a detached checkout is supported) and a
  fingerprint of every material build input (tracked or new files under `src/`,
  `Directory.Build.props`, `.editorconfig`, `Info.json`, `LoaderReferences.targets`, the
  pin file and its verifier). A missing, corrupt or different reference (including the
  installed newer loader) fails the build; there is no fallback to `UnityModManagerDir`.
- Direct `dotnet msbuild`/MSBuild/IDE builds import `LoaderReferences.targets`. On every
  build, before reference resolution, it re-verifies the cache and the manifest; after
  resolution the compiler's actual inputs (`@(ReferencePath)`, found by file name or by
  assembly identity) must be exactly the two verified files by full path, so a stray
  HintPath, a same-stem or renamed file in the pinned directory or the installed loader
  is refused. The fast up-to-date check is disabled and the pin, verifier, guard and
  manifest are compile inputs.
- `ManagerVersion` must be a JSON string equal to 0.31.1 (`Info.json`, the expected
  product manifest, the verifier) and the pin must equal the declared minimum.
- `scripts/Package.ps1` (and `Qualify.ps1 -Package`) refuse a DLL whose receipt has
  different bytes, configuration, build inputs or loader identities, and require the DLL
  read back from the produced ZIP to equal the receipt's DLL hash.
- The standalone `scripts/Validate-Package.ps1` reads the packaged DLL's AssemblyRef
  table (in Windows PowerShell in a separate process, so several packages can be
  validated in one session), requires exactly UnityModManager 0.31.1.0 and 0Harmony12
  1.2.0.1, checks the manifest, accepts only the six allow-listed files and requires the
  documentation and licence entries to be UTF-8 text, so no loader, Harmony, game or
  Unity DLL can be packaged, renamed or not. Its report records the packaged DLL's
  SHA-256, MVID and observed loader references. `scripts/Install.ps1` validates the
  supplied ZIP, then validates a private copy and extracts that same copy
  (`Expand-ValidatedPackage`); the extracted DLL must equal the validated one.
- `Qualify.ps1` credits contract and package records only for the DLL of the current
  build record: contract reports must name that DLL's hash, and a package counts only
  when the ZIP on disk, its package record and its validation record all describe it.
  `-VerifyContracts` checks the DLL of the selected `-Configuration`.
- `UnityModManagerDir` identifies the loader used by the contract checks.
  `Verify-GameOverLoadContracts.ps1` accepts it only when UnityModManager and the
  Harmony2 beside it (`0Harmony.dll`) match one exact profile: 0.31.1 + 2.3.1.1, 0.32.4
  + 2.3.6.0, 0.33.0 + 2.3.6.0 or 0.33.4 + 2.4.3.0; the selected profile, Harmony2 and
  Harmony12 identities and the verified DLL hash are recorded in the contract report
  and the qualification summary. Accepting a profile is not a runtime pass. The
  deterministic test runner resolves loader assemblies from that directory at run time
  (test-only; it compiles the production project, so its compile inputs are pinned).

The previous manifest required 0.33.0 and the published v0.1.3 DLL references
UnityModManager 0.33.0.0. Historical release records keep their original versions
and evidence; existing published ZIPs are unchanged.

## Reproduce the checks

```powershell
.\scripts\Qualify.ps1 -Build -Test -VerifyContracts      # the agent-review `qualify` gate
.\scripts\Test-LoaderBaseline.ps1                       # failure-boundary suite on the committed HEAD
.\scripts\Test-LoaderProfiles.ps1 -ProfileRoot <folder> # managed contract checks per loader profile
.\scripts\Validate-Package.ps1 -PackagePath <zip> -ReportPath <file>   # standalone pre-install validator
```

`Test-LoaderBaseline.ps1` clones the committed HEAD into a temporary directory whose
path contains a space (a detached checkout), seeds its ignored cache, builds it, and runs
every check in a separate PowerShell or MSBuild process; this repository's `artifacts`
and the installed game are never written. It downloads (or accepts with
`-LegacyReleaseZip` / `-WrongLoaderPackage`) two hash-checked fixtures and only reads
them: the genuine v0.1.3 release (SHA-256 `8b59d76d…887d2fbed`, its DLL compiled against
UnityModManager 0.33.0.0) and the author's UnityModManager 0.32.4 NuGet package
(`a8438e92…082c9ec9`, DLL `1387468b…7bfd88`) as the known distinct wrong-loader fixture;
the owner's installed loader is only measured. Its 62 checks cover cache bytes; dropped
or misnamed pins and raised/array-typed manifests; direct and incremental builds (quoted
compiler paths, manifest-only and pin-only changes); resolved-input probes (identical
copy elsewhere, same-stem `.exe`, renamed copy, 0.32.4 fixture); packaging and
`Qualify.ps1 -Package` refusing reused DLLs after source, helper, guard or project
changes and accepting identical inputs or a matching rebuild; receipt binding; the
archived-DLL/receipt comparison; smuggled or renamed dependency DLLs and non-string
`ManagerVersion` values; the v0.1.3 DLL with only its manifest lowered (refused); both
packages validated in one Windows PowerShell session; the validated private-copy
extraction; `Qualify.ps1` refusing to credit another validated ZIP or a ZIP replaced on
disk; and contract checks of a Debug build while a Release build exists.

`Test-LoaderProfiles.ps1` takes a folder of profile subfolders, each holding
`UnityModManager.dll`, `0Harmony.dll` and `0Harmony12.dll`. For each it writes a
temporary `GamePath.props` (game assemblies from the configured installation, loader
files from the profile) and runs both contract verifiers in a separate process: they load
Assembly-CSharp, check the profile identities, and apply, verify and remove this product's
Harmony patches through that profile's 0Harmony12 → 0Harmony stack. Build each profile
from the author's NuGet `unitymodmanager.<v>.nupkg` (`lib/net35/UnityModManager.dll`), the
official `Lib.Harmony` package of the Harmony2 version that DLL references
(`lib/net48/0Harmony.dll`, the variant UMM installs) and the pinned 0Harmony12.

The static API audit uses the fleet mission's `LoaderApiAudit` tool (outside this
repository; a small .NET program using System.Reflection.Metadata) with the same
profiles: it resolves every TypeRef and MemberRef the DLL makes into UnityModManager,
0Harmony12 and 0Harmony by name and decoded signature, with base-type walk and type
forwarders. The newest-stable row was selected on 2026-11-23 from the author's NuGet
feed (0.33.4, published 2026-11-19, the highest version; project URL the Nexus page) and
confirmed by the author's GitHub HEAD `3d14bf0d` (`<Version>0.33.4</Version>`).

## Evidence for this change (2026-11-23)

Candidate DLL (Release, `dotnet msbuild` on Windows against the pinned cache and the
Kingmaker 2.1.7b managed assemblies): SHA-256
`fadf2dab6ff3b8a92c81a3515b633f0de7482879ac5ca43a79ca9ac7c0031248`, MVID
`4bcbb685-5152-4399-98e2-19fb6d19c6cd`; AssemblyRefs UnityModManager 0.31.1.0 and
0Harmony12 1.2.0.1; 0 compiler warnings/errors. `Qualify.ps1 -Build -Test -VerifyContracts
-Package`: 84/84 deterministic tests, Kingmaker and game-over load contracts on that DLL
(installed profile 0.33.0 + Harmony2 2.3.6.0), package SHA-256
`83611dd565b69ac399b010fd57cc7f65e948fb7ece22417b8f82c19b65700adc`, validation passed.
`Test-LoaderBaseline.ps1`: 62/62. The candidate commit is recorded in the pull request.

| Observation | Result |
| --- | --- |
| 1. Declared minimum | UMM 0.31.1 (`Info.json`) |
| 2. Verified compile baseline | UnityModManager 0.31.1.0 + 0Harmony12 1.2.0.1, pinned bytes above, confirmed on the compiler command line and in the DLL's AssemblyRefs |
| 3. Static/API and managed Harmony checks | See the table below (same candidate DLL) |
| 4. Observed native behaviour | **NOT RUN** for every loader version (see below) |

| Loader profile | UnityModManager (SHA-256) | 0Harmony (Harmony2) | 0Harmony12 | Static API audit (9 types, 25 members) | Managed contract check (`Test-LoaderProfiles.ps1`) |
| --- | --- | --- | --- | --- | --- |
| 0.31.1 (baseline) | 0.31.1.0 `2e038ff2…` | 2.3.1.1 net48 `5f7ad0df…` | 1.2.0.1 `aa1cd483…` | all resolved | passed: core and optional patches applied and owned; core kept after optional unpatch |
| 0.32.4 | 0.32.4.0 `1387468b…` | 2.3.6.0 net48 `df043f05…` | 1.2.0.1 `aa1cd483…` | all resolved | passed (same) |
| 0.33.0 (owner install, measured 2026-11-23) | 0.33.0.0 `63e5baf7…` | 2.3.6.0 `df043f05…` | 1.2.0.1 `aa1cd483…` | all resolved | passed (same) |
| 0.33.4 (newest stable) | 0.33.4.0 `c5ed5617…` | 2.4.3.0 net48 `ddc070b5…` | 1.2.0.1 `aa1cd483…` | all resolved | passed (same) |
| mismatch: 0.33.4 with Harmony2 2.3.6 | 0.33.4.0 `c5ed5617…` | 2.3.6.0 `df043f05…` | 1.2.0.1 `aa1cd483…` | — | refused (Harmony2 does not match the 0.33.4 profile) |

Profiles other than the owner row are component-assembled from official packages, not
official UMM distribution ZIPs; the owner row is a read-only copy of the live loader.
The static audit shows that referenced names and signatures exist. The managed check
runs the real Harmony stack against the real game assembly, outside the game: it does
not start Unity, load a save, run UMM's loader, or exercise preservation, recovery or the
game-over UI, and it is not a runtime compatibility claim.

Native runtime: **NOT RUN** on 0.31.1, 0.32.4, 0.33.0 and 0.33.4. The only runtime
route (`docs/SMOKE-TEST.md`) installs into the live game with a disposable campaign; this
change must not replace the owner's live loader, mods or saves, and no disposable game
copy or automated harness exists in this repository. The candidate is therefore not
runtime-verified on any loader, including the 0.31.1 minimum. No combined mod-stack check
was run.

## Required native qualification (before claiming runtime support)

| Runtime | Required disposition |
| --- | --- |
| UMM 0.31.1 | Mandatory: disposable-campaign smoke on the same candidate DLL before claiming support |
| UMM 0.32.4 | Compatibility target; same smoke, same DLL |
| UMM 0.33.0 / 0.33.4 | Compatibility targets; old evidence does not qualify the new baseline build |
| Other versions | Not qualified; record the exact loader and Harmony identities before testing |

For every run record the mod DLL hash, UMM/Harmony hashes and versions, game
version, loaded mod set, settings round trip, enable/disable outcome, product
behaviour and save/reload outcome. The developer's live installation and saves must
not be downgraded or replaced.

For Second to Last Azlanti, use a disposable Last Azlanti campaign and verify
preservation after death, both game-over load controls, recovery restoration and
non-Last-Azlanti/manual-deletion behaviour, with a fresh-process reload. Follow
`docs/SMOKE-TEST.md`.
