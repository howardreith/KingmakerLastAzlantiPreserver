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
        private bool recoveryConfirmed;
        private RecoveryDecision cachedRecoveryDecision;
        private DateTime nextRecoveryRefreshUtc;

        public SettingsView(
            Settings settings,
            RuntimeStatus status,
            Func<RecoveryDecision> getRecoveryDecision,
            Func<string, bool, RecoveryDecision> restore)
        {
            this.settings = settings ?? throw new ArgumentNullException(nameof(settings));
            this.status = status ?? throw new ArgumentNullException(nameof(status));
            this.getRecoveryDecision = getRecoveryDecision ?? throw new ArgumentNullException(nameof(getRecoveryDecision));
            this.restore = restore ?? throw new ArgumentNullException(nameof(restore));
        }

        public void Draw()
        {
            RuntimeStatusSnapshot snapshot = status.Snapshot();
            GUILayout.Label(ProductMetadata.Name + " " + ProductMetadata.Version);
            settings.PreserveLastAzlantiSaveOnGameOver = GUILayout.Toggle(
                settings.PreserveLastAzlantiSaveOnGameOver,
                "Preserve Last Azlanti save on game over");
            settings.MaintainHiddenRecoverySnapshot = GUILayout.Toggle(
                settings.MaintainHiddenRecoverySnapshot,
                "Maintain hidden recovery snapshot");
            settings.VerboseDiagnostics = GUILayout.Toggle(settings.VerboseDiagnostics, "Verbose diagnostics");

            GUILayout.Space(6f);
            GUILayout.Label("Protection: " + (snapshot.ProtectionAvailable ? "AVAILABLE" : "UNAVAILABLE"));
            GUILayout.Label("Game-over hook: " + snapshot.GameOverHook);
            GUILayout.Label("Deletion hook: " + snapshot.DeletionHook);
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
    }
}
