using System;
using System.IO;
using System.Linq;
using System.Reflection;
using Harmony12;
using Kingmaker.EntitySystem.Persistence;
using Kingmaker.Utility;
using KingmakerLastAzlantiPreserver.Integration;
using KingmakerLastAzlantiPreserver.Logging;
using KingmakerLastAzlantiPreserver.Patches;
using KingmakerLastAzlantiPreserver.Preservation;
using KingmakerLastAzlantiPreserver.Recovery;
using KingmakerLastAzlantiPreserver.UI;
using UnityEngine;
using UnityModManagerNet;

namespace KingmakerLastAzlantiPreserver
{
    public sealed class CompositionRoot
    {
        private readonly Settings settings;
        private readonly IModLogger logger;
        private readonly RuntimeStatus status;
        private readonly RecoverySnapshotService recovery;
        private readonly SettingsView settingsView;
        private readonly string saveRoot;
        private readonly CompatibilityDetector compatibilityDetector = new CompatibilityDetector();
        private HarmonyInstance coreHarmony;
        private HarmonyInstance gameOverLoadHarmony;
        private KingmakerContracts contracts;
        private GameOverLoadContracts gameOverLoadContracts;
        private ActiveSaveResolver activeSaveResolver;
        private GameOverPreservationCoordinator coordinator;
        private GameOverLoadEligibilityService gameOverLoadEligibility;
        private GameOverLoadControlCoordinator gameOverLoadControls;
        private bool enabled;
        private bool corePatchesInstalled;
        private bool gameOverLoadPatchesInstalled;
        private string coreFailure = "The mod is disabled.";
        private string gameOverLoadFailure = "The mod is disabled.";
        private DateTime nextCompatibilityCheckUtc;
        private string lastCompatibilityWarning = string.Empty;

        public CompositionRoot(Settings settings, IModLogger logger)
        {
            this.settings = settings ?? throw new ArgumentNullException(nameof(settings));
            this.logger = logger ?? throw new ArgumentNullException(nameof(logger));
            status = new RuntimeStatus();

            string persistentRoot = ApplicationPaths.persistentDataPath;
            if (string.IsNullOrWhiteSpace(persistentRoot)) persistentRoot = Application.persistentDataPath;
            if (string.IsNullOrWhiteSpace(persistentRoot))
            {
                throw new InvalidOperationException("Neither Kingmaker nor Unity supplied a persistent-data path.");
            }

            saveRoot = Path.Combine(persistentRoot, SaveManager.SaveFolderName);
            string recoveryRoot = Path.Combine(persistentRoot, "LastAzlantiPreserver", "Recovery");
            recovery = new RecoverySnapshotService(saveRoot, recoveryRoot, logger);
            status.SetRecoveryDirectory(recovery.RecoveryRoot);
            settingsView = new SettingsView(
                settings,
                status,
                recovery.GetLatestGuardedDecision,
                TryManualRestore,
                OnFeatureSettingsChanged);
        }

        public bool SetEnabled(bool value)
        {
            if (!value)
            {
                Disable();
                return true;
            }

            if (enabled) return true;
            enabled = true;
            InstallCoreProtection();
            if (corePatchesInstalled) InstallGameOverLoadControls();
            RefreshFeatureStatuses();

            if (corePatchesInstalled)
            {
                recovery.ClearSurvivingMarkers();
                RefreshCompatibilityWarning();
                logger.Info("Core preservation available against Assembly-CSharp " + contracts.AssemblySha256 +
                    " (MVID " + contracts.AssemblyMvid + ").");
            }

            return true;
        }

        public void Update()
        {
            if (!enabled || coordinator == null || activeSaveResolver == null) return;
            coordinator.WatchdogCleanup();
            status.SetLastAzlantiRecognized(activeSaveResolver.IsCurrentLastAzlantiRecognized());
            if (DateTime.UtcNow >= nextCompatibilityCheckUtc) RefreshCompatibilityWarning();
        }

        public void DrawGui()
        {
            settingsView.Draw();
        }

        public void Save(UnityModManager.ModEntry modEntry)
        {
            settings.Save(modEntry);
        }

        public bool TryUnload()
        {
            Disable();
            return true;
        }

        private void InstallCoreProtection()
        {
            try
            {
                contracts = new KingmakerContractResolver().Resolve();
                activeSaveResolver = new ActiveSaveResolver(contracts, saveRoot);
                gameOverLoadEligibility = new GameOverLoadEligibilityService(
                    settings,
                    activeSaveResolver,
                    new GameOverLoadEligibilityPolicy(),
                    new GameOverLoadOutcomeTracker(),
                    status,
                    logger);
                gameOverLoadEligibility.SetAvailability(true, false, false);
                coordinator = new GameOverPreservationCoordinator(
                    settings,
                    activeSaveResolver,
                    new DeleteInvocationClassifier(),
                    new PreservationContextTracker(),
                    new PreservationPolicy(),
                    recovery,
                    gameOverLoadEligibility,
                    status,
                    logger);
                PatchBridge.Initialize(coordinator, logger);

                coreHarmony = HarmonyInstance.Create(ProductMetadata.CoreHarmonyId);
                ApplyCorePatches();
                VerifyCorePatchOwnership();
                corePatchesInstalled = true;
                coreFailure = string.Empty;
                gameOverLoadEligibility.SetAvailability(true, true, false);
            }
            catch (Exception exception)
            {
                PatchBridge.Clear();
                string cleanupFailure = TryCleanup(
                    "remove partial core Harmony ownership",
                    () => coreHarmony?.UnpatchAll(ProductMetadata.CoreHarmonyId));
                coreHarmony = null;
                coordinator = null;
                activeSaveResolver = null;
                gameOverLoadEligibility = null;
                corePatchesInstalled = false;
                coreFailure = exception.GetType().Name + ": " + exception.Message + cleanupFailure;
                gameOverLoadFailure = "Core preservation is unavailable: " + coreFailure;
                status.SetError(coreFailure);
                logger.Exception("Last Azlanti core protection unavailable; the core bridge was cleared and patch cleanup was attempted", exception);
            }
        }

        private void InstallGameOverLoadControls()
        {
            try
            {
                gameOverLoadContracts = new GameOverLoadContractResolver().Resolve(contracts);
                gameOverLoadControls = new GameOverLoadControlCoordinator(
                    gameOverLoadContracts,
                    gameOverLoadEligibility,
                    logger);
                GameOverLoadPatchBridge.Initialize(gameOverLoadControls, logger);
                gameOverLoadHarmony = HarmonyInstance.Create(ProductMetadata.GameOverLoadHarmonyId);
                ApplyGameOverLoadPatches();
                VerifyGameOverLoadPatchOwnership();
                gameOverLoadPatchesInstalled = true;
                gameOverLoadFailure = string.Empty;
                gameOverLoadEligibility.SetAvailability(true, true, true);
                logger.Info("Optional game-over loading controls available at " +
                    gameOverLoadContracts.PrimaryPatchTargetDisplay + ".");
            }
            catch (Exception exception)
            {
                GameOverLoadPatchBridge.Clear();
                string cleanupFailure = TryCleanup(
                    "restore optional game-over loading controls",
                    () => gameOverLoadControls?.Release());
                cleanupFailure += TryCleanup(
                    "remove partial optional Harmony ownership",
                    () => gameOverLoadHarmony?.UnpatchAll(ProductMetadata.GameOverLoadHarmonyId));
                gameOverLoadHarmony = null;
                gameOverLoadControls = null;
                gameOverLoadPatchesInstalled = false;
                gameOverLoadFailure = exception.GetType().Name + ": " + exception.Message + cleanupFailure;
                gameOverLoadEligibility.SetAvailability(true, true, false);
                gameOverLoadEligibility.ClearGameOverOperation("optional UI contract or patch failure");
                status.SetError("Optional game-over loading controls unavailable: " + gameOverLoadFailure);
                logger.Exception(
                    "Optional game-over loading controls unavailable; core preservation remains installed",
                    exception);
            }
        }

        private void ApplyCorePatches()
        {
            MethodInfo contextPrefix = typeof(GameOverContextPatch).GetMethod(nameof(GameOverContextPatch.Prefix));
            MethodInfo contextPostfix = typeof(GameOverContextPatch).GetMethod(nameof(GameOverContextPatch.Postfix));
            MethodInfo deactivatePrefix = typeof(GameOverContextPatch).GetMethod(nameof(GameOverContextPatch.DeactivatePrefix));
            MethodInfo modeActivatePostfix = typeof(GameOverContextPatch).GetMethod(nameof(GameOverContextPatch.GameModeOnActivatePostfix));
            MethodInfo deletePrefix = typeof(SaveDeletionPatch).GetMethod(nameof(SaveDeletionPatch.Prefix));
            coreHarmony.Patch(contracts.GameOverActivate, new HarmonyMethod(contextPrefix), new HarmonyMethod(contextPostfix), null);
            coreHarmony.Patch(contracts.GameOverDeactivate, new HarmonyMethod(deactivatePrefix), null, null);
            coreHarmony.Patch(contracts.GameModeOnActivate, null, new HarmonyMethod(modeActivatePostfix), null);
            coreHarmony.Patch(contracts.DeleteSave, new HarmonyMethod(deletePrefix), null, null);
        }

        private void ApplyGameOverLoadPatches()
        {
            Type patchType = typeof(GameOverLoadControlsPatch);
            gameOverLoadHarmony.Patch(
                gameOverLoadContracts.LegacyCanvasPreShow,
                null,
                new HarmonyMethod(patchType.GetMethod(nameof(GameOverLoadControlsPatch.LegacyCanvasPreShowPostfix))),
                null);
            PatchOptionalPrefix(gameOverLoadContracts.LegacyLoadLastSave, nameof(GameOverLoadControlsPatch.LegacyLoadLastPrefix));
            PatchOptionalPrefix(gameOverLoadContracts.LegacyLoadGame, nameof(GameOverLoadControlsPatch.LegacyLoadGamePrefix));
            PatchOptionalPrefix(gameOverLoadContracts.LegacyRestartGame, nameof(GameOverLoadControlsPatch.LegacyRestartPrefix));
            PatchOptionalPrefix(gameOverLoadContracts.LegacyMainMenu, nameof(GameOverLoadControlsPatch.LegacyMainMenuPrefix));
            gameOverLoadHarmony.Patch(
                gameOverLoadContracts.ConsoleMenuConstructor,
                null,
                new HarmonyMethod(patchType.GetMethod(nameof(GameOverLoadControlsPatch.ConsoleConstructorPostfix))),
                null);
            PatchOptionalPrefix(gameOverLoadContracts.ConsoleLoadLastPredicate, nameof(GameOverLoadControlsPatch.ConsolePredicatePrefix));
            PatchOptionalPrefix(gameOverLoadContracts.ConsoleLoadPredicate, nameof(GameOverLoadControlsPatch.ConsolePredicatePrefix));
            PatchOptionalPrefix(gameOverLoadContracts.ConsoleLoadLastSave, nameof(GameOverLoadControlsPatch.ConsoleLoadLastPrefix));
            PatchOptionalPrefix(gameOverLoadContracts.ConsoleLoad, nameof(GameOverLoadControlsPatch.ConsoleLoadGamePrefix));
            PatchOptionalPrefix(gameOverLoadContracts.ConsoleNewGame, nameof(GameOverLoadControlsPatch.ConsoleNewGamePrefix));
            PatchOptionalPrefix(gameOverLoadContracts.ConsoleMainMenu, nameof(GameOverLoadControlsPatch.ConsoleMainMenuPrefix));
            PatchOptionalPrefix(gameOverLoadContracts.ConsoleDispose, nameof(GameOverLoadControlsPatch.ConsoleDisposePrefix));
            PatchOptionalPrefix(gameOverLoadContracts.NativeLoadGame, nameof(GameOverLoadControlsPatch.NativeLoadPrefix));
            gameOverLoadHarmony.Patch(
                gameOverLoadContracts.DeleteSave,
                null,
                new HarmonyMethod(patchType.GetMethod(nameof(GameOverLoadControlsPatch.DeleteSavePostfix))),
                null);
        }

        private void PatchOptionalPrefix(MethodBase target, string patchMethodName)
        {
            MethodInfo patch = typeof(GameOverLoadControlsPatch).GetMethod(patchMethodName);
            gameOverLoadHarmony.Patch(target, new HarmonyMethod(patch), null, null);
        }

        private void VerifyCorePatchOwnership()
        {
            if (!OwnsPatch(coreHarmony, contracts.GameOverActivate, typeof(GameOverContextPatch).GetMethod(nameof(GameOverContextPatch.Prefix)), true, ProductMetadata.CoreHarmonyId) ||
                !OwnsPatch(coreHarmony, contracts.GameOverActivate, typeof(GameOverContextPatch).GetMethod(nameof(GameOverContextPatch.Postfix)), false, ProductMetadata.CoreHarmonyId) ||
                !OwnsPatch(coreHarmony, contracts.GameOverDeactivate, typeof(GameOverContextPatch).GetMethod(nameof(GameOverContextPatch.DeactivatePrefix)), true, ProductMetadata.CoreHarmonyId) ||
                !OwnsPatch(coreHarmony, contracts.GameModeOnActivate, typeof(GameOverContextPatch).GetMethod(nameof(GameOverContextPatch.GameModeOnActivatePostfix)), false, ProductMetadata.CoreHarmonyId) ||
                !OwnsPatch(coreHarmony, contracts.DeleteSave, typeof(SaveDeletionPatch).GetMethod(nameof(SaveDeletionPatch.Prefix)), true, ProductMetadata.CoreHarmonyId))
            {
                throw new InvalidOperationException("Core Harmony patch ownership could not be verified.");
            }
        }

        private void VerifyGameOverLoadPatchOwnership()
        {
            VerifyOptionalPatch(gameOverLoadContracts.LegacyCanvasPreShow, nameof(GameOverLoadControlsPatch.LegacyCanvasPreShowPostfix), false);
            VerifyOptionalPatch(gameOverLoadContracts.LegacyLoadLastSave, nameof(GameOverLoadControlsPatch.LegacyLoadLastPrefix), true);
            VerifyOptionalPatch(gameOverLoadContracts.LegacyLoadGame, nameof(GameOverLoadControlsPatch.LegacyLoadGamePrefix), true);
            VerifyOptionalPatch(gameOverLoadContracts.LegacyRestartGame, nameof(GameOverLoadControlsPatch.LegacyRestartPrefix), true);
            VerifyOptionalPatch(gameOverLoadContracts.LegacyMainMenu, nameof(GameOverLoadControlsPatch.LegacyMainMenuPrefix), true);
            VerifyOptionalPatch(gameOverLoadContracts.ConsoleMenuConstructor, nameof(GameOverLoadControlsPatch.ConsoleConstructorPostfix), false);
            VerifyOptionalPatch(gameOverLoadContracts.ConsoleLoadLastPredicate, nameof(GameOverLoadControlsPatch.ConsolePredicatePrefix), true);
            VerifyOptionalPatch(gameOverLoadContracts.ConsoleLoadPredicate, nameof(GameOverLoadControlsPatch.ConsolePredicatePrefix), true);
            VerifyOptionalPatch(gameOverLoadContracts.ConsoleLoadLastSave, nameof(GameOverLoadControlsPatch.ConsoleLoadLastPrefix), true);
            VerifyOptionalPatch(gameOverLoadContracts.ConsoleLoad, nameof(GameOverLoadControlsPatch.ConsoleLoadGamePrefix), true);
            VerifyOptionalPatch(gameOverLoadContracts.ConsoleNewGame, nameof(GameOverLoadControlsPatch.ConsoleNewGamePrefix), true);
            VerifyOptionalPatch(gameOverLoadContracts.ConsoleMainMenu, nameof(GameOverLoadControlsPatch.ConsoleMainMenuPrefix), true);
            VerifyOptionalPatch(gameOverLoadContracts.ConsoleDispose, nameof(GameOverLoadControlsPatch.ConsoleDisposePrefix), true);
            VerifyOptionalPatch(gameOverLoadContracts.NativeLoadGame, nameof(GameOverLoadControlsPatch.NativeLoadPrefix), true);
            VerifyOptionalPatch(gameOverLoadContracts.DeleteSave, nameof(GameOverLoadControlsPatch.DeleteSavePostfix), false);
        }

        private void VerifyOptionalPatch(MethodBase target, string patchName, bool prefix)
        {
            MethodInfo patch = typeof(GameOverLoadControlsPatch).GetMethod(patchName);
            if (!OwnsPatch(gameOverLoadHarmony, target, patch, prefix, ProductMetadata.GameOverLoadHarmonyId))
            {
                throw new InvalidOperationException("Optional Harmony ownership missing for " + GameOverLoadContracts.FormatMethod(target) + ".");
            }
        }

        private static bool OwnsPatch(
            HarmonyInstance harmony,
            MethodBase target,
            MethodInfo patchMethod,
            bool prefix,
            string owner)
        {
            Harmony12.Patches patches = harmony.GetPatchInfo(target);
            if (patches == null) return false;
            return (prefix ? patches.Prefixes : patches.Postfixes)
                .Any(patch => string.Equals(patch.owner, owner, StringComparison.Ordinal) && patch.patch == patchMethod);
        }

        private RecoveryDecision TryManualRestore(string recoveryId, bool confirmed)
        {
            RecoveryDecision decision = recovery.TryGuardedRestore(recoveryId, confirmed);
            if (decision.Kind == RecoveryDecisionKind.Restored && activeSaveResolver != null)
            {
                activeSaveResolver.RefreshSaveList();
            }

            return decision;
        }

        private void OnFeatureSettingsChanged()
        {
            if ((!settings.PreserveLastAzlantiSaveOnGameOver || !settings.EnableGameOverLoadControls) &&
                gameOverLoadEligibility != null)
            {
                gameOverLoadEligibility.ClearGameOverOperation("a required setting was disabled");
            }

            RefreshFeatureStatuses();
            gameOverLoadControls?.RefreshCurrentControls();
        }

        private void RefreshFeatureStatuses()
        {
            RuntimeFeatureState coreState = !enabled
                ? RuntimeFeatureState.Disabled
                : (!corePatchesInstalled
                    ? RuntimeFeatureState.Unavailable
                    : (settings.PreserveLastAzlantiSaveOnGameOver ? RuntimeFeatureState.Available : RuntimeFeatureState.Disabled));
            string gameOverHook = contracts == null ? "unresolved" : contracts.GameOverHookDisplay;
            string deletionHook = contracts == null ? "unresolved" : contracts.DeletionHookDisplay;
            status.SetCoreProtection(coreState, corePatchesInstalled, gameOverHook, deletionHook);

            RuntimeFeatureState uiState;
            string uiDetail;
            if (!enabled)
            {
                uiState = RuntimeFeatureState.Disabled;
                uiDetail = "The mod is disabled.";
            }
            else if (!corePatchesInstalled)
            {
                uiState = RuntimeFeatureState.Unavailable;
                uiDetail = "Core preservation is unavailable: " + coreFailure;
            }
            else if (!gameOverLoadPatchesInstalled)
            {
                uiState = RuntimeFeatureState.Unavailable;
                uiDetail = gameOverLoadFailure;
            }
            else if (!settings.PreserveLastAzlantiSaveOnGameOver)
            {
                uiState = RuntimeFeatureState.Disabled;
                uiDetail = "Core preservation is disabled.";
            }
            else if (!settings.EnableGameOverLoadControls)
            {
                uiState = RuntimeFeatureState.Disabled;
                uiDetail = "The game-over loading-control setting is disabled.";
            }
            else
            {
                uiState = RuntimeFeatureState.Available;
                uiDetail = "Exact PC and controller UI patches are installed.";
            }

            status.SetGameOverLoadControls(
                uiState,
                gameOverLoadPatchesInstalled,
                gameOverLoadContracts == null ? "unresolved" : gameOverLoadContracts.PrimaryPatchTargetDisplay,
                gameOverLoadContracts == null ? "unresolved" : gameOverLoadContracts.ControllerPatchTargetDisplay,
                uiDetail);
        }

        private void RefreshCompatibilityWarning()
        {
            if (coreHarmony == null || contracts == null) return;
            string warning = compatibilityDetector.Detect(
                coreHarmony,
                contracts,
                gameOverLoadHarmony,
                gameOverLoadContracts);
            status.SetCompatibilityWarning(warning);
            if (!string.Equals(warning, lastCompatibilityWarning, StringComparison.Ordinal) && !string.IsNullOrEmpty(warning))
            {
                logger.Warning("COMPATIBILITY WARNING: " + warning);
            }

            lastCompatibilityWarning = warning;
            nextCompatibilityCheckUtc = DateTime.UtcNow.AddMinutes(1);
        }

        private void Disable()
        {
            enabled = false;
            GameOverLoadPatchBridge.Clear();
            string cleanupFailure = TryCleanup(
                "clear optional game-over operation",
                () => gameOverLoadControls?.LeaveGameOver("mod disable/unload"));
            cleanupFailure += TryCleanup(
                "release optional game-over loading controls",
                () => gameOverLoadControls?.Release());
            cleanupFailure += TryCleanup(
                "mark optional game-over loading unavailable",
                () => gameOverLoadEligibility?.SetAvailability(false, corePatchesInstalled, gameOverLoadPatchesInstalled));
            cleanupFailure += TryCleanup(
                "remove optional Harmony ownership",
                () => gameOverLoadHarmony?.UnpatchAll(ProductMetadata.GameOverLoadHarmonyId));
            gameOverLoadHarmony = null;
            gameOverLoadControls = null;
            gameOverLoadPatchesInstalled = false;

            PatchBridge.Clear();
            cleanupFailure += TryCleanup(
                "clear core game-over operation",
                () => coordinator?.LeaveGameOver("mod disable/unload"));
            cleanupFailure += TryCleanup(
                "remove core Harmony ownership",
                () => coreHarmony?.UnpatchAll(ProductMetadata.CoreHarmonyId));
            coreHarmony = null;
            coordinator = null;
            activeSaveResolver = null;
            gameOverLoadEligibility = null;
            contracts = null;
            gameOverLoadContracts = null;
            corePatchesInstalled = false;
            coreFailure = "The mod is disabled.";
            gameOverLoadFailure = "The mod is disabled.";
            lastCompatibilityWarning = string.Empty;
            status.SetCompatibilityWarning(string.Empty);
            RefreshFeatureStatuses();
            if (!string.IsNullOrEmpty(cleanupFailure)) status.SetError(cleanupFailure.Trim());
        }

        private string TryCleanup(string operation, Action cleanup)
        {
            try
            {
                cleanup();
                return string.Empty;
            }
            catch (Exception exception)
            {
                logger.Exception(operation, exception);
                return " Cleanup failure during " + operation + ": " +
                    exception.GetType().Name + ": " + exception.Message + ".";
            }
        }
    }
}
