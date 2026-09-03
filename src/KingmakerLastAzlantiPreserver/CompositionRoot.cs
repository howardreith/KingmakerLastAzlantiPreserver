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
        private HarmonyInstance harmony;
        private KingmakerContracts contracts;
        private ActiveSaveResolver activeSaveResolver;
        private GameOverPreservationCoordinator coordinator;
        private bool enabled;
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
            settingsView = new SettingsView(settings, status, recovery.GetLatestGuardedDecision, TryManualRestore);
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
            try
            {
                contracts = new KingmakerContractResolver().Resolve();
                activeSaveResolver = new ActiveSaveResolver(contracts, saveRoot);
                DeleteInvocationClassifier classifier = new DeleteInvocationClassifier();
                coordinator = new GameOverPreservationCoordinator(
                    settings,
                    activeSaveResolver,
                    classifier,
                    new PreservationContextTracker(),
                    new PreservationPolicy(),
                    recovery,
                    status,
                    logger);
                PatchBridge.Initialize(coordinator, logger);

                harmony = HarmonyInstance.Create(ProductMetadata.Id);
                ApplyPatches();
                VerifyPatchOwnership();
                status.SetProtection(true, contracts.GameOverHookDisplay, contracts.DeletionHookDisplay);
                recovery.ClearSurvivingMarkers();

                RefreshCompatibilityWarning();
                logger.Info("Protection available against Assembly-CSharp " + contracts.AssemblySha256 +
                    " (MVID " + contracts.AssemblyMvid + ").");
            }
            catch (Exception exception)
            {
                if (harmony != null) harmony.UnpatchAll(ProductMetadata.Id);
                PatchBridge.Clear();
                coordinator = null;
                activeSaveResolver = null;
                string gameOver = contracts == null ? "unresolved" : contracts.GameOverHookDisplay;
                string deletion = contracts == null ? "unresolved" : contracts.DeletionHookDisplay;
                status.SetProtection(false, gameOver, deletion);
                status.SetError(exception.GetType().Name + ": " + exception.Message);
                logger.Exception("Last Azlanti protection unavailable; no speculative patches were applied", exception);
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

        private void ApplyPatches()
        {
            MethodInfo contextPrefix = typeof(GameOverContextPatch).GetMethod(nameof(GameOverContextPatch.Prefix));
            MethodInfo contextPostfix = typeof(GameOverContextPatch).GetMethod(nameof(GameOverContextPatch.Postfix));
            MethodInfo deactivatePrefix = typeof(GameOverContextPatch).GetMethod(nameof(GameOverContextPatch.DeactivatePrefix));
            MethodInfo modeActivatePostfix = typeof(GameOverContextPatch).GetMethod(nameof(GameOverContextPatch.GameModeOnActivatePostfix));
            MethodInfo deletePrefix = typeof(SaveDeletionPatch).GetMethod(nameof(SaveDeletionPatch.Prefix));
            harmony.Patch(
                contracts.GameOverActivate,
                new HarmonyMethod(contextPrefix),
                new HarmonyMethod(contextPostfix),
                null);
            harmony.Patch(
                contracts.GameOverDeactivate,
                new HarmonyMethod(deactivatePrefix),
                null,
                null);
            harmony.Patch(
                contracts.GameModeOnActivate,
                null,
                new HarmonyMethod(modeActivatePostfix),
                null);
            harmony.Patch(
                contracts.DeleteSave,
                new HarmonyMethod(deletePrefix),
                null,
                null);
        }

        private void VerifyPatchOwnership()
        {
            if (!OwnsPatch(contracts.GameOverActivate, typeof(GameOverContextPatch).GetMethod(nameof(GameOverContextPatch.Prefix)), true) ||
                !OwnsPatch(contracts.GameOverActivate, typeof(GameOverContextPatch).GetMethod(nameof(GameOverContextPatch.Postfix)), false) ||
                !OwnsPatch(contracts.GameOverDeactivate, typeof(GameOverContextPatch).GetMethod(nameof(GameOverContextPatch.DeactivatePrefix)), true) ||
                !OwnsPatch(contracts.GameModeOnActivate, typeof(GameOverContextPatch).GetMethod(nameof(GameOverContextPatch.GameModeOnActivatePostfix)), false) ||
                !OwnsPatch(contracts.DeleteSave, typeof(SaveDeletionPatch).GetMethod(nameof(SaveDeletionPatch.Prefix)), true))
            {
                throw new InvalidOperationException("Harmony patch ownership could not be verified.");
            }
        }

        private bool OwnsPatch(MethodBase target, MethodInfo patchMethod, bool prefix)
        {
            Harmony12.Patches patches = harmony.GetPatchInfo(target);
            if (patches == null) return false;
            return (prefix ? patches.Prefixes : patches.Postfixes)
                .Any(patch => string.Equals(patch.owner, ProductMetadata.Id, StringComparison.Ordinal) && patch.patch == patchMethod);
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

        private void RefreshCompatibilityWarning()
        {
            if (harmony == null || contracts == null) return;
            string warning = compatibilityDetector.Detect(harmony, contracts);
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
            coordinator?.CompleteCurrentIfAny("mod disable/unload");
            PatchBridge.Clear();
            if (harmony != null) harmony.UnpatchAll(ProductMetadata.Id);
            harmony = null;
            coordinator = null;
            activeSaveResolver = null;
            contracts = null;
            enabled = false;
            lastCompatibilityWarning = string.Empty;
            status.SetProtection(false, "disabled", "disabled");
        }
    }
}
