<!-- agent-review:v1 enrollment=klap-umm0311-codex-umm-0311-baseline-20261123-20261123162452-aa01 key=r03-review part=1/1 sha256=4e72ee7ad78869d2f2b8151a7bf4bf8b55a8df3ff765188ca79829a4bad15d87 -->
### Codex GPT-6.2 Astra — review — round 3 — candidate `ad074787ff`

**Decision:** `changes_required` — The candidate passed the configured gate, and the package records establish both the 0.31.1 compilation and rejection of the genuine 0.33.0 release DLL. Changes are required because qualification can still credit a different build or loader check, and the standalone validator can overwrite its caller’s ZIP.

## Continuation for Claude

Keep the correction within Preserver’s build, package and verification tooling. Derive build identity from the effective compiler inputs independently of the installed loader. Credit cached packages and contracts only when their producing inputs and verification records match. Make a requested qualification stage fail when its final evidence is inconsistent.

Move ZIP replacement into the disposable test harness, validate directory entries by their decoded contents, and use two known-distinct loader profiles for the profile-change control. Check the Harmony assembly actually used when a PowerShell host is reused. Preserve the product identity, gameplay code and historical evidence.

Run the focused cases in the findings and the controller’s qualify gate on the corrected commit. Supply the resulting DLL, ZIP and profile identities. The native rows can retain their documented NOT RUN disposition under the existing disposable-campaign policy.

#### Findings

**R1-F1** · P1 · defect · blocks readiness — Include effective imported compiler settings in the build receipt
- Location: `scripts/Common.ps1:215`; acceptance: §5, §6
- Trigger: Change a compiler property in the already-imported GamePath.props after building, then package the existing DLL.
- Expected: A compiler-affecting imported setting must invalidate the producing receipt.
- Actual: The fingerprint now covers the wrapper and four Managed DLLs. It reads literal HintPath entries and omits other effective settings in the imported GamePath.props. Changing CheckForOverflowUnderflow in that file changes the compiler option for this project while leaving every fingerprint input unchanged.
- Why it blocks / does not: Package.ps1 can accept a DLL produced with different compiler settings from those selected for the current source.
- Requested correction: Include the effective compile-relevant imported settings and selected references in the build fingerprint. Keep runtime-only profile selection independent.
- Requested evidence: In a temporary checkout, change a compiler-affecting property in GamePath.props. Show refusal of the old receipt and acceptance after rebuilding with that property.

**R1-F2** · P1 · defect · blocks readiness — Bind cached package credit to the producing build and validation
- Location: `scripts/Qualify.ps1:87`; acceptance: §5, §6, §8
- Trigger: Rebuild identical DLL bytes after a build-helper change, or change the package validator, then qualify without packaging.
- Expected: Current package credit must identify the producing build, packaged files and applicable validation.
- Actual: Qualify compares DLL, ZIP and document digests but ignores package.json’s build_inputs_sha256. Its predicate returned true with the supplied 5a42c827 and 7e0f66cf producing and current fingerprints. A validator-only change also leaves every compared key intact. Package.ps1 calculates the document digest before copying the files, so a concurrent edit can make that digest describe different bytes from the archive.
- Why it blocks / does not: A cached pass can be attributed to a different producing build or to validation rules that have never inspected the ZIP.
- Requested correction: Compare the package’s producing fingerprint with the current build receipt and fingerprint the files actually staged or archived. Revalidate a retained ZIP when its validation rules change, or report the package stage as unrun.
- Requested evidence: Start with a matching Release receipt. Exercise a changed build input that reproduces the DLL, a changed packaging rule, and a document change during staging. Show the matching package control still receives credit.

**R2-F3** · P2 · defect · blocks readiness — Exclude pre-fix and mixed-profile contract receipts
- Location: `scripts/Qualify.ps1:74`; acceptance: §7, §8
- Trigger: Retain records from fd9f30f across a rebuild of the same DLL, or retain the first report from an incomplete profile switch.
- Expected: Both contract results must establish the actual candidate and selected profile before qualification reuses them.
- Actual: The immediately preceding fd9f30f verifier wrote all seven hashes the reuse predicate reads, including a DLL hash from the requested filename. It lacked loaded_location and loaded_mvid. The predicate accepted that receipt shape in a read-only check. The core report also carries no loader identity and is written before the UI verifier completes, allowing a core report from one profile to be paired with an older UI report from another.
- Why it blocks / does not: A historical check affected by the known assembly-binding defect, or a pair of reports from different profiles, can still receive current ownership credit.
- Requested correction: Require records from the binding-aware verifiers and bind both reports to the same completed check and profile. Reporting cached contracts as unrun is also sufficient.
- Requested evidence: Use the actual fd9f30f receipt shape and a mixed pair left by a second incomplete profile run. Both should yield a usable summary without current contract credit. A fresh matching pair should pass.

**R3-F1** · P2 · defect · blocks readiness — Remove the caller-ZIP overwrite from the standalone validator
- Location: `scripts/Validate-Package.ps1:23`; acceptance: §5, §6
- Trigger: Validate a supplied ZIP with KLAP_VALIDATE_TEST_REPLACE_INPUT_AFTER_COPY present in the environment.
- Expected: Validation may write its private copy and report. The caller retains control of the source ZIP.
- Actual: The production validator copies an environment-selected file over PackagePath with overwrite enabled before inspecting its private copy. The committed regression confirms that the caller’s path ends with a different ZIP digest. Install.ps1 invokes this code before its ShouldProcess check.
- Why it blocks / does not: A standalone validation or installation preview can destroy the supplied archive and print a pass for bytes that no longer occupy that path.
- Requested correction: Remove the input-overwrite hook from the production validator. Have the disposable test harness perform the external replacement and keep private-copy creation inside the cleanup scope.
- Requested evidence: Show that standalone validation and the installation preview preserve the supplied ZIP, while a replacement performed by the harness still yields a report for one consistent snapshot.

**R3-F2** · P2 · defect · blocks readiness — Decouple build fingerprinting from installed-loader admission
- Location: `scripts/Common.ps1:215`; acceptance: §5, §6
- Trigger: Build or package with a valid Kingmaker Managed directory and pinned cache before configuring a compatibility-test loader.
- Expected: The pinned production build and packaging paths should work with the required compile inputs. Managed compatibility checks should validate their selected runtime.
- Actual: Get-BuildInputFingerprint calls Get-KingmakerConfiguration, which unconditionally requires installed UnityModManager.dll and 0Harmony12.dll. Build-Local.ps1 and Package.ps1 now fail there even when all game assemblies and pinned compile references are available.
- Why it blocks / does not: The wrapper and package path acquired a runtime-installation prerequisite during the fingerprint correction.
- Requested correction: Resolve the game compile inputs for fingerprinting without requiring the runtime loader files. Retain the runtime checks at their consumers.
- Requested evidence: Use a disposable configuration with genuine Managed references and pins and an absent runtime-loader directory. Show Build-Local and Package succeeding and the managed contract check reporting its missing prerequisite.

**R3-F3** · P1 · defect · blocks readiness — Make qualification success depend on the requested stages
- Location: `scripts/Qualify.ps1:106`; acceptance: §4, §6, §8
- Trigger: The product DLL changes between the wrapper build and final receipt comparison, or a build-only qualification retains an earlier test report.
- Expected: A requested qualification stage must produce current evidence for the selected candidate. A skipped stage may be reported as unrun.
- Actual: Qualify catches a failed receipt check, clears build credit, then unconditionally writes non-runtime-qualification-passed and exits successfully. Test.ps1 rebuilds the product after Build-Local creates the receipt, so a different second output can reach this path during the configured gate. On a build-only invocation, lines 128–129 also report any retained tests.json as the current result without a candidate identity.
- Why it blocks / does not: The controller can receive success after a requested stage loses its candidate binding, and a partial summary can report tests passed on a previous DLL.
- Requested correction: Derive final status and exit behavior from the requested stages’ current results. Credit skipped tests only with matching evidence, or report them as unrun.
- Requested evidence: In a disposable checkout, make the test-project rebuild produce a different valid DLL and show the full qualification returning failure. Show that a build-only run after a source change does not inherit a previous test pass.

**R3-F4** · P2 · defect · blocks readiness — Bind managed ownership evidence to the Harmony2 module used
- Location: `scripts/Verify-GameOverLoadContracts.ps1:145`; acceptance: §7
- Trigger: Run direct contract verification twice in one Windows PowerShell host with the same product DLL and different admitted Harmony2 profiles.
- Expected: The Harmony2 identity recorded for a managed patch operation must correspond to the assembly used in that process.
- Actual: The verifier hashes the selected 0Harmony.dll on disk. It checks the loaded product DLL, but never checks which Harmony2 module the loaded Harmony12 adapter used. All four profiles share the same adapter identity. In a reused host that adapter can retain its first Harmony2 binding while the report names the newly selected file.
- Why it blocks / does not: A managed contract result can attribute patch ownership to a Harmony2 version that did not perform the check.
- Requested correction: Isolate each supported verifier invocation in a fresh process, or verify and record the actually bound Harmony modules before crediting ownership.
- Requested evidence: Use the same product DLL with 0.31.1 and 0.33.4 successively from one host. Show the actual Harmony2 module identities for each result or an explicit binding-mismatch refusal.

**R3-F5** · P2 · defect · blocks readiness — Accept valid compressed representations of empty ZIP directories
- Location: `scripts/Validate-Package.ps1:38`; acceptance: §5, §6
- Trigger: A standalone ZIP includes an allowed empty directory encoded as a five-byte DEFLATE stream.
- Expected: An allowed directory entry with zero decoded bytes should be accepted independently of its valid compression encoding.
- Actual: The validator rejects an allowed directory whenever CompressedLength exceeds two. A level-zero DEFLATE stream for an empty input is five bytes and decodes to zero bytes, as confirmed in memory.
- Why it blocks / does not: A valid supplied package containing the six required files can be rejected before installation solely because of its ZIP writer’s compression choice.
- Requested correction: Check the allowed folder name and decoded emptiness. Remove the two-byte compressed-size assumption.
- Requested evidence: Accept a genuine candidate ZIP with an explicit empty licenses directory encoded with level-zero DEFLATE. Retain refusal of foreign and data-bearing directory entries.

**R3-F6** · P2 · defect · blocks readiness — Make the profile-change test independent of the initial loader
- Location: `scripts/Test-LoaderBaseline.ps1:505`; acceptance: §6, §7
- Trigger: Start Test-LoaderBaseline.ps1 with UnityModManagerDir already pointing to a genuine complete 0.31.1 profile.
- Expected: The profile-switch negative control must select different component identities. Identical profiles should give the same result regardless of directory.
- Actual: The new case verifies contracts under the initially configured profile, switches to a disposable 0.31.1 directory and always expects contracts_current_for_candidate to be false. If the initial profile is already genuine 0.31.1, all three loader hashes match and the correct reuse result makes the test fail.
- Why it blocks / does not: The documented boundary suite cannot pass in a supported baseline configuration.
- Requested correction: Use known-distinct disposable profiles for the negative case and a byte-identical copy for the positive case.
- Requested evidence: Run the complete boundary suite with the initial configuration pointed at the disposable baseline. Show both profile controls passing.

**R3-F7** · P3 · optional_polish · non-blocking — Clarify which bytes the evidence index hashes
- Location: `docs/evidence/umm-0311/INDEX.md:6`; acceptance: §8
- Trigger: Hash the two checked-out auditor source exports using the repository’s Windows line-ending settings.
- Expected: Readers should be able to reproduce the indexed digests using the documented byte representation.
- Actual: Both auditor .txt files check out with CRLF. Their working-file hashes differ from INDEX.md, while their LF Git blobs match the index exactly.
- Why it blocks / does not: All 15 committed evidence blobs verify. This affects the convenience of checking two exports on Windows.
- Requested correction: Identify the exported fingerprints as Git-blob byte hashes or prescribe LF checkout for the two auditor source exports.
- Requested evidence: The documented verification method should reproduce both source-export digests on Windows.

#### Prior finding assessments

- **R1-F1** — `fix_rejected` — Wrapper changes and changes to the four Managed DLLs now invalidate reuse. Other compiler settings in the imported GamePath.props still escape the fingerprint.
- **R1-F10** — `fix_verified` — The committed boundary and package records identify the source, archived DLL, MVID, AssemblyRefs, ZIP, genuine older release and standalone outcomes. The gate at H corroborates the candidate DLL digest.
- **R1-F11** — `fix_verified` — The auditor source, SDK project and CLI usage are available. The static results, managed results, component inventory and author-distribution selection record identify the frozen DLL, all four profiles and the mismatched-stack refusal.
- **R1-F2** — `fix_rejected` — The selected DLL and ordinary README changes are now checked. The cached-package predicate still accepts a different producing-build fingerprint and does not establish that the current validator approved the ZIP.
- **R1-F3** — `fix_verified` — The guard checks ReferencePathWithRefAssemblies after reference-assembly selection. The recorded substitution was refused, and the successful direct build recorded both canonical paths on the Csc command line.
- **R2-F1** — `fix_verified` — The validator now inspects and hashes the same private ZIP. The replacement case records the original ZIP and its matching DLL. R3-F1 covers the separate mutation of the caller’s file.
- **R2-F2** — `fix_verified` — Directory records are checked before the file count. The suite records refusal of nonempty entries for both the package’s own folder and a foreign folder. R3-F5 covers a new false rejection of valid empty directories.
- **R2-F3** — `fix_rejected` — The aeef5c8-style missing fields and a simple whole-profile switch are handled. Records from the immediately preceding verifier still earn credit without a loaded-module observation, and the core result cannot identify its own loader profile.
- **R2-F4** — `fix_verified` — Both verifiers check the loaded product assembly’s path and MVID. The recorded one-host Release-then-Debug case explicitly refused the second binding and identified both MVIDs.
- **R2-F5** — `fix_verified` — Each comparison child receives the private frozen DLL, and its reported digest is checked before credit. The recorded replacement of the original build output left both comparison rows on the frozen digest.

#### Evidence assessment

- **Inspected:** The enrolled mission, AGENTS.md, full feature diff, correction delta from fd9f30f, developer report, transcript notice, controller receipt and prior findings ledger.; The production project and MSBuild targets, reference acquisition, build and package receipts, standalone validator, install preflight, qualification scripts, both contract verifiers and their test harnesses.; The compatibility and smoke-test documentation, audit tool source, profile inventories, newest-stable selection and committed build, package, test and contract records.
- **Executed verification:** The controller receipt on ad074787 records exit 0 for Qualify.ps1 -Build -Test -VerifyContracts, zero compiler warnings and errors, 84 passing tests and managed patch ownership on the owner’s 0.33.0 profile. The gate reported an existing package result and did not invoke -Package.; Committed machine outputs on 67a09d2 record 85/85 boundary cases, standalone acceptance of ZIP 83611dd565b69ac399b010fd57cc7f65e948fb7ece22417b8f82c19b65700adc, and rejection of the genuine v0.1.3 DLL after lowering only its packaged manifest. The final commit changed documentation and evidence only.; The static audit records 9 type references and 25 member references resolved on all four profiles. Separate managed results record four successful fresh-process checks on the frozen DLL and refusal of the mismatched Harmony2 control.; I verified HEAD, the mission digest, all 15 indexed evidence hashes against their Git blobs, and the five-file package-input digest against the candidate checkout. git diff --check passed.; I evaluated the qualification predicates in memory using the supplied records. Contract reuse returned true with the fd9f30f receipt fields, and package reuse returned true with different producing and current build-input fingerprints. A separate in-memory DEFLATE check produced five compressed bytes that decoded to zero bytes.
- **Source inspection only:** I traced the build wrapper’s installed-loader prerequisite, the production ZIP replacement hook, the contract report write order, the same-host Harmony binding path and the baseline-profile test assumption from source.; Install.ps1 and its WhatIf entry point were inspected. The committed suite exercised private-copy extraction in a disposable directory.
- **Required gaps:** Build and package provenance must cover effective compile settings, the producing receipt and the contents actually packaged.; Contract reuse and qualification status must distinguish current, historical and failed stages, including across loader changes in one host.; Standalone validation must preserve caller files and accept valid empty directory encodings. The profile-change regression must work when the initially configured loader is already 0.31.1.
- **Limitations:** The foreground developer transcript was withheld. The candidate-bound controller receipt and the separately committed machine outputs have distinct provenance. I did not rerun builds, installation, network requests or game workflows in the read-only snapshot.; Native preservation, recovery, reload and deletion controls were NOT RUN on 0.31.1, 0.32.4, owner 0.33.0 and 0.33.4. The repository documents the missing approved disposable setup. No combined-stack run was claimed.

#### Summary

- **Delivered behavior:** Info.json declares UMM 0.31.1. The verified Release DLL fadf2dab6ff3b8a92c81a3515b633f0de7482879ac5ca43a79ca9ac7c0031248 references UnityModManager 0.31.1.0 and Harmony12 1.2.0.1. Standalone validation accepted the baseline archive and rejected the manifest-lowered legacy release. Native compatibility remains unqualified on every loader.
- **Scope reviewed:** The complete Preserver mission for draft PR #7 at ad074787, including all ten pending findings, the correction delta since fd9f30f and its directly affected build, package and qualification paths.
- **Pending later-phase work:** none
- **Unresolved questions:** none
- **Remaining owner review:** Whether to authorize a disposable Last Azlanti campaign for native defeat, preservation, recovery, reload and deletion controls before making a runtime support claim.; Disposition of draft PR #7 after the blocking findings are resolved.

#### Provenance (controller-recorded)

| | Requested | Observed |
|---|---|---|
| Model | `gpt-6.2-astra` | `gpt-6.2-astra` (turns ['gpt-6.2-astra']) |
| Reasoning effort | `max` | `max` (turns ['max']) |
| Sandbox / approvals | read-only / never | `read-only` / `never` |

Owner guidance bound to this review: none.

Owner amendments bound to this review: none.

Codex CLI `0.170.0`, thread `01a20a9c-5a49-7f62-aba9-a16ab8598e38`, duration 767.3s, response sha256 `43d9cd4be286ad41aa732cec43b391a703ef0e9589be101a8de2d2c66bb27e96`, request `klap-umm0311-codex-umm-0311-baseline-20261123-20261123162452-aa01-r03-bde49c`. Observed values come from the Codex session rollout's recorded thread settings, not from the model's own statements; the serving backend's model identity is not separately exposed.

<details><summary>Complete structured review (agent-review.review.v1)</summary>

```json
{
  "candidate_commit": "ad074787ff28cbbd4b87d72f60dea8b124068c40",
  "checkpoint_id": "final",
  "checkpoint_type": "final",
  "decision": "changes_required",
  "decision_rationale": "The candidate passed the configured gate, and the package records establish both the 0.31.1 compilation and rejection of the genuine 0.33.0 release DLL. Changes are required because qualification can still credit a different build or loader check, and the standalone validator can overwrite its caller\u2019s ZIP.\n\n## Continuation for Claude\n\nKeep the correction within Preserver\u2019s build, package and verification tooling. Derive build identity from the effective compiler inputs independently of the installed loader. Credit cached packages and contracts only when their producing inputs and verification records match. Make a requested qualification stage fail when its final evidence is inconsistent.\n\nMove ZIP replacement into the disposable test harness, validate directory entries by their decoded contents, and use two known-distinct loader profiles for the profile-change control. Check the Harmony assembly actually used when a PowerShell host is reused. Preserve the product identity, gameplay code and historical evidence.\n\nRun the focused cases in the findings and the controller\u2019s qualify gate on the corrected commit. Supply the resulting DLL, ZIP and profile identities. The native rows can retain their documented NOT RUN disposition under the existing disposable-campaign policy.",
  "evidence_assessment": {
    "executed_verification": [
      "The controller receipt on ad074787 records exit 0 for Qualify.ps1 -Build -Test -VerifyContracts, zero compiler warnings and errors, 84 passing tests and managed patch ownership on the owner\u2019s 0.33.0 profile. The gate reported an existing package result and did not invoke -Package.",
      "Committed machine outputs on 67a09d2 record 85/85 boundary cases, standalone acceptance of ZIP 83611dd565b69ac399b010fd57cc7f65e948fb7ece22417b8f82c19b65700adc, and rejection of the genuine v0.1.3 DLL after lowering only its packaged manifest. The final commit changed documentation and evidence only.",
      "The static audit records 9 type references and 25 member references resolved on all four profiles. Separate managed results record four successful fresh-process checks on the frozen DLL and refusal of the mismatched Harmony2 control.",
      "I verified HEAD, the mission digest, all 15 indexed evidence hashes against their Git blobs, and the five-file package-input digest against the candidate checkout. git diff --check passed.",
      "I evaluated the qualification predicates in memory using the supplied records. Contract reuse returned true with the fd9f30f receipt fields, and package reuse returned true with different producing and current build-input fingerprints. A separate in-memory DEFLATE check produced five compressed bytes that decoded to zero bytes."
    ],
    "inspected": [
      "The enrolled mission, AGENTS.md, full feature diff, correction delta from fd9f30f, developer report, transcript notice, controller receipt and prior findings ledger.",
      "The production project and MSBuild targets, reference acquisition, build and package receipts, standalone validator, install preflight, qualification scripts, both contract verifiers and their test harnesses.",
      "The compatibility and smoke-test documentation, audit tool source, profile inventories, newest-stable selection and committed build, package, test and contract records."
    ],
    "limitations": [
      "The foreground developer transcript was withheld. The candidate-bound controller receipt and the separately committed machine outputs have distinct provenance. I did not rerun builds, installation, network requests or game workflows in the read-only snapshot.",
      "Native preservation, recovery, reload and deletion controls were NOT RUN on 0.31.1, 0.32.4, owner 0.33.0 and 0.33.4. The repository documents the missing approved disposable setup. No combined-stack run was claimed."
    ],
    "required_gaps": [
      "Build and package provenance must cover effective compile settings, the producing receipt and the contents actually packaged.",
      "Contract reuse and qualification status must distinguish current, historical and failed stages, including across loader changes in one host.",
      "Standalone validation must preserve caller files and accept valid empty directory encodings. The profile-change regression must work when the initially configured loader is already 0.31.1."
    ],
    "source_inspection_only": [
      "I traced the build wrapper\u2019s installed-loader prerequisite, the production ZIP replacement hook, the contract report write order, the same-host Harmony binding path and the baseline-profile test assumption from source.",
      "Install.ps1 and its WhatIf entry point were inspected. The committed suite exercised private-copy extraction in a disposable directory."
    ]
  },
  "findings": [
    {
      "acceptance_ids": [
        "\u00a75",
        "\u00a76"
      ],
      "actual": "The fingerprint now covers the wrapper and four Managed DLLs. It reads literal HintPath entries and omits other effective settings in the imported GamePath.props. Changing CheckForOverflowUnderflow in that file changes the compiler option for this project while leaving every fingerprint input unchanged.",
      "blocking_rationale": "Package.ps1 can accept a DLL produced with different compiler settings from those selected for the current source.",
      "blocks_readiness": true,
      "category": "defect",
      "expected": "A compiler-affecting imported setting must invalidate the producing receipt.",
      "id": "R1-F1",
      "location": {
        "file": "scripts/Common.ps1",
        "line": 215
      },
      "priority": "P1",
      "requested_correction": "Include the effective compile-relevant imported settings and selected references in the build fingerprint. Keep runtime-only profile selection independent.",
      "requested_evidence": "In a temporary checkout, change a compiler-affecting property in GamePath.props. Show refusal of the old receipt and acceptance after rebuilding with that property.",
      "title": "Include effective imported compiler settings in the build receipt",
      "trigger": "Change a compiler property in the already-imported GamePath.props after building, then package the existing DLL."
    },
    {
      "acceptance_ids": [
        "\u00a75",
        "\u00a76",
        "\u00a78"
      ],
      "actual": "Qualify compares DLL, ZIP and document digests but ignores package.json\u2019s build_inputs_sha256. Its predicate returned true with the supplied 5a42c827 and 7e0f66cf producing and current fingerprints. A validator-only change also leaves every compared key intact. Package.ps1 calculates the document digest before copying the files, so a concurrent edit can make that digest describe different bytes from the archive.",
      "blocking_rationale": "A cached pass can be attributed to a different producing build or to validation rules that have never inspected the ZIP.",
      "blocks_readiness": true,
      "category": "defect",
      "expected": "Current package credit must identify the producing build, packaged files and applicable validation.",
      "id": "R1-F2",
      "location": {
        "file": "scripts/Qualify.ps1",
        "line": 87
      },
      "priority": "P1",
      "requested_correction": "Compare the package\u2019s producing fingerprint with the current build receipt and fingerprint the files actually staged or archived. Revalidate a retained ZIP when its validation rules change, or report the package stage as unrun.",
      "requested_evidence": "Start with a matching Release receipt. Exercise a changed build input that reproduces the DLL, a changed packaging rule, and a document change during staging. Show the matching package control still receives credit.",
      "title": "Bind cached package credit to the producing build and validation",
      "trigger": "Rebuild identical DLL bytes after a build-helper change, or change the package validator, then qualify without packaging."
    },
    {
      "acceptance_ids": [
        "\u00a77",
        "\u00a78"
      ],
      "actual": "The immediately preceding fd9f30f verifier wrote all seven hashes the reuse predicate reads, including a DLL hash from the requested filename. It lacked loaded_location and loaded_mvid. The predicate accepted that receipt shape in a read-only check. The core report also carries no loader identity and is written before the UI verifier completes, allowing a core report from one profile to be paired with an older UI report from another.",
      "blocking_rationale": "A historical check affected by the known assembly-binding defect, or a pair of reports from different profiles, can still receive current ownership credit.",
      "blocks_readiness": true,
      "category": "defect",
      "expected": "Both contract results must establish the actual candidate and selected profile before qualification reuses them.",
      "id": "R2-F3",
      "location": {
        "file": "scripts/Qualify.ps1",
        "line": 74
      },
      "priority": "P2",
      "requested_correction": "Require records from the binding-aware verifiers and bind both reports to the same completed check and profile. Reporting cached contracts as unrun is also sufficient.",
      "requested_evidence": "Use the actual fd9f30f receipt shape and a mixed pair left by a second incomplete profile run. Both should yield a usable summary without current contract credit. A fresh matching pair should pass.",
      "title": "Exclude pre-fix and mixed-profile contract receipts",
      "trigger": "Retain records from fd9f30f across a rebuild of the same DLL, or retain the first report from an incomplete profile switch."
    },
    {
      "acceptance_ids": [
        "\u00a75",
        "\u00a76"
      ],
      "actual": "The production validator copies an environment-selected file over PackagePath with overwrite enabled before inspecting its private copy. The committed regression confirms that the caller\u2019s path ends with a different ZIP digest. Install.ps1 invokes this code before its ShouldProcess check.",
      "blocking_rationale": "A standalone validation or installation preview can destroy the supplied archive and print a pass for bytes that no longer occupy that path.",
      "blocks_readiness": true,
      "category": "defect",
      "expected": "Validation may write its private copy and report. The caller retains control of the source ZIP.",
      "id": "R3-F1",
      "location": {
        "file": "scripts/Validate-Package.ps1",
        "line": 23
      },
      "priority": "P2",
      "requested_correction": "Remove the input-overwrite hook from the production validator. Have the disposable test harness perform the external replacement and keep private-copy creation inside the cleanup scope.",
      "requested_evidence": "Show that standalone validation and the installation preview preserve the supplied ZIP, while a replacement performed by the harness still yields a report for one consistent snapshot.",
      "title": "Remove the caller-ZIP overwrite from the standalone validator",
      "trigger": "Validate a supplied ZIP with KLAP_VALIDATE_TEST_REPLACE_INPUT_AFTER_COPY present in the environment."
    },
    {
      "acceptance_ids": [
        "\u00a75",
        "\u00a76"
      ],
      "actual": "Get-BuildInputFingerprint calls Get-KingmakerConfiguration, which unconditionally requires installed UnityModManager.dll and 0Harmony12.dll. Build-Local.ps1 and Package.ps1 now fail there even when all game assemblies and pinned compile references are available.",
      "blocking_rationale": "The wrapper and package path acquired a runtime-installation prerequisite during the fingerprint correction.",
      "blocks_readiness": true,
      "category": "defect",
      "expected": "The pinned production build and packaging paths should work with the required compile inputs. Managed compatibility checks should validate their selected runtime.",
      "id": "R3-F2",
      "location": {
        "file": "scripts/Common.ps1",
        "line": 215
      },
      "priority": "P2",
      "requested_correction": "Resolve the game compile inputs for fingerprinting without requiring the runtime loader files. Retain the runtime checks at their consumers.",
      "requested_evidence": "Use a disposable configuration with genuine Managed references and pins and an absent runtime-loader directory. Show Build-Local and Package succeeding and the managed contract check reporting its missing prerequisite.",
      "title": "Decouple build fingerprinting from installed-loader admission",
      "trigger": "Build or package with a valid Kingmaker Managed directory and pinned cache before configuring a compatibility-test loader."
    },
    {
      "acceptance_ids": [
        "\u00a74",
        "\u00a76",
        "\u00a78"
      ],
      "actual": "Qualify catches a failed receipt check, clears build credit, then unconditionally writes non-runtime-qualification-passed and exits successfully. Test.ps1 rebuilds the product after Build-Local creates the receipt, so a different second output can reach this path during the configured gate. On a build-only invocation, lines 128\u2013129 also report any retained tests.json as the current result without a candidate identity.",
      "blocking_rationale": "The controller can receive success after a requested stage loses its candidate binding, and a partial summary can report tests passed on a previous DLL.",
      "blocks_readiness": true,
      "category": "defect",
      "expected": "A requested qualification stage must produce current evidence for the selected candidate. A skipped stage may be reported as unrun.",
      "id": "R3-F3",
      "location": {
        "file": "scripts/Qualify.ps1",
        "line": 106
      },
      "priority": "P1",
      "requested_correction": "Derive final status and exit behavior from the requested stages\u2019 current results. Credit skipped tests only with matching evidence, or report them as unrun.",
      "requested_evidence": "In a disposable checkout, make the test-project rebuild produce a different valid DLL and show the full qualification returning failure. Show that a build-only run after a source change does not inherit a previous test pass.",
      "title": "Make qualification success depend on the requested stages",
      "trigger": "The product DLL changes between the wrapper build and final receipt comparison, or a build-only qualification retains an earlier test report."
    },
    {
      "acceptance_ids": [
        "\u00a77"
      ],
      "actual": "The verifier hashes the selected 0Harmony.dll on disk. It checks the loaded product DLL, but never checks which Harmony2 module the loaded Harmony12 adapter used. All four profiles share the same adapter identity. In a reused host that adapter can retain its first Harmony2 binding while the report names the newly selected file.",
      "blocking_rationale": "A managed contract result can attribute patch ownership to a Harmony2 version that did not perform the check.",
      "blocks_readiness": true,
      "category": "defect",
      "expected": "The Harmony2 identity recorded for a managed patch operation must correspond to the assembly used in that process.",
      "id": "R3-F4",
      "location": {
        "file": "scripts/Verify-GameOverLoadContracts.ps1",
        "line": 145
      },
      "priority": "P2",
      "requested_correction": "Isolate each supported verifier invocation in a fresh process, or verify and record the actually bound Harmony modules before crediting ownership.",
      "requested_evidence": "Use the same product DLL with 0.31.1 and 0.33.4 successively from one host. Show the actual Harmony2 module identities for each result or an explicit binding-mismatch refusal.",
      "title": "Bind managed ownership evidence to the Harmony2 module used",
      "trigger": "Run direct contract verification twice in one Windows PowerShell host with the same product DLL and different admitted Harmony2 profiles."
    },
    {
      "acceptance_ids": [
        "\u00a75",
        "\u00a76"
      ],
      "actual": "The validator rejects an allowed directory whenever CompressedLength exceeds two. A level-zero DEFLATE stream for an empty input is five bytes and decodes to zero bytes, as confirmed in memory.",
      "blocking_rationale": "A valid supplied package containing the six required files can be rejected before installation solely because of its ZIP writer\u2019s compression choice.",
      "blocks_readiness": true,
      "category": "defect",
      "expected": "An allowed directory entry with zero decoded bytes should be accepted independently of its valid compression encoding.",
      "id": "R3-F5",
      "location": {
        "file": "scripts/Validate-Package.ps1",
        "line": 38
      },
      "priority": "P2",
      "requested_correction": "Check the allowed folder name and decoded emptiness. Remove the two-byte compressed-size assumption.",
      "requested_evidence": "Accept a genuine candidate ZIP with an explicit empty licenses directory encoded with level-zero DEFLATE. Retain refusal of foreign and data-bearing directory entries.",
      "title": "Accept valid compressed representations of empty ZIP directories",
      "trigger": "A standalone ZIP includes an allowed empty directory encoded as a five-byte DEFLATE stream."
    },
    {
      "acceptance_ids": [
        "\u00a76",
        "\u00a77"
      ],
      "actual": "The new case verifies contracts under the initially configured profile, switches to a disposable 0.31.1 directory and always expects contracts_current_for_candidate to be false. If the initial profile is already genuine 0.31.1, all three loader hashes match and the correct reuse result makes the test fail.",
      "blocking_rationale": "The documented boundary suite cannot pass in a supported baseline configuration.",
      "blocks_readiness": true,
      "category": "defect",
      "expected": "The profile-switch negative control must select different component identities. Identical profiles should give the same result regardless of directory.",
      "id": "R3-F6",
      "location": {
        "file": "scripts/Test-LoaderBaseline.ps1",
        "line": 505
      },
      "priority": "P2",
      "requested_correction": "Use known-distinct disposable profiles for the negative case and a byte-identical copy for the positive case.",
      "requested_evidence": "Run the complete boundary suite with the initial configuration pointed at the disposable baseline. Show both profile controls passing.",
      "title": "Make the profile-change test independent of the initial loader",
      "trigger": "Start Test-LoaderBaseline.ps1 with UnityModManagerDir already pointing to a genuine complete 0.31.1 profile."
    },
    {
      "acceptance_ids": [
        "\u00a78"
      ],
      "actual": "Both auditor .txt files check out with CRLF. Their working-file hashes differ from INDEX.md, while their LF Git blobs match the index exactly.",
      "blocking_rationale": "All 15 committed evidence blobs verify. This affects the convenience of checking two exports on Windows.",
      "blocks_readiness": false,
      "category": "optional_polish",
      "expected": "Readers should be able to reproduce the indexed digests using the documented byte representation.",
      "id": "R3-F7",
      "location": {
        "file": "docs/evidence/umm-0311/INDEX.md",
        "line": 6
      },
      "priority": "P3",
      "requested_correction": "Identify the exported fingerprints as Git-blob byte hashes or prescribe LF checkout for the two auditor source exports.",
      "requested_evidence": "The documented verification method should reproduce both source-export digests on Windows.",
      "title": "Clarify which bytes the evidence index hashes",
      "trigger": "Hash the two checked-out auditor source exports using the repository\u2019s Windows line-ending settings."
    }
  ],
  "prior_finding_assessments": [
    {
      "assessment": "fix_rejected",
      "finding_id": "R1-F1",
      "rationale": "Wrapper changes and changes to the four Managed DLLs now invalidate reuse. Other compiler settings in the imported GamePath.props still escape the fingerprint."
    },
    {
      "assessment": "fix_verified",
      "finding_id": "R1-F10",
      "rationale": "The committed boundary and package records identify the source, archived DLL, MVID, AssemblyRefs, ZIP, genuine older release and standalone outcomes. The gate at H corroborates the candidate DLL digest."
    },
    {
      "assessment": "fix_verified",
      "finding_id": "R1-F11",
      "rationale": "The auditor source, SDK project and CLI usage are available. The static results, managed results, component inventory and author-distribution selection record identify the frozen DLL, all four profiles and the mismatched-stack refusal."
    },
    {
      "assessment": "fix_rejected",
      "finding_id": "R1-F2",
      "rationale": "The selected DLL and ordinary README changes are now checked. The cached-package predicate still accepts a different producing-build fingerprint and does not establish that the current validator approved the ZIP."
    },
    {
      "assessment": "fix_verified",
      "finding_id": "R1-F3",
      "rationale": "The guard checks ReferencePathWithRefAssemblies after reference-assembly selection. The recorded substitution was refused, and the successful direct build recorded both canonical paths on the Csc command line."
    },
    {
      "assessment": "fix_verified",
      "finding_id": "R2-F1",
      "rationale": "The validator now inspects and hashes the same private ZIP. The replacement case records the original ZIP and its matching DLL. R3-F1 covers the separate mutation of the caller\u2019s file."
    },
    {
      "assessment": "fix_verified",
      "finding_id": "R2-F2",
      "rationale": "Directory records are checked before the file count. The suite records refusal of nonempty entries for both the package\u2019s own folder and a foreign folder. R3-F5 covers a new false rejection of valid empty directories."
    },
    {
      "assessment": "fix_rejected",
      "finding_id": "R2-F3",
      "rationale": "The aeef5c8-style missing fields and a simple whole-profile switch are handled. Records from the immediately preceding verifier still earn credit without a loaded-module observation, and the core result cannot identify its own loader profile."
    },
    {
      "assessment": "fix_verified",
      "finding_id": "R2-F4",
      "rationale": "Both verifiers check the loaded product assembly\u2019s path and MVID. The recorded one-host Release-then-Debug case explicitly refused the second binding and identified both MVIDs."
    },
    {
      "assessment": "fix_verified",
      "finding_id": "R2-F5",
      "rationale": "Each comparison child receives the private frozen DLL, and its reported digest is checked before credit. The recorded replacement of the original build output left both comparison rows on the frozen digest."
    }
  ],
  "request_id": "klap-umm0311-codex-umm-0311-baseline-20261123-20261123162452-aa01-r03-bde49c",
  "round": 3,
  "schema_version": "agent-review.review.v1",
  "summary": {
    "delivered_behavior": "Info.json declares UMM 0.31.1. The verified Release DLL fadf2dab6ff3b8a92c81a3515b633f0de7482879ac5ca43a79ca9ac7c0031248 references UnityModManager 0.31.1.0 and Harmony12 1.2.0.1. Standalone validation accepted the baseline archive and rejected the manifest-lowered legacy release. Native compatibility remains unqualified on every loader.",
    "pending_later_phase_work": [],
    "remaining_owner_review": [
      "Whether to authorize a disposable Last Azlanti campaign for native defeat, preservation, recovery, reload and deletion controls before making a runtime support claim.",
      "Disposition of draft PR #7 after the blocking findings are resolved."
    ],
    "scope_reviewed": "The complete Preserver mission for draft PR #7 at ad074787, including all ten pending findings, the correction delta since fd9f30f and its directly affected build, package and qualification paths.",
    "unresolved_questions": []
  }
}
```
</details>

_Model-generated review by Codex using the requested model, posted by the agent-review controller through the owner's GitHub account. Not a human review or approval._
