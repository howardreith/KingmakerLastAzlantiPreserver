<!-- agent-review:v1 enrollment=klap-umm0311-codex-umm-0311-baseline-20261123-20261123162452-aa01 key=r04-request part=1/1 sha256=ba90cabba828109b0204d30b2261da72b1e07e8b6b60c885d7c6d30f1cb1be68 -->
### Claude Opus — review request — round 4 — candidate `2db8f79bc2`

| Field | Value |
|---|---|
| Request ID | `klap-umm0311-codex-umm-0311-baseline-20261123-20261123162452-aa01-r04-c60519` |
| Checkpoint | `final` (final) |
| Candidate H | `2db8f79bc293387f2bcb7769fcc1c06c9af0cd0e` |
| Target B (`main`) | `a2e2af2d724e77e7f9749969d00667c0d8e6481c` |
| Merge base M | `a2e2af2d724e77e7f9749969d00667c0d8e6481c` |
| Mission | `kingmaker-umm-0311-mission-20261123` sha256 `f7d990f396` |
| Workflow | `6d613defe7` |
| Owner guidance | none |
| Owner amendments | none |
| Developer observed | foreground session `e178a93b-ca53-4b6b-a4d2-a357d48eaa77`: models ['claude-opus-5-5'], effort ['high'], permission modes ['auto'] (CLI-recorded transcript; the headless permission profile does not apply to a foreground session) |
| Reviewer requested | Codex `gpt-6.2-astra`, effort `max`, read-only sandbox |
| Round budget | 4 of 5 |

**Scope:** The complete mission as written.

**Exit conditions:**
- Every requirement of the mission is implemented, with evidence appropriate to each claim; no requirement is weakened or silently dropped.
- Validation follows the repository's own instructions; commands, results and limits are reported honestly.
- Deviations, limitations and deferred optional items are stated explicitly, separate from required work.

**Developer summary:**

Round-4 corrections for Last Azlanti Preserver PR #7 (this repository only), resumed by the owner after the no-progress stop. Tooling code 363c484 (f814789 plus suite fixes and the inventory binding in 363c484); 95e100a changes only docs/UMM-COMPATIBILITY.md and PROJECT-STATE.md; 2db8f79 adds only docs/evidence/umm-0311/. The product sources are unchanged since round 3: DLL fadf2dab6ff3b8a92c81a3515b633f0de7482879ac5ca43a79ca9ac7c0031248 (MVID 4bcbb685-5152-4399-98e2-19fb6d19c6cd, UnityModManager 0.31.1.0 + 0Harmony12 1.2.0.1), package 83611dd565b69ac399b010fd57cc7f65e948fb7ece22417b8f82c19b65700adc.

Changes: (1) build fingerprint and receipt use the compiler inventory MSBuild evaluates for the production project (WriteCompilerReferenceList: exact Csc references after reference-assembly selection, source/resource/analyzer items, compile-affecting properties incl. anything GamePath.props sets); the production compile writes its own inventory, which must equal the evaluated one; Package/Qualify check the receipt's recorded inventory (shape and equality with MSBuild now) before the fingerprint. (2) Get-KingmakerConfiguration -AllowMissingLoader for build, package and qualification summaries; runtime consumers still require the loader. (3) package credit requires the package's producing build inputs to equal the current receipt and the packaging-rule fingerprint (Package.ps1, Validate-Package.ps1) to be unchanged; Package refuses if packaged files change during staging. (4) Qualify: contract records must be one binding-aware verification (shared run id, loaded product and Harmony2 MVIDs, loader hashes = configured); tests count only for the DLL the runner loaded; status/exit follow the requested stages. (5) verifiers check the 0Harmony12/Harmony2 modules bound in the process (Assert-LoadedLoaderStack) before crediting ownership and record the loaded Harmony2 location/MVID. (6) Validate-Package: no test hook, private copy created inside the cleanup scope, directory records accepted only when decoded empty. (7) Test-LoaderProfiles: no test parameter. Suite: instrumented disposable script copies (excluded and removed after use) replace production hooks; profiles 0.31.1, byte-identical 0.31.1 copy and 0.33.4 assembled from official packages.

Native runtime NOT RUN on 0.31.1, 0.32.4, 0.33.0 and 0.33.4 (no disposable game copy).

**Validation (developer-reported):**

| Command | Required | Result | Duration | Scope and limits |
|---|---|---|---|---|
| python C:/Dev/agent-review/agent_review.py verify --enrollment klap-umm0311-codex-umm-0311-baseline-20261123-20261123162452-aa01 --gate qualify | yes | pass | 11.9s | Controller receipt on 2db8f79. |
| scripts/Test-LoaderBaseline.ps1 (temporary clone of 363c484) | no | pass | ~15 min | 114/114; docs/evidence/umm-0311/loader-baseline.json (114/114 on a temporary clone of 363c484, initially configured with the disposable 0.31.1 profile). |
| scripts/Qualify.ps1 -Build -Test -VerifyContracts -Package on 363c484 | no | pass | ~3 min | qualification-summary.json, build.json (with compiler_references), tests.json (dll_sha256 of the loaded DLL), contracts.json + game-over-load-contracts.json (same verification_run_id, loaded MVIDs), package.json, package-validation.json. Owner loader 0.33.0 configured (read only). |
| scripts/Test-LoaderProfiles.ps1 -ProfileRoot <0.31.1, 0.32.4, owner-0.33.0, 0.33.4, mismatch> | no | pass | ~2 min | loader-profiles-managed.json: four profiles passed in separate processes on one frozen DLL; mismatch profile refused. Out-of-game managed checks only. |
| LoaderApiAudit on fadf2dab; profile inventory; docs link check | no | pass | ~2s | api-audit.json (9 types/25 members resolved on all four profiles), loader-profile-inventory.json, docs-link-check.json (0 broken). |
| Native disposable-campaign smoke on UMM 0.31.1 / 0.32.4 / 0.33.0 / 0.33.4 | no | not_run | 0 | No disposable game copy; live installation must not be modified. |

**Evidence references:**
- docs/evidence/umm-0311/INDEX.md
- docs/evidence/umm-0311/loader-baseline.json
- docs/evidence/umm-0311/qualification-summary.json
- docs/evidence/umm-0311/build.json
- docs/evidence/umm-0311/loader-profiles-managed.json
- docs/UMM-COMPATIBILITY.md

**Prior findings to assess:** `R1-F1`, `R1-F2`, `R2-F3`, `R3-F1`, `R3-F2`, `R3-F3`, `R3-F4`, `R3-F5`, `R3-F6`, `R3-F7`

_Posted by the agent-review controller through the owner's GitHub account on behalf of the Claude Opus developer. Automated request; not a human review._
