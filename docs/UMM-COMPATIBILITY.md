# UMM compatibility baseline

## Contract

As requested on 2026-11-23, `Info.json` declares UMM **0.31.1**. Production
references come from `scripts/loader-reference-pins.json`, using the same upstream
0.31.1 and Harmony12 bytes already pinned by Kingmaker Cutscene Skip.
`scripts/Build-Local.ps1` downloads and hash-checks them under ignored
`artifacts/references`, and records their identities with the mod DLL hash.
`scripts/Package.ps1` rejects missing or mismatched loader-reference receipts.
The standalone ZIP validator also checks the packaged DLL AssemblyRef versions,
so installing a supplied ZIP cannot bypass the baseline by lowering only its manifest.
Direct MSBuild and IDE builds also verify the pinned hashes and assembly identities
through `LoaderReferences.targets`; replacing the cached DLL cannot bypass the guard.
`UnityModManagerDir` continues to identify the installed runtime for contract
checks; upgrading that installation does not change the production build baseline.
No loader or Harmony DLL is packaged or installed by these build changes.

The previous source manifest required 0.33.0; historical release records keep
their original versions and evidence. Existing published ZIPs are unchanged.

## Qualification status

This change sets the build and manifest contract. No full product build or new
in-game loader run has been completed for this change. The Windows game host was offline during the 2026-11-23 audit.
Passing a reference hash or member audit does not qualify game behaviour.

| Runtime | Required disposition |
| --- | --- |
| UMM 0.31.1 | Mandatory minimum-version build and disposable-game smoke before claiming support |
| UMM 0.32.4 | Compatibility target; run the same product smoke on the same candidate DLL |
| UMM 0.33.0 | Compatibility target; old evidence does not qualify the new baseline build |
| Other 0.31.x / 0.32.x / 0.33.x and later | Not qualified by this change; add the exact loader and Harmony identities before testing |

For every run record the mod DLL hash, UMM/Harmony hashes and versions, game
version, loaded mod set, settings round trip, enable/disable outcome, product
behaviour and save/reload outcome. Use only the existing disposable-game workflow.
The developer's live installation and saves must not be downgraded or replaced.

For Second to Last Azlanti, use a disposable Last Azlanti campaign and verify
preservation after death, both game-over load controls, recovery restoration and
non-Last-Azlanti/manual-deletion behaviour. Follow `docs/SMOKE-TEST.md`.
