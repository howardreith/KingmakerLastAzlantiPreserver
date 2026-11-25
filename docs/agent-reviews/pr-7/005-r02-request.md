<!-- agent-review:v1 enrollment=klap-umm0311-codex-umm-0311-baseline-20261123-20261123162452-aa01 key=r02-request part=1/1 sha256=f37d2d58e8187385dfebca00ebc344fddfb3b7c2256eed88dc7e335970825c93 -->
### Claude Opus — review request — round 2 — candidate `fd9f30f762`

| Field | Value |
|---|---|
| Request ID | `klap-umm0311-codex-umm-0311-baseline-20261123-20261123162452-aa01-r02-40e907` |
| Checkpoint | `final` (final) |
| Candidate H | `fd9f30f7620d87a9de53c37563ad903f31801073` |
| Target B (`main`) | `a2e2af2d724e77e7f9749969d00667c0d8e6481c` |
| Merge base M | `a2e2af2d724e77e7f9749969d00667c0d8e6481c` |
| Mission | `kingmaker-umm-0311-mission-20261123` sha256 `f7d990f396` |
| Workflow | `6d613defe7` |
| Owner guidance | none |
| Owner amendments | none |
| Developer observed | foreground session `e178a93b-ca53-4b6b-a4d2-a357d48eaa77`: models ['claude-opus-5-5'], effort ['high'], permission modes ['auto'] (CLI-recorded transcript; the headless permission profile does not apply to a foreground session) |
| Reviewer requested | Codex `gpt-6.2-astra`, effort `max`, read-only sandbox |
| Round budget | 2 of 5 |

**Scope:** The complete mission as written.

**Exit conditions:**
- Every requirement of the mission is implemented, with evidence appropriate to each claim; no requirement is weakened or silently dropped.
- Validation follows the repository's own instructions; commands, results and limits are reported honestly.
- Deviations, limitations and deferred optional items are stated explicitly, separate from required work.

**Developer summary:**

Round-2 correction batch for Last Azlanti Preserver PR #7 (this repository only). Candidate fd9f30f; production DLL unchanged (fadf2dab6ff3b8a92c81a3515b633f0de7482879ac5ca43a79ca9ac7c0031248, MVID 4bcbb685-5152-4399-98e2-19fb6d19c6cd); package 83611dd565b69ac399b010fd57cc7f65e948fb7ece22417b8f82c19b65700adc. ZIP hash reconciliation: every package built from this DLL and the current README/licence files is 83611dd5... (Qualify -Package in the worktree, the suite's clone package and artifacts/packages agree, printed this round); the changed-source packages in the suite are deliberately different and named as such.

Changes: build_inputs_sha256 fingerprint + configuration in build.json and Assert-PinnedBuildReceipt (Package.ps1, Qualify -Package); Package passes -ExpectedDllSha256 and records validated package/DLL hashes; canonical pin set and string ManagerVersion in verifier, Common.ps1 and Assert-ProductManifest; LoaderReferences.targets exact full-path inputs (file name or FusionName), DisableFastUpToDateCheck, pins/verifier/guard/manifest as compile inputs; Validate-Package text-entry content check; Windows PowerShell metadata read in a child process; Install.ps1 extracts only via Expand-ValidatedPackage; Qualify.ps1 credits contract and package records only when they describe the current build record's DLL (ZIP on disk = package record = validation record) and passes the selected configuration's DLL to the verifiers; both contract verifiers take -DllPath and record the verified DLL hash; Verify-GameOverLoadContracts admits exact profiles 0.31.1/2.3.1.1, 0.32.4/2.3.6.0, 0.33.0/2.3.6.0, 0.33.4/2.4.3.0, verifies and records Harmony2 beside UMM, and the summary carries loader_profile and Harmony2; Get-GitMetadata handles a detached HEAD; new scripts/Test-LoaderProfiles.ps1 runs both verifiers per loader-profile folder in separate processes with a temporary GamePath.props (installed loader untouched); Test-LoaderBaseline.ps1 rewritten like Dice's (temp clone with a space, private verified fixtures, 0.32.4 wrong-loader fixture, 62 checks); docs updated (no local paths per AGENTS.md).

Managed evidence (out of game, printed this round): for DLL fadf2dab the real contract verifiers applied, verified and removed the core and optional Harmony patches through each loader stack: 0.31.1 (Harmony2 2.3.1.1), 0.32.4 (2.3.6.0), owner 0.33.0 (2.3.6.0), 0.33.4 (2.4.3.0) all passed; UMM 0.33.4 with Harmony2 2.3.6.0 was refused. Static audit (9 types/25 members) resolved on all four. Native runtime remains NOT RUN on every loader (no disposable game copy/harness; live install untouched).

**Validation (developer-reported):**

| Command | Required | Result | Duration | Scope and limits |
|---|---|---|---|---|
| python C:/Dev/agent-review/agent_review.py verify --enrollment klap-umm0311-codex-umm-0311-baseline-20261123-20261123162452-aa01 --gate qualify | yes | pass | ~10s | Controller receipt on fd9f30f: Qualify -Build -Test -VerifyContracts: 0/0 compiler diagnostics, DLL fadf2dab..., 84/84 tests, Kingmaker + game-over load contracts verified on that DLL with the installed profile 0.33.0 + Harmony2 2.3.6.0 (gate log extract printed this round). |
| powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Test-LoaderBaseline.ps1 -LegacyReleaseZip <v0.1.3 zip> -WrongLoaderPackage <umm 0.32.4 nupkg> | no | pass | ~4 min | 62/62 in a detached temp clone of fd9f30f (path with a space). Install.ps1 not executed (live game); Expand-ValidatedPackage executed. VS IDE not driven; incremental dotnet msbuild /t:Build was. |
| powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Test-LoaderProfiles.ps1 -ProfileRoot <4 profiles + 1 mismatch> | no | pass | ~1 min | Out-of-game managed check: game assembly + Harmony stack in PowerShell; no Unity, UMM loader, save, preservation/recovery or UI exercised; not a runtime claim. Profiles other than the owner copy are component-assembled from official NuGet packages. |
| LoaderApiAudit --mod KingmakerLastAzlantiPreserver.dll (fadf2dab) --profile 0.31.1 / 0.32.4 / owner-0.33.0 / 0.33.4 | no | pass | ~1s | Static only. |
| Native disposable-campaign smoke on UMM 0.31.1 / 0.32.4 / 0.33.0 / 0.33.4 | no | not_run | 0 | No disposable game copy or harness; live installation must not be modified. |

**Evidence references:**
- docs/UMM-COMPATIBILITY.md
- scripts/Test-LoaderBaseline.ps1
- scripts/Test-LoaderProfiles.ps1
- scripts/Qualify.ps1
- scripts/Verify-GameOverLoadContracts.ps1
- C:/Dev/missions/kingmaker-umm-0311/evidence/klap-fd9f30f-loader-baseline.json
- C:/Dev/missions/kingmaker-umm-0311/evidence/klap-fd9f30f-loader-profiles.json
- C:/Dev/missions/kingmaker-umm-0311/evidence/klap-fd9f30f-api-audit.json

**Prior findings to assess:** `R1-F1`, `R1-F10`, `R1-F11`, `R1-F2`, `R1-F3`, `R1-F4`, `R1-F5`, `R1-F6`, `R1-F7`, `R1-F8`, `R1-F9`

_Posted by the agent-review controller through the owner's GitHub account on behalf of the Claude Opus developer. Automated request; not a human review._
