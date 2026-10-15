# Nexus Mods release copy

Prepared for the **unreleased v0.1.2 branding candidate**. Nothing here has been uploaded. Before posting, publish the GitHub release first, then copy the final file name and SHA-256 from its `SHA256SUMS.txt` into this page.

## Title

```text
Mr. Bard's Second to Last Azlanti
```

## Short description (search results)

```text
Stops Kingmaker's game-over screen from deleting your only Last Azlanti autosave. Optionally lets you use Load Last Save / Load Game on the Beneath the Stolen Lands results screen. Formerly Last Azlanti Preserver.
```

## Description

In a **Last Azlanti** (Only One Save) run, Pathfinder: Kingmaker deletes your single autosave when the party dies. This mod lets the normal game-over sequence run and blocks only that one deletion, so the save is still there afterwards.

**What it does**

- **Keeps the save.** It acts only when Only One Save is on, the active save is the Last Azlanti (IronMan) save, and the deletion comes from the game-over sequence. Everything else in that sequence runs as normal.
- **Leaves your own deletions alone.** Deleting a save yourself from the load screen works exactly as in the base game and is never undone. Ordinary campaigns are unaffected.
- **Optional hidden recovery snapshot** (on by default). Before the game-over deletion call, it keeps one verified copy of the save outside the `Saved Games` folder. Kingmaker never lists that copy as a save. A restore never overwrites an existing file and needs an explicit confirmation in the Unity Mod Manager panel.
- **Optional game-over loading** (added in 0.1.1, on by default). On the standalone Beneath the Stolen Lands results screen, once the mod has actually preserved the live save, Kingmaker's own **Load Last Save** and **Load Game** buttons work, so you don't have to go back to the main menu. The buttons, loading flow and cancel behavior are still the game's own. *This feature has not yet been tested in a running game; see Known limitations.*
- **Unity Mod Manager panel** with four settings (preserve on game over, game-over loading, hidden recovery snapshot, verbose diagnostics), plus status lines for core protection, game-over loading, recovery and compatibility warnings.

**What it does not do:** enable manual saving or quicksaving, add save slots, change autosave timing, change difficulty or death rules, create a visible extra save, skip the game-over screen, or reload automatically.

## Requirements

- **Pathfinder: Kingmaker 2.1.7b**; see Supported game version.
- **Unity Mod Manager 0.33.0** (the manifest's minimum `ManagerVersion`). The mod uses the Harmony 1.2 library (`0Harmony12`, 1.2.0.1) that ships with Unity Mod Manager. Neither is included in this download.
- No other mods are required.

## Installation

1. Close Pathfinder: Kingmaker.
2. Disable or remove the original **FirstAzlanti** mod if you use it. Don't run both.
3. Download `KingmakerLastAzlantiPreserver-0.1.2.zip` from the Files tab.
4. In Unity Mod Manager, select Pathfinder: Kingmaker, open the **Mods** tab, and drag the ZIP in (or use its install button). The archive contains one `KingmakerLastAzlantiPreserver` folder, which ends up as `<Kingmaker install>/Mods/KingmakerLastAzlantiPreserver`.
5. Start the game, open the Unity Mod Manager window, and check that **Mr. Bard's Second to Last Azlanti** (version 0.1.2, author Mr. Bard) is enabled and that its panel reports **Core preservation: AVAILABLE**.

## Upgrading from Last Azlanti Preserver 0.1.0 or 0.1.1

Versions 0.1.0 and 0.1.1 were published as **Last Azlanti Preserver**. Version 0.1.2 only changes the name, author and version shown in Unity Mod Manager. The technical mod ID (`KingmakerLastAzlantiPreserver`), DLL, entry point, install folder and recovery location are unchanged.

- **Install it over the old version.** It uses the same folder and mod ID, so Unity Mod Manager lists it under the new name instead of adding a second mod.
- **Your settings carry over.** The download contains no `Settings.xml`, and the settings themselves have not changed. If you want a fallback, back up `Mods/KingmakerLastAzlantiPreserver/Settings.xml` first.
- **Finish any pending recovery first.** Before upgrading, open the mod's panel and read the **Guarded recovery** line. If it says a validated pending recovery can restore a save, complete that restore with your current version before upgrading. Recovery data records the exact mod version that created it, and 0.1.2 will not restore a recovery created by 0.1.0 or 0.1.1. A rejected recovery is not deleted; its files stay in `<Kingmaker persistent data>/LastAzlantiPreserver/Recovery`.
- Gameplay behavior is identical to 0.1.1.

## Supported game version

- Pathfinder: Kingmaker **2.1.7b** only. The mod was built and checked against the Steam release (app 640820, build 6757524).
- On load, the mod compares the game's `Assembly-CSharp.dll` with that exact 2.1.7b build. On any other build it doesn't patch the game; the panel reports core preservation as unavailable and the game behaves normally. Copies from other storefronts are untested and work only if their game assembly is identical.

## Known limitations

- **Runtime testing is incomplete.**
  - The core save preservation from v0.1.0 has been seen working by the author in one throwaway standalone Beneath the Stolen Lands Last Azlanti run: the party died, the results screen appeared, and the kept save loaded from the main menu. That is one scenario, not full testing.
  - The **game-over loading buttons** added in v0.1.1 have passed automated tests and exact checks against the game's code, but have **not yet been tested in a running game**. They still need manual runtime testing.
  - Version 0.1.2 contains the same code and has not been launched in game either.
- **Steam Cloud** has not been tested.
- **Controller** navigation of the game-over loading buttons has not been tested.
- The loading buttons apply only to the standalone **Beneath the Stolen Lands** results screen. They are disabled again by loading, Start Again, Main Menu, another game over, turning the setting or mod off, or a failed safety check.
- Deleting a save from the game-over **Load Game** window still deletes it, just as in the base game, and is never undone.
- A pending recovery only works with the exact mod version that created it (see Upgrading).

## Compatibility

- This is a standalone mod. It doesn't depend on, and isn't part of, any other gameplay mod.
- It patches `GameOverIronmanController.Activate`/`Deactivate`, `GameMode.OnActivate` and `SaveManager.DeleteSave(SaveInfo)`. The optional loading feature also patches the game-over results screen. Core protection and the optional feature are patched separately, so if the optional feature fails, the buttons stay at their normal disabled state and the save is still protected.
- The panel warns if the original FirstAzlanti mod is loaded, and if another mod has patched the same game methods.
- The mod stores its own data only in its Unity Mod Manager `Settings.xml` and the hidden recovery folder. It does not add content to your saves.

## Credits and permissions

- **Author:** Mr. Bard.
- **FirstAzlanti** (KingmakerFumi) by **Truinto**, MIT License. This mod's approach was informed by FirstAzlanti's identification of the game-over seam. It is a new implementation that keeps `Activate` running and blocks only the exact game-over deletion. The full upstream MIT notice is included as `licenses/FIRST-AZLANTI-MIT.txt`, and the details are in `THIRD-PARTY-NOTICES.md`.
- **Unity Mod Manager** and **Harmony** are required, but neither is included in this download.
- **License:** MIT (see `LICENSE` in the download). Reuse, modification and redistribution are allowed as long as the copyright and permission notice is kept. Choose Nexus permission settings that match the MIT terms (owner decision).

## Source code and bug reports

- Source: <https://github.com/howardreith/KingmakerLastAzlantiPreserver>
- Bug reports: <https://github.com/howardreith/KingmakerLastAzlantiPreserver/issues>

When you report a bug, please include your game version, Unity Mod Manager version, mod version, the status lines from the mod's panel, your other enabled mods, and the Unity Mod Manager log (with **Verbose diagnostics** on, if you can reproduce the problem). Please don't post save files you care about.

## Nexus changelog entry (0.1.2)

- Renamed to **Mr. Bard's Second to Last Azlanti** (formerly Last Azlanti Preserver), with Mr. Bard as author. The mod ID, install folder and settings are unchanged, and gameplay is unchanged.
