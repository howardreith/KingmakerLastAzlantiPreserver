# Architecture

## Safety boundary

Version 0.1.1 has two independent Harmony owners.

The critical core owner retains the accepted v0.1.0 seams:

1. `GameOverIronmanController.Activate()` prefix/postfix establishes and completes a synchronous preservation context.
2. `GameOverIronmanController.Deactivate()` prefix is a lifecycle cleanup fallback.
3. `GameMode.OnActivate()` postfix clears a context when its internal controller exception handler caught an `Activate` failure.
4. `SaveManager.DeleteSave(SaveInfo)` prefix delegates to the pure preservation policy.

The optional owner affects only the standalone Endless game-over loading experience and its state boundaries:

- a postfix on `GameOverCanvas.PreShow()` runs after vanilla dispatches `EndlessGameOverView.PreShow()` and receives the exact serialized `m_EndlessGameOverView`;
- prefixes on the two desktop native actions revalidate permission, while Start Again and Main Menu only clear UI state;
- the console Endless menu constructor and its two exact condition delegates refresh only `LoadLastSaveVm` and `LoadVm`, and action/terminal methods have equivalent revalidation or cleanup;
- `Game.LoadGame(SaveInfo)` has a state-clear-only prefix, and `SaveManager.DeleteSave(SaveInfo)` has a UI-outcome-clear-only postfix.

The optional patches never choose a save, open a replacement window, deserialize, delete, or suppress a delete. Native callbacks remain authoritative. A negative or uncertain UI decision does not force controls disabled; it leaves vanilla state untouched, except that the coordinator may restore only its own earlier elevation on the same verified view. The action prefixes pass through when Kingmaker's native `OnlyOneSave` gate is off, preserving ordinary Endless behavior; when that gate is on, a failed live revalidation blocks only an action that vanilla made unavailable.

Core contracts resolve and patch first. Optional contracts use a separate resolver and Harmony ID. Optional resolution, application, ownership, or compatibility failure restores any owned control state and unpatches only the optional owner. Core protection can continue to report `AVAILABLE` while game-over loading reports `UNAVAILABLE` or `DISABLED`.

## Responsibilities

| Area | Responsibility |
| --- | --- |
| `Patches/` | Thin, exception-safe Harmony delegation; uncertain action authorization fails to the vanilla-disabled path. |
| `Integration/` | Exact Kingmaker contracts, live save identity/path checks, UI outcome lifetime, control ownership, compatibility, and runtime status. |
| `Preservation/` | Synchronous deletion context, pure deletion predicate, and game-over orchestration. |
| `Recovery/` | Path validation, byte copy, hashing, metadata, markers, and restore decisions. |
| `UI/` | UMM settings/status and confirmation-gated fallback. |
| `Logging/` | UMM logging abstraction. |

## Core interception lifecycle

`Activate` is synchronous in 2.1.7b. Its prefix verifies Only One Save plus an active IronMan `SaveInfo`, starts a 30-second/thread-bound context, and optionally creates a snapshot and marker. When `Activate` reaches `DeleteSave(SaveInfo)`, the deletion prefix requires every policy fact: feature enabled, Only One Save true, target IronMan, fresh context created by that game-over prefix, same managed thread, no explicit load-game deletion frame, and exact target identity match.

If all facts hold, Harmony skips only `DeleteSave`; `Activate` continues into its native loading-screen reset. The postfix evaluates the marker and always closes the synchronous core scope. The normal result is that the live source still exists, so the marker is cleared. If an alternate deletion removed it during that marked synchronous operation, the validated snapshot is restored with create-new semantics and the save list is refreshed.

Harmony12 1.2 has no finalizer API. Exception cleanup therefore remains layered through the normal postfix, `GameMode.OnActivate`'s internally caught exception boundary, `Deactivate`, and a bounded update watchdog. A stale or cross-thread context cannot block deletion because freshness, thread, identity, mode, type, and settings are checked independently.

## UI-only preserved-operation lifecycle

The UI lifetime is not the deletion lifetime. Only after core completion has closed the synchronous context may the coordinator record an operation GUID plus the exact preserved `SaveIdentity`, and only when a matching live native source still exists. This outcome cannot authorize deletion suppression or recovery.

At desktop binding, `GameOverCanvas.PreShow()` has already allowed vanilla to calculate both button states. The mod captures the exact two baseline `Button.interactable` values and enables only those controls on a positive live decision. At console binding, the two existing `ContextMenuEntityVM` conditions are overridden only when the same positive predicate holds and are refreshed through their native `Refresh()` method.

Before Load Last Save, the service revalidates the live file and the exact native selection, then clears the operation as native loading starts. Before Load Game, it revalidates but retains the operation because opening/cancelling the overlay is not a load or terminal transition. `Game.LoadGame`, Start Again, Main Menu, the next game-over prefix, disable/unload, or failure clears the outcome. Explicit deletion from the open native window still reaches the core deletion prefix outside its synchronous authority and passes through; the optional postfix then clears the UI-only outcome outright. During the scoped game-over suppression that same postfix clears an empty/pre-bind state, after which normal core completion records the newly verified outcome.

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
