using System;
using KingmakerLastAzlantiPreserver.Integration;
using KingmakerLastAzlantiPreserver.Recovery;
using UnityEngine;

namespace KingmakerLastAzlantiPreserver.UI
{
    public sealed class SettingsView
    {
        private readonly Settings settings;
        private readonly RuntimeStatus status;
        private readonly Func<RecoveryDecision> getRecoveryDecision;
        private readonly Func<string, bool, RecoveryDecision> restore;
        private readonly Action settingsChanged;
        private bool recoveryConfirmed;
        private RecoveryDecision cachedRecoveryDecision;
        private DateTime nextRecoveryRefreshUtc;

        public SettingsView(
            Settings settings,
            RuntimeStatus status,
            Func<RecoveryDecision> getRecoveryDecision,
            Func<string, bool, RecoveryDecision> restore,
            Action settingsChanged)
        {
            this.settings = settings ?? throw new ArgumentNullException(nameof(settings));
            this.status = status ?? throw new ArgumentNullException(nameof(status));
            this.getRecoveryDecision = getRecoveryDecision ?? throw new ArgumentNullException(nameof(getRecoveryDecision));
            this.restore = restore ?? throw new ArgumentNullException(nameof(restore));
            this.settingsChanged = settingsChanged ?? throw new ArgumentNullException(nameof(settingsChanged));
        }

        public void Draw()
        {
            RuntimeStatusSnapshot snapshot = status.Snapshot();
            GUILayout.Label(ProductMetadata.Name + " " + ProductMetadata.Version);
            bool oldPreservation = settings.PreserveLastAzlantiSaveOnGameOver;
            bool oldLoadControls = settings.EnableGameOverLoadControls;
            settings.PreserveLastAzlantiSaveOnGameOver = GUILayout.Toggle(
                settings.PreserveLastAzlantiSaveOnGameOver,
                "Preserve Last Azlanti save on game over");
            bool oldGuiEnabled = GUI.enabled;
            GUI.enabled = oldGuiEnabled && snapshot.CoreContractsInstalled && settings.PreserveLastAzlantiSaveOnGameOver;
            settings.EnableGameOverLoadControls = GUILayout.Toggle(
                settings.EnableGameOverLoadControls,
                "Allow loading the preserved save from the game-over screen");
            GUI.enabled = oldGuiEnabled;
            settings.MaintainHiddenRecoverySnapshot = GUILayout.Toggle(
                settings.MaintainHiddenRecoverySnapshot,
                "Maintain hidden recovery snapshot");
            settings.VerboseDiagnostics = GUILayout.Toggle(settings.VerboseDiagnostics, "Verbose diagnostics");
            if (oldPreservation != settings.PreserveLastAzlantiSaveOnGameOver ||
                oldLoadControls != settings.EnableGameOverLoadControls)
            {
                settingsChanged();
                snapshot = status.Snapshot();
            }

            GUILayout.Space(6f);
            GUILayout.Label("Core preservation: " + FormatState(snapshot.CoreProtectionState));
            GUILayout.Label("Game-over loading controls: " + FormatState(snapshot.GameOverLoadControlsState));
            GUILayout.Label("Game-over hook: " + snapshot.GameOverHook);
            GUILayout.Label("Deletion hook: " + snapshot.DeletionHook);
            GUILayout.Label("Game-over UI hook: " + snapshot.GameOverLoadHook);
            GUILayout.Label("Controller UI hook: " + snapshot.ControllerLoadHook);
            GUILayout.Label("Game-over loading detail: " + snapshot.GameOverLoadControlsDetail);
            GUILayout.Label("Latest game-over loading eligibility: " + snapshot.LatestGameOverLoadEligibility);
            GUILayout.Label("Last Azlanti save recognized: " + (snapshot.LastAzlantiRecognized ? "yes" : "no"));
            GUILayout.Label("Recovery directory: " + snapshot.RecoveryDirectory);
            GUILayout.Label("Latest recovery: " + snapshot.LatestRecoveryResult);
            GUILayout.Label("Latest interception: " + snapshot.LatestInterceptionResult);
            GUILayout.Label("Latest error: " + snapshot.LatestError);
            if (!string.IsNullOrEmpty(snapshot.CompatibilityWarning))
            {
                GUILayout.Space(4f);
                GUILayout.Label("COMPATIBILITY WARNING: " + snapshot.CompatibilityWarning);
            }

            GUILayout.Space(8f);
            if (cachedRecoveryDecision == null || DateTime.UtcNow >= nextRecoveryRefreshUtc)
            {
                RefreshRecoveryDecision();
            }

            if (GUILayout.Button("Refresh guarded recovery status")) RefreshRecoveryDecision();
            RecoveryDecision recoveryDecision = cachedRecoveryDecision;
            GUILayout.Label("Guarded recovery: " + recoveryDecision.Message);
            recoveryConfirmed = GUILayout.Toggle(
                recoveryConfirmed,
                "I confirm restoration of the recorded disposable/missing save path");
            bool oldEnabled = GUI.enabled;
            GUI.enabled = oldEnabled && recoveryConfirmed && recoveryDecision.CanRestore;
            if (GUILayout.Button("Restore validated pending recovery"))
            {
                RecoveryDecision result = restore(recoveryDecision.RecoveryId, recoveryConfirmed);
                status.SetRecoveryResult(result.Message);
                if (result.Kind == RecoveryDecisionKind.Rejected) status.SetError(result.Message);
                cachedRecoveryDecision = result;
                nextRecoveryRefreshUtc = DateTime.UtcNow.AddMinutes(1);
                recoveryConfirmed = false;
            }

            GUI.enabled = oldEnabled;
        }

        private void RefreshRecoveryDecision()
        {
            cachedRecoveryDecision = getRecoveryDecision();
            nextRecoveryRefreshUtc = DateTime.UtcNow.AddMinutes(1);
        }

        private static string FormatState(RuntimeFeatureState state)
        {
            return state.ToString().ToUpperInvariant();
        }
    }
}
