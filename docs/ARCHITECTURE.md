# Architecture

## Safety boundary

The mod patches no save creation, autosave selection, save eligibility, quicksave, manual-save, load, difficulty, death, or game-over presentation behavior. It applies four narrowly scoped Harmony hook sites:

1. `GameOverIronmanController.Activate()` prefix/postfix establishes and completes a scoped context.
2. `GameOverIronmanController.Deactivate()` prefix is a lifecycle cleanup fallback.
3. `GameMode.OnActivate()` postfix clears a context when its internal controller exception handler caught an `Activate` failure.
4. `SaveManager.DeleteSave(SaveInfo)` prefix delegates to the pure preservation policy.

All targets are resolved explicitly and their observed IL relationship is verified before patching. Any contract mismatch leaves all protection patches unapplied and exposes `UNAVAILABLE` in UMM.

## Responsibilities

| Area | Responsibility |
| --- | --- |
| `Patches/` | Thin Harmony bridge only; exceptions fail open and are logged. |
| `Integration/` | Exact Kingmaker contracts, active save identity, explicit-delete classification, compatibility, runtime status. |
| `Preservation/` | Context lifecycle, pure predicate, game-over orchestration. |
| `Recovery/` | Path validation, byte copy, hashing, metadata, markers, restore decisions. |
| `UI/` | UMM toggles/status and confirmation-gated fallback. |
| `Logging/` | UMM logging abstraction. |

## Interception lifecycle

`Activate` is synchronous in 2.1.7b. Its prefix verifies Only One Save plus an active IronMan `SaveInfo`, starts a 30-second/thread-bound context, and optionally creates a snapshot and marker. When `Activate` reaches `DeleteSave(SaveInfo)`, the deletion prefix requires every policy fact: feature enabled, Only One Save true, target IronMan, fresh context created by that game-over prefix, same managed thread, no explicit load-game deletion frame, and exact target identity match.

If all facts hold, Harmony skips only `DeleteSave`; `Activate` continues into its native loading-screen reset. The postfix evaluates the marker: the normal result is that the live source still exists, so the marker is cleared. If an alternate deletion somehow removed it during that marked synchronous operation, the validated snapshot is restored with create-new semantics and the save list is refreshed.

Harmony12 1.2 has no finalizer API. Therefore exception cleanup is layered: the postfix handles normal return; a postfix on `GameMode.OnActivate` runs after that method's own per-controller exception handler; `Deactivate` handles mode teardown; and UMM's next same-thread update atomically detaches any remaining context. A worker-thread context is allowed to expire rather than being cleared concurrently. A stale or cross-thread context cannot block deletion because freshness, thread, identity, mode, type, and settings are checked independently.

The deletion decision deliberately does not require reflection to find the original `Activate` method on the stack. A local Harmony12 probe showed that a patched target is represented by a dynamic wrapper and the original `MethodInfo`/metadata token is absent. Treating an exact frame as mandatory would therefore fail open during the operation the mod must protect. The prefix/postfix scope is the reliable lifecycle signal supported by the observed synchronous method.

## Recovery storage

Kingmaker computes its save root as `Path.Combine(ApplicationPaths.persistentDataPath, SaveManager.SaveFolderName)`, where the release value is `Saved Games`. The mod derives a sibling root:

```text
<Kingmaker persistent data>/LastAzlantiPreserver/Recovery/
  <sha256 identity>/
    snapshot.bin
    metadata.json
    pending.json     # exists only while an operation is unresolved
```

The identity hashes the normalized source path and campaign `GameId`. The `.bin` copy is outside `Saved Games` and cannot match the game's `*.zks`/`*.zip` scan. No gameplay object or save-owned mod state exists, so uninstalling the mod does not affect save deserialization.
