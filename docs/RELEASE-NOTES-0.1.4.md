# Mr. Bard's Second to Last Azlanti 0.1.4

Unity Mod Manager 0.31.1 loader baseline. No gameplay change.

- **Lower loader minimum.** The declared Unity Mod Manager minimum is now **0.31.1** (0.1.3 declared 0.33.0 and its DLL referenced UnityModManager 0.33.0.0).
- **Pinned compile baseline.** The DLL is compiled against hash-pinned **UnityModManager 0.31.1.0** and **0Harmony12 1.2.0.1** references, independent of the loader installed on the build machine. The build and package checks refuse a DLL compiled against any other UnityModManager.
- **Unchanged.** Save preservation, game-over loading, recovery, the settings and their `Settings.xml` keys, the settings panel, the UMM ID, DLL, install folder and recovery location behave as in 0.1.3.

## Loader compatibility evidence

| Item | Status |
|---|---|
| Declared minimum (`Info.json` `ManagerVersion`) | UMM 0.31.1 |
| Pinned compile baseline | UnityModManager 0.31.1.0, 0Harmony12 1.2.0.1 (hash-pinned) |
| Static loader API audit | Every referenced loader member resolved on UMM 0.31.1, 0.32.4, 0.33.0 and 0.33.4 (static only) |
| Out-of-game managed checks | `scripts/Test-LoaderProfiles.ps1` applied and removed the product's Harmony patches through each of those four loader stacks, outside the game |
| Native gameplay and combined mod-stack testing | **NOT RUN** on any loader version |

The static audit and the out-of-game Harmony checks are not native compatibility testing, and they make no claim about future UMM versions.

## Testing and release disposition

This is an **owner-authorized** stable release: on 2026-11-26 the owner authorized merging the accepted UMM 0.31.1 loader baseline, tagging, and publishing 0.1.4 before any in-game test. 0.1.4 is **not runtime-qualified**. Automated compilation, the behavior/filesystem/settings tests, exact Kingmaker 2.1.7b core and game-over UI contract checks, Harmony ownership isolation, and package validation are required for the release. The **MANUAL RUNTIME TEST REQUIRED** boundary remains, and Steam Cloud remains separately unqualified.
