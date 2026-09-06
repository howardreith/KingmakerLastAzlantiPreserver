# Kingmaker 2.1.7b reconnaissance

## Evidence identity

The installed title was discovered from Steam registry metadata, `libraryfolders.vdf`, and app manifest `appmanifest_640820.acf`; no Steam path was assumed. Committed documentation represents it as `<KINGMAKER_INSTALL>` and the managed root as `<KINGMAKER_MANAGED>`. The ignored `GamePath.props` contains the actual local path.

- Steam App ID: `640820`
- installed depot build ID: `6757524`
- `<KINGMAKER_INSTALL>/Kingmaker_Data/resources.assets` contains serialized `Version` value `2.1.7b`
- `Assembly-CSharp.dll` length: `7,262,208` bytes
- `Assembly-CSharp.dll` SHA-256: `3b6450ffec440e296e586f71c711b195aed144b28d53e1cbb29406d18fef5afb`
- `Assembly-CSharp.dll` module MVID: `07fa1e4d-8618-41b3-9b8d-faa17d3b26f7`
- historical v0.1.0 qualification UMM identity: `UnityModManager, Version=0.32.4.0`; SHA-256 `1387468bc3af41c50fe51859a3bb7af4922891aa8f13a6187e7a348ceaabfd88`
- v0.1.1 candidate UMM identity retained by explicit owner approval: `UnityModManager, Version=0.33.0.0`; SHA-256 `63e5baf7b1738e4091b5fd17ccb738ecdb4d1dbf246061dfd55dc52835d52691`; MVID `54059519-2754-445a-b5ee-fdb9326336e2`
- v0.1.1 legacy Harmony adapter identity: `0Harmony12, Version=1.2.0.1`; SHA-256 `aa1cd48317254985d8b700cc74953477d1b40c3022ce9aa4c95ed2b8327e1292`; MVID `918c071f-383e-46dc-a374-6879300cbe15`

The v0.1.1 UMM 0.33.0 managed-load and automated contract evidence is not a game launch or GUI qualification, and it does not rewrite the historical 0.32.4 evidence or imply compatibility with other loader versions.

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

## v0.1.1 standalone Endless results-screen controls

### Desktop view, fields, and vanilla state

The owner-described standalone Beneath the Stolen Lands results screen is the legacy/desktop view:

```text
Kingmaker.UI.EndlessGameOver.EndlessGameOverView                  type token 0x02000855
  System.Void PreShow()                                          method token 0x060040AA
  System.Void OnRestartGame()                                    method token 0x060040AC
  System.Void OnLoadLastSave()                                   method token 0x060040AD
  System.Void OnLoadGame()                                       method token 0x060040AE
  System.Void OnMainMenu()                                       method token 0x060040AF
  UnityEngine.UI.Button m_LoadLastSaveButton                     field token 0x04002BE5
  UnityEngine.UI.Button m_LoadGameButton                         field token 0x04002BE6
```

Both button fields are private `[UnityEngine.SerializeField]` fields. `PreShow()` computes the vanilla `canLoad` fact as the inverse of `SettingsRoot.Instance.OnlyOneSave.CurrentValue`. It assigns:

```text
m_LoadGameButton.interactable = canLoad
m_LoadLastSaveButton.interactable =
    canLoad && SaveManager.GetLatestSave(DlcType.Endless) != null
```

The disabled state for these two controls is therefore `UnityEngine.UI.Selectable.interactable`. The relevant assignments do not hide either `GameObject`, change a `CanvasGroup`, replace a label, or install a separate navigation layer. Other `PreShow` work does use active/canvas state for the overall results presentation, which is why the mod changes only the two serialized Button properties after vanilla returns.

The native desktop action paths are:

```text
Button pointer click / keyboard submit -> existing serialized UnityEvent
  Load Last Save -> EndlessGameOverView.OnLoadLastSave()
    -> SaveManager.GetLatestSave(DlcType.Endless)
    -> Game.LoadGame(SaveInfo)

  Load Game -> EndlessGameOverView.OnLoadGame()
    -> EventBus generated callback
       EndlessGameOverView+<>c.<OnLoadGame>b__18_0(
           ISaveLoadWindowUIHandler)                             token 0x0600B0E6
    -> ISaveLoadWindowUIHandler.HandleOpenSaveLoadWindow(
           SaveLoadWindow.ScreenType)
```

No managed method on `EndlessGameOverView` registers those public callbacks, so their listener association is prefab-serialized. A targeted read-only string search across local serialized asset file classes did not expose the listener strings without extraction; no prefab or proprietary asset was extracted or committed. The mod does not replace or add listeners: it retains the two exact serialized Button instances, so native `Button.OnPointerClick`/`Button.OnSubmit`, sounds, selection, and persistent callbacks remain in control.

`OnLoadLastSave()` and `OnLoadGame()` contain no secondary `OnlyOneSave` guard. Their narrow action prefixes therefore revalidate a feature-elevated Last Azlanti action, but pass through to the original callbacks whenever `OnlyOneSave` is false so an ordinary Endless run retains vanilla behavior. With `OnlyOneSave` true, a failed revalidation skips the otherwise unguarded callback and restores only feature-owned state. `OnRestartGame()` and `OnMainMenu()` retain their native reset-to-preset/main-menu behavior and are patched only to clear UI-only state before they run.

### Narrow desktop patch point

`EndlessGameOverView.PreShow()` is the exact method that writes the two vanilla states, but its 402-byte body directly invokes Unity `InternalCall` methods such as `CanvasGroup.set_alpha`, `Component.get_gameObject`, and `GameObject.SetActive`. The desktop-CLR Harmony ownership gate cannot rebuild those ECall references. Rather than ship an ownership-unverifiable target, the implementation uses the immediately enclosing canonical method:

```text
Kingmaker.UI.Canvases.GameOverCanvas                             type token 0x020008A1
  System.Void PreShow()                                          method token 0x060043FE
  EndlessGameOverView m_EndlessGameOverView                     field token 0x04002D6A
```

`GameOverCanvas.PreShow()` is a 27-byte IL method. It performs base presentation, tests `IsEndless`, then calls the exact `m_EndlessGameOverView.PreShow()`. The selected postfix on this method therefore runs immediately after vanilla has applied the target view state, retrieves the exact private `[SerializeField]` view rather than searching a hierarchy, and remains fully patch/ownership-verifiable under the canonical automated gate. Ordinary campaign presentation reaches the shared canvas but does not dispatch the Endless view; eligibility also independently requires the Endless game-over state, so no ordinary control is elevated.

### Controller view and native confirm path

The controller-specific results menu is:

```text
Kingmaker.UI._ConsoleUI.Endless.GameOver.EndlessGameOverMenuPartVm
                                                                    type token 0x02000B72
  .ctor()                                                          method token 0x0600600B
  ContextMenuEntityVM LoadLastSaveVm                               field token 0x04003FE7
  ContextMenuEntityVM LoadVm                                       field token 0x04003FE8
  System.Void OnButtonLoadLastSave()                               method token 0x0600600D
  System.Void OnButtonLoad()                                       method token 0x0600600E
  System.Void OnButtonNewGame()                                    method token 0x0600600C
  System.Void OnButtonMainMenu()                                   method token 0x0600600F
  System.Void DisposeImplementation()                              method token 0x06006010

Kingmaker.UI._ConsoleUI.Endless.GameOver.EndlessGameOverMenuPartVm+<>c__DisplayClass4_0
  System.Boolean canLoad                                           field token 0x0400862D
  System.Boolean <.ctor>b__2()                                     method token 0x0600B7E3
  System.Boolean <.ctor>b__4()                                     method token 0x0600B7E4
```

The constructor captures `canLoad = !OnlyOneSave.CurrentValue`. The first predicate is `canLoad && GetLatestSave(DlcType.Endless) != null`; the second is `canLoad`. The optional prefixes override only these two predicates on a positive scoped decision and call `ContextMenuEntityVM.Refresh()` only for the two exact fields.

`EndlessGameOverMenuPartView.InternalBind()` (token `0x06006007`) binds New Game, Load Last Save, Load, and Main Menu to their corresponding existing view models and places those exact four entities in a vertical `ConsoleMultiNavigationCollection`. `GetInputLayer(InputLayer)` (token `0x06006005`) binds native input action 8 to `OnConfirm()` (token `0x06006006`), which calls `CurrentEntity.OnConfirm()`. That continues through `ContextMenuEntityView.OnConfirm()` (token `0x06006216`) to `ContextMenuEntityVM.OnClick()` (token `0x06006224`), checks the existing entity condition, and invokes its native command.

The controller commands remain:

```text
OnButtonLoadLastSave()
  -> SaveManager.GetLatestSave()             # global overload in this native callback
  -> Game.LoadGame(SaveInfo)

OnButtonLoad()
  -> EndlessGameOverMenuPartVm+<>c.<OnButtonLoad>b__7_0(
         ISaveLoadManagerUIHandler)                              token 0x0600B7E7
  -> ISaveLoadManagerUIHandler.HandleOpen(SaveLoadManagerMode, Boolean)
```

Because the controller callback uses the global `GetLatestSave()` overload, action eligibility separately requires that this exact native result matches the preserved operation identity; the desktop action equivalently validates `GetLatestSave(DlcType.Endless)`.

### Ordering, load window, and terminal boundaries

The verified ordering is:

```text
Game.DoStartMode(GameModeType.GameOver)                           token 0x06000CBF
  -> GameMode.OnActivate()                                        token 0x06007E02
     -> IController.Activate()
        -> GameOverIronmanController.Activate()
           -> GetIronmanSave()
           -> scoped DeleteSave(SaveInfo) suppression
           -> LoadingProcess.ResetManualLoadingScreen()
  -> Game.HandleGameModeChanged(oldMode, GameOver)                token 0x06000CC3
     -> BaseGameOverCanvas.OnGameModeStart(GameOver)              token 0x060043F2
        -> GameOverCanvas.PreShow()
           -> EndlessGameOverView.PreShow() when IsEndless
        -> optional postfix revalidates/elevates exact controls
```

`DoStartMode` creates and pushes the new `GameMode` before calling `OnStart()` and `OnActivate()`; `CurrentMode` reads the pushed stack head. The production resolver now enforces that ordered IL relationship through `HandleGameModeChanged`, plus the generated `IGameModeHandler.OnGameModeStart` callback and `BaseGameOverCanvas.PreShow()` dispatch. Thus `CurrentMode` is already `GameOver` when the preservation postfix records its outcome, and the synchronous core context is always closed before the UI consumes that outcome. The UI outcome is a separate operation GUID plus exact `SaveIdentity`, created only after a deletion was actually suppressed and the live source passed revalidation.

Desktop `SaveLoadWindow.HandleOpenSaveLoadWindow(ScreenType)` (token `0x06003964`) opens the existing overlay. Its close/back/Escape routes call `Hide()` (token `0x06003956`) and do not start another game-over operation or load. Controller game-over context implements `ISaveLoadManagerUIHandler.HandleOpen(mode, bool)` at token `0x06006372`; its full-screen close action returns to the underlying game-over context. Consequently opening/cancelling Load Game retains the operation record but performs a fresh bind/action evaluation. It is not counted as a load.

The legacy game-over load window ultimately uses `SaveLoadWindow.HandleHardcodeMainMenuSaveLoad(SaveInfo)` (token `0x0600396A`) -> `Game.LoadGame(SaveInfo)`. The controller load window uses `CommonUiLoadService+<>c__DisplayClass2_0.<Load>b__0()` (token `0x0600B621`) -> the same native method. A state-clear-only prefix on `Game.LoadGame(SaveInfo)` revokes the operation before any actual native load. Controller view-model disposal releases only the tracked view reference because it may accompany opening the native load window; it does not turn that opening into a terminal grant boundary. Start Again, Main Menu, a later game-over prefix, actual game-over departure/deactivation, setting/mod disable, optional failure, and unload are terminal. Explicit native load-window deletion remains outside the synchronous core context; after it passes through, the optional delete postfix clears the UI-only outcome and restores both controls. When the core game-over delete is suppressed, that postfix runs before normal core completion records the fresh verified outcome, so it cannot erase the new grant.

No second `ResetManualLoadingScreen()` call, lower-level deserializer, replacement loader, automatic navigation, localized-label lookup, hierarchy search, per-frame polling, or hidden-snapshot load path is introduced.

## Upstream oracle

Pinned source: <https://github.com/Truinto/KingmakerFumi/blob/a2e16e29998ff1e784f00ac1b8e0bc4c85c47e91/FirstAzlanti/Main.cs>

Pinned license: <https://github.com/Truinto/KingmakerFumi/blob/a2e16e29998ff1e784f00ac1b8e0bc4c85c47e91/LICENSE>

The upstream prefixes `Activate`, calls `ResetManualLoadingScreen`, skips the entire original, and separately copies an IronMan save beside the original before `SaveRoutine` overwrite. Local 2.1.7b inspection confirms the oracle's seam but supports a narrower implementation: retain `Activate`, intercept only its concrete deletion, and place one transactional recovery copy outside the scanned save directory. Attribution is in `THIRD-PARTY-NOTICES.md` and `licenses/FIRST-AZLANTI-MIT.txt`.
