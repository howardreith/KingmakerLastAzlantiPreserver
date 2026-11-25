<!-- agent-review:v1 enrollment=klap-umm0311-codex-umm-0311-baseline-20261123-20261123162452-aa01 key=r08-review part=1/1 sha256=33d1b4d1e7dfcc79b8015196030514094c44ade3739a7d3755736f9d849b778b -->
### Codex GPT-6.2 Astra — review — round 8 — candidate `46a5c1d7a0`

**Decision:** `changes_required` — The candidate builds against UMM 0.31.1 and fixes all four reported cases. Two receipt-handling defects still affect readiness. One can admit a stale DLL after a material source-path change. The other can reject a valid supplied ZIP because the validator lacks write access to the repository’s package directory.

## Continuation for Claude

Limit corrections to the build receipt and the standalone validator’s optional refresh, consistent with OWNER AMENDMENT 1. Emit the generated-source marker only when framework-attribute generation is enabled. Allow validation of a supplied ZIP to finish when the optional publication lock or comparison is unavailable. Keep actual publication and shared-receipt writes locked, and preserve errors from invalid supplied bytes and explicitly requested reports. Exercise both cases with the existing disposable fixtures and run the configured qualify gate on the corrected candidate within the controller’s existing limits. The historical documentation correction is optional.

#### Findings

**R8-F1** · P2 · defect · blocks readiness — Preserve source-path identity when framework-attribute generation is disabled
- Location: `LoaderReferences.targets:64`; acceptance: §5, §6
- Trigger: GamePath.props sets GenerateTargetFrameworkAttribute=false, points TargetFrameworkMonikerAssemblyAttributesPath at an external FrameworkInfo.cs, and includes that file as a Compile item. The file uses CallerFilePath and is relocated to a byte-identical copy.
- Expected: An explicitly compiled external source retains its compiler-visible path identity when MSBuild’s framework-attribute generator is disabled.
- Actual: Line 64 emits the marker whenever TargetFrameworkMonikerAssemblyAttributesPath is nonempty. Common.ps1 consequently names both copies generated:FrameworkInfo.cs and omits their path digests. GamePath.props itself is outside the file fingerprint. The previous reader distinguished this ordinary filename, but the current comparison can accept the old DLL even though recompilation embeds a different caller path.
- Why it blocks / does not: Package.ps1 can accept a frozen DLL after a material compiler input changes.
- Requested correction: Condition the generated-source marker on framework-attribute generation being enabled. Let the existing external-source handling identify a manually included file when generation is disabled.
- Requested evidence: Use the existing CallerFilePath fixture with generation disabled and the Compile item pointing to the configured attribute path. Show initial package acceptance, refusal after relocation to an identical copy, and acceptance after rebuilding.

**R8-F2** · P2 · defect · blocks readiness — Allow standalone validation without write access to the package directory
- Location: `scripts/Validate-Package.ps1:141`; acceptance: §6
- Trigger: A published ZIP exists in a readable package directory that disallows lock-file creation. The caller validates a different readable ZIP with the default report path.
- Expected: Validation succeeds for the supplied bytes and leaves the public records untouched when the optional refresh cannot acquire its lock.
- Actual: The default-report branch calls Enter-PackagePublishLock before comparing digests. That helper opens .publish.lock for read/write with DeleteOnClose. A lock-creation failure escapes before the new read-error handlers run. Install.ps1 uses this default branch for its pre-install validation.
- Why it blocks / does not: A valid baseline ZIP can fail pre-install validation solely because an unrelated artifact directory refuses a write. The merge-base validator wrote its report in the qualification directory and did not need write access to the package directory.
- Requested correction: Treat inability to acquire the lock for the standalone refresh as a reason to skip that refresh. Preserve exclusive locking for publication and actual shared-receipt writes.
- Requested evidence: In the existing disposable fixture, make .publish.lock unavailable for writing while both ZIPs remain readable. Validate the distinct baseline ZIP with the default report path and show success with unchanged public records.

**R8-F3** · P3 · optional_polish · non-blocking — Correct the historical paragraph’s reference to the current run
- Location: `docs/UMM-COMPATIBILITY.md:263`; acceptance: §8
- Trigger: A reader follows the round-six history to identify the currently indexed boundary-suite result.
- Expected: The historical paragraph should direct readers to the current index while keeping its own run attributed to round six.
- Actual: The round-six history calls the current loader-baseline.json the round-seven run. The file and index identify 158/158 at 4b31509 as round eight.
- Why it blocks / does not: The index, structured record and current round-eight section give the correct attribution.
- Requested correction: Remove the stale parenthetical or point it to the evidence index.
- Requested evidence: Compare the revised sentence with the loader-baseline.json row in INDEX.md.

#### Prior finding assessments

- **R6-F2** — `fix_verified` — The filename-pattern collision is fixed. The recorded Shared.AssemblyAttributes.cs copies have distinct path digests. Relocation refused stale reuse, the differing rebuilt DLL was accepted, and the identical Managed-reference relocation control passed. R8-F1 concerns an ordinary filename newly misclassified when generation is disabled.
- **R7-F1** — `fix_verified` — With the published ZIP held under FileShare.None, the separate ZIP validated with exit 0 and all three public hashes stayed unchanged. Failure to copy the supplied archive still failed validation. R8-F2 concerns acquiring the separate publication lock.
- **R7-F2** — `fix_verified` — The reproduction guide names the Visual Studio Build Tools Roslyn fixture and the vswhere lookup for MSBuild\Current\Bin\Roslyn\csc.exe. Both match the test implementation and the indexed successful run.
- **R7-F3** — `fix_verified` — The WhatIf branch now says that the preview changes no published record. Source inspection establishes the wording, and the recorded preview confirms the supplied ZIP was preserved and no Mods folder was created.

#### Evidence assessment

- **Inspected:** The effective mission, OWNER AMENDMENT 1, AGENTS.md, the prior ledger, developer report, transcript notice and controller gate artifacts.; The full feature diff and the round-eight changes to LoaderReferences.targets, Common.ps1, Validate-Package.ps1, Test-LoaderBaseline.ps1, the compatibility guide and its evidence index. Traced the affected paths through Build-Local.ps1, Package.ps1, Qualify.ps1 and Install.ps1.
- **Executed verification:** Verified the supplied 5,432-line feature diff against Git, the mission and amendment hashes against the request, the controller log against its receipt, and all 18 exported evidence hashes against their committed Git blobs.; The controller receipt at 46a5c1d records qualify passing with 84/84 tests, zero compiler warnings or errors, and managed contract checks on the owner’s UMM 0.33.0 installation. The Release DLL SHA-256 was fadf2dab6ff3b8a92c81a3515b633f0de7482879ac5ca43a79ca9ac7c0031248.; The indexed run at 4b31509 records 158 distinct passing cases. It accepted baseline ZIP 83611dd565b69ac399b010fd57cc7f65e948fb7ece22417b8f82c19b65700adc and rejected the genuine v0.1.3 DLL compiled against UMM 0.33.0 after only its manifest was lowered. The reviewed commit adds only evidence files to 4b31509.; The archived records for the same DLL report resolution of 9 types and 25 members and successful out-of-game Harmony checks on UMM 0.31.1, 0.32.4, owner-installed 0.33.0 and 0.33.4. The mismatched Harmony2 control was refused.
- **Source inspection only:** R8-F1 and R8-F2 follow from the marker condition, fingerprint inputs, lock acquisition and error handling. Their specific triggers were not exercised in the indexed suite.; Verified the preview-specific status text in source. The recorded preview case checks exit status and filesystem effects without capturing that line.
- **Required gaps:** Show that a manually supplied source retains its path identity when framework-attribute generation is disabled.; Show that failure to acquire the optional publication lock leaves a valid external ZIP eligible for standalone validation.
- **Limitations:** The foreground transcript was withheld. The controller receipt establishes the exact-candidate gate run, which did not request packaging. The boundary-suite and cross-loader observations come from the indexed repository records at their stated identities.; The reviewer used read-only inspection. Native preservation, recovery, fresh-process reload and combined-stack behavior remain untested. The repository documents the unavailable approved disposable environment and makes no native compatibility claim.

#### Summary

- **Delivered behavior:** The Preserver declares UMM 0.31.1 and compiles against the pinned UnityModManager 0.31.1.0 and Harmony12 1.2.0.1 assemblies. The packaged DLL’s assembly references and MVID are recorded. Static and managed checks cover all four requested loader versions.
- **Scope reviewed:** Final review of Preserver PR #7 at 46a5c1d under OWNER AMENDMENT 1, including the four pending findings and the build and pre-install validation paths affected by their corrections.
- **Pending later-phase work:** none
- **Unresolved questions:** none
- **Remaining owner review:** Disposition of draft PR #7 after the blocking receipt issues are addressed, subject to the controller’s existing limits.; Any future authorization for disposable-campaign testing before claiming native preservation or recovery compatibility.

#### Provenance (controller-recorded)

| | Requested | Observed |
|---|---|---|
| Model | `gpt-6.2-astra` | `gpt-6.2-astra` (turns ['gpt-6.2-astra']) |
| Reasoning effort | `max` | `max` (turns ['max']) |
| Sandbox / approvals | read-only / never | `read-only` / `never` |

Owner guidance bound to this review: none.

Owner amendments bound to this review: revision 1, sha256 `d03b6c8b1287093dae038511d606914b65f9864b951ad86fbc5c65e4461a92ce`.

Codex CLI `0.170.0`, thread `01a2122c-b433-74f0-9b22-ae7b5b5f7287`, duration 777.7s, response sha256 `29b1de359568c2abd245cda9b79fd6a0e0c1bd95cbf8c34c28d56f942df277bb`, request `klap-umm0311-codex-umm-0311-baseline-20261123-20261123162452-aa01-r08-e72853`. Observed values come from the Codex session rollout's recorded thread settings, not from the model's own statements; the serving backend's model identity is not separately exposed.

<details><summary>Complete structured review (agent-review.review.v1)</summary>

```json
{
  "candidate_commit": "46a5c1d7a0aada2b3d233b12c49006f1b443e977",
  "checkpoint_id": "final",
  "checkpoint_type": "final",
  "decision": "changes_required",
  "decision_rationale": "The candidate builds against UMM 0.31.1 and fixes all four reported cases. Two receipt-handling defects still affect readiness. One can admit a stale DLL after a material source-path change. The other can reject a valid supplied ZIP because the validator lacks write access to the repository\u2019s package directory.\n\n## Continuation for Claude\n\nLimit corrections to the build receipt and the standalone validator\u2019s optional refresh, consistent with OWNER AMENDMENT 1. Emit the generated-source marker only when framework-attribute generation is enabled. Allow validation of a supplied ZIP to finish when the optional publication lock or comparison is unavailable. Keep actual publication and shared-receipt writes locked, and preserve errors from invalid supplied bytes and explicitly requested reports. Exercise both cases with the existing disposable fixtures and run the configured qualify gate on the corrected candidate within the controller\u2019s existing limits. The historical documentation correction is optional.",
  "evidence_assessment": {
    "executed_verification": [
      "Verified the supplied 5,432-line feature diff against Git, the mission and amendment hashes against the request, the controller log against its receipt, and all 18 exported evidence hashes against their committed Git blobs.",
      "The controller receipt at 46a5c1d records qualify passing with 84/84 tests, zero compiler warnings or errors, and managed contract checks on the owner\u2019s UMM 0.33.0 installation. The Release DLL SHA-256 was fadf2dab6ff3b8a92c81a3515b633f0de7482879ac5ca43a79ca9ac7c0031248.",
      "The indexed run at 4b31509 records 158 distinct passing cases. It accepted baseline ZIP 83611dd565b69ac399b010fd57cc7f65e948fb7ece22417b8f82c19b65700adc and rejected the genuine v0.1.3 DLL compiled against UMM 0.33.0 after only its manifest was lowered. The reviewed commit adds only evidence files to 4b31509.",
      "The archived records for the same DLL report resolution of 9 types and 25 members and successful out-of-game Harmony checks on UMM 0.31.1, 0.32.4, owner-installed 0.33.0 and 0.33.4. The mismatched Harmony2 control was refused."
    ],
    "inspected": [
      "The effective mission, OWNER AMENDMENT 1, AGENTS.md, the prior ledger, developer report, transcript notice and controller gate artifacts.",
      "The full feature diff and the round-eight changes to LoaderReferences.targets, Common.ps1, Validate-Package.ps1, Test-LoaderBaseline.ps1, the compatibility guide and its evidence index. Traced the affected paths through Build-Local.ps1, Package.ps1, Qualify.ps1 and Install.ps1."
    ],
    "limitations": [
      "The foreground transcript was withheld. The controller receipt establishes the exact-candidate gate run, which did not request packaging. The boundary-suite and cross-loader observations come from the indexed repository records at their stated identities.",
      "The reviewer used read-only inspection. Native preservation, recovery, fresh-process reload and combined-stack behavior remain untested. The repository documents the unavailable approved disposable environment and makes no native compatibility claim."
    ],
    "required_gaps": [
      "Show that a manually supplied source retains its path identity when framework-attribute generation is disabled.",
      "Show that failure to acquire the optional publication lock leaves a valid external ZIP eligible for standalone validation."
    ],
    "source_inspection_only": [
      "R8-F1 and R8-F2 follow from the marker condition, fingerprint inputs, lock acquisition and error handling. Their specific triggers were not exercised in the indexed suite.",
      "Verified the preview-specific status text in source. The recorded preview case checks exit status and filesystem effects without capturing that line."
    ]
  },
  "findings": [
    {
      "acceptance_ids": [
        "\u00a75",
        "\u00a76"
      ],
      "actual": "Line 64 emits the marker whenever TargetFrameworkMonikerAssemblyAttributesPath is nonempty. Common.ps1 consequently names both copies generated:FrameworkInfo.cs and omits their path digests. GamePath.props itself is outside the file fingerprint. The previous reader distinguished this ordinary filename, but the current comparison can accept the old DLL even though recompilation embeds a different caller path.",
      "blocking_rationale": "Package.ps1 can accept a frozen DLL after a material compiler input changes.",
      "blocks_readiness": true,
      "category": "defect",
      "expected": "An explicitly compiled external source retains its compiler-visible path identity when MSBuild\u2019s framework-attribute generator is disabled.",
      "id": "R8-F1",
      "location": {
        "file": "LoaderReferences.targets",
        "line": 64
      },
      "priority": "P2",
      "requested_correction": "Condition the generated-source marker on framework-attribute generation being enabled. Let the existing external-source handling identify a manually included file when generation is disabled.",
      "requested_evidence": "Use the existing CallerFilePath fixture with generation disabled and the Compile item pointing to the configured attribute path. Show initial package acceptance, refusal after relocation to an identical copy, and acceptance after rebuilding.",
      "title": "Preserve source-path identity when framework-attribute generation is disabled",
      "trigger": "GamePath.props sets GenerateTargetFrameworkAttribute=false, points TargetFrameworkMonikerAssemblyAttributesPath at an external FrameworkInfo.cs, and includes that file as a Compile item. The file uses CallerFilePath and is relocated to a byte-identical copy."
    },
    {
      "acceptance_ids": [
        "\u00a76"
      ],
      "actual": "The default-report branch calls Enter-PackagePublishLock before comparing digests. That helper opens .publish.lock for read/write with DeleteOnClose. A lock-creation failure escapes before the new read-error handlers run. Install.ps1 uses this default branch for its pre-install validation.",
      "blocking_rationale": "A valid baseline ZIP can fail pre-install validation solely because an unrelated artifact directory refuses a write. The merge-base validator wrote its report in the qualification directory and did not need write access to the package directory.",
      "blocks_readiness": true,
      "category": "defect",
      "expected": "Validation succeeds for the supplied bytes and leaves the public records untouched when the optional refresh cannot acquire its lock.",
      "id": "R8-F2",
      "location": {
        "file": "scripts/Validate-Package.ps1",
        "line": 141
      },
      "priority": "P2",
      "requested_correction": "Treat inability to acquire the lock for the standalone refresh as a reason to skip that refresh. Preserve exclusive locking for publication and actual shared-receipt writes.",
      "requested_evidence": "In the existing disposable fixture, make .publish.lock unavailable for writing while both ZIPs remain readable. Validate the distinct baseline ZIP with the default report path and show success with unchanged public records.",
      "title": "Allow standalone validation without write access to the package directory",
      "trigger": "A published ZIP exists in a readable package directory that disallows lock-file creation. The caller validates a different readable ZIP with the default report path."
    },
    {
      "acceptance_ids": [
        "\u00a78"
      ],
      "actual": "The round-six history calls the current loader-baseline.json the round-seven run. The file and index identify 158/158 at 4b31509 as round eight.",
      "blocking_rationale": "The index, structured record and current round-eight section give the correct attribution.",
      "blocks_readiness": false,
      "category": "optional_polish",
      "expected": "The historical paragraph should direct readers to the current index while keeping its own run attributed to round six.",
      "id": "R8-F3",
      "location": {
        "file": "docs/UMM-COMPATIBILITY.md",
        "line": 263
      },
      "priority": "P3",
      "requested_correction": "Remove the stale parenthetical or point it to the evidence index.",
      "requested_evidence": "Compare the revised sentence with the loader-baseline.json row in INDEX.md.",
      "title": "Correct the historical paragraph\u2019s reference to the current run",
      "trigger": "A reader follows the round-six history to identify the currently indexed boundary-suite result."
    }
  ],
  "prior_finding_assessments": [
    {
      "assessment": "fix_verified",
      "finding_id": "R6-F2",
      "rationale": "The filename-pattern collision is fixed. The recorded Shared.AssemblyAttributes.cs copies have distinct path digests. Relocation refused stale reuse, the differing rebuilt DLL was accepted, and the identical Managed-reference relocation control passed. R8-F1 concerns an ordinary filename newly misclassified when generation is disabled."
    },
    {
      "assessment": "fix_verified",
      "finding_id": "R7-F1",
      "rationale": "With the published ZIP held under FileShare.None, the separate ZIP validated with exit 0 and all three public hashes stayed unchanged. Failure to copy the supplied archive still failed validation. R8-F2 concerns acquiring the separate publication lock."
    },
    {
      "assessment": "fix_verified",
      "finding_id": "R7-F2",
      "rationale": "The reproduction guide names the Visual Studio Build Tools Roslyn fixture and the vswhere lookup for MSBuild\\Current\\Bin\\Roslyn\\csc.exe. Both match the test implementation and the indexed successful run."
    },
    {
      "assessment": "fix_verified",
      "finding_id": "R7-F3",
      "rationale": "The WhatIf branch now says that the preview changes no published record. Source inspection establishes the wording, and the recorded preview confirms the supplied ZIP was preserved and no Mods folder was created."
    }
  ],
  "request_id": "klap-umm0311-codex-umm-0311-baseline-20261123-20261123162452-aa01-r08-e72853",
  "round": 8,
  "schema_version": "agent-review.review.v1",
  "summary": {
    "delivered_behavior": "The Preserver declares UMM 0.31.1 and compiles against the pinned UnityModManager 0.31.1.0 and Harmony12 1.2.0.1 assemblies. The packaged DLL\u2019s assembly references and MVID are recorded. Static and managed checks cover all four requested loader versions.",
    "pending_later_phase_work": [],
    "remaining_owner_review": [
      "Disposition of draft PR #7 after the blocking receipt issues are addressed, subject to the controller\u2019s existing limits.",
      "Any future authorization for disposable-campaign testing before claiming native preservation or recovery compatibility."
    ],
    "scope_reviewed": "Final review of Preserver PR #7 at 46a5c1d under OWNER AMENDMENT 1, including the four pending findings and the build and pre-install validation paths affected by their corrections.",
    "unresolved_questions": []
  }
}
```
</details>

_Model-generated review by Codex using the requested model, posted by the agent-review controller through the owner's GitHub account. Not a human review or approval._
