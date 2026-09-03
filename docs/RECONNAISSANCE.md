# Kingmaker 2.1.7b reconnaissance

## Evidence identity

The installed title was discovered from Steam registry metadata, `libraryfolders.vdf`, and app manifest `appmanifest_640820.acf`; no Steam path was assumed. Committed documentation represents it as `<KINGMAKER_INSTALL>` and the managed root as `<KINGMAKER_MANAGED>`. The ignored `GamePath.props` contains the actual local path.

- Steam App ID: `640820`
- installed depot build ID: `6757524`
- `<KINGMAKER_INSTALL>/Kingmaker_Data/resources.assets` contains serialized `Version` value `2.1.7b`
- `Assembly-CSharp.dll` length: `7,262,208` bytes
- `Assembly-CSharp.dll` SHA-256: `3b6450ffec440e296e586f71c711b195aed144b28d53e1cbb29406d18fef5afb`
- `Assembly-CSharp.dll` module MVID: `07fa1e4d-8618-41b3-9b8d-faa17d3b26f7`
- local UMM assembly identity: `UnityModManager, Version=0.32.4.0`; SHA-256 `1387468bc3af41c50fe51859a3bb7af4922891aa8f13a6187e7a348ceaabfd88`
- local Harmony adapter identity: `0Harmony12, Version=1.2.0.1`; SHA-256 `aa1cd48317254985d8b700cc74953477d1b40c3022ce9aa4c95ed2b8327e1292`

Generated contract evidence may contain the local path under ignored `artifacts/`; no game binary, decompiled source, save, log, local path file, or proprietary asset is committed.

## Exact contracts

Relevant exact type names and signatures from the local assembly are:

```text
Kingmaker.Controllers.GameOverIronmanController
  System.Void Activate()
  System.Void Deactivate()
  System.Void Tick()

Kingmaker.EntitySystem.Persistence.SaveManager
  SaveInfo GetIronmanSave()
  System.Boolean IsIronmanSave(SaveInfo save)
  System.Void DeleteSave(System.String folderName)
  System.Void DeleteSave(SaveInfo saveInfo)
  IEnumerator<System.Object> SaveRoutine(SaveInfo saveInfo, System.Boolean forceAuto)
  System.Void SerializeAndSaveThread(SaveInfo saveInfo, SavesStorage.SaveCreateDTO dto, SaveInfo originalSave)
  System.Void UpdateSaveListIfNeeded(System.Boolean force)
  System.Void RemoveSaveFromList(SaveInfo saveInfo)
  private SaveInfo m_IronmanSave
  static System.String SaveFolderName

Kingmaker.EntitySystem.Persistence.SaveInfo
  System.String FolderName { get; set; }
  System.String FileName { get; }
  System.String GameId { get; set; }
  System.String GameName { get; set; }
  SaveType Type { get; set; }
  ISaver Saver { get; set; }

Kingmaker.EntitySystem.Persistence.SaveInfo+SaveType
  Manual=0, Quick=1, Auto=2, Remote=3, Bugreport=4,
  IronMan=5, ForImport=6

Kingmaker.UI.SettingsUI.SettingsRoot
  static SettingsListScreen Instance { get; }
Kingmaker.UI.SettingsUI.SettingsRoot+SettingsListScreen
  SettingsEntityBool OnlyOneSave
  SettingsEntityBool StartGameIronMan
Kingmaker.UI.SettingsUI.SettingsEntityBool
  System.Boolean CurrentValue { get; }

Kingmaker.EntitySystem.Persistence.LoadingProcess
  static LoadingProcess Instance { get; }
  System.Void ResetManualLoadingScreen()

Kingmaker.EntitySystem.Persistence.ZipSaver
  System.Void Clear()
Kingmaker.EntitySystem.Persistence.FolderSaver
  System.Void Clear()
Kingmaker.EntitySystem.Persistence.SteamSavesReplicator
  System.Void DeleteSave(SaveInfo saveInfo)
  System.Void DeleteSaveThreaded(SaveInfo saveInfo)
```

`SaveInfo.SaveType` is a public nested enum. `FolderName` is the full source path; `FileName` returns `Path.GetFileName(FolderName)` only when `FolderName` is nonempty.

## Game-over control flow and exact deletion path

`GameModesFactory.Initialize()` constructs `GameOverIronmanController` at IL `0x08f3` and registers it only for `GameModeType.GameOver` (`10`). `GameMode.OnActivate()` iterates controllers and calls `IController.Activate()` synchronously inside a per-controller exception handler. There is no direct static call reference to the concrete `Activate`; interface dispatch reaches it.

The complete meaningful control flow of the 98-byte concrete method is:

```text
GameOverIronmanController.Activate(): void
  IL_0000  SettingsRoot.Instance.OnlyOneSave.CurrentValue
  IL_000f  if false, branch to IL_0057
  IL_0011  log "Deleting ironman save: " +
           Game.Instance.SaveManager.GetIronmanSave().FolderName
  IL_0039  Game.Instance.SaveManager
  IL_0043  Game.Instance.SaveManager.GetIronmanSave()
  IL_0052  callvirt SaveManager.DeleteSave(SaveInfo)
  IL_0057  LoadingProcess.Instance
  IL_005c  callvirt LoadingProcess.ResetManualLoadingScreen()
  IL_0061  ret
```

`Activate` returns `void`; it is not an iterator, coroutine, callback registration, task, or async state machine. Its deletion call is direct and synchronous. The local deletion inside `SaveManager.DeleteSave(SaveInfo)` is synchronous; one secondary Steam Cloud deletion is scheduled asynchronously as described below.

The concrete delete seam performs:

```text
SaveManager.DeleteSave(SaveInfo saveInfo): void
  lock (m_Lock)
    if (saveInfo.IsActuallySaved)
      IL_001f  saveInfo.Saver.Clear()
      IL_002b  SteamSavesReplicator.DeleteSave(saveInfo)
    IL_0032  saveInfo.FolderName = null
    IL_0038  saveInfo.Dispose()
    IL_0044  m_SavedGames.Remove(saveInfo)
  IL_0077  MainThreadDispatcher.Post(...)
```

The posted callback raises `ISavesUpdatedHandler.OnSaveListUpdated` through `EventBus`. `ZipSaver.Clear()` tests `File.Exists` and calls `File.Delete` on the `.zks`/zip file (logging exceptions). `FolderSaver.Clear()` deletes each file in a legacy save directory. `SteamSavesReplicator.DeleteSave()` initializes the store and schedules `DeleteSaveThreaded()` with `Task.Run`; that worker calls `SteamRemoteStorage.FileDelete(saveInfo.FileName)` for `.zks`, removes the cloud registry entry, and uploads the registry.

Therefore skipping the concrete `DeleteSave(SaveInfo)` call prevents all destructive local, cached-list, notification, and Steam-delete side effects. It does not require a compensating list refresh in the normal intercepted path because the live `SaveInfo` never leaves `m_SavedGames`. The native `ResetManualLoadingScreen()` still executes and resets its `CountingGuard`.

## Save discovery and ordinary overwrite behavior

`SaveManager.SavePath` lazily computes:

```text
Path.Combine(ApplicationPaths.persistentDataPath, SaveManager.SaveFolderName)
```

`SaveFolderName` is `Saved Games` in a release build (`Saved Games Test` only in beta mode). `UpdateSaveListTask()` enumerates immediate legacy directories plus `*.zks` and `*.zip` files only within that root, loads their headers, rebuilds `m_SavedGames`, and updates Steam replication.

`SaveRoutine(SaveInfo, bool)` is a compiler-generated iterator entrypoint. Its `MoveNext` performs the save pipeline, while `SerializeAndSaveThread(...)` commits the saver and then calls `DeleteSave(originalSave)` at IL `0x0406` when replacing an old slot. That ordinary overwrite call is intentionally not blocked: it occurs outside the scoped game-over context. No patch is applied to `SaveRoutine`, so native one-slot autosaving and overwriting remain unchanged.

## All observed SaveManager deletion callers

An exhaustive metadata-token scan of every method body found these direct callers of `DeleteSave(SaveInfo)`:

- `Kingmaker.Controllers.GameOverIronmanController.Activate()` — the only game-over caller
- `Kingmaker.EntitySystem.Persistence.SaveManager.DeleteSave(String)` — lookup/delegating overload
- `Kingmaker.EntitySystem.Persistence.SaveManager.SerializeAndSaveThread(...)` — normal slot replacement
- `Kingmaker.Game+<>c__DisplayClass177_0.<LoadNewGame>b__4()` — new-game cleanup
- `Kingmaker.UI.SaveLoadWindow.SaveSlot.TryDeleteMySave(BoxButton)` — explicit legacy load/save UI
- `Kingmaker.UI.SaveLoadWindow.SaveSlotInject.TryDeleteMySave(BoxButton)` — explicit injected UI
- `Kingmaker.Cheats.CheatsSaves.DeleteSaveGame(String)` — cheat path
- `Kingmaker.Utility.ReportingUtils.CreateSaveFile()` — report temporary save cleanup
- `Kingmaker.Utility.ReportingUtils.Clear()` — report cleanup

The only direct caller of `DeleteSave(String)` is `Kingmaker.UI._ConsoleUI.SaveLoadManager.ViewModel.SaveLoadManagerVM.ExecuteDeleteSave(SaveInfo)`, which passes `FolderName`; the string overload locates the cached `SaveInfo` and delegates to `DeleteSave(SaveInfo)`.

No other method whose declaring type contains `GameOver` calls either overload. Searches also covered metadata/type/member/string occurrences of `IronMan`, `Ironman`, `LastAzlanti`, `OnlyOneSave`, `GameOverIronmanController`, `DeleteSave`, `Delete`, `RemoveSave`, and `SaveRoutine`. `LastAzlanti` is used as a UI field name (`NewGameWinPhaseStory.m_LastAzlantiSetting`); runtime save discipline uses `OnlyOneSave` and `SaveType.IronMan`.

## Manual deletion distinction

Manual deletion is UI-confirmed before entering one of the three exact UI methods above. It has no mod-created game-over context or marker. The mod also explicitly classifies those UI frames and forces pass-through even if another mod were to cause unusual reentrancy. The console method reaches the same concrete seam through `DeleteSave(String)`. Consequently deliberate deletion clears local/cloud/cache state exactly as vanilla and cannot create a marker or trigger resurrection.

## Selected Harmony strategy

The selected strategy is preferred option 1: patch the actual deletion method, but suppress it only inside an exact active game-over preservation context.

- `Activate` prefix resolves the exact active `GetIronmanSave()` identity and establishes context.
- `DeleteSave(SaveInfo)` prefix applies the complete predicate and returns false only for a matching IronMan target in that fresh, thread-bound synchronous context.
- `Activate` postfix completes recovery and clears context. `GameMode.OnActivate` catches controller exceptions internally, so its postfix is the immediate exception-path cleanup; `Deactivate` and a bounded update watchdog add fallbacks.
- No filesystem or policy logic is present in Harmony entrypoints.

This is narrower than transpiling the call and materially narrower than skipping `Activate`. It preserves the native log and `ResetManualLoadingScreen`, retains normal game-over presentation, leaves every non-game-over delete call untouched, and fails closed at contract-install time rather than applying a speculative target.

Harmony12 `1.2.0.1` exposes prefix/postfix/transpiler but no finalizer API. The exact local `GameMode.OnActivate` body has an exception-handling clause around interface-dispatched controller activation; its postfix therefore runs after a controller exception was caught. The watchdog detaches any remaining same-thread context on the next UMM update and expires a cross-thread context after 30 seconds.

A local Harmony12 application probe also established that a patched target appears in `StackTrace` as a dynamic wrapper: the original target `MethodInfo` and metadata token were absent. An exact original-frame predicate would therefore make protection unavailable at the critical call. The selected implementation instead treats the short-lived `Activate` prefix/postfix state, matching managed thread, target identity, IronMan type, Only One Save setting, and freshness bound as the concrete game-over lifecycle proof. This uses the observed synchronous control flow without depending on unstable dynamic-method stack names.

## Upstream oracle

Pinned source: <https://github.com/Truinto/KingmakerFumi/blob/a2e16e29998ff1e784f00ac1b8e0bc4c85c47e91/FirstAzlanti/Main.cs>

Pinned license: <https://github.com/Truinto/KingmakerFumi/blob/a2e16e29998ff1e784f00ac1b8e0bc4c85c47e91/LICENSE>

The upstream prefixes `Activate`, calls `ResetManualLoadingScreen`, skips the entire original, and separately copies an IronMan save beside the original before `SaveRoutine` overwrite. Local 2.1.7b inspection confirms the oracle's seam but supports a narrower implementation: retain `Activate`, intercept only its concrete deletion, and place one transactional recovery copy outside the scanned save directory. Attribution is in `THIRD-PARTY-NOTICES.md` and `licenses/FIRST-AZLANTI-MIT.txt`.
