# Last Azlanti Preserver 0.1.1

Scoped game-over loading controls for Pathfinder: Kingmaker 2.1.7b.

- Enables only Kingmaker's native Load Last Save and Load Game controls on the standalone Beneath the Stolen Lands results screen after the exact live Last Azlanti save was preserved.
- Revalidates the current game-over operation, native IronMan identity, direct-child save-root path, live source file, and exact native callback selection at bind and action time.
- Uses Kingmaker's own load-last callback, load window, cancellation behavior, navigation, and loading flow; it adds no visible save, replacement loader, automatic reload, or silent navigation.
- Adds a default-enabled independent UMM setting and restores only feature-owned control state when disabled.
- Keeps critical core preservation and optional UI contracts/Harmony ownership isolated so UI incompatibility fails to vanilla disabled controls without removing save protection.
- Leaves one-save discipline, autosaves, Start Again, Main Menu, ordinary campaigns, and explicit load-window deletion native.

The v0.1.0 core was owner-observed preserving a save in one disposable standalone scenario, but its two results-screen loading controls stayed disabled and required returning to Main Menu. v0.1.1 addresses only that scoped UI gap.

Automated compilation, 62 behavior/filesystem/settings tests, exact canonical core/UI contracts, Harmony ownership isolation, and package validation are required for the candidate. v0.1.1 is **not runtime-qualified** until the disposable-campaign GUI checklist passes; Steam Cloud remains separately unqualified. Preparation or local installation is not a runtime compatibility claim and does not authorize publication.
