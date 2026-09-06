# Project state

## Product

- Product/UMM ID/assembly: `Last Azlanti Preserver` / `KingmakerLastAzlantiPreserver` / `KingmakerLastAzlantiPreserver.dll`
- Candidate version: `0.1.1`
- Target: Pathfinder: Kingmaker `2.1.7b`, owner-approved UMM `0.33.0`, installed `0Harmony12`/Harmony `1.2.0.1`, .NET Framework 4.7.2, C# 7.3
- Feature branch: `codex/game-over-load-controls-v0.1.1`
- Accepted base: `main` at `a65dc113b1daddc8b2903fd6d29a19cecb125aad`

## Implemented candidate

- Retains the accepted exact-contract `GameOverIronmanController.Activate` scope and `SaveManager.DeleteSave(SaveInfo)` preservation policy without broadening deletion authority.
- Resolves and owns core preservation separately from the optional game-over loading enhancement; optional failure/unpatch leaves core ownership intact.
- Elevates only the two native desktop/controller Endless game-over loading controls after a matching deletion suppression and live-source validation.
- Revalidates mod/core/settings state, game-over and Endless mode, Only One Save, current native IronMan save, nonempty native folder, direct-child save-root containment, ordinary live file, exact operation identity, freshness, and the exact native callback selection at bind/action time.
- Keeps Load Last Save and Load Game on Kingmaker's native callbacks; Load Game cancellation retains the same operation for revalidation while an actual load and all terminal boundaries revoke it.
- Keeps UI-only outcome state separate from the synchronous deletion/recovery scope. A hidden snapshot cannot grant loading, suppress deletion, or become a visible save.
- Adds the default-enabled `EnableGameOverLoadControls` UMM setting, migration behavior, separate core/UI status and conflicts, latest eligibility reason, and owned-state restoration.
- Preserves an existing ordinary UMM `Settings.xml` during transactional installation.

## Candidate automated evidence

- Assembly-CSharp SHA-256: `3b6450ffec440e296e586f71c711b195aed144b28d53e1cbb29406d18fef5afb`
- Assembly-CSharp MVID: `07fa1e4d-8618-41b3-9b8d-faa17d3b26f7`
- UMM identity: `UnityModManager, Version=0.33.0.0`; SHA-256 `63e5baf7b1738e4091b5fd17ccb738ecdb4d1dbf246061dfd55dc52835d52691`; MVID `54059519-2754-445a-b5ee-fdb9326336e2`
- Harmony identity: `0Harmony12, Version=1.2.0.1`; SHA-256 `aa1cd48317254985d8b700cc74953477d1b40c3022ce9aa4c95ed2b8327e1292`; MVID `918c071f-383e-46dc-a374-6879300cbe15`
- Exact core contract verification: passed against the canonical local assembly.
- Exact optional UI contract verification: passed for `GameOverCanvas.PreShow()`, `EndlessGameOverView.PreShow()`, and `EndlessGameOverMenuPartVm..ctor()` plus their exact controls, callbacks, and load flows.
- Harmony ownership: five core patch entries and fifteen optional patch targets applied and observed; removing the optional owner left all core entries owned.
- Behavior/filesystem/settings/status tests: 62 passed, 0 failed.
- Production compilation: passed with 0 warnings and 0 errors.
- Final DLL/package hashes and local candidate installation are recorded in ignored qualification evidence and the private implementation handoff after final qualification.

## Historical v0.1.0 evidence

- v0.1.0 automated qualification recorded 26/26 tests, exact core contracts, zero-warning compilation, package validation, and transactional installation under its then-measured UMM 0.32.4 environment.
- The owner subsequently observed core preservation work in one disposable standalone Beneath the Stolen Lands Last Azlanti run: party death reached the normal results screen; Start Again and Main Menu remained available; Load Last Save and Load Game were visible but disabled; returning to Main Menu successfully loaded the preserved native save.
- That observation is positive evidence for v0.1.0 core preservation in that scenario. It is not a v0.1.1 GUI pass, full runtime qualification, or Steam Cloud qualification.
- The setup session for this machine retained owner-approved UMM 0.33.0, passed managed assembly/configuration checks, and installed v0.1.0 as the sole mod, but expressly did not launch Kingmaker or touch saves.

## Runtime and release disposition

- Runtime qualification: **MANUAL RUNTIME TEST REQUIRED / not performed**.
- Steam Cloud compatibility: **unqualified pending separate deliberate test**.
- Owner-authorized pre-runtime release: **approved for v0.1.1 on 2026-09-06**. The owner explicitly requested finalization, merge, tag, and stable publication before personally installing and performing the disposable-campaign GUI checks.
- That authorization changes the publication disposition only. It is not runtime evidence, does not mark the release runtime-qualified, and does not qualify Steam Cloud.
- The guarded publisher retains the stricter accepted-runtime path and has a separate, explicit v0.1.1 owner-authorized path that records `runtime_qualified: false` in release provenance.

Generated machine-readable evidence under `artifacts/` is intentionally ignored because it includes local paths. Installation is recorded separately from runtime testing.
