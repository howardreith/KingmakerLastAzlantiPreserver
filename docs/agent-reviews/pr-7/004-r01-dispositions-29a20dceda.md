<!-- agent-review:v1 enrollment=klap-umm0311-codex-umm-0311-baseline-20261123-20261123162452-aa01 key=r01-dispositions-29a20dceda part=1/1 sha256=29a20dceda5c18fdd3ba1e9674fa93fed4040a355c2f0a4185ab757cd61e7c1f -->
### Claude Opus — finding dispositions — round 1

Candidate after corrections: `fd9f30f7620d87a9de53c37563ad903f31801073`

- **R1-F1** — `fixed` — commits: `22edd77`, `fd9f30f762`
  Test-LoaderBaseline.ps1 on clean fd9f30f (62/62, per-case output printed in this round's transcript): package-reuse-after-{production-source,reference-helper,msbuild-guard,project-file}-change-rejected, qualify-package-reuse-after-source-change-rejected, package-after-restoring-identical-inputs-accepted, rebuild-after-source-change-accepted, package-after-matching-rebuild-accepted, receipt-other-configuration-rejected (temporary Git clone).
- **R1-F2** — `fixed` — commits: `22edd77`, `fd9f30f762`
  Test-LoaderBaseline.ps1 on clean fd9f30f (62/62, per-case output printed in this round's transcript): archived-dll-vs-first-receipt-rejected, receipt-of-first-build-for-changed-dll-rejected, qualify-credits-current-package (83611dd5...), qualify-ignores-validation-of-another-zip and qualify-ignores-replaced-zip-on-disk ('not run for the current DLL'). One matching record: source fd9f30f, build DLL = archived DLL fadf2dab..., ZIP 83611dd5... (suite summary and gate printed).
- **R1-F3** — `fixed` — commits: `22edd77`, `fd9f30f762`
  Test-LoaderBaseline.ps1 on clean fd9f30f (62/62, per-case output printed in this round's transcript): pin-definition-without-harmony12-rejected, pin-definition-misnamed-harmony12-rejected (populated cache), resolved-input-same-stem-file-in-pinned-dir-rejected, resolved-input-renamed-loader-in-pinned-dir-rejected (FusionName), msbuild-direct-compiles-against-pinned-inputs (both genuine DLLs by exact path). No reference-assembly substitution exists for these references (compiler line shows the cache paths).
- **R1-F4** — `fixed` — commits: `22edd77`, `fd9f30f762`
  Test-LoaderBaseline.ps1 on clean fd9f30f (62/62, per-case output printed in this round's transcript): package-harmony-bytes-under-readme-name-rejected, package-loader-bytes-under-licence-name-rejected; package-candidate-accepted as positive control.
- **R1-F5** — `fixed` — commits: `22edd77`, `fd9f30f762`
  Verify-GameOverLoadContracts admits exact 0.33.4/2.4.3.0 (plus existing profiles), verifies and records Harmony2, and Qualify carries loader_profile/harmony2_* (gate output printed: 'Loader profile: 0.33.0.0; Harmony2: 0Harmony, Version=2.3.6.0 ...'). Test-LoaderProfiles.ps1 output printed: 0.33.4 profile reached the contracts and passed with patch ownership True/True; UMM 0.33.4 + Harmony2 2.3.6.0 refused ('does not match that loader profile's 0Harmony'); isolated profile folders, live install untouched.
- **R1-F6** — `fixed` — commits: `22edd77`, `fd9f30f762`
  Test-LoaderBaseline.ps1 on clean fd9f30f (62/62, per-case output printed in this round's transcript): contracts-verify-selected-debug-dll (Debug DLL 59db6277... verified while Release fadf2dab... exists; summary contracts_verified_dll_sha256 = Debug hash). Both verifiers take -DllPath and record mod_dll hash.
- **R1-F7** — `fixed` — commits: `22edd77`, `fd9f30f762`
  Test-LoaderBaseline.ps1 on clean fd9f30f (62/62, per-case output printed in this round's transcript): clone-build-from-detached-commit (detached clone, receipt source_commit fd9f30f, dirty False); ordinary branch builds pass (gate on the branch worktree).
- **R1-F8** — `fixed` — commits: `22edd77`, `fd9f30f762`
  Test-LoaderBaseline.ps1 on clean fd9f30f (62/62, per-case output printed in this round's transcript): wrong-loader cases use the hash-pinned UnityModManager 0.32.4 fixture; owner install only measured (0.33.0.0 63e5baf7...). Profile-specific behaviour of the installed loader is covered by Test-LoaderProfiles (0.31.1 and newer profiles from disposable configuration).
- **R1-F9** — `fixed` — commits: `22edd77`, `fd9f30f762`
  Test-LoaderBaseline.ps1 on clean fd9f30f (62/62, per-case output printed in this round's transcript): clone path contains a space; msbuild-direct-compiles-against-pinned-inputs prints both resolved quoted paths (UnityModManager.dll, 0Harmony12.dll).
- **R1-F10** — `fixed` — commits: `22edd77`, `fd9f30f762`
  Printed this round: suite per-case results with source SHA, build/archived DLL hash, MVID, AssemblyRefs, ZIP hash, legacy asset identity (v0.1.3 8b59d76d..., DLL refs UMM 0.33.0.0), acceptance/rejection reasons for cache, direct-build, receipt and dependency cases; docs and report reference the same artifact (fadf2dab / 83611dd5).
- **R1-F11** — `fixed` — commits: `22edd77`, `fd9f30f762`
  docs/UMM-COMPATIBILITY.md documents the audit method and profile construction; printed this round: audit for DLL fadf2dab with every component identity/hash per profile (9 types/25 members, 0 unresolved on all four). Newest-stable selection evidence (NuGet version index, 0.33.4 highest; GitHub 3d14bf0d Version 0.33.4) was printed in this session's transcript (Dice round 2 evidence step) and is recorded in the doc.

**Validation (developer-reported):**

| Command | Required | Result | Duration | Scope and limits |
|---|---|---|---|---|
| python C:/Dev/agent-review/agent_review.py verify --enrollment klap-umm0311-codex-umm-0311-baseline-20261123-20261123162452-aa01 --gate qualify | yes | pass | ~10s | Controller receipt on fd9f30f: Qualify -Build -Test -VerifyContracts: 0/0 compiler diagnostics, DLL fadf2dab..., 84/84 tests, Kingmaker + game-over load contracts verified on that DLL with the installed profile 0.33.0 + Harmony2 2.3.6.0 (gate log extract printed this round). |
| powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Test-LoaderBaseline.ps1 -LegacyReleaseZip <v0.1.3 zip> -WrongLoaderPackage <umm 0.32.4 nupkg> | no | pass | ~4 min | 62/62 in a detached temp clone of fd9f30f (path with a space). Install.ps1 not executed (live game); Expand-ValidatedPackage executed. VS IDE not driven; incremental dotnet msbuild /t:Build was. |
| powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Test-LoaderProfiles.ps1 -ProfileRoot <4 profiles + 1 mismatch> | no | pass | ~1 min | Out-of-game managed check: game assembly + Harmony stack in PowerShell; no Unity, UMM loader, save, preservation/recovery or UI exercised; not a runtime claim. Profiles other than the owner copy are component-assembled from official NuGet packages. |
| LoaderApiAudit --mod KingmakerLastAzlantiPreserver.dll (fadf2dab) --profile 0.31.1 / 0.32.4 / owner-0.33.0 / 0.33.4 | no | pass | ~1s | Static only. |
| Native disposable-campaign smoke on UMM 0.31.1 / 0.32.4 / 0.33.0 / 0.33.4 | no | not_run | 0 | No disposable game copy or harness; live installation must not be modified. |

_Model-generated developer response (Claude opus / high), posted by the agent-review controller through the owner's GitHub account; not a human review._
