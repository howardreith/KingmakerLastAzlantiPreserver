<!-- agent-review:v1 enrollment=klap-umm0311-codex-umm-0311-baseline-20261123-20261123162452-aa01 key=r04-dispositions-3d05339dcd part=1/1 sha256=3d05339dcd627edd75bc2a2b6540d71f89080616839fcfe8c7d1b4dcc21cdf09 -->
### Claude Opus — finding dispositions — round 4

Candidate after corrections: `a66c49a8be3f5d1828b6cb4f80402943d6aa5564`

- **R1-F1** — `fixed` — commits: `5d00290`, `27713aa`, `a66c49a`
  docs/evidence/umm-0311/loader-baseline.json (128/128 on a temporary clone of 5d00290): package-reuse-after-base-address-change-rejected, rebuild-with-base-address-records-it (receipt option /baseaddress:0x11000000; DLL 44b24a21...), package-after-base-address-rebuild-accepted; rebuild-with-external-win32-resource-records-its-content (/win32res:external.res with the file's SHA-256; DLL 151c6e3e...), package-with-external-win32-resource-accepted, package-reuse-after-win32-resource-replaced-rejected (same path, new content), rebuild-after-win32-resource-replaced-changes-dll (DLL 94aa3715...), package-after-win32-resource-rebuild-accepted, rebuild-without-imported-options-reproduces-first-dll; package-with-identical-managed-references-elsewhere-accepted (relocation control kept); receipt-reference-inventory-equals-csc-inputs.
- **R1-F2** — `fixed` — commits: `5d00290`, `27713aa`, `a66c49a`
  docs/evidence/umm-0311/loader-baseline.json (128/128 on a temporary clone of 5d00290): package-document-restaged-before-archive-rejected (instrumented disposable Package.ps1 appends to the staged README after the staging copy: 'the archived documents differ from the verified repository files'), restage-refusal-preserves-accepted-zip-and-records, qualify-package-control-credited-after-staging-refusal (matching control).
- **R4-F1** — `fixed` — commits: `5d00290`, `27713aa`, `a66c49a`
  docs/evidence/umm-0311/loader-baseline.json (128/128 on a temporary clone of 5d00290): qualify-identifies-tested-substitute-after-output-restored (the test project's output copy restored to the genuine DLL after the runner exits; tests.json still names the substitute a14c2a44... and Qualify fails 'tests did not run against the current DLL'), qualify-fails-when-tests-ran-against-a-different-dll, qualify-build-and-test-control-passes.
- **R4-F2** — `fixed` — commits: `5d00290`, `27713aa`, `a66c49a`
  docs/evidence/umm-0311/loader-baseline.json (128/128 on a temporary clone of 5d00290): qualify-build-only-without-runtime-loader-gives-no-test-credit (after a passing -Test run, a build-only qualification with no loader directory reports 0 tests 'not run in this qualification'), qualify-build-only-after-source-change-inherits-no-test-pass.
- **R4-F3** — `fixed` — commits: `5d00290`, `27713aa`, `a66c49a`
  docs/evidence/umm-0311/loader-baseline.json (128/128 on a temporary clone of 5d00290): staging-refusal-preserves-accepted-zip-and-records (validated ZIP, package.json and package-validation.json byte-identical immediately after the document-change refusal, without repackaging), package-document-changed-during-staging-rejected.
- **R4-F4** — `fixed` — commits: `a66c49a`
  docs/evidence/umm-0311/INDEX.md: the sha256sum pipeline is labelled for Git Bash or a POSIX shell, and the Python command for Windows PowerShell and cmd.exe; run from Windows PowerShell it reproduces the indexed Git-blob digests (checked for api-audit.json).

**Validation (developer-reported):**

| Command | Required | Result | Duration | Scope and limits |
|---|---|---|---|---|
| python C:/Dev/agent-review/agent_review.py verify --enrollment klap-umm0311-codex-umm-0311-baseline-20261123-20261123162452-aa01 --gate qualify | yes | pass | 10.6s | Controller receipt on a66c49a. |
| scripts/Test-LoaderBaseline.ps1 (temporary clone of 5d00290) | no | pass | ~20 min | 128/128; docs/evidence/umm-0311/loader-baseline.json (128/128 on a temporary clone of 5d00290). |
| scripts/Qualify.ps1 -Build -Test -VerifyContracts -Package on a clean clone of 5d00290 | no | pass | ~3 min | qualification-summary.json, build.json (Csc command-line inventory), tests.json (private-copy DLL identity), contracts, package records. Owner loader 0.33.0 configured (read only). |
| scripts/Test-LoaderProfiles.ps1 (0.31.1, 0.32.4, owner-0.33.0, 0.33.4, mismatch) | no | pass | ~2 min | loader-profiles-managed.json: four profiles passed in separate processes on one frozen DLL; mismatch refused. Out-of-game managed checks. |
| LoaderApiAudit on fadf2dab; profile inventory; docs link check | no | pass | ~2s | api-audit.json (9 types/25 members resolved on all four profiles), loader-profile-inventory.json, docs-link-check.json (0 broken). |
| Native disposable-campaign smoke on UMM 0.31.1 / 0.32.4 / 0.33.0 / 0.33.4 | no | not_run | 0 | No disposable game copy; live installation must not be modified. |

_Model-generated developer response (Claude opus / high), posted by the agent-review controller through the owner's GitHub account; not a human review._
