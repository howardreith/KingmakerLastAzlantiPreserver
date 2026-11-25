<!-- agent-review:v1 enrollment=klap-umm0311-codex-umm-0311-baseline-20261123-20261123162452-aa01 key=r07-review part=1/1 sha256=b5bf4b51c84e036b1e768a506a08e4d98b930f50c1245abeef3a776480f8c165 -->
### Codex GPT-6.2 Astra — review — round 7 — candidate `6d4dc370be`

**Decision:** `changes_required` — The pinned compilation and package checks are supported. Two correctness issues remain. An external source filename can still conceal a material path change from the build receipt, and a locked published ZIP can prevent validation of a different, readable archive. The reproduction instructions also omit the compiler fixture required by the new test.

## Continuation for Claude

Within OWNER AMENDMENT 1, narrow the generated-source exception and keep validation of a supplied archive independent of access to the published ZIP. Document the test-only compiler prerequisite or reuse the existing SDK. Adapt the existing external-source and held-file cases, retain the passing publication-overlap and legacy-DLL controls, and attach the configured qualify receipt for the corrected commit. These corrections concern build evidence, standalone validation, and their reproduction instructions. The existing review and execution budgets apply.

#### Findings

**R6-F2** · P2 · defect · blocks readiness — Distinguish external sources that match the assembly-attributes filename pattern
- Location: `scripts/Common.ps1:245`; acceptance: §5, §6
- Trigger: GamePath.props redirects an external Compile item named Shared.AssemblyAttributes.cs to a byte-identical copy in another directory. The source uses CallerFilePath.
- Expected: A change in the compiler-visible path of this external source must invalidate frozen reuse.
- Actual: Get-InputName labels every *.AssemblyAttributes.cs file as generated. Get-SourceName then returns that label before hashing the path. Both copies become generated:Shared.AssemblyAttributes.cs with the same content digest. The old receipt can pass even though recompilation embeds the other caller path.
- Why it blocks / does not: A material compiler input can change while Package.ps1 continues to admit the previous DLL.
- Requested correction: Identify the actual MSBuild-generated framework-attribute source explicitly. Apply the external path digest to other external Compile items, or refuse an ambiguous input before admitting reuse.
- Requested evidence: Use the existing CallerFilePath fixture with the basename Shared.AssemblyAttributes.cs. Show initial acceptance, stale-receipt rejection after relocation, and acceptance of the differing rebuilt DLL. Retain the byte-identical Managed-reference relocation control.

**R7-F1** · P2 · defect · blocks readiness — Keep a locked published ZIP from failing validation of a supplied ZIP
- Location: `scripts/Validate-Package.ps1:139`; acceptance: §6
- Trigger: A caller validates a readable external ZIP while another process holds the repository's published ZIP against reads.
- Expected: Validation should succeed for the readable, valid supplied archive and leave the published receipt untouched when the published bytes cannot be compared.
- Actual: After inspecting the supplied archive, the validator opens the published ZIP at line 139 to decide whether to refresh the shared receipt. A sharing violation escapes that block and fails the command. Install.ps1 uses this default report path for its pre-install check.
- Why it blocks / does not: The standalone pre-install validator can refuse a genuine baseline archive solely because another archive is locked.
- Requested correction: Make the shared receipt refresh optional when the published ZIP cannot be read, or give Package.ps1 sole ownership of that receipt. Preserve failures from validating the supplied archive and from writing an explicitly requested separate report.
- Requested evidence: Hold the published ZIP with FileShare.None in the disposable clone and validate a distinct valid ZIP using the default report path. Show success for the supplied bytes and unchanged public records. The existing overlap and lowered-manifest rejection cases should still pass.

**R7-F2** · P2 · required_gap · blocks readiness — Identify the compiler fixture needed to reproduce the relative-selector test
- Location: `scripts/Test-LoaderBaseline.ps1:519`; acceptance: §8
- Trigger: Test-LoaderBaseline.ps1 runs on a Windows host with the documented SDK and targeting pack but without a Visual Studio installation discoverable by vswhere.
- Expected: The reproduction instructions should identify the additional test fixture or the case should use a compiler supplied by the documented SDK.
- Actual: The new case only obtains its project-selected csc.exe through Visual Studio Installer's vswhere and MSBuild\Current\Bin\Roslyn. Without that installation, the fixture directory lacks the compiler and the assertion explicitly fails. The documented prerequisites list the SDK/MSBuild and the 4.7.2 targeting pack.
- Why it blocks / does not: A developer following the documented setup can build the product yet cannot reproduce the newly cited compiler-selection check.
- Requested correction: Document the Visual Studio Build Tools Roslyn compiler and its discovery requirement as specific to this test, or obtain the fixture from the existing SDK.
- Requested evidence: For a documentation correction, show that the stated prerequisite matches the implemented lookup. The indexed run already demonstrates success with the Visual Studio fixture.

**R7-F3** · P3 · optional_polish · non-blocking — Report the actual reason a preview skips the receipt write
- Location: `scripts/Validate-Package.ps1:154`; acceptance: §6
- Trigger: Install.ps1 -WhatIf validates the current published ZIP.
- Expected: The preview should identify WhatIf as the reason the receipt write was skipped.
- Actual: WhatIf skips the digest comparison, then the common message says the archive is not the published package. That message also appears for the canonical ZIP itself.
- Why it blocks / does not: The preview preserves the archive and receipt. Only its explanation is incorrect.
- Requested correction: Use a preview-specific message or neutral wording that makes no claim about a digest comparison that was skipped.
- Requested evidence: Check the status line from the existing disposable installation preview using the published ZIP.

#### Prior finding assessments

- **R1-F1** — `fix_verified` — The target resolves the compiler in the project directory. The repository-root control recorded project-selected csc.exe f895c265 instead of the baef2676 decoy, accepted the matching package, and refused reuse after replacement of the selected binary.
- **R5-F2** — `fix_verified` — The default validator refresh now compares bytes under the publication lock. In the recorded overlap, validation of A completed after publication of B and both public receipts retained B's 2475fc6c digest. The held-record rollback and retry controls also passed.
- **R6-F1** — `fix_verified` — The test rebuilds and packages the original props before changing only the compiler selector. Both inventories have 69 entries, the assertion requires refusal at entry 0, and restoring the original compiler restores acceptance.
- **R6-F2** — `fix_rejected` — The recorded ordinary .cs fixture now distinguishes the two paths and produces different DLLs. The filename-based generated-source exception still collapses two external *.AssemblyAttributes.cs paths into the same receipt entry.
- **R6-F3** — `deferral_accepted` — A failed qualification can leave its GUID-named temporary result. Each later invocation allocates a fresh path, so the leftover cannot grant test credit. Separate follow-up for this storage cleanup fits OWNER AMENDMENT 1.
- **R6-F4** — `fix_verified` — The reproduction section points to the current indexed count of 157/157 and attributes 128 and 145/145 to their respective historical rounds.

#### Evidence assessment

- **Inspected:** Mission, OWNER AMENDMENT 1, AGENTS.md, all six pending ledger entries, developer report, transcript notice, and candidate-bound gate receipt.; The 39-file feature diff and round-seven changes to compiler selection, source identity, package publication, standalone validation, their consumers, regression cases, and reproduction instructions.
- **Executed verification:** The controller ran Qualify.ps1 -Build -Test -VerifyContracts at H. It exited 0 on a clean worktree with 84/84 tests, zero compiler warnings or errors, and both managed contract checks passing on DLL fadf2dab6ff3b8a92c81a3515b633f0de7482879ac5ca43a79ca9ac7c0031248.; The committed boundary-suite record contains 157 distinct passing cases at c39b471. Only documentation and evidence changed between that commit and H. The standalone validator accepted ZIP 83611dd565b69ac399b010fd57cc7f65e948fb7ece22417b8f82c19b65700adc and recorded the same DLL, MVID 4bcbb685-5152-4399-98e2-19fb6d19c6cd, UnityModManager 0.31.1.0, and 0Harmony12 1.2.0.1. It rejected the genuine v0.1.3 DLL referencing UMM 0.33.0.0 after only its manifest was lowered.; The archived static and managed checks identify the same DLL across UMM 0.31.1, 0.32.4, owner-installed 0.33.0, and the selected 0.33.4. The audit resolved 9 types and 25 members on each row. The managed check also refused the mismatched 0.33.4/Harmony2 profile.; Read-only review checks matched the supplied 5,359-line diff to Git after line-ending normalization and verified all 17 indexed evidence-file SHA-256 values against their committed Git blobs.
- **Source inspection only:** Traced the generated filename classification through Get-SourceName, the ordered compiler inventory, and Package.ps1 receipt admission.; Traced the published-ZIP read and its error propagation through Validate-Package.ps1 and Install.ps1. The held-unrelated-ZIP case and the preview message are findings from source inspection.
- **Required gaps:** R6-F2 needs stale-receipt rejection for an external path-sensitive source whose filename matches the generated-source pattern.; R7-F1 needs successful default-path validation of a readable supplied ZIP while the distinct published ZIP is unavailable for hashing.; R7-F2 needs reproducible instructions for obtaining or locating the compiler used by the relative-selector test.
- **Limitations:** The controller withheld the mixed foreground transcript. The exact-H gate omitted packaging. Package and boundary-suite observations come from the indexed c39b471 run.; The developer report quotes different external-source path and DLL digests from the attached c39b471 record. The recorded rebuilt DLL prefixes are bd6c5203 and 222ad968.; The review sandbox permitted source and evidence inspection only. Its constrained PowerShell also prevented an independent file-sharing probe. Native gameplay and combined-stack checks are recorded as NOT RUN.

#### Summary

- **Delivered behavior:** The manifest declares UMM 0.31.1. The Windows build and archived DLL establish UnityModManager 0.31.1.0 and Harmony12 1.2.0.1 as compiler references. Static and managed checks cover four exact loader profiles. The outstanding defects concern frozen-DLL reuse and standalone validation.
- **Scope reviewed:** Last Azlanti Preserver draft PR #7 at the final checkpoint, including the six pending findings and directly affected build, validation, and evidence paths under OWNER AMENDMENT 1.
- **Pending later-phase work:** none
- **Unresolved questions:** none
- **Remaining owner review:** Any later native compatibility claim requires an authorized disposable-campaign smoke test covering defeat, preservation, recovery, manual deletion, non-Azlanti behavior, and fresh-process reload.

#### Provenance (controller-recorded)

| | Requested | Observed |
|---|---|---|
| Model | `gpt-6.2-astra` | `gpt-6.2-astra` (turns ['gpt-6.2-astra']) |
| Reasoning effort | `max` | `max` (turns ['max']) |
| Sandbox / approvals | read-only / never | `read-only` / `never` |

Owner guidance bound to this review: none.

Owner amendments bound to this review: revision 1, sha256 `d03b6c8b1287093dae038511d606914b65f9864b951ad86fbc5c65e4461a92ce`.

Codex CLI `0.170.0`, thread `01a20f6a-84c0-7943-87fb-fc267cdcff4b`, duration 596.2s, response sha256 `ea5ee985cdcbaeb402d3563ed9553abd19e410ff234b832a10c52089b26f8f4f`, request `klap-umm0311-codex-umm-0311-baseline-20261123-20261123162452-aa01-r07-06763d`. Observed values come from the Codex session rollout's recorded thread settings, not from the model's own statements; the serving backend's model identity is not separately exposed.

<details><summary>Complete structured review (agent-review.review.v1)</summary>

```json
{
  "candidate_commit": "6d4dc370be89f3ff8efbc3e16543377292805dcf",
  "checkpoint_id": "final",
  "checkpoint_type": "final",
  "decision": "changes_required",
  "decision_rationale": "The pinned compilation and package checks are supported. Two correctness issues remain. An external source filename can still conceal a material path change from the build receipt, and a locked published ZIP can prevent validation of a different, readable archive. The reproduction instructions also omit the compiler fixture required by the new test.\n\n## Continuation for Claude\n\nWithin OWNER AMENDMENT 1, narrow the generated-source exception and keep validation of a supplied archive independent of access to the published ZIP. Document the test-only compiler prerequisite or reuse the existing SDK. Adapt the existing external-source and held-file cases, retain the passing publication-overlap and legacy-DLL controls, and attach the configured qualify receipt for the corrected commit. These corrections concern build evidence, standalone validation, and their reproduction instructions. The existing review and execution budgets apply.",
  "evidence_assessment": {
    "executed_verification": [
      "The controller ran Qualify.ps1 -Build -Test -VerifyContracts at H. It exited 0 on a clean worktree with 84/84 tests, zero compiler warnings or errors, and both managed contract checks passing on DLL fadf2dab6ff3b8a92c81a3515b633f0de7482879ac5ca43a79ca9ac7c0031248.",
      "The committed boundary-suite record contains 157 distinct passing cases at c39b471. Only documentation and evidence changed between that commit and H. The standalone validator accepted ZIP 83611dd565b69ac399b010fd57cc7f65e948fb7ece22417b8f82c19b65700adc and recorded the same DLL, MVID 4bcbb685-5152-4399-98e2-19fb6d19c6cd, UnityModManager 0.31.1.0, and 0Harmony12 1.2.0.1. It rejected the genuine v0.1.3 DLL referencing UMM 0.33.0.0 after only its manifest was lowered.",
      "The archived static and managed checks identify the same DLL across UMM 0.31.1, 0.32.4, owner-installed 0.33.0, and the selected 0.33.4. The audit resolved 9 types and 25 members on each row. The managed check also refused the mismatched 0.33.4/Harmony2 profile.",
      "Read-only review checks matched the supplied 5,359-line diff to Git after line-ending normalization and verified all 17 indexed evidence-file SHA-256 values against their committed Git blobs."
    ],
    "inspected": [
      "Mission, OWNER AMENDMENT 1, AGENTS.md, all six pending ledger entries, developer report, transcript notice, and candidate-bound gate receipt.",
      "The 39-file feature diff and round-seven changes to compiler selection, source identity, package publication, standalone validation, their consumers, regression cases, and reproduction instructions."
    ],
    "limitations": [
      "The controller withheld the mixed foreground transcript. The exact-H gate omitted packaging. Package and boundary-suite observations come from the indexed c39b471 run.",
      "The developer report quotes different external-source path and DLL digests from the attached c39b471 record. The recorded rebuilt DLL prefixes are bd6c5203 and 222ad968.",
      "The review sandbox permitted source and evidence inspection only. Its constrained PowerShell also prevented an independent file-sharing probe. Native gameplay and combined-stack checks are recorded as NOT RUN."
    ],
    "required_gaps": [
      "R6-F2 needs stale-receipt rejection for an external path-sensitive source whose filename matches the generated-source pattern.",
      "R7-F1 needs successful default-path validation of a readable supplied ZIP while the distinct published ZIP is unavailable for hashing.",
      "R7-F2 needs reproducible instructions for obtaining or locating the compiler used by the relative-selector test."
    ],
    "source_inspection_only": [
      "Traced the generated filename classification through Get-SourceName, the ordered compiler inventory, and Package.ps1 receipt admission.",
      "Traced the published-ZIP read and its error propagation through Validate-Package.ps1 and Install.ps1. The held-unrelated-ZIP case and the preview message are findings from source inspection."
    ]
  },
  "findings": [
    {
      "acceptance_ids": [
        "\u00a75",
        "\u00a76"
      ],
      "actual": "Get-InputName labels every *.AssemblyAttributes.cs file as generated. Get-SourceName then returns that label before hashing the path. Both copies become generated:Shared.AssemblyAttributes.cs with the same content digest. The old receipt can pass even though recompilation embeds the other caller path.",
      "blocking_rationale": "A material compiler input can change while Package.ps1 continues to admit the previous DLL.",
      "blocks_readiness": true,
      "category": "defect",
      "expected": "A change in the compiler-visible path of this external source must invalidate frozen reuse.",
      "id": "R6-F2",
      "location": {
        "file": "scripts/Common.ps1",
        "line": 245
      },
      "priority": "P2",
      "requested_correction": "Identify the actual MSBuild-generated framework-attribute source explicitly. Apply the external path digest to other external Compile items, or refuse an ambiguous input before admitting reuse.",
      "requested_evidence": "Use the existing CallerFilePath fixture with the basename Shared.AssemblyAttributes.cs. Show initial acceptance, stale-receipt rejection after relocation, and acceptance of the differing rebuilt DLL. Retain the byte-identical Managed-reference relocation control.",
      "title": "Distinguish external sources that match the assembly-attributes filename pattern",
      "trigger": "GamePath.props redirects an external Compile item named Shared.AssemblyAttributes.cs to a byte-identical copy in another directory. The source uses CallerFilePath."
    },
    {
      "acceptance_ids": [
        "\u00a76"
      ],
      "actual": "After inspecting the supplied archive, the validator opens the published ZIP at line 139 to decide whether to refresh the shared receipt. A sharing violation escapes that block and fails the command. Install.ps1 uses this default report path for its pre-install check.",
      "blocking_rationale": "The standalone pre-install validator can refuse a genuine baseline archive solely because another archive is locked.",
      "blocks_readiness": true,
      "category": "defect",
      "expected": "Validation should succeed for the readable, valid supplied archive and leave the published receipt untouched when the published bytes cannot be compared.",
      "id": "R7-F1",
      "location": {
        "file": "scripts/Validate-Package.ps1",
        "line": 139
      },
      "priority": "P2",
      "requested_correction": "Make the shared receipt refresh optional when the published ZIP cannot be read, or give Package.ps1 sole ownership of that receipt. Preserve failures from validating the supplied archive and from writing an explicitly requested separate report.",
      "requested_evidence": "Hold the published ZIP with FileShare.None in the disposable clone and validate a distinct valid ZIP using the default report path. Show success for the supplied bytes and unchanged public records. The existing overlap and lowered-manifest rejection cases should still pass.",
      "title": "Keep a locked published ZIP from failing validation of a supplied ZIP",
      "trigger": "A caller validates a readable external ZIP while another process holds the repository's published ZIP against reads."
    },
    {
      "acceptance_ids": [
        "\u00a78"
      ],
      "actual": "The new case only obtains its project-selected csc.exe through Visual Studio Installer's vswhere and MSBuild\\Current\\Bin\\Roslyn. Without that installation, the fixture directory lacks the compiler and the assertion explicitly fails. The documented prerequisites list the SDK/MSBuild and the 4.7.2 targeting pack.",
      "blocking_rationale": "A developer following the documented setup can build the product yet cannot reproduce the newly cited compiler-selection check.",
      "blocks_readiness": true,
      "category": "required_gap",
      "expected": "The reproduction instructions should identify the additional test fixture or the case should use a compiler supplied by the documented SDK.",
      "id": "R7-F2",
      "location": {
        "file": "scripts/Test-LoaderBaseline.ps1",
        "line": 519
      },
      "priority": "P2",
      "requested_correction": "Document the Visual Studio Build Tools Roslyn compiler and its discovery requirement as specific to this test, or obtain the fixture from the existing SDK.",
      "requested_evidence": "For a documentation correction, show that the stated prerequisite matches the implemented lookup. The indexed run already demonstrates success with the Visual Studio fixture.",
      "title": "Identify the compiler fixture needed to reproduce the relative-selector test",
      "trigger": "Test-LoaderBaseline.ps1 runs on a Windows host with the documented SDK and targeting pack but without a Visual Studio installation discoverable by vswhere."
    },
    {
      "acceptance_ids": [
        "\u00a76"
      ],
      "actual": "WhatIf skips the digest comparison, then the common message says the archive is not the published package. That message also appears for the canonical ZIP itself.",
      "blocking_rationale": "The preview preserves the archive and receipt. Only its explanation is incorrect.",
      "blocks_readiness": false,
      "category": "optional_polish",
      "expected": "The preview should identify WhatIf as the reason the receipt write was skipped.",
      "id": "R7-F3",
      "location": {
        "file": "scripts/Validate-Package.ps1",
        "line": 154
      },
      "priority": "P3",
      "requested_correction": "Use a preview-specific message or neutral wording that makes no claim about a digest comparison that was skipped.",
      "requested_evidence": "Check the status line from the existing disposable installation preview using the published ZIP.",
      "title": "Report the actual reason a preview skips the receipt write",
      "trigger": "Install.ps1 -WhatIf validates the current published ZIP."
    }
  ],
  "prior_finding_assessments": [
    {
      "assessment": "fix_verified",
      "finding_id": "R1-F1",
      "rationale": "The target resolves the compiler in the project directory. The repository-root control recorded project-selected csc.exe f895c265 instead of the baef2676 decoy, accepted the matching package, and refused reuse after replacement of the selected binary."
    },
    {
      "assessment": "fix_verified",
      "finding_id": "R5-F2",
      "rationale": "The default validator refresh now compares bytes under the publication lock. In the recorded overlap, validation of A completed after publication of B and both public receipts retained B's 2475fc6c digest. The held-record rollback and retry controls also passed."
    },
    {
      "assessment": "fix_verified",
      "finding_id": "R6-F1",
      "rationale": "The test rebuilds and packages the original props before changing only the compiler selector. Both inventories have 69 entries, the assertion requires refusal at entry 0, and restoring the original compiler restores acceptance."
    },
    {
      "assessment": "fix_rejected",
      "finding_id": "R6-F2",
      "rationale": "The recorded ordinary .cs fixture now distinguishes the two paths and produces different DLLs. The filename-based generated-source exception still collapses two external *.AssemblyAttributes.cs paths into the same receipt entry."
    },
    {
      "assessment": "deferral_accepted",
      "finding_id": "R6-F3",
      "rationale": "A failed qualification can leave its GUID-named temporary result. Each later invocation allocates a fresh path, so the leftover cannot grant test credit. Separate follow-up for this storage cleanup fits OWNER AMENDMENT 1."
    },
    {
      "assessment": "fix_verified",
      "finding_id": "R6-F4",
      "rationale": "The reproduction section points to the current indexed count of 157/157 and attributes 128 and 145/145 to their respective historical rounds."
    }
  ],
  "request_id": "klap-umm0311-codex-umm-0311-baseline-20261123-20261123162452-aa01-r07-06763d",
  "round": 7,
  "schema_version": "agent-review.review.v1",
  "summary": {
    "delivered_behavior": "The manifest declares UMM 0.31.1. The Windows build and archived DLL establish UnityModManager 0.31.1.0 and Harmony12 1.2.0.1 as compiler references. Static and managed checks cover four exact loader profiles. The outstanding defects concern frozen-DLL reuse and standalone validation.",
    "pending_later_phase_work": [],
    "remaining_owner_review": [
      "Any later native compatibility claim requires an authorized disposable-campaign smoke test covering defeat, preservation, recovery, manual deletion, non-Azlanti behavior, and fresh-process reload."
    ],
    "scope_reviewed": "Last Azlanti Preserver draft PR #7 at the final checkpoint, including the six pending findings and directly affected build, validation, and evidence paths under OWNER AMENDMENT 1.",
    "unresolved_questions": []
  }
}
```
</details>

_Model-generated review by Codex using the requested model, posted by the agent-review controller through the owner's GitHub account. Not a human review or approval._
