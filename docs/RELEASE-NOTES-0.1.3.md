# Mr. Bard's Second to Last Azlanti 0.1.3

A cleaner Unity Mod Manager settings panel. No gameplay change.

- **Simpler panel.** Three settings with plain labels: **Keep your Last Azlanti save after defeat**, **Allow loading from the game-over screen**, and **Keep a hidden recovery backup**. A one-line note says that Last Azlanti's normal saving restrictions remain unchanged, and a short status shows whether save protection, game-over loading, and the recovery backup are Ready, Off, or Unavailable. The duplicate name/version heading is gone.
- **Troubleshooting on request.** Verbose diagnostics, hook names, patch, eligibility, and save-recognition details, the recovery directory, the latest recovery/interception/error results, and the full compatibility report are in a collapsed **Troubleshooting** section.
- **Problems stay visible.** An unavailable feature, a failure at the last defeat, a loaded FirstAzlanti mod, and other mods patching the same game code are reported in short messages that name the affected feature. Other mods' patches are shown as unverified compatibility, not as a conflict, and a game-over loading problem no longer reads like a save-protection failure.
- **Recovery only when needed.** The restore controls appear only when a pending recovery needs attention. A restorable recovery still requires the explicit confirmation; a recovery that fails validation is shown as blocked, with its reason, and cannot be restored.
- **Unchanged.** The settings, their `Settings.xml` keys and defaults, save preservation, game-over loading, recovery validation and format compatibility, manual deletion, and ordinary campaigns behave as in 0.1.2.

## Testing and release disposition

This is an **owner-authorized** stable release: on 2026-10-15 the owner authorized merging, tagging, and publishing 0.1.3 before inspecting the new panel in-game. 0.1.3 is **not runtime-qualified**. Automated compilation, the behavior/filesystem/settings tests (including panel tests for each status, warning, and recovery state), exact Kingmaker 2.1.7b core and game-over UI contract checks, Harmony ownership isolation, and package validation are required for the release. The new panel has not been displayed in a running game: its layout and wrapping, like the v0.1.1 game-over loading controls, remain **MANUAL RUNTIME TEST REQUIRED**. Steam Cloud remains separately unqualified.
