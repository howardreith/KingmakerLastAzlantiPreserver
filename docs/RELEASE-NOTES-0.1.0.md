# Last Azlanti Preserver 0.1.0

Initial compilation-qualified release candidate for Pathfinder: Kingmaker 2.1.7b.

Release disposition: the owner explicitly authorized `v0.1.0` as the actual stable release for main-computer testing before human runtime qualification. Runtime and Steam Cloud qualification remain pending; publication is not a claim that those tests passed.

- Preserves the one legitimate Last Azlanti autosave when the native game-over controller tries to delete it.
- Leaves native game-over presentation and loading-screen cleanup running.
- Does not enable quick/manual saves, add slots, alter autosaves, change rules, or auto-reload.
- Allows explicit load-game deletion and leaves ordinary campaigns untouched.
- Maintains an optional hidden, current-only, SHA-256-verified recovery snapshot outside the save list.
- Fails closed on unsupported game contracts and reports status in UMM.

Automated source/build/contracts/filesystem/package qualification is complete. Human disposable-campaign runtime qualification and separate Steam Cloud qualification remain required; no runtime compatibility claim is made yet.
