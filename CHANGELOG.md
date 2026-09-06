# Changelog

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
