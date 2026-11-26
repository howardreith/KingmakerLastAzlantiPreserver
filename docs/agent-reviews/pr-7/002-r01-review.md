<!-- agent-review:v1 enrollment=klap-umm0311-codex-umm-0311-baseline-20261123-20261123162452-aa01 key=r01-review part=1/1 sha256=0f5bb7164f7596540e77b54d33dd521bef6b27cb7b9f8b8987877929d0a72ac2 -->
### Codex GPT-6.2 Astra — review — round 1 — candidate `aeef5c8845`

**Decision:** `changes_required` — The clean Release build, 84 deterministic tests, and managed contract checks passed. Changes are required because an old DLL can be packaged after its build inputs change, qualification can credit the wrong ZIP, and the supplied execution records do not establish the standalone package regression or the four-loader API audit.

## Continuation for Claude

Bind the material build inputs, compiled DLL, archived DLL, and validation result to one another. Close the missing-pin and package-content checks. Carry the selected candidate and complete loader profile through managed qualification, and correct the build and test failures identified below.

Run the existing qualify gate on the corrected commit. Provide reviewer-visible execution output for the package failure cases and the static audit of one frozen DLL across all four profiles. Reconcile the two reported ZIP hashes. Keep corrections within Preserver’s build, validation, and documentation scope. Preserve the existing gates, product identity, historical release records, and live installation. Native qualification can remain NOT RUN under the documented fixture constraint.

#### Findings

**R1-F1** · P1 · defect · blocks readiness — Invalidate frozen DLLs when material build inputs change
- Location: `scripts/Common.ps1:185`; acceptance: §5, §6
- Trigger: Build once, change a production source file, project reference, or pinning helper, then run Package.ps1 with the old DLL and build.json.
- Expected: Frozen DLL reuse must depend on the material inputs that produced it.
- Actual: Assert-PinnedBuildReceipt compares the loose DLL hash and selected loader fields only. It ignores source_commit and source_dirty and has no fingerprint for the project, targets, reference helper, or production source. Test-LoaderBaseline only warns when the recorded source differs.
- Why it blocks / does not: A previous build can be presented as the current source candidate after a material input changes.
- Requested correction: Record and verify material build inputs when reusing a DLL, including the pin definition, reference helper, project and imported build files, and production source. Make stale provenance fail candidate qualification.
- Requested evidence: Use a temporary Git worktree or repository to show a matching build passing, an old DLL and receipt being refused after a material input changes, and a rebuilt candidate passing.

**R1-F2** · P1 · defect · blocks readiness — Bind package qualification to the archive actually validated
- Location: `scripts/Qualify.ps1:85`; acceptance: §5, §6, §8
- Trigger: Run qualification without -Package while earlier package evidence exists, or validate a separate supplied ZIP using the default report path.
- Expected: A package pass should identify one actual ZIP whose extracted DLL matches the qualified build receipt.
- Actual: Package.ps1 checks the loose DLL before staging and never compares the archived DLL hash returned by validation with the build receipt. Qualify.ps1 independently reads package.json and package-validation.json. The recorded gate omitted -Package yet printed a passed ZIP hash beginning b547baf9. The developer report identifies a ZIP beginning 83611dd5.
- Why it blocks / does not: The qualification summary can attribute a validation pass to a different archive. The supplied gate cannot establish which ZIP belongs to this candidate.
- Requested correction: Compare the extracted DLL digest with the build receipt during candidate packaging. Tie the validation result to the actual ZIP digest. When packaging is omitted, report it as unrun or explicitly verify the identity and freshness of any reused result.
- Requested evidence: Show that a prior package report or validation of another ZIP cannot yield a current package pass. Supply one matching source, build DLL, archived DLL, and ZIP record.

**R1-F3** · P1 · defect · blocks readiness — Require both pins and verify the exact compiler inputs
- Location: `scripts/Get-PinnedLoaderReferences.ps1:13`; acceptance: §5, §6
- Trigger: A pin definition is removed while an older cached file remains, or resolution selects a same-stem file beside the verified DLL.
- Expected: Both required pin definitions and both exact loader files supplied to the compiler must be verified.
- Actual: The pin reader requires a UnityModManager entry but allows the Harmony12 entry to disappear. With a cached 0Harmony12.dll present, the project still resolves it and the post-resolution guard accepts its filename stem and parent directory. Its bytes have gone unchecked. The standalone validator also iterates the shortened list. Even with both pins present, the resolved-path test compares the stem and directory rather than the exact verified file.
- Why it blocks / does not: A supported direct build can compile against an unverified required dependency, and package validation can silently drop the corresponding AssemblyRef check.
- Requested correction: Require the two expected assembly-to-file mappings in the build and package checks. Match the effective compiler reference paths to the exact verified DLLs, including any reference-assembly substitution.
- Requested evidence: Show rejection of an incomplete pin manifest with a populated cache and of a different resolved file with the expected stem in the verified directory. Retain a passing direct build against both genuine DLLs.

**R1-F4** · P2 · defect · blocks readiness — Check the contents of allowlisted text entries
- Location: `scripts/Validate-Package.ps1:27`; acceptance: §5, §6
- Trigger: A supplied archive has the six expected filenames but contains a dependency binary in a text entry.
- Expected: The six-file package rule should exclude dependency binaries from the archive’s contents.
- Actual: The four documentation and license entries are checked only for their names, nonzero lengths, and safe paths. A managed assembly occupying one of those entries passes those checks. The new swapped-file tests change the entry name, so they exercise a different case.
- Why it blocks / does not: A supplied ZIP can carry an excluded loader or game binary and still receive a standalone validation pass.
- Requested correction: Validate the ancillary entries as text or otherwise reject managed binary payloads in those positions while retaining the existing filename and mod metadata checks.
- Requested evidence: Run the standalone validator against a temporary archive with a mislabeled managed dependency in an ancillary entry and against the genuine candidate as a positive control.

**R1-F5** · P2 · defect · blocks readiness — Admit the newest measured profile and record Harmony2
- Location: `scripts/Verify-GameOverLoadContracts.ps1:128`; acceptance: §7, §8
- Trigger: Select the documented 0.33.4 profile through GamePathProps, or compare two profiles with identical UMM and Harmony12 files but different Harmony2 files.
- Expected: Each measured comparison profile should be usable for the repository’s managed contract check and identified by its complete relevant loader stack.
- Actual: The contract verifier’s table ends at 0.33.0 and rejects the documented 0.33.4 profile before testing it. For admitted versions the verifier checks and records UMM and 0Harmony12 only. Its report cannot distinguish different underlying 0Harmony.dll builds.
- Why it blocks / does not: The managed check excludes an explicit comparison target and cannot identify the complete Harmony stack for the rows it admits.
- Requested correction: Admit the exact measured 0.33.4 profile, preserve the existing exact profiles, and verify and record the selected Harmony2 assembly along with UMM and Harmony12. Carry those identities into the qualification result.
- Requested evidence: Show a managed check reaching the contracts with the measured newest profile, its actual outcome, and refusal of a mismatched Harmony stack using isolated profile files.

**R1-F6** · P2 · defect · blocks readiness — Run contract checks on the selected configuration’s DLL
- Location: `scripts/Qualify.ps1:16`; acceptance: §6, §7
- Trigger: Run Qualify.ps1 -Build -Test -VerifyContracts -Configuration Debug.
- Expected: Contract checks and their receipts should identify the same candidate DLL selected by qualification.
- Actual: Qualify.ps1 forwards Configuration to build and test but omits it when invoking the contract scripts. Both contract verifiers select artifacts/bin/Release explicitly. A Debug qualification can test an older Release DLL or fail because that unrelated DLL is absent.
- Why it blocks / does not: A supported qualification invocation can credit patch ownership and contract results to a DLL that did not undergo those checks.
- Requested correction: Pass the selected candidate DLL or configuration through both contract verifiers and record the hash of the DLL actually checked.
- Requested evidence: Qualify a Debug build in an isolated worktree and show that the contract record names its exact DLL hash, including when a different Release build exists.

**R1-F7** · P2 · defect · blocks readiness — Allow the production wrapper to build a detached commit
- Location: `scripts/Build-Local.ps1:9`; acceptance: §5, §6
- Trigger: Invoke Build-Local.ps1 in a detached worktree with valid game paths and reference files.
- Expected: A detached commit should yield a usable source SHA and dirty state even when it has no branch name.
- Actual: The new Get-GitMetadata call reaches Common.ps1 line 75, where .Trim() is called on the output of git branch --show-current. I evaluated that expression in the detached snapshot and it raised InvokeMethodOnNull.
- Why it blocks / does not: The documented production build wrapper now stops before MSBuild for a valid checkout of an exact commit.
- Requested correction: Handle empty branch output in Get-GitMetadata while retaining the exact commit and dirty-state checks.
- Requested evidence: Show that the build receipt records the correct SHA from a clean detached checkout and that ordinary branch builds still pass.

**R1-F8** · P2 · defect · blocks readiness — Remove the regression suite’s assumption that installed UMM is newer
- Location: `scripts/Test-LoaderBaseline.ps1:105`; acceptance: §6, §7
- Trigger: Run Test-LoaderBaseline.ps1 with UnityModManagerDir pointing to the genuine baseline.
- Expected: Negative controls should use a known different reference. Genuine baseline bytes should pass regardless of the installed loader version.
- Actual: The suite always expects a copy of the installed UMM to fail its hash check. It also constructs a supposedly mismatched receipt using the installed UMM hash at line 203. On a genuine 0.31.1 installation the copied bytes are valid and the receipt edit changes nothing, so both cases falsely fail.
- Why it blocks / does not: The documented regression suite cannot pass in the required baseline environment.
- Requested correction: Use a verified, distinct loader fixture for the wrong-bytes and wrong-receipt cases. Determine the expected result for a copy of the installed loader from its measured identity.
- Requested evidence: Demonstrate the suite with a genuine 0.31.1 profile and a newer profile using disposable configuration, with the live installation preserved.

**R1-F9** · P2 · defect · blocks readiness — Handle quoted compiler reference paths
- Location: `scripts/Test-LoaderBaseline.ps1:116`; acceptance: §5, §6
- Trigger: The repository’s artifacts/references directory is under a Windows path containing a space.
- Expected: Compiler evidence should recognize quoted and unquoted paths and compare each complete path to its pin.
- Actual: Both compiler-reference regexes exclude spaces inside a quoted path. A read-only check of the UMM regex against a quoted path under a directory named Preserver Build returned zero matches.
- Why it blocks / does not: The required direct-compiler check reports a failure for a valid Windows checkout path.
- Requested correction: Parse whole quoted reference arguments or consume structured compiler inputs. Retain the exact path and count assertions.
- Requested evidence: Run the direct compiler-input check from a worktree with a space in its path and show the two resolved filenames.

**R1-F10** · P1 · evidence_gap · blocks readiness — Supply execution evidence for the package and legacy regression
- Location: `docs/UMM-COMPATIBILITY.md:79`; acceptance: §5, §6, §8
- Trigger: Assess the reported 23/23 result and candidate package hash for the final checkpoint.
- Expected: Reviewer-visible execution evidence should establish the correct package passing and the genuine 0.33.0-compiled v0.1.3 DLL with its lowered manifest failing before installation.
- Actual: The supplied gate command and full log cover build, deterministic tests, and contracts. They contain no Test-LoaderBaseline execution, standalone validator output, packaged AssemblyRef observation, or legacy rejection. The referenced external results are absent from the review inputs.
- Why it blocks / does not: The required archive and failure-boundary observations cannot be independently confirmed from a passing build or the test source.
- Requested correction: Provide scoped machine-produced output for the package and regression runs through the permitted evidence route. Align documentation and the developer report with the artifact that those runs identify.
- Requested evidence: Include the source SHA, build and archived DLL hashes, MVID, observed AssemblyRefs, ZIP hash, verified legacy asset identity, standalone acceptance and rejection reasons, and outcomes of the cache, direct-build, receipt, and dependency cases.

**R1-F11** · P1 · evidence_gap · blocks readiness — Make the four-loader static API assessment reproducible
- Location: `docs/UMM-COMPATIBILITY.md:91`; acceptance: §7, §8
- Trigger: Verify the compatibility table against the evidence supplied for this candidate.
- Expected: A reviewer should be able to identify the audit procedure and confirm the exact candidate, profile provenance, components, and observed result for each row.
- Actual: The document reports nine types and 25 members resolving on four profiles. The reproduction commands omit the audit. Its tool and result are referenced only outside the snapshot, and the gate log contains no per-profile API audit output.
- Why it blocks / does not: The required static compatibility assessment lacks reproducible instructions and execution evidence tied to the frozen DLL.
- Requested correction: Document a reproducible audit invocation and accessible tool or method. Supply scoped machine-produced results and the official distribution evidence used to select the newest stable row.
- Requested evidence: For 0.31.1, 0.32.4, owner-installed 0.33.0, and the selected newest stable version, show the same candidate DLL digest, exact UMM/Harmony component identities and provenance, and resolved or failed API counts.

#### Evidence assessment

- **Inspected:** The controller request, enrolled mission, repository instructions, developer report, prior-findings ledger, transcript notice, qualify receipt, and full gate log.; The full 16-file feature diff and its build, test, packaging, standalone validation, installation, contract-verification, qualification, and release consumers.; The compatibility and build documentation, historical v0.1.3 asset identity, and disposable-campaign smoke procedure.
- **Executed verification:** The controller ran Qualify.ps1 -Build -Test -VerifyContracts on the clean candidate. It exited 0 in 7.8 seconds with zero compiler warnings or errors. The Release DLL SHA-256 was fadf2dab6ff3b8a92c81a3515b633f0de7482879ac5ca43a79ca9ac7c0031248.; The gate log records 84/84 tests, the Kingmaker and game-over load contract checks, five core and fifteen optional Harmony patch entries, and successful ownership isolation. It identifies installed UMM 0.33.0.0 and Harmony12 1.2.0.1.; Read-only reviewer checks confirmed HEAD, the mission digest, the gate log digest recorded in the receipt, and a clean git diff --check. The detached-branch expression raised InvokeMethodOnNull. The compiler-reference regex returned zero matches for a quoted reference path containing a space.
- **Source inspection only:** Info.json declares 0.31.1. The production project selects the pinned UMM and Harmony12 references with Private=False. The pin file contains the mission’s upstream hashes, and the cache is ignored by Git.; The standalone validator reads the archived DLL’s AssemblyRefs and records its hash and MVID. Install.ps1 calls it before extraction. The genuine v0.1.3 regression and direct compiler probes are present in test source.; The compatibility document describes four static audit results. The scoped execution evidence contains only the installed-environment managed contract run.
- **Required gaps:** Candidate-bound execution output for the standalone validator, genuine lowered-manifest regression, and other required failure cases, including the identity of the ZIP that passed.; Reproducible, machine-produced static API results for the same DLL across the four measured loader and Harmony profiles.; Verification of the corrected receipt, reference, package-content, profile-selection, and supported build/test paths in the findings.
- **Limitations:** The review used the detached read-only snapshot. The controller withheld the mixed foreground transcript. The external evidence files named in the developer report were not included in the review inputs.; Native behavior is recorded as NOT RUN on 0.31.1, 0.32.4, 0.33.0, and 0.33.4. No combined-stack run was reported. The mission permits this disposition where an approved disposable runtime path is unavailable.

#### Summary

- **Delivered behavior:** The shipping manifest declares UMM 0.31.1. The normal Release build uses the pinned reference cache, and the standalone validator inspects the packaged DLL’s loader references. The controller confirmed compilation, deterministic tests, and managed contracts on the installed 0.33.0 environment.
- **Scope reviewed:** Draft PR #7 for KingmakerLastAzlantiPreserver, from a2e2af2 to aeef5c8, including the affected build, package, qualification, and compatibility evidence paths.
- **Pending later-phase work:** none
- **Unresolved questions:** Which ZIP hash is backed by a matching archive-validation run for the reviewed source?
- **Remaining owner review:** Any future authorization and observation of the disposable Last Azlanti defeat, preservation, recovery, and manual-deletion controls on identified loader profiles.

#### Provenance (controller-recorded)

| | Requested | Observed |
|---|---|---|
| Model | `gpt-6.2-astra` | `gpt-6.2-astra` (turns ['gpt-6.2-astra']) |
| Reasoning effort | `max` | `max` (turns ['max']) |
| Sandbox / approvals | read-only / never | `read-only` / `never` |

Owner guidance bound to this review: none.

Owner amendments bound to this review: none.

Codex CLI `0.170.0`, thread `01a20a4d-5b2d-7c22-b50d-d8233eea4fc2`, duration 692.6s, response sha256 `21e4872013f4813faf9ce0409444aa00c61017777b0fb4ff8b83656dd16e7a06`, request `klap-umm0311-codex-umm-0311-baseline-20261123-20261123162452-aa01-r01-5c7004`. Observed values come from the Codex session rollout's recorded thread settings, not from the model's own statements; the serving backend's model identity is not separately exposed.

<details><summary>Complete structured review (agent-review.review.v1)</summary>

```json
{
  "candidate_commit": "aeef5c8845a2128e791f6c1cf79ccfbed51f06aa",
  "checkpoint_id": "final",
  "checkpoint_type": "final",
  "decision": "changes_required",
  "decision_rationale": "The clean Release build, 84 deterministic tests, and managed contract checks passed. Changes are required because an old DLL can be packaged after its build inputs change, qualification can credit the wrong ZIP, and the supplied execution records do not establish the standalone package regression or the four-loader API audit.\n\n## Continuation for Claude\n\nBind the material build inputs, compiled DLL, archived DLL, and validation result to one another. Close the missing-pin and package-content checks. Carry the selected candidate and complete loader profile through managed qualification, and correct the build and test failures identified below.\n\nRun the existing qualify gate on the corrected commit. Provide reviewer-visible execution output for the package failure cases and the static audit of one frozen DLL across all four profiles. Reconcile the two reported ZIP hashes. Keep corrections within Preserver\u2019s build, validation, and documentation scope. Preserve the existing gates, product identity, historical release records, and live installation. Native qualification can remain NOT RUN under the documented fixture constraint.",
  "evidence_assessment": {
    "executed_verification": [
      "The controller ran Qualify.ps1 -Build -Test -VerifyContracts on the clean candidate. It exited 0 in 7.8 seconds with zero compiler warnings or errors. The Release DLL SHA-256 was fadf2dab6ff3b8a92c81a3515b633f0de7482879ac5ca43a79ca9ac7c0031248.",
      "The gate log records 84/84 tests, the Kingmaker and game-over load contract checks, five core and fifteen optional Harmony patch entries, and successful ownership isolation. It identifies installed UMM 0.33.0.0 and Harmony12 1.2.0.1.",
      "Read-only reviewer checks confirmed HEAD, the mission digest, the gate log digest recorded in the receipt, and a clean git diff --check. The detached-branch expression raised InvokeMethodOnNull. The compiler-reference regex returned zero matches for a quoted reference path containing a space."
    ],
    "inspected": [
      "The controller request, enrolled mission, repository instructions, developer report, prior-findings ledger, transcript notice, qualify receipt, and full gate log.",
      "The full 16-file feature diff and its build, test, packaging, standalone validation, installation, contract-verification, qualification, and release consumers.",
      "The compatibility and build documentation, historical v0.1.3 asset identity, and disposable-campaign smoke procedure."
    ],
    "limitations": [
      "The review used the detached read-only snapshot. The controller withheld the mixed foreground transcript. The external evidence files named in the developer report were not included in the review inputs.",
      "Native behavior is recorded as NOT RUN on 0.31.1, 0.32.4, 0.33.0, and 0.33.4. No combined-stack run was reported. The mission permits this disposition where an approved disposable runtime path is unavailable."
    ],
    "required_gaps": [
      "Candidate-bound execution output for the standalone validator, genuine lowered-manifest regression, and other required failure cases, including the identity of the ZIP that passed.",
      "Reproducible, machine-produced static API results for the same DLL across the four measured loader and Harmony profiles.",
      "Verification of the corrected receipt, reference, package-content, profile-selection, and supported build/test paths in the findings."
    ],
    "source_inspection_only": [
      "Info.json declares 0.31.1. The production project selects the pinned UMM and Harmony12 references with Private=False. The pin file contains the mission\u2019s upstream hashes, and the cache is ignored by Git.",
      "The standalone validator reads the archived DLL\u2019s AssemblyRefs and records its hash and MVID. Install.ps1 calls it before extraction. The genuine v0.1.3 regression and direct compiler probes are present in test source.",
      "The compatibility document describes four static audit results. The scoped execution evidence contains only the installed-environment managed contract run."
    ]
  },
  "findings": [
    {
      "acceptance_ids": [
        "\u00a75",
        "\u00a76"
      ],
      "actual": "Assert-PinnedBuildReceipt compares the loose DLL hash and selected loader fields only. It ignores source_commit and source_dirty and has no fingerprint for the project, targets, reference helper, or production source. Test-LoaderBaseline only warns when the recorded source differs.",
      "blocking_rationale": "A previous build can be presented as the current source candidate after a material input changes.",
      "blocks_readiness": true,
      "category": "defect",
      "expected": "Frozen DLL reuse must depend on the material inputs that produced it.",
      "id": "R1-F1",
      "location": {
        "file": "scripts/Common.ps1",
        "line": 185
      },
      "priority": "P1",
      "requested_correction": "Record and verify material build inputs when reusing a DLL, including the pin definition, reference helper, project and imported build files, and production source. Make stale provenance fail candidate qualification.",
      "requested_evidence": "Use a temporary Git worktree or repository to show a matching build passing, an old DLL and receipt being refused after a material input changes, and a rebuilt candidate passing.",
      "title": "Invalidate frozen DLLs when material build inputs change",
      "trigger": "Build once, change a production source file, project reference, or pinning helper, then run Package.ps1 with the old DLL and build.json."
    },
    {
      "acceptance_ids": [
        "\u00a75",
        "\u00a76",
        "\u00a78"
      ],
      "actual": "Package.ps1 checks the loose DLL before staging and never compares the archived DLL hash returned by validation with the build receipt. Qualify.ps1 independently reads package.json and package-validation.json. The recorded gate omitted -Package yet printed a passed ZIP hash beginning b547baf9. The developer report identifies a ZIP beginning 83611dd5.",
      "blocking_rationale": "The qualification summary can attribute a validation pass to a different archive. The supplied gate cannot establish which ZIP belongs to this candidate.",
      "blocks_readiness": true,
      "category": "defect",
      "expected": "A package pass should identify one actual ZIP whose extracted DLL matches the qualified build receipt.",
      "id": "R1-F2",
      "location": {
        "file": "scripts/Qualify.ps1",
        "line": 85
      },
      "priority": "P1",
      "requested_correction": "Compare the extracted DLL digest with the build receipt during candidate packaging. Tie the validation result to the actual ZIP digest. When packaging is omitted, report it as unrun or explicitly verify the identity and freshness of any reused result.",
      "requested_evidence": "Show that a prior package report or validation of another ZIP cannot yield a current package pass. Supply one matching source, build DLL, archived DLL, and ZIP record.",
      "title": "Bind package qualification to the archive actually validated",
      "trigger": "Run qualification without -Package while earlier package evidence exists, or validate a separate supplied ZIP using the default report path."
    },
    {
      "acceptance_ids": [
        "\u00a75",
        "\u00a76"
      ],
      "actual": "The pin reader requires a UnityModManager entry but allows the Harmony12 entry to disappear. With a cached 0Harmony12.dll present, the project still resolves it and the post-resolution guard accepts its filename stem and parent directory. Its bytes have gone unchecked. The standalone validator also iterates the shortened list. Even with both pins present, the resolved-path test compares the stem and directory rather than the exact verified file.",
      "blocking_rationale": "A supported direct build can compile against an unverified required dependency, and package validation can silently drop the corresponding AssemblyRef check.",
      "blocks_readiness": true,
      "category": "defect",
      "expected": "Both required pin definitions and both exact loader files supplied to the compiler must be verified.",
      "id": "R1-F3",
      "location": {
        "file": "scripts/Get-PinnedLoaderReferences.ps1",
        "line": 13
      },
      "priority": "P1",
      "requested_correction": "Require the two expected assembly-to-file mappings in the build and package checks. Match the effective compiler reference paths to the exact verified DLLs, including any reference-assembly substitution.",
      "requested_evidence": "Show rejection of an incomplete pin manifest with a populated cache and of a different resolved file with the expected stem in the verified directory. Retain a passing direct build against both genuine DLLs.",
      "title": "Require both pins and verify the exact compiler inputs",
      "trigger": "A pin definition is removed while an older cached file remains, or resolution selects a same-stem file beside the verified DLL."
    },
    {
      "acceptance_ids": [
        "\u00a75",
        "\u00a76"
      ],
      "actual": "The four documentation and license entries are checked only for their names, nonzero lengths, and safe paths. A managed assembly occupying one of those entries passes those checks. The new swapped-file tests change the entry name, so they exercise a different case.",
      "blocking_rationale": "A supplied ZIP can carry an excluded loader or game binary and still receive a standalone validation pass.",
      "blocks_readiness": true,
      "category": "defect",
      "expected": "The six-file package rule should exclude dependency binaries from the archive\u2019s contents.",
      "id": "R1-F4",
      "location": {
        "file": "scripts/Validate-Package.ps1",
        "line": 27
      },
      "priority": "P2",
      "requested_correction": "Validate the ancillary entries as text or otherwise reject managed binary payloads in those positions while retaining the existing filename and mod metadata checks.",
      "requested_evidence": "Run the standalone validator against a temporary archive with a mislabeled managed dependency in an ancillary entry and against the genuine candidate as a positive control.",
      "title": "Check the contents of allowlisted text entries",
      "trigger": "A supplied archive has the six expected filenames but contains a dependency binary in a text entry."
    },
    {
      "acceptance_ids": [
        "\u00a77",
        "\u00a78"
      ],
      "actual": "The contract verifier\u2019s table ends at 0.33.0 and rejects the documented 0.33.4 profile before testing it. For admitted versions the verifier checks and records UMM and 0Harmony12 only. Its report cannot distinguish different underlying 0Harmony.dll builds.",
      "blocking_rationale": "The managed check excludes an explicit comparison target and cannot identify the complete Harmony stack for the rows it admits.",
      "blocks_readiness": true,
      "category": "defect",
      "expected": "Each measured comparison profile should be usable for the repository\u2019s managed contract check and identified by its complete relevant loader stack.",
      "id": "R1-F5",
      "location": {
        "file": "scripts/Verify-GameOverLoadContracts.ps1",
        "line": 128
      },
      "priority": "P2",
      "requested_correction": "Admit the exact measured 0.33.4 profile, preserve the existing exact profiles, and verify and record the selected Harmony2 assembly along with UMM and Harmony12. Carry those identities into the qualification result.",
      "requested_evidence": "Show a managed check reaching the contracts with the measured newest profile, its actual outcome, and refusal of a mismatched Harmony stack using isolated profile files.",
      "title": "Admit the newest measured profile and record Harmony2",
      "trigger": "Select the documented 0.33.4 profile through GamePathProps, or compare two profiles with identical UMM and Harmony12 files but different Harmony2 files."
    },
    {
      "acceptance_ids": [
        "\u00a76",
        "\u00a77"
      ],
      "actual": "Qualify.ps1 forwards Configuration to build and test but omits it when invoking the contract scripts. Both contract verifiers select artifacts/bin/Release explicitly. A Debug qualification can test an older Release DLL or fail because that unrelated DLL is absent.",
      "blocking_rationale": "A supported qualification invocation can credit patch ownership and contract results to a DLL that did not undergo those checks.",
      "blocks_readiness": true,
      "category": "defect",
      "expected": "Contract checks and their receipts should identify the same candidate DLL selected by qualification.",
      "id": "R1-F6",
      "location": {
        "file": "scripts/Qualify.ps1",
        "line": 16
      },
      "priority": "P2",
      "requested_correction": "Pass the selected candidate DLL or configuration through both contract verifiers and record the hash of the DLL actually checked.",
      "requested_evidence": "Qualify a Debug build in an isolated worktree and show that the contract record names its exact DLL hash, including when a different Release build exists.",
      "title": "Run contract checks on the selected configuration\u2019s DLL",
      "trigger": "Run Qualify.ps1 -Build -Test -VerifyContracts -Configuration Debug."
    },
    {
      "acceptance_ids": [
        "\u00a75",
        "\u00a76"
      ],
      "actual": "The new Get-GitMetadata call reaches Common.ps1 line 75, where .Trim() is called on the output of git branch --show-current. I evaluated that expression in the detached snapshot and it raised InvokeMethodOnNull.",
      "blocking_rationale": "The documented production build wrapper now stops before MSBuild for a valid checkout of an exact commit.",
      "blocks_readiness": true,
      "category": "defect",
      "expected": "A detached commit should yield a usable source SHA and dirty state even when it has no branch name.",
      "id": "R1-F7",
      "location": {
        "file": "scripts/Build-Local.ps1",
        "line": 9
      },
      "priority": "P2",
      "requested_correction": "Handle empty branch output in Get-GitMetadata while retaining the exact commit and dirty-state checks.",
      "requested_evidence": "Show that the build receipt records the correct SHA from a clean detached checkout and that ordinary branch builds still pass.",
      "title": "Allow the production wrapper to build a detached commit",
      "trigger": "Invoke Build-Local.ps1 in a detached worktree with valid game paths and reference files."
    },
    {
      "acceptance_ids": [
        "\u00a76",
        "\u00a77"
      ],
      "actual": "The suite always expects a copy of the installed UMM to fail its hash check. It also constructs a supposedly mismatched receipt using the installed UMM hash at line 203. On a genuine 0.31.1 installation the copied bytes are valid and the receipt edit changes nothing, so both cases falsely fail.",
      "blocking_rationale": "The documented regression suite cannot pass in the required baseline environment.",
      "blocks_readiness": true,
      "category": "defect",
      "expected": "Negative controls should use a known different reference. Genuine baseline bytes should pass regardless of the installed loader version.",
      "id": "R1-F8",
      "location": {
        "file": "scripts/Test-LoaderBaseline.ps1",
        "line": 105
      },
      "priority": "P2",
      "requested_correction": "Use a verified, distinct loader fixture for the wrong-bytes and wrong-receipt cases. Determine the expected result for a copy of the installed loader from its measured identity.",
      "requested_evidence": "Demonstrate the suite with a genuine 0.31.1 profile and a newer profile using disposable configuration, with the live installation preserved.",
      "title": "Remove the regression suite\u2019s assumption that installed UMM is newer",
      "trigger": "Run Test-LoaderBaseline.ps1 with UnityModManagerDir pointing to the genuine baseline."
    },
    {
      "acceptance_ids": [
        "\u00a75",
        "\u00a76"
      ],
      "actual": "Both compiler-reference regexes exclude spaces inside a quoted path. A read-only check of the UMM regex against a quoted path under a directory named Preserver Build returned zero matches.",
      "blocking_rationale": "The required direct-compiler check reports a failure for a valid Windows checkout path.",
      "blocks_readiness": true,
      "category": "defect",
      "expected": "Compiler evidence should recognize quoted and unquoted paths and compare each complete path to its pin.",
      "id": "R1-F9",
      "location": {
        "file": "scripts/Test-LoaderBaseline.ps1",
        "line": 116
      },
      "priority": "P2",
      "requested_correction": "Parse whole quoted reference arguments or consume structured compiler inputs. Retain the exact path and count assertions.",
      "requested_evidence": "Run the direct compiler-input check from a worktree with a space in its path and show the two resolved filenames.",
      "title": "Handle quoted compiler reference paths",
      "trigger": "The repository\u2019s artifacts/references directory is under a Windows path containing a space."
    },
    {
      "acceptance_ids": [
        "\u00a75",
        "\u00a76",
        "\u00a78"
      ],
      "actual": "The supplied gate command and full log cover build, deterministic tests, and contracts. They contain no Test-LoaderBaseline execution, standalone validator output, packaged AssemblyRef observation, or legacy rejection. The referenced external results are absent from the review inputs.",
      "blocking_rationale": "The required archive and failure-boundary observations cannot be independently confirmed from a passing build or the test source.",
      "blocks_readiness": true,
      "category": "evidence_gap",
      "expected": "Reviewer-visible execution evidence should establish the correct package passing and the genuine 0.33.0-compiled v0.1.3 DLL with its lowered manifest failing before installation.",
      "id": "R1-F10",
      "location": {
        "file": "docs/UMM-COMPATIBILITY.md",
        "line": 79
      },
      "priority": "P1",
      "requested_correction": "Provide scoped machine-produced output for the package and regression runs through the permitted evidence route. Align documentation and the developer report with the artifact that those runs identify.",
      "requested_evidence": "Include the source SHA, build and archived DLL hashes, MVID, observed AssemblyRefs, ZIP hash, verified legacy asset identity, standalone acceptance and rejection reasons, and outcomes of the cache, direct-build, receipt, and dependency cases.",
      "title": "Supply execution evidence for the package and legacy regression",
      "trigger": "Assess the reported 23/23 result and candidate package hash for the final checkpoint."
    },
    {
      "acceptance_ids": [
        "\u00a77",
        "\u00a78"
      ],
      "actual": "The document reports nine types and 25 members resolving on four profiles. The reproduction commands omit the audit. Its tool and result are referenced only outside the snapshot, and the gate log contains no per-profile API audit output.",
      "blocking_rationale": "The required static compatibility assessment lacks reproducible instructions and execution evidence tied to the frozen DLL.",
      "blocks_readiness": true,
      "category": "evidence_gap",
      "expected": "A reviewer should be able to identify the audit procedure and confirm the exact candidate, profile provenance, components, and observed result for each row.",
      "id": "R1-F11",
      "location": {
        "file": "docs/UMM-COMPATIBILITY.md",
        "line": 91
      },
      "priority": "P1",
      "requested_correction": "Document a reproducible audit invocation and accessible tool or method. Supply scoped machine-produced results and the official distribution evidence used to select the newest stable row.",
      "requested_evidence": "For 0.31.1, 0.32.4, owner-installed 0.33.0, and the selected newest stable version, show the same candidate DLL digest, exact UMM/Harmony component identities and provenance, and resolved or failed API counts.",
      "title": "Make the four-loader static API assessment reproducible",
      "trigger": "Verify the compatibility table against the evidence supplied for this candidate."
    }
  ],
  "prior_finding_assessments": [],
  "request_id": "klap-umm0311-codex-umm-0311-baseline-20261123-20261123162452-aa01-r01-5c7004",
  "round": 1,
  "schema_version": "agent-review.review.v1",
  "summary": {
    "delivered_behavior": "The shipping manifest declares UMM 0.31.1. The normal Release build uses the pinned reference cache, and the standalone validator inspects the packaged DLL\u2019s loader references. The controller confirmed compilation, deterministic tests, and managed contracts on the installed 0.33.0 environment.",
    "pending_later_phase_work": [],
    "remaining_owner_review": [
      "Any future authorization and observation of the disposable Last Azlanti defeat, preservation, recovery, and manual-deletion controls on identified loader profiles."
    ],
    "scope_reviewed": "Draft PR #7 for KingmakerLastAzlantiPreserver, from a2e2af2 to aeef5c8, including the affected build, package, qualification, and compatibility evidence paths.",
    "unresolved_questions": [
      "Which ZIP hash is backed by a matching archive-validation run for the reviewed source?"
    ]
  }
}
```
</details>

_Model-generated review by Codex using the requested model, posted by the agent-review controller through the owner's GitHub account. Not a human review or approval._
