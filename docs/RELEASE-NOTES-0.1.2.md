# Mr. Bard's Second to Last Azlanti 0.1.2

Formerly **Last Azlanti Preserver**. Same mod, new name, plus recovery data that survives updates.

- **New name and author.** Unity Mod Manager now lists the mod as **Mr. Bard's Second to Last Azlanti** by **Mr. Bard**. The UMM ID `KingmakerLastAzlantiPreserver`, the DLL, its entry point, the `Mods/KingmakerLastAzlantiPreserver` folder, `Settings.xml`, and the `LastAzlantiPreserver/Recovery` directory are unchanged, so 0.1.2 installs over 0.1.0 or 0.1.1 as the same mod and keeps your settings.
- **Recovery compatibility across releases.** A pending recovery is now accepted by its recovery format (format 1, unchanged since v0.1.0) instead of the exact mod version that wrote it. A valid recovery left pending by 0.1.0 or 0.1.1 can be restored by 0.1.2 from the UMM panel. Missing, unknown, or disagreeing format versions and malformed writer versions are still rejected, and every length, SHA-256, identity, path, marker, timing, no-overwrite, and explicit-confirmation check is unchanged. Nothing is migrated or rewritten.
- **No gameplay change.** Save preservation, the optional game-over loading controls, deletion behavior, and ordinary campaigns behave exactly as in 0.1.1.

## Testing and release disposition

This is an **owner-authorized** stable release: on 2026-10-15 the owner authorized merging, tagging, and publishing 0.1.2 without an additional human playtest. 0.1.2 is **not runtime-qualified**. Automated compilation, behavior/filesystem/settings tests, exact Kingmaker 2.1.7b core and game-over UI contract checks, Harmony ownership isolation, and package validation are required for the release. The cross-release recovery path is covered by tests that restore the verbatim recovery files written by the published v0.1.1 DLL; it has not been exercised in a running game. The v0.1.1 game-over loading controls remain **MANUAL RUNTIME TEST REQUIRED**, and Steam Cloud remains separately unqualified.
