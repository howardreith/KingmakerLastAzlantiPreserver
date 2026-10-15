# Changelog

## 0.1.2 - 2026-10-15

- Renamed the public display name to **Mr. Bard's Second to Last Azlanti** and the Unity Mod Manager author to **Mr. Bard**; the UMM settings title, load log line, and assembly title/product/company show the new name.
- Kept the UMM `Id`, DLL/assembly name, `EntryMethod`, namespaces, Harmony owner IDs, install folder, settings, and recovery directory unchanged so the update installs over Last Azlanti Preserver 0.1.0/0.1.1 as the same mod.
- Pending recoveries are accepted by their supported recovery format (format 1, unchanged since v0.1.0) instead of exact equality with the running mod version. The writer's `ModVersion` is kept as provenance and must be a well-formed release number; unknown, missing, or disagreeing metadata/marker formats are still rejected. A valid recovery left pending by 0.1.0/0.1.1 can now be restored by 0.1.2. All length, SHA-256, identity, path, marker, timing, reparse-point, no-overwrite, and confirmation checks are unchanged.
- Added tests that restore the verbatim recovery files written by the published v0.1.1 DLL and cover newer writers, unsupported formats, malformed writer versions, tampering, and evaluation without rewrites; added package and repository checks for the exact branded manifest and stable identity.
- The guarded publisher derives the release version, title, asset, and notes from the committed manifest and requires a dated owner authorization for the exact version on its pre-runtime path.
- Owner-authorized stable release, **not runtime-qualified**: the **MANUAL RUNTIME TEST REQUIRED** boundary from v0.1.1 still applies.

## 0.1.1 - 2026-09-06

- Added a default-enabled, independently gated option to use Kingmaker's native Load Last Save and Load Game controls on the standalone Beneath the Stolen Lands game-over screen after a matching live Last Azlanti save was actually preserved.
- Added live save-root, file, mode, save-type, native-selection, operation-identity, and staleness revalidation at bind and action time; a hidden snapshot alone never grants loading.
- Preserved native callbacks and cancellation behavior while clearing the UI-only operation at load, Start Again, Main Menu, later game-over, disable/unload, and failure boundaries.
- Split core and optional UI Harmony ownership, status, compatibility reporting, and failure cleanup so optional unavailability cannot remove core protection.
- Added exact desktop/controller 2.1.7b UI contract and Harmony-isolation verification, expanded behavior tests, settings migration coverage, and settings-preserving transactional installation.
- Published under the owner's explicit pre-runtime authorization; GUI and Steam Cloud qualification remain pending until personally observed, and publication is not a claim that either passed.

## 0.1.0 - 2026-09-03

- Added game-over-only preservation of Kingmaker Last Azlanti saves.
- Added one hidden, transactional recovery snapshot per active save identity.
- Added guarded recovery, UMM settings/status, compatibility diagnostics, contract verification, tests, packaging, and transactional installation tooling.
