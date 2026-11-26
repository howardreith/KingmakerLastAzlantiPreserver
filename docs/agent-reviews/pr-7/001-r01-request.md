<!-- agent-review:v1 enrollment=klap-umm0311-codex-umm-0311-baseline-20261123-20261123162452-aa01 key=r01-request part=1/1 sha256=452fe3c08a990e3407de26f20b661ae3a96d7df7a4f17efc0fb4666b849d9be0 -->
### Claude Opus — review request — round 1 — candidate `aeef5c8845`

| Field | Value |
|---|---|
| Request ID | `klap-umm0311-codex-umm-0311-baseline-20261123-20261123162452-aa01-r01-5c7004` |
| Checkpoint | `final` (final) |
| Candidate H | `aeef5c8845a2128e791f6c1cf79ccfbed51f06aa` |
| Target B (`main`) | `a2e2af2d724e77e7f9749969d00667c0d8e6481c` |
| Merge base M | `a2e2af2d724e77e7f9749969d00667c0d8e6481c` |
| Mission | `kingmaker-umm-0311-mission-20261123` sha256 `f7d990f396` |
| Workflow | `6d613defe7` |
| Owner guidance | none |
| Owner amendments | none |
| Developer observed | foreground session `e178a93b-ca53-4b6b-a4d2-a357d48eaa77`: models ['claude-opus-5-5'], effort ['high'], permission modes ['auto'] (CLI-recorded transcript; the headless permission profile does not apply to a foreground session) |
| Reviewer requested | Codex `gpt-6.2-astra`, effort `max`, read-only sandbox |
| Round budget | 1 of 5 |

**Scope:** The complete mission as written.

**Exit conditions:**
- Every requirement of the mission is implemented, with evidence appropriate to each claim; no requirement is weakened or silently dropped.
- Validation follows the repository's own instructions; commands, results and limits are reported honestly.
- Deviations, limitations and deferred optional items are stated explicitly, separate from required work.

**Developer summary:**

Last Azlanti Preserver UMM 0.31.1 baseline, adopting PR #7 (codex/umm-0311-baseline-20261123; earlier commits 8b0c9ea/8d0eadd were authored on an offline host without game assemblies and never built). This repository's scope only.

Reconciled state: Info.json and Get-ExpectedProductManifest require ManagerVersion 0.31.1; the production csproj references UnityModManager 0.31.1.0 (author NuGet package sha 05a82b66..., DLL sha 2e038ff2...) and 0Harmony12 1.2.0.1 (sha aa1cd483..., newman55 commit 10cfb1cc) only from the verified artifacts/references cache, with no fallback to the installed loader; AGENTS.md (changed by the PR) now describes the pinned references instead of the installed ones.

Added this round (aeef5c8):
1. LoaderReferences.targets: AssertPinnedLoaderReferencesResolved after ResolveAssemblyReferences/before CoreCompile requires exactly one UnityModManager and one 0Harmony12 in @(ReferencePath), both inside the pinned directory, so the compiler's resolved input is checked on direct dotnet msbuild/MSBuild/IDE builds, not only the selected HintPath.
2. Build-Local receipt (artifacts/qualification/build.json) now records source_commit/source_dirty beside dll_sha256 and loader_references; Validate-Package's report records the packaged DLL's SHA-256, MVID and observed loader AssemblyRefs.
3. scripts/Test-LoaderBaseline.ps1 (new; same design as the Dice Roller test): 23 checks in separate powershell.exe processes with real files: cache genuine/corrupt/missing/installed-0.33.0 bytes; direct dotnet msbuild of the production csproj with a corrupt cache (refused) and the genuine cache (compiler line names exactly the pinned UnityModManager.dll and 0Harmony12.dll); probe projects resolving UnityModManager to an identical copy elsewhere or the installed loader (refused); manifest raised above pin / pin raised above minimum on copies of the real scripts (refused, with an accepted control); receipts vs other DLL bytes, missing loader refs, another loader (refused) and the matching build (accepted); the real Package.ps1 candidate (accepted by the standalone validator) and copies with added 0Harmony12.dll, swapped-in UnityModManager.dll or Assembly-CSharp-firstpass.dll (refused); and the required regression: genuine published v0.1.3 ZIP (sha 8b59d76d..., DLL references UnityModManager 0.33.0.0, asserted in the test) with only Info.json lowered to 0.31.1, refused by standalone Validate-Package.ps1 with 'must reference pinned UnityModManager 0.31.1.0'. Validator reports go to temp, not over artifacts/qualification.
4. Docs: docs/UMM-COMPATIBILITY.md rewritten (contract, reproduction, measured evidence, four separated observations, NOT RUN native rows); PROJECT-STATE baseline paragraph, README and BUILD-AND-RELEASE updated to measured facts; historical sections unchanged.

Unchanged from the PR and kept deliberately: Verify-GameOverLoadContracts accepts the installed loader only if it hash-matches the 0.31.1, 0.32.4 or 0.33.0 comparison inputs (environment check, not a runtime claim); the deterministic test runner resolves loader assemblies from the installed UMM directory at run time (test-only; it compiles the production project via ProjectReference so compile inputs are pinned).

Newer loaders: static API audit (fleet tool C:/Dev/missions/kingmaker-umm-0311/tools/LoaderApiAudit) on candidate DLL fadf2dab...: 9 types / 25 members into UnityModManager/0Harmony12/0Harmony all resolved on 0.31.1, 0.32.4, owner-install 0.33.0 and 0.33.4 (newest stable: author NuGet 2026-11-19; GitHub HEAD 3d14bf0d Version 0.33.4). Component-assembled profiles, labelled; static only.

Native runtime: NOT RUN on all loader versions; the only route (docs/SMOKE-TEST.md) installs into the live game, which this mission forbids changing; no disposable game copy or harness exists here. Not runtime-verified, including on 0.31.1.

**Validation (developer-reported):**

| Command | Required | Result | Duration | Scope and limits |
|---|---|---|---|---|
| python C:/Dev/agent-review/agent_review.py verify --enrollment klap-umm0311-codex-umm-0311-baseline-20261123-20261123162452-aa01 --gate qualify | yes | pass | 7.8s | Controller receipt on aeef5c8: Qualify.ps1 -Build -Test -VerifyContracts: Release build 0 warnings/errors (DLL fadf2dab6ff3b8a92c81a3515b633f0de7482879ac5ca43a79ca9ac7c0031248, MVID 4bcbb685-5152-4399-98e2-19fb6d19c6cd, AssemblyRefs UnityModManager 0.31.1.0 + 0Harmony12 1.2.0.1), 84/84 deterministic tests, Kingmaker and game-over load contracts against installed Kingmaker 2.1.7b / UMM 0.33.0. |
| powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Test-LoaderBaseline.ps1 -ReportPath <evidence> | no | pass | ~60s | 23/23 on the clean aeef5c8 build (receipt source_commit aeef5c8, not dirty); candidate package sha256 83611dd565b69ac399b010fd57cc7f65e948fb7ece22417b8f82c19b65700adc. Install.ps1 was not executed (live game); its validate-before-extract order is a source-order check. |
| LoaderApiAudit --mod KingmakerLastAzlantiPreserver.dll (fadf2dab) --profile 0.31.1/0.32.4/owner-0.33.0/0.33.4 | no | pass | ~1s | Static metadata resolution only; no binding/reflection/Harmony/Unity/save claim. |
| Native disposable-campaign smoke on UMM 0.31.1 / 0.32.4 / 0.33.0 / 0.33.4 | no | not_run | 0 | No disposable game copy or harness; live installation must not be modified. Recorded as NOT RUN. |

**Evidence references:**
- docs/UMM-COMPATIBILITY.md
- scripts/Test-LoaderBaseline.ps1
- LoaderReferences.targets
- C:/Dev/missions/kingmaker-umm-0311/evidence/klap-aeef5c8-qualify-gate.log
- C:/Dev/missions/kingmaker-umm-0311/evidence/klap-aeef5c8-loader-baseline.json
- C:/Dev/missions/kingmaker-umm-0311/evidence/klap-api-audit-fadf2dab.json
- C:/Dev/missions/kingmaker-umm-0311/loaders/PROFILES.md

_Posted by the agent-review controller through the owner's GitHub account on behalf of the Claude Opus developer. Automated request; not a human review._
