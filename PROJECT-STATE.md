# Project state

## Product

- Product/UMM ID/assembly: `Last Azlanti Preserver` / `KingmakerLastAzlantiPreserver` / `KingmakerLastAzlantiPreserver.dll`
- Version: `0.1.0`
- Target: Pathfinder: Kingmaker `2.1.7b`, UMM `0.32.x`, Harmony12, .NET Framework 4.7.2, C# 7.3
- Branch: `codex/last-azlanti-preserver-0.1.0`

## Implemented

- Exact-contract resolution with fail-closed MVID/SHA/signature/IL checks.
- Scoped `GameOverIronmanController.Activate` context and exact `SaveManager.DeleteSave(SaveInfo)` interception.
- Explicit load-game deletion, unrelated save, non-IronMan, wrong-thread, stale-context, and non-game-over pass-through policy.
- Exception-safe cleanup via the normal postfix, `GameMode.OnActivate`'s internally caught exception boundary, `Deactivate`, and a bounded update watchdog.
- One hidden, transactional, SHA-256-verified snapshot per source identity outside Kingmaker's save scanner.
- Pending-marker-bound automatic recovery only before the synchronous game-over scope closes; restart fallback is confirmation-gated in UMM.
- UMM settings, status, compatibility warnings, deterministic tests, contract verification, packaging, package validation, and transactional installer.

## Automated evidence

- Assembly-CSharp SHA-256: `3b6450ffec440e296e586f71c711b195aed144b28d53e1cbb29406d18fef5afb`
- Assembly-CSharp MVID: `07fa1e4d-8618-41b3-9b8d-faa17d3b26f7`
- Contract verification: passed; Harmony ownership verified after application in an isolated verification process.
- Harmony replacement evidence: `GameOverIronmanController.Activate` resolves to `System.Reflection.Emit.DynamicMethod` after patching, so lifecycle state rather than an unavailable original stack token is used.
- Behavior/filesystem tests: 26 passed, 0 failed.
- Production compilation: passed with 0 warnings and 0 errors.
- Release DLL SHA-256: `89dc72c1b331a818a7e6112b5c1d6b5d8d51d8027d74e1bc3d3168fb653ada23`
- Package SHA-256: `d320b8d71512af64ac423e03b3e4108ba6e7478f711a2c6e3e66cf1acba71afe`
- Package validation: passed with exactly six allowlisted files, assembly identity `KingmakerLastAzlantiPreserver, Version=0.1.0.0`.
- Transactional install: passed at `<KINGMAKER_INSTALL>/Mods/KingmakerLastAzlantiPreserver`; installed DLL hash matches the release DLL.
- Owner-authorized release disposition: publish actual stable/latest `v0.1.0` for main-computer testing before runtime qualification, with the unqualified status disclosed in release notes and manifest.
- Runtime qualification: **not performed**.
- Steam Cloud compatibility: **unqualified pending separate human test**.

Generated machine-readable evidence under `artifacts/` is intentionally ignored because it includes local paths. Git commit/push/draft-PR evidence is reported at handoff and does not alter the qualified package.
