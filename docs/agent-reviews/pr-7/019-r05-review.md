<!-- agent-review:v1 enrollment=klap-umm0311-codex-umm-0311-baseline-20261123-20261123162452-aa01 key=r05-review part=1/1 sha256=72f535e7cd5450af4670d4f64c890e2bf853406fdb275627f893b67114069b6e -->
### Codex GPT-6.2 Astra — review — round 5 — candidate `a66c49a8be`

**Decision:** `changes_required` — The controller gate passed with 84 tests and zero compiler diagnostics. Five prior findings are fixed. R1-F1 remains open because material compiler inputs can still change without invalidating the DLL receipt. The review also found defects in resource preparation, package publication and test-result attribution.

## Continuation for Claude

Keep the corrections within Preserver’s build and qualification tooling. Make receipt comparison account for the effective compiler, ordered arguments and indirect file inputs. Use the same resource preparation for comparison and production builds. Preserve the control that accepts byte-identical Managed references in another directory. Publish the validated ZIP and both receipts as a consistent set, with the final archive in the established package_path field. Have Qualify consume the test result from its own invocation. Extend the existing disposable-clone cases with the focused controls in the findings, export their results and run the configured qualify gate on the corrected commit. Keep gameplay, product identity and the owner’s live installation outside these corrections.

#### Findings

**R1-F1** · P1 · defect · blocks readiness — Keep indirect inputs and their order in the compiler receipt
- Location: `scripts/Common.ps1:231`; acceptance: §5, §6
- Trigger: Select an ignored response file through CompilerResponseFile in GamePath.props, then change an option inside that file without changing its path.
- Expected: The receipt must distinguish compiler invocations that can produce different DLLs.
- Actual: Csc emits a response file as @path. The parser treats that token as a source filename, retains the @ and accepts an 'absent' digest. Editing the real file leaves the receipt equal. The parser also sorts the arguments, losing imported source order that can affect emitted metadata. The replacement inventory drops CscToolPath and CscToolExe, which the previous receipt captured and MSBuild passes separately to the task.
- Why it blocks / does not: Package admission can accept a frozen DLL after an input that determines its compiled bytes has changed.
- Requested correction: Preserve argument order, account for the effective compiler selection and bind response-file inputs to their contents and material dependencies. Refusing reuse for an input the helper cannot identify is also sufficient.
- Requested evidence: In a disposable clone, change /baseaddress inside a project-relative response file under ignored artifacts. Show stale reuse refused and a matching rebuild accepted, or a clear refusal of the unsupported input. Include controls for reordered imported sources and a changed compiler selection.

**R5-F1** · P2 · defect · blocks readiness — Prepare embedded resources before comparing compiler inputs
- Location: `scripts/Common.ps1:279`; acceptance: §5, §6
- Trigger: Add an ordinary EmbeddedResource through the ignored import after building the candidate.
- Expected: The comparison pass and production build must see the same prepared resources.
- Actual: The comparison invokes /t:Compile in a fresh intermediate directory. In SDK 8.0.424 the normal build runs PrepareResources before Compile. That stage supplies the metadata and generated files used by _GenerateCompileInputs. The comparison can omit the resource, allowing the previous receipt to pass. On a real rebuild, Build-Local can then reject the additional /resource argument as a mismatch.
- Why it blocks / does not: Adding a standard MSBuild resource can both leave an old DLL eligible for packaging and prevent the matching rebuild from receiving a receipt.
- Requested correction: Run the production resource-preparation prerequisites when collecting the comparison inventory. Keep generated outputs isolated from the production build.
- Requested evidence: After a baseline build, add a neutral EmbeddedResource from outside src through GamePath.props. Show the old package receipt refused, the matching rebuild accepted and the resource present in the rebuilt assembly.

**R5-F2** · P2 · defect · blocks readiness — Preserve the accepted package through final receipt writes
- Location: `scripts/Package.ps1:84`; acceptance: §5, §6
- Trigger: Validation succeeds for a different ZIP, but a public receipt cannot be replaced.
- Expected: The published ZIP, package receipt and validation receipt must describe one accepted package after either success or failure.
- Actual: Package.ps1 removes the accepted ZIP, moves the replacement into place, then writes the two public JSON files separately. If package.json is locked against writes, the new ZIP and validation record are already public when the last write fails. There is no rollback. Two publishers can also interleave these writes.
- Why it blocks / does not: A failed packaging command can discard the last accepted archive and leave its receipt describing different bytes.
- Requested correction: Prepare both records before replacing public files, serialize final publication and preserve the previous set if a replacement fails.
- Requested evidence: Start with a validated ZIP, change a packaged README to produce a distinct valid replacement and hold package.json against writes. Immediately after the failure, compare all three public files with the accepted originals. Then show a successful retry.

**R5-F3** · P2 · defect · blocks readiness — Bind test credit to the qualification that ran the tests
- Location: `scripts/Qualify.ps1:43`; acceptance: §4, §6
- Trigger: A second test invocation finishes after the first qualification’s test stage and before that qualification reads tests.json.
- Expected: Qualification must evaluate the result returned by its own test invocation.
- Actual: Qualify invokes Test.ps1, runs any later stages and then reads the shared artifacts/qualification/tests.json. The predicate checks the -Test switch, DLL digest and passed status. It has no link to the invocation that supplied the result. Another run’s matching record can hide a tested-DLL mismatch, and a concurrent Debug result can make a valid Release run fail.
- Why it blocks / does not: A requested test stage can still receive credit for a DLL its own runner did not exercise.
- Requested correction: Pass the test result directly to Qualify or use an invocation-specific receipt that Qualify verifies. The standalone test command can still publish its usual report.
- Requested evidence: Extend the substitute-DLL case by replacing the shared tests.json with the passing control’s report after Test.ps1 returns. The substitute run must still fail, and the matching control must pass.

**R5-F4** · P2 · defect · blocks readiness — Publish the final ZIP path in the validation receipt
- Location: `scripts/Package.ps1:87`; acceptance: §5, §6, §8
- Trigger: Read package_path after any successful Package.ps1 invocation.
- Expected: After successful publication, package-validation.json.package_path must identify the accepted ZIP on disk.
- Actual: Package.ps1 adds a new field named package while leaving package_path pointed at artifacts/.package-<guid>. The finally block deletes that directory. The committed package-validation.json demonstrates both paths on the successful candidate.
- Why it blocks / does not: A consumer following the established package_path field cannot open the archive certified by the published validation record.
- Requested correction: Set the existing package_path field to the final ZIP when publishing the validation receipt.
- Requested evidence: After Package.ps1 returns and staging is removed, open the ZIP using only package-validation.json.package_path and verify its recorded SHA-256.

**R5-F5** · P3 · optional_polish · non-blocking — Clean up partial test-run directories
- Location: `scripts/Test.ps1:13`; acceptance: §6
- Trigger: An output file becomes unavailable during the recursive copy.
- Expected: The cleanup scope should cover creation and population of the private runner directory.
- Actual: Copy-Item runs before the try block. An error after the destination directory is created leaves a partial klap-test-run directory in the temporary folder.
- Why it blocks / does not: This affects temporary-file cleanup on a failed copy. The successful qualification evidence is unaffected.
- Requested correction: Move the private output copy inside the existing try/finally.
- Requested evidence: A disposable copy failure should leave the set of klap-test-run directories unchanged.

#### Prior finding assessments

- **R1-F1** — `fix_rejected` — The requested BaseAddress and Win32Resource cases now reject stale receipts, produce different DLLs on rebuild and accept the matching outputs. Byte-identical Managed relocation also passes. The remaining response-file, ordering and compiler-selection omissions still violate the same material-input requirement.
- **R1-F2** — `fix_verified` — Staging is private to each invocation. Package.ps1 fingerprints the documents read from the validated archive. The recorded post-copy README substitution was refused and the matching package control passed.
- **R4-F1** — `fix_verified` — The runner now executes from a private output copy hashed before and after testing. Restoring the public test-output DLL after the runner exited left the substitute digest a14c2a44 in its receipt, and qualification refused it. R5-F3 concerns which receipt Qualify subsequently reads.
- **R4-F2** — `fix_verified` — A build-only qualification now reports zero tests and 'not run in this qualification'. The recorded controls cover a previously passing suite followed by a missing runtime loader and a build after a source change.
- **R4-F3** — `fix_verified` — Both staging-refusal cases compared the accepted ZIP and both records immediately after refusal and found their hashes unchanged. R5-F2 concerns a later failure during publication.
- **R4-F4** — `fix_verified` — The index identifies the shells for both checksum methods. Using the installed Python executable from Windows PowerShell reproduced both indexed auditor digests, be870827… and 93989652….

#### Evidence assessment

- **Inspected:** Mission, repository instructions, developer report, transcript notice, six pending ledger entries, prior dispositions, controller receipt and full gate log.; The supplied 4,811-line feature diff matched Git’s diff for all 38 changed files. I inspected the round-five changes and their build, test, package, qualification and release consumers.; Compiler and loader targets, pin definitions, standalone validator, regression cases, compatibility documentation and structured evidence. I also checked the installed SDK’s Csc task arguments and resource-preparation target dependencies.
- **Executed verification:** The controller receipt and matching log confirm that Qualify.ps1 -Build -Test -VerifyContracts passed at a66c49a. It built DLL fadf2dab6ff3b8a92c81a3515b633f0de7482879ac5ca43a79ca9ac7c0031248, reported 84/84 tests and verified managed contracts with the owner’s UMM 0.33.0 and Harmony2 2.3.6.0. The gate credited an existing package record.; The committed run records at 5d00290 report 128/128 boundary checks, successful standalone validation of ZIP 83611dd565b69ac399b010fd57cc7f65e948fb7ece22417b8f82c19b65700adc and rejection of the genuine UMM 0.33.0-compiled v0.1.3 DLL with only its manifest lowered. The intervening commits changed documentation and evidence only.; The archived static and managed checks identify the same DLL and MVID 4bcbb685-5152-4399-98e2-19fb6d19c6cd across 0.31.1, 0.32.4, owner 0.33.0 and 0.33.4. They record 9 type and 25 member references resolved on every row, managed patch ownership on all four and refusal of the mismatched Harmony2 control.; I verified the mission and controller-log hashes, all 16 indexed Git-blob hashes and the build and package fingerprints from the checkout and recorded compiler inventory. Both auditor exports matched using the documented Python calculation from Windows PowerShell.; Read-only checks showed that reversing two recorded source entries gives identical normalized inventory text, that the test-credit predicate accepts a passing receipt from a different run, and that the exported validation receipt’s package_path differs from the published ZIP path.
- **Source inspection only:** The response-file, compiler-selection and embedded-resource findings follow from the repository scripts and SDK target definitions. No new production DLL was compiled during review.; The partial-publication and temporary-copy failure paths were traced through their writes and cleanup scopes. The supplied staging-refusal tests finish before final publication begins.
- **Required gaps:** Close the remaining compiler-receipt omissions and verify admission of a matching build with an ordinary embedded resource.; Demonstrate consistent package publication through a receipt-write failure and publish a validation record whose package_path resolves to the accepted ZIP.; Demonstrate that a second test invocation cannot supply the result credited to the first qualification.
- **Limitations:** The foreground transcript was withheld because it mixes projects. The exact-candidate controller log covers build, tests and managed contracts. Package creation and the boundary cases are evidenced by the committed records at 5d00290.; The review was read-only. I did not rerun compilation, package publication or the proposed failure cases.; Native defeat, preservation, recovery, fresh-process reload and manual-deletion controls were NOT RUN on all four loaders. The mission permits that disposition without an approved disposable game setup. The combined mod stack was also untested.

#### Summary

- **Delivered behavior:** The manifest declares UMM 0.31.1. The recorded production DLL references UnityModManager 0.31.1.0 and 0Harmony12 1.2.0.1. The exact-candidate gate passed, and the standalone validator rejected the lowered-manifest legacy DLL. The remaining defects concern artifact reuse, publication and qualification evidence.
- **Scope reviewed:** Final correction review of Last Azlanti Preserver PR #7 at a66c49a, covering the six pending findings, the repository’s applicable mission requirements and the consumers of the changed build, package and test tooling.
- **Pending later-phase work:** none
- **Unresolved questions:** none
- **Remaining owner review:** Disposition of draft PR #7 after the corrected candidate completes controller review.; Per-loader native acceptance requires an approved disposable setup to observe Last Azlanti defeat, preservation, recovery and fresh-process reload, together with manual-deletion and non-Azlanti controls.

#### Provenance (controller-recorded)

| | Requested | Observed |
|---|---|---|
| Model | `gpt-6.2-astra` | `gpt-6.2-astra` (turns ['gpt-6.2-astra']) |
| Reasoning effort | `max` | `max` (turns ['max']) |
| Sandbox / approvals | read-only / never | `read-only` / `never` |

Owner guidance bound to this review: none.

Owner amendments bound to this review: none.

Codex CLI `0.170.0`, thread `01a20b27-52c2-72b3-93e8-4a066a4dc567`, duration 790.0s, response sha256 `bc66032b35d571762a8d1e5d49986c23e88ef597fd51eae384b798dd67df3a66`, request `klap-umm0311-codex-umm-0311-baseline-20261123-20261123162452-aa01-r05-b5e499`. Observed values come from the Codex session rollout's recorded thread settings, not from the model's own statements; the serving backend's model identity is not separately exposed.

<details><summary>Complete structured review (agent-review.review.v1)</summary>

```json
{
  "candidate_commit": "a66c49a8be3f5d1828b6cb4f80402943d6aa5564",
  "checkpoint_id": "final",
  "checkpoint_type": "final",
  "decision": "changes_required",
  "decision_rationale": "The controller gate passed with 84 tests and zero compiler diagnostics. Five prior findings are fixed. R1-F1 remains open because material compiler inputs can still change without invalidating the DLL receipt. The review also found defects in resource preparation, package publication and test-result attribution.\n\n## Continuation for Claude\n\nKeep the corrections within Preserver\u2019s build and qualification tooling. Make receipt comparison account for the effective compiler, ordered arguments and indirect file inputs. Use the same resource preparation for comparison and production builds. Preserve the control that accepts byte-identical Managed references in another directory. Publish the validated ZIP and both receipts as a consistent set, with the final archive in the established package_path field. Have Qualify consume the test result from its own invocation. Extend the existing disposable-clone cases with the focused controls in the findings, export their results and run the configured qualify gate on the corrected commit. Keep gameplay, product identity and the owner\u2019s live installation outside these corrections.",
  "evidence_assessment": {
    "executed_verification": [
      "The controller receipt and matching log confirm that Qualify.ps1 -Build -Test -VerifyContracts passed at a66c49a. It built DLL fadf2dab6ff3b8a92c81a3515b633f0de7482879ac5ca43a79ca9ac7c0031248, reported 84/84 tests and verified managed contracts with the owner\u2019s UMM 0.33.0 and Harmony2 2.3.6.0. The gate credited an existing package record.",
      "The committed run records at 5d00290 report 128/128 boundary checks, successful standalone validation of ZIP 83611dd565b69ac399b010fd57cc7f65e948fb7ece22417b8f82c19b65700adc and rejection of the genuine UMM 0.33.0-compiled v0.1.3 DLL with only its manifest lowered. The intervening commits changed documentation and evidence only.",
      "The archived static and managed checks identify the same DLL and MVID 4bcbb685-5152-4399-98e2-19fb6d19c6cd across 0.31.1, 0.32.4, owner 0.33.0 and 0.33.4. They record 9 type and 25 member references resolved on every row, managed patch ownership on all four and refusal of the mismatched Harmony2 control.",
      "I verified the mission and controller-log hashes, all 16 indexed Git-blob hashes and the build and package fingerprints from the checkout and recorded compiler inventory. Both auditor exports matched using the documented Python calculation from Windows PowerShell.",
      "Read-only checks showed that reversing two recorded source entries gives identical normalized inventory text, that the test-credit predicate accepts a passing receipt from a different run, and that the exported validation receipt\u2019s package_path differs from the published ZIP path."
    ],
    "inspected": [
      "Mission, repository instructions, developer report, transcript notice, six pending ledger entries, prior dispositions, controller receipt and full gate log.",
      "The supplied 4,811-line feature diff matched Git\u2019s diff for all 38 changed files. I inspected the round-five changes and their build, test, package, qualification and release consumers.",
      "Compiler and loader targets, pin definitions, standalone validator, regression cases, compatibility documentation and structured evidence. I also checked the installed SDK\u2019s Csc task arguments and resource-preparation target dependencies."
    ],
    "limitations": [
      "The foreground transcript was withheld because it mixes projects. The exact-candidate controller log covers build, tests and managed contracts. Package creation and the boundary cases are evidenced by the committed records at 5d00290.",
      "The review was read-only. I did not rerun compilation, package publication or the proposed failure cases.",
      "Native defeat, preservation, recovery, fresh-process reload and manual-deletion controls were NOT RUN on all four loaders. The mission permits that disposition without an approved disposable game setup. The combined mod stack was also untested."
    ],
    "required_gaps": [
      "Close the remaining compiler-receipt omissions and verify admission of a matching build with an ordinary embedded resource.",
      "Demonstrate consistent package publication through a receipt-write failure and publish a validation record whose package_path resolves to the accepted ZIP.",
      "Demonstrate that a second test invocation cannot supply the result credited to the first qualification."
    ],
    "source_inspection_only": [
      "The response-file, compiler-selection and embedded-resource findings follow from the repository scripts and SDK target definitions. No new production DLL was compiled during review.",
      "The partial-publication and temporary-copy failure paths were traced through their writes and cleanup scopes. The supplied staging-refusal tests finish before final publication begins."
    ]
  },
  "findings": [
    {
      "acceptance_ids": [
        "\u00a75",
        "\u00a76"
      ],
      "actual": "Csc emits a response file as @path. The parser treats that token as a source filename, retains the @ and accepts an 'absent' digest. Editing the real file leaves the receipt equal. The parser also sorts the arguments, losing imported source order that can affect emitted metadata. The replacement inventory drops CscToolPath and CscToolExe, which the previous receipt captured and MSBuild passes separately to the task.",
      "blocking_rationale": "Package admission can accept a frozen DLL after an input that determines its compiled bytes has changed.",
      "blocks_readiness": true,
      "category": "defect",
      "expected": "The receipt must distinguish compiler invocations that can produce different DLLs.",
      "id": "R1-F1",
      "location": {
        "file": "scripts/Common.ps1",
        "line": 231
      },
      "priority": "P1",
      "requested_correction": "Preserve argument order, account for the effective compiler selection and bind response-file inputs to their contents and material dependencies. Refusing reuse for an input the helper cannot identify is also sufficient.",
      "requested_evidence": "In a disposable clone, change /baseaddress inside a project-relative response file under ignored artifacts. Show stale reuse refused and a matching rebuild accepted, or a clear refusal of the unsupported input. Include controls for reordered imported sources and a changed compiler selection.",
      "title": "Keep indirect inputs and their order in the compiler receipt",
      "trigger": "Select an ignored response file through CompilerResponseFile in GamePath.props, then change an option inside that file without changing its path."
    },
    {
      "acceptance_ids": [
        "\u00a75",
        "\u00a76"
      ],
      "actual": "The comparison invokes /t:Compile in a fresh intermediate directory. In SDK 8.0.424 the normal build runs PrepareResources before Compile. That stage supplies the metadata and generated files used by _GenerateCompileInputs. The comparison can omit the resource, allowing the previous receipt to pass. On a real rebuild, Build-Local can then reject the additional /resource argument as a mismatch.",
      "blocking_rationale": "Adding a standard MSBuild resource can both leave an old DLL eligible for packaging and prevent the matching rebuild from receiving a receipt.",
      "blocks_readiness": true,
      "category": "defect",
      "expected": "The comparison pass and production build must see the same prepared resources.",
      "id": "R5-F1",
      "location": {
        "file": "scripts/Common.ps1",
        "line": 279
      },
      "priority": "P2",
      "requested_correction": "Run the production resource-preparation prerequisites when collecting the comparison inventory. Keep generated outputs isolated from the production build.",
      "requested_evidence": "After a baseline build, add a neutral EmbeddedResource from outside src through GamePath.props. Show the old package receipt refused, the matching rebuild accepted and the resource present in the rebuilt assembly.",
      "title": "Prepare embedded resources before comparing compiler inputs",
      "trigger": "Add an ordinary EmbeddedResource through the ignored import after building the candidate."
    },
    {
      "acceptance_ids": [
        "\u00a75",
        "\u00a76"
      ],
      "actual": "Package.ps1 removes the accepted ZIP, moves the replacement into place, then writes the two public JSON files separately. If package.json is locked against writes, the new ZIP and validation record are already public when the last write fails. There is no rollback. Two publishers can also interleave these writes.",
      "blocking_rationale": "A failed packaging command can discard the last accepted archive and leave its receipt describing different bytes.",
      "blocks_readiness": true,
      "category": "defect",
      "expected": "The published ZIP, package receipt and validation receipt must describe one accepted package after either success or failure.",
      "id": "R5-F2",
      "location": {
        "file": "scripts/Package.ps1",
        "line": 84
      },
      "priority": "P2",
      "requested_correction": "Prepare both records before replacing public files, serialize final publication and preserve the previous set if a replacement fails.",
      "requested_evidence": "Start with a validated ZIP, change a packaged README to produce a distinct valid replacement and hold package.json against writes. Immediately after the failure, compare all three public files with the accepted originals. Then show a successful retry.",
      "title": "Preserve the accepted package through final receipt writes",
      "trigger": "Validation succeeds for a different ZIP, but a public receipt cannot be replaced."
    },
    {
      "acceptance_ids": [
        "\u00a74",
        "\u00a76"
      ],
      "actual": "Qualify invokes Test.ps1, runs any later stages and then reads the shared artifacts/qualification/tests.json. The predicate checks the -Test switch, DLL digest and passed status. It has no link to the invocation that supplied the result. Another run\u2019s matching record can hide a tested-DLL mismatch, and a concurrent Debug result can make a valid Release run fail.",
      "blocking_rationale": "A requested test stage can still receive credit for a DLL its own runner did not exercise.",
      "blocks_readiness": true,
      "category": "defect",
      "expected": "Qualification must evaluate the result returned by its own test invocation.",
      "id": "R5-F3",
      "location": {
        "file": "scripts/Qualify.ps1",
        "line": 43
      },
      "priority": "P2",
      "requested_correction": "Pass the test result directly to Qualify or use an invocation-specific receipt that Qualify verifies. The standalone test command can still publish its usual report.",
      "requested_evidence": "Extend the substitute-DLL case by replacing the shared tests.json with the passing control\u2019s report after Test.ps1 returns. The substitute run must still fail, and the matching control must pass.",
      "title": "Bind test credit to the qualification that ran the tests",
      "trigger": "A second test invocation finishes after the first qualification\u2019s test stage and before that qualification reads tests.json."
    },
    {
      "acceptance_ids": [
        "\u00a75",
        "\u00a76",
        "\u00a78"
      ],
      "actual": "Package.ps1 adds a new field named package while leaving package_path pointed at artifacts/.package-<guid>. The finally block deletes that directory. The committed package-validation.json demonstrates both paths on the successful candidate.",
      "blocking_rationale": "A consumer following the established package_path field cannot open the archive certified by the published validation record.",
      "blocks_readiness": true,
      "category": "defect",
      "expected": "After successful publication, package-validation.json.package_path must identify the accepted ZIP on disk.",
      "id": "R5-F4",
      "location": {
        "file": "scripts/Package.ps1",
        "line": 87
      },
      "priority": "P2",
      "requested_correction": "Set the existing package_path field to the final ZIP when publishing the validation receipt.",
      "requested_evidence": "After Package.ps1 returns and staging is removed, open the ZIP using only package-validation.json.package_path and verify its recorded SHA-256.",
      "title": "Publish the final ZIP path in the validation receipt",
      "trigger": "Read package_path after any successful Package.ps1 invocation."
    },
    {
      "acceptance_ids": [
        "\u00a76"
      ],
      "actual": "Copy-Item runs before the try block. An error after the destination directory is created leaves a partial klap-test-run directory in the temporary folder.",
      "blocking_rationale": "This affects temporary-file cleanup on a failed copy. The successful qualification evidence is unaffected.",
      "blocks_readiness": false,
      "category": "optional_polish",
      "expected": "The cleanup scope should cover creation and population of the private runner directory.",
      "id": "R5-F5",
      "location": {
        "file": "scripts/Test.ps1",
        "line": 13
      },
      "priority": "P3",
      "requested_correction": "Move the private output copy inside the existing try/finally.",
      "requested_evidence": "A disposable copy failure should leave the set of klap-test-run directories unchanged.",
      "title": "Clean up partial test-run directories",
      "trigger": "An output file becomes unavailable during the recursive copy."
    }
  ],
  "prior_finding_assessments": [
    {
      "assessment": "fix_rejected",
      "finding_id": "R1-F1",
      "rationale": "The requested BaseAddress and Win32Resource cases now reject stale receipts, produce different DLLs on rebuild and accept the matching outputs. Byte-identical Managed relocation also passes. The remaining response-file, ordering and compiler-selection omissions still violate the same material-input requirement."
    },
    {
      "assessment": "fix_verified",
      "finding_id": "R1-F2",
      "rationale": "Staging is private to each invocation. Package.ps1 fingerprints the documents read from the validated archive. The recorded post-copy README substitution was refused and the matching package control passed."
    },
    {
      "assessment": "fix_verified",
      "finding_id": "R4-F1",
      "rationale": "The runner now executes from a private output copy hashed before and after testing. Restoring the public test-output DLL after the runner exited left the substitute digest a14c2a44 in its receipt, and qualification refused it. R5-F3 concerns which receipt Qualify subsequently reads."
    },
    {
      "assessment": "fix_verified",
      "finding_id": "R4-F2",
      "rationale": "A build-only qualification now reports zero tests and 'not run in this qualification'. The recorded controls cover a previously passing suite followed by a missing runtime loader and a build after a source change."
    },
    {
      "assessment": "fix_verified",
      "finding_id": "R4-F3",
      "rationale": "Both staging-refusal cases compared the accepted ZIP and both records immediately after refusal and found their hashes unchanged. R5-F2 concerns a later failure during publication."
    },
    {
      "assessment": "fix_verified",
      "finding_id": "R4-F4",
      "rationale": "The index identifies the shells for both checksum methods. Using the installed Python executable from Windows PowerShell reproduced both indexed auditor digests, be870827\u2026 and 93989652\u2026."
    }
  ],
  "request_id": "klap-umm0311-codex-umm-0311-baseline-20261123-20261123162452-aa01-r05-b5e499",
  "round": 5,
  "schema_version": "agent-review.review.v1",
  "summary": {
    "delivered_behavior": "The manifest declares UMM 0.31.1. The recorded production DLL references UnityModManager 0.31.1.0 and 0Harmony12 1.2.0.1. The exact-candidate gate passed, and the standalone validator rejected the lowered-manifest legacy DLL. The remaining defects concern artifact reuse, publication and qualification evidence.",
    "pending_later_phase_work": [],
    "remaining_owner_review": [
      "Disposition of draft PR #7 after the corrected candidate completes controller review.",
      "Per-loader native acceptance requires an approved disposable setup to observe Last Azlanti defeat, preservation, recovery and fresh-process reload, together with manual-deletion and non-Azlanti controls."
    ],
    "scope_reviewed": "Final correction review of Last Azlanti Preserver PR #7 at a66c49a, covering the six pending findings, the repository\u2019s applicable mission requirements and the consumers of the changed build, package and test tooling.",
    "unresolved_questions": []
  }
}
```
</details>

_Model-generated review by Codex using the requested model, posted by the agent-review controller through the owner's GitHub account. Not a human review or approval._
