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
  identities, the source commit/dirty state (a detached checkout is supported), the
  compiler inventory and a fingerprint of every material build input. The inventory is the exact
  Csc command line (an opt-in `WriteCompilerReferenceList` target in `LoaderReferences.targets`
  with `ProvideCommandLineArgs`): a `SkipCompilerExecution` pass through `PrepareResources` and
  `CoreCompile` in a fresh intermediate directory (resources prepared as the production build
  prepares them) gives every argument Csc would receive for the production project and
  configuration, including anything `GamePath.props` or another import sets. The inventory starts
  with the effective compiler by content (`CscToolPath`/`CscToolExe` when set, otherwise Roslyn's
  `csc.dll` under `dotnet msbuild` or `csc.exe`; a relative selector is resolved against the project
  directory, where MSBuild runs the compiler, never against the caller's directory) and, without
  `/noconfig`, the implicit `csc.rsp`; then every argument in the compiler's order, as a path-free
  identity: every option verbatim (for example `/checked+`, `/baseaddress:...`, `/define:...`),
  references and sources (generated ones included) by name and SHA-256, and file-valued options (`/win32res`, `/win32icon`, `/keyfile`,
  `/resource`, rule sets and others) by the content of the file they name. A source outside the repository (for example one imported by
  `GamePath.props`) also carries the SHA-256 of its compiler-visible full path
  (`external:<name>@path-sha256=<digest>`), because that path reaches the DLL (`CallerFilePath`,
  diagnostics), so a byte-identical copy elsewhere is a different input; references stay identified by
  content, so a byte-identical reference elsewhere is the same input. An input that cannot be
  identified refuses reuse, and forms whose material files the inventory cannot name are refused at
  the build and at every receipt admission: an explicit compiler response file (`@file`), linked
  references (`/link`) and wildcard source recursion (`/recurse`). The production compile writes its
  own command line, which must equal the evaluated one entry by entry; receipt comparisons check the
  entry count and then kind, name and digest of each entry in order, and a refusal names the first
  difference. The fingerprint covers tracked or new files under
  `src/`, `Directory.Build.props`, `.editorconfig`, `Info.json`, `LoaderReferences.targets`,
  the pin file and its verifier, `Build-Local.ps1`/`Common.ps1` and that inventory. Building,
  packaging and qualification summaries need the game assemblies and the pins, not the
  runtime loader directory. Receipt fields (the recorded inventory included) are
  type-checked before any comparison. A missing, corrupt or different reference (including
  the installed newer loader) fails the build; there is no fallback to `UnityModManagerDir`.
- Direct `dotnet msbuild`/MSBuild builds import `LoaderReferences.targets`. On every
  build, before reference resolution, it re-verifies the cache and the manifest; after
  reference-assembly selection and immediately before compilation, the list Csc receives
  (`@(ReferencePathWithRefAssemblies)`; each loader assembly found by file name or by
  assembly identity) must contain exactly the two verified files by full path, so a stray
  HintPath, a substituted reference assembly, a same-stem or renamed file in the pinned
  directory or the installed loader is refused. The fast up-to-date check is disabled and the pin, verifier, guard and
  manifest are compile inputs.
- `ManagerVersion` must be a JSON string equal to 0.31.1 (`Info.json`, the expected
  product manifest, the verifier) and the pin must equal the declared minimum.
- `scripts/Package.ps1` (and `Qualify.ps1 -Package`) refuse a DLL whose receipt has
  different bytes, configuration, loader identities or compiler inventory (the recorded
  inventory must equal what MSBuild evaluates now) or whose build inputs changed. Staging, the new
  archive and its validation report live in a folder private to the invocation; the documents read
  back from the validated archive must equal the repository files hashed before staging, and the DLL
  read back must equal the receipt's DLL. Both records are then prepared privately (the validation
  record's `package_path` names the published ZIP), and the set of ZIP, `package-validation.json` and
  `package.json` is published by one publisher at a time (an exclusive lock file removed when its
  handle closes): backup acquisition, placement and rollback are one recovery scope that tracks exactly
  the files this invocation moved and placed, so any failure restores the previous set; if
  restoration itself fails, the previous files are kept (not deleted) and named. The package record names the
  producing build inputs, a fingerprint of the packaged documents and a fingerprint of the packaging
  rules (`Package.ps1`, `Validate-Package.ps1`).
- The published `package-validation.json` has one owner, the publication above. A standalone
  `Validate-Package.ps1` never writes it and never takes the publication lock: it writes a report only to an
  explicitly requested other `-ReportPath` (a write failure there fails the validation), says when it wrote
  none, and refuses the canonical receipt path as `-ReportPath`. An invalid ZIP still fails.
- The standalone `scripts/Validate-Package.ps1` reads the packaged DLL's AssemblyRef
  table (in Windows PowerShell in a separate process, so several packages can be
  validated in one session), inspects and hashes one private copy of the ZIP, requires
  exactly UnityModManager 0.31.1.0 and 0Harmony12 1.2.0.1, checks the manifest, accepts
  only the six allow-listed files (directory records only for the package's own folders
  and only when their decoded content is empty, whatever the compression) and requires the documentation and licence entries to be UTF-8
  text, so no loader, Harmony, game or
  Unity DLL can be packaged, renamed or not. Its report records the packaged DLL's
  SHA-256, MVID and observed loader references. The private copy is created inside the
  validator's cleanup scope, so a copy failure leaves nothing behind; the validator has no
  test hooks. `scripts/Install.ps1` validates the
  supplied ZIP, then validates a private copy and extracts that same copy
  (`Expand-ValidatedPackage`); the extracted DLL must equal the validated one.
- `Qualify.ps1` credits earlier records only for the current candidate: the build receipt
  must be well formed and match the selected configuration's DLL and the current build
  inputs; both contract records must come from one binding-aware verification run (the
  same run id, the loaded product and Harmony2 modules recorded) under the loader
  components configured now, so earlier-format or mixed records are not current; a test
  record counts only when the tests ran in this qualification (`-Test`), and only for the product DLL
  the runner loaded (the runner executes from a private copy of its output folder, made inside its
  cleanup scope and hashed before and after the run), so skipped tests are reported as not run.
  `Qualify.ps1` reads that result from its own invocation (`Test.ps1 -ResultPath` to a file private to
  the invocation), never from the shared `artifacts\qualification\tests.json`, which another run can
  rewrite; a package counts
  only when the ZIP on disk, its package record and its validation record describe that DLL,
  the files it copies are unchanged, its producing build inputs equal the current receipt's
  and the packaging rules are unchanged. Anything else is reported as not current. The
  final status and exit code follow the stages requested in the run: a requested build,
  test, contract or package stage without current evidence for the same candidate fails the
  run. `-VerifyContracts` checks the DLL of the selected `-Configuration`.
- The verifiers refuse to report on an assembly other than the requested file (a second
  same-identity DLL in one host) and, before crediting patch ownership, check that the
  0Harmony12 and Harmony2 modules bound in the process are the configured files (a host
  reused for a second loader profile is refused); the contract records name the loaded
  Harmony2 module (location and MVID).
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
path contains a space (a detached checkout), seeds its ignored cache, configures it with a
disposable 0.31.1 loader profile (so no check depends on the owner's installed loader),
builds it, and runs
every check in a separate PowerShell or MSBuild process; this repository's `artifacts`
and the installed game are never written. It downloads (or accepts with
`-LegacyReleaseZip`, `-WrongLoaderPackage`, `-Harmony2Package`, `-NewestLoaderPackage`,
`-NewestHarmony2Package`) hash-checked fixtures and only reads them: the official
Lib.Harmony 2.3.1.1 / 2.4.3 and UnityModManager 0.33.4 NuGet packages that complete the
disposable 0.31.1 and 0.33.4 profiles, the genuine v0.1.3 release (SHA-256 `8b59d76d…887d2fbed`, its DLL compiled against
UnityModManager 0.33.0.0) and the author's UnityModManager 0.32.4 NuGet package
(`a8438e92…082c9ec9`, DLL `1387468b…7bfd88`) as the known distinct wrong-loader fixture;
the owner's installed loader is only measured. Its checks (the current count is in
`docs/evidence/umm-0311/loader-baseline.json`, listed in the evidence index; round 5 recorded 128) cover cache bytes; dropped
or misnamed pins and raised/array-typed manifests; direct and incremental builds (quoted
compiler paths, manifest-only and pin-only changes); resolved-input probes (identical
copy elsewhere, same-stem `.exe`, renamed copy, 0.32.4 fixture); packaging and
`Qualify.ps1 -Package` refusing reused DLLs after source, helper, guard or project
changes and accepting identical inputs or a matching rebuild; receipt binding; the
archived-DLL/receipt comparison; smuggled or renamed dependency DLLs and non-string
`ManagerVersion` values; the v0.1.3 DLL with only its manifest lowered (refused); both
packages validated in one Windows PowerShell session; the validated private-copy
extraction; `Qualify.ps1` refusing to credit another validated ZIP or a ZIP replaced on
disk; and contract checks of a Debug build while a Release build exists; wrapper and resolved
managed-reference changes; malformed receipt fields; a substituted reference assembly;
data-bearing directory records; a replaced caller ZIP during validation; partial
qualification after a source or packaged-README change, with older-format records and
after switching profiles; a second DLL in one host; and profile comparisons on one frozen
DLL while the build output changes. Round 4 adds: an overflow-checking option imported from
`GamePath.props` (stale package refused, effective option recorded, rebuild accepted,
removal refused until rebuilt); the receipt's reference inventory equal to the real Csc
`/reference` list, and a changed or missing recorded inventory refused; build and package
with no runtime loader directory (and the contract check reporting the missing loader);
package credit withdrawn after a build-input change that reproduces the same DLL, after a
packaging-rule change and when a document changes during staging, and restored by matching
controls; a failed qualification when the tests ran against a different valid DLL and no
inherited test pass after a source change; contract records in the fd9f30f shape and mixed
pairs from a second interrupted verification (same profile and 0.33.4) not credited, a fresh
pair credited; switching to the known-distinct 0.33.4 profile withdrawing credit while a
byte-identical copy of the verified profile keeps it; one host refusing a second loader
profile as a Harmony binding mismatch after recording the first run's bound Harmony2;
separate-process profile comparisons on the distinct 0.31.1 and 0.33.4 profiles; a
checked level-0 DEFLATE empty directory accepted (and a failed fixture write failing the
case); a validator copy failure leaving no private directory; the caller ZIP replaced by the
harness after the validator's snapshot; and standalone validation and `Install.ps1 -WhatIf`
(against a disposable game folder) leaving the supplied ZIP unchanged. Cases that need an
injected step use disposable instrumented copies of the scripts inside the clone, removed
after use; the committed scripts contain no test hooks. Round 5 adds: `BaseAddress` imported from
`GamePath.props` and an external `Win32Resource` replaced at the same path (stale packages refused, the
rebuilt receipts record the option and the resource's digest, the DLL changes, matching rebuilds
accepted); a document restaged after the staging copy (refused, accepted ZIP and records unchanged);
the staging refusal keeping the accepted ZIP and records; the test runner's output copy restored after
the run (the record still names the substitute it loaded); and a build-only qualification without a
runtime loader after a passing test run (no test credit).

Test-only prerequisite: the relative-compiler-selector cases copy the Roslyn compiler folder of
a Visual Studio installation (Visual Studio Build Tools is enough) as the project-selected
compiler. The suite finds it with `%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe
-latest -products * -find MSBuild\Current\Bin\Roslyn\csc.exe`; without such an installation
`relative-compiler-selector-receipt-names-the-project-selected-binary` fails (its detail reports
`Roslyn csc.exe source: not found`) and the selector's package case fails with it. The product
build, packaging and the other cases use the .NET SDK's `dotnet msbuild` and do not need it.

`Test-LoaderProfiles.ps1` takes a folder of profile subfolders, each holding
`UnityModManager.dll`, `0Harmony.dll` and `0Harmony12.dll`. For each it writes a
temporary `GamePath.props` (game assemblies from the configured installation, loader
files from the profile) and runs both contract verifiers, on one private frozen copy of
the candidate DLL, in a separate process: they load
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

## Evidence for this change (2026-11-25, round 9)

Round 9 changes only build-evidence, validation and test tooling (`LoaderReferences.targets`,
`Validate-Package.ps1`, `Test-LoaderBaseline.ps1`) and this guide; the product sources and the candidate DLL
bytes are unchanged, and earlier records keep their original identities in the index. The compiler-input list
names MSBuild's attribute source as generated only when MSBuild generates it (`GenerateTargetFrameworkAttribute`
true, attribute text present, sources present); with generation off, a file at the configured attribute path is an
ordinary source with its path digest. Standalone validation no longer refreshes the published receipt (see
above). `Test-LoaderBaseline.ps1` on the round-9 tooling (`loader-baseline.json`; the index gives its commit and
counts) runs the `CallerFilePath` fixture with generation off at the configured attribute path (no generated
entry; accepted, refused after relocation to an identical copy, the differing rebuild accepted), validates a
distinct ZIP while the publication lock is held exclusively (passes; public records unchanged), refuses the
canonical receipt as `-ReportPath`, and fails when an explicit report cannot be written.

### Round 8 (history)

Round 8 changes only build-evidence, validation and test tooling (`LoaderReferences.targets`, `Common.ps1`,
`Validate-Package.ps1`, `Test-LoaderBaseline.ps1`) and this guide; the product sources and the candidate DLL
bytes are unchanged, and earlier records keep their original identities in the index. The compiler-input
list now records the exact path of the attribute source MSBuild generates
(`TargetFrameworkMonikerAssemblyAttributesPath`), and only that file is named `generated:` in the build
receipt; any other source, including an external file named like `Shared.AssemblyAttributes.cs`, keeps
its path digest. In round 8 a standalone validation with the default report path treated the published-receipt
refresh as optional (replaced in round 9 by no refresh at all). `Test-LoaderBaseline.ps1` on the round-8 tooling
(158/158 at `4b31509`) ran the `CallerFilePath` fixture as
`Shared.AssemblyAttributes.cs` (accepted, refused after relocation to a byte-identical copy, the differing
rebuild accepted; each receipt names only MSBuild's `.NETFramework,Version=v4.7.2.AssemblyAttributes.cs` as
generated) and validates a distinct ZIP while the published ZIP is held with `FileShare.None`.

### Round 7 (history)

Round 7 changes only build, packaging and test tooling (`LoaderReferences.targets`, `Common.ps1`,
`Package.ps1`, `Validate-Package.ps1`, `Test-LoaderBaseline.ps1`); the product sources are unchanged since
round 3, so the candidate DLL bytes are those of the earlier records, which keep their original identities
in the index. `Test-LoaderBaseline.ps1` on the round-7 tooling (157/157 at `c39b471`) added: the compiler selection changed alone on the props of the accepted receipt (control
accepted, refused at entry 0 with the entry count unchanged, accepted after restoring; each step records the
selected compiler); a project-relative selector with a different same-named file below the repository root
(the receipt and package admission name the project-selected binary; replacing that binary refuses reuse);
a `CallerFilePath` source moved to a byte-identical copy in another folder (refused; the rebuild differs
and is accepted); and the published validation receipt (another archive leaves it unchanged, the published
bytes refresh it, and a validation of ZIP A overlapping the publication of ZIP B leaves ZIP, `package.json`
and `package-validation.json` all describing B). `r1f1-reproduction.txt` shows the inventory on the round-6
commit naming the caller-relative file and on the round-7 commit naming the project-selected binary.

Round 6 (history): tooling at `27c0af5`.

Candidate DLL (Release, `dotnet msbuild` on Windows against the pinned cache and the
Kingmaker 2.1.7b managed assemblies): SHA-256
`fadf2dab6ff3b8a92c81a3515b633f0de7482879ac5ca43a79ca9ac7c0031248`, MVID
`4bcbb685-5152-4399-98e2-19fb6d19c6cd`; AssemblyRefs UnityModManager 0.31.1.0 and
0Harmony12 1.2.0.1; 0 compiler warnings/errors. The qualification summary, build, package and
validation records in the index come from the round-6 qualify run (the index names its commit).
`Test-LoaderBaseline.ps1` on the round-6 tooling recorded 145/145 at `27c0af5` (the evidence index names the
current `loader-baseline.json` run). Round 6 added: a neutral EmbeddedResource from outside `src` (old receipt refused, rebuild
embeds it), imported sources reordered (refused, rebuild accepted), a changed compiler selection
(refused), a response file under ignored artifacts (refused at package and build), the package record
held during a distinct replacement (all three public files unchanged, retry publishes the set),
`package_path` reopening the published ZIP, a control `tests.json` substituted after `Test.ps1` returns
(the substitute run still fails), and a failed private test-run copy leaving no directory.

Earlier rounds (history): round 5 recorded `Test-LoaderBaseline.ps1` 128/128 and `Qualify.ps1 -Build -Test
-VerifyContracts -Package` (84/84 tests, package `83611dd565b69ac399b010fd57cc7f65e948fb7ece22417b8f82c19b65700adc`)
on `5d00290`.

Machine-generated records for the candidate are committed as structured files in
[`docs/evidence/umm-0311/`](evidence/umm-0311/INDEX.md) (qualification summary, build,
package and validation records, contract reports, the boundary-suite and managed
loader-profile results, the static audit, a full loader-profile inventory with every
component's identity and references, the newest-stable selection record and the audit
tool's source). Local path prefixes are replaced by placeholders. The configured
`qualify` gate's own receipt is produced by the agent-review controller.

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
