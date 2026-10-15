using System;
using System.Collections.Generic;
using System.IO;
using KingmakerLastAzlantiPreserver.Integration;
using KingmakerLastAzlantiPreserver.Recovery;

namespace KingmakerLastAzlantiPreserver.UI
{
    // Unity-free presentation and interaction state for the UMM panel. SettingsView only renders the model.
    public sealed class SettingsPanel
    {
        public const string PreserveSaveLabel = "Keep your Last Azlanti save after defeat";
        public const string GameOverLoadingLabel = "Allow loading from the game-over screen";
        public const string RecoveryBackupLabel = "Keep a hidden recovery backup";
        public const string VerboseDiagnosticsLabel = "Verbose diagnostics (more detail in the Unity Mod Manager log)";
        public const string Explanation = "Last Azlanti's normal saving restrictions remain unchanged.";
        public const string ShowTroubleshootingLabel = "Show troubleshooting";
        public const string HideTroubleshootingLabel = "Hide troubleshooting";

        private static readonly TimeSpan RecoveryRefreshInterval = TimeSpan.FromMinutes(1);
        private readonly Settings settings;
        private readonly RuntimeStatus status;
        private readonly Func<RecoveryDecision> getRecoveryDecision;
        private readonly Func<string, bool, RecoveryDecision> restore;
        private readonly Action settingsChanged;
        private readonly Func<DateTime> utcNow;
        private bool troubleshootingExpanded;
        private bool recoveryConfirmed;
        private RecoveryDecision cachedRecoveryDecision;
        private DateTime nextRecoveryRefreshUtc;

        public SettingsPanel(
            Settings settings,
            RuntimeStatus status,
            Func<RecoveryDecision> getRecoveryDecision,
            Func<string, bool, RecoveryDecision> restore,
            Action settingsChanged,
            Func<DateTime> utcNow = null)
        {
            this.settings = settings ?? throw new ArgumentNullException(nameof(settings));
            this.status = status ?? throw new ArgumentNullException(nameof(status));
            this.getRecoveryDecision = getRecoveryDecision ?? throw new ArgumentNullException(nameof(getRecoveryDecision));
            this.restore = restore ?? throw new ArgumentNullException(nameof(restore));
            this.settingsChanged = settingsChanged ?? throw new ArgumentNullException(nameof(settingsChanged));
            this.utcNow = utcNow ?? (() => DateTime.UtcNow);
        }

        public void RefreshRecoveryIfDue()
        {
            if (cachedRecoveryDecision == null || utcNow() >= nextRecoveryRefreshUtc) RefreshRecovery();
        }

        public void RefreshRecovery()
        {
            RecoveryDecision previous = cachedRecoveryDecision;
            RecoveryDecision current;
            try
            {
                current = getRecoveryDecision();
            }
            catch (Exception exception)
            {
                current = new RecoveryDecision(
                    RecoveryDecisionKind.Rejected,
                    "Recovery status could not be read: " + exception.GetType().Name + ": " + exception.Message,
                    string.Empty,
                    string.Empty,
                    false);
            }

            cachedRecoveryDecision = current;
            nextRecoveryRefreshUtc = utcNow().Add(RecoveryRefreshInterval);

            // A confirmation applies only to the restorable recovery it was given for.
            if (previous == null || !current.CanRestore ||
                !string.Equals(previous.RecoveryId, current.RecoveryId, StringComparison.Ordinal))
            {
                recoveryConfirmed = false;
            }
        }

        public void SetSetting(PanelSetting setting, bool value)
        {
            switch (setting)
            {
                case PanelSetting.PreserveSave:
                    if (settings.PreserveLastAzlantiSaveOnGameOver == value) return;
                    settings.PreserveLastAzlantiSaveOnGameOver = value;
                    settingsChanged();
                    return;
                case PanelSetting.GameOverLoading:
                    if (settings.EnableGameOverLoadControls == value || !IsGameOverLoadingToggleEnabled(status.Snapshot())) return;
                    settings.EnableGameOverLoadControls = value;
                    settingsChanged();
                    return;
                case PanelSetting.RecoveryBackup:
                    settings.MaintainHiddenRecoverySnapshot = value;
                    return;
                case PanelSetting.VerboseDiagnostics:
                    settings.VerboseDiagnostics = value;
                    return;
            }
        }

        public void ToggleTroubleshooting()
        {
            troubleshootingExpanded = !troubleshootingExpanded;
        }

        public void SetRecoveryConfirmed(bool value)
        {
            recoveryConfirmed = value && cachedRecoveryDecision != null && cachedRecoveryDecision.CanRestore;
        }

        public void RestoreRecovery()
        {
            RecoveryDecision decision = cachedRecoveryDecision;
            if (decision == null || !decision.CanRestore || !recoveryConfirmed) return;

            RecoveryDecision result;
            try
            {
                result = restore(decision.RecoveryId, recoveryConfirmed);
            }
            catch (Exception exception)
            {
                result = new RecoveryDecision(
                    RecoveryDecisionKind.Rejected,
                    "Recovery restore failed: " + exception.GetType().Name + ": " + exception.Message,
                    decision.RecoveryId,
                    decision.OriginalPath,
                    false);
            }

            status.SetRecoveryResult(result.Message);
            if (result.Kind == RecoveryDecisionKind.Rejected) status.SetError(result.Message);
            cachedRecoveryDecision = result;
            nextRecoveryRefreshUtc = utcNow().Add(RecoveryRefreshInterval);
            recoveryConfirmed = false;
        }

        // Builds from cached state only: no filesystem access and no side effects.
        public SettingsPanelModel Build()
        {
            RuntimeStatusSnapshot snapshot = status.Snapshot();
            bool preserve = settings.PreserveLastAzlantiSaveOnGameOver;
            List<PanelToggle> toggles = new List<PanelToggle>
            {
                new PanelToggle(PanelSetting.PreserveSave, PreserveSaveLabel, preserve, true),
                new PanelToggle(
                    PanelSetting.GameOverLoading,
                    GameOverLoadingLabel,
                    settings.EnableGameOverLoadControls,
                    IsGameOverLoadingToggleEnabled(snapshot)),
                new PanelToggle(PanelSetting.RecoveryBackup, RecoveryBackupLabel, settings.MaintainHiddenRecoverySnapshot, true)
            };

            return new SettingsPanelModel(
                toggles,
                Explanation,
                BuildStatus(snapshot),
                BuildContext(snapshot),
                BuildAlerts(snapshot),
                BuildRecovery(),
                troubleshootingExpanded ? HideTroubleshootingLabel : ShowTroubleshootingLabel,
                troubleshootingExpanded ? BuildTroubleshooting(snapshot) : null);
        }

        private bool IsGameOverLoadingToggleEnabled(RuntimeStatusSnapshot snapshot)
        {
            return snapshot.CoreContractsInstalled && settings.PreserveLastAzlantiSaveOnGameOver;
        }

        private List<PanelStatusLine> BuildStatus(RuntimeStatusSnapshot snapshot)
        {
            List<PanelStatusLine> lines = new List<PanelStatusLine>();
            if (!snapshot.ModEnabled) return lines;

            bool coreUnavailable = snapshot.CoreProtectionState == RuntimeFeatureState.Unavailable;
            bool coreReady = snapshot.CoreProtectionState == RuntimeFeatureState.Available;
            bool preserve = settings.PreserveLastAzlantiSaveOnGameOver;

            PanelFeatureStatus saveProtection = coreUnavailable
                ? PanelFeatureStatus.Unavailable
                : (coreReady ? PanelFeatureStatus.Ready : PanelFeatureStatus.Off);

            PanelFeatureStatus gameOverLoading;
            if (coreUnavailable || snapshot.GameOverLoadControlsState == RuntimeFeatureState.Unavailable) gameOverLoading = PanelFeatureStatus.Unavailable;
            else if (!settings.EnableGameOverLoadControls) gameOverLoading = PanelFeatureStatus.Off;
            else if (!preserve) gameOverLoading = PanelFeatureStatus.NeedsSaveProtection;
            else if (snapshot.GameOverLoadControlsState == RuntimeFeatureState.Available) gameOverLoading = PanelFeatureStatus.Ready;
            else gameOverLoading = PanelFeatureStatus.Off;

            // The backup is taken only inside an active save-protection operation.
            PanelFeatureStatus recoveryBackup;
            if (coreUnavailable) recoveryBackup = PanelFeatureStatus.Unavailable;
            else if (!settings.MaintainHiddenRecoverySnapshot) recoveryBackup = PanelFeatureStatus.Off;
            else if (!preserve) recoveryBackup = PanelFeatureStatus.NeedsSaveProtection;
            else if (coreReady) recoveryBackup = PanelFeatureStatus.Ready;
            else recoveryBackup = PanelFeatureStatus.Off;

            lines.Add(StatusLine(PanelFeature.SaveProtection, "Save protection", saveProtection));
            lines.Add(StatusLine(PanelFeature.GameOverLoading, "Game-over loading", gameOverLoading));
            lines.Add(StatusLine(PanelFeature.RecoveryBackup, "Recovery backup", recoveryBackup));
            return lines;
        }

        private static PanelStatusLine StatusLine(PanelFeature feature, string name, PanelFeatureStatus value)
        {
            return new PanelStatusLine(feature, value, name + ": " + FormatFeatureStatus(value));
        }

        private static string FormatFeatureStatus(PanelFeatureStatus value)
        {
            switch (value)
            {
                case PanelFeatureStatus.Ready: return "Ready";
                case PanelFeatureStatus.NeedsSaveProtection: return "Off (needs save protection)";
                case PanelFeatureStatus.Unavailable: return "Unavailable";
                default: return "Off";
            }
        }

        private static string BuildContext(RuntimeStatusSnapshot snapshot)
        {
            if (!snapshot.ModEnabled) return "The mod is turned off in Unity Mod Manager.";
            if (snapshot.CoreProtectionState != RuntimeFeatureState.Available) return null;

            // Recognition is not protection: nothing is claimed about a save until a defeat is handled.
            return snapshot.LastAzlantiRecognized
                ? "Your current Last Azlanti save is recognized."
                : "No Last Azlanti game is active.";
        }

        private List<PanelAlert> BuildAlerts(RuntimeStatusSnapshot snapshot)
        {
            List<PanelAlert> alerts = new List<PanelAlert>();
            if (snapshot.ModEnabled)
            {
                if (snapshot.CoreProtectionState == RuntimeFeatureState.Unavailable)
                {
                    alerts.Add(new PanelAlert(
                        PanelAlertKind.SaveProtectionUnavailable,
                        PanelTone.Problem,
                        "Save protection is unavailable, so defeat deletes Last Azlanti saves as in the unmodded game. See Troubleshooting."));
                }
                else if (snapshot.GameOverLoadControlsState == RuntimeFeatureState.Unavailable)
                {
                    alerts.Add(new PanelAlert(
                        PanelAlertKind.GameOverLoadingUnavailable,
                        PanelTone.Notice,
                        "Game-over loading is unavailable. Save protection is not affected. See Troubleshooting."));
                }
            }

            CompatibilityReport compatibility = snapshot.Compatibility;
            if (compatibility.FirstAzlantiLoaded)
            {
                alerts.Add(new PanelAlert(
                    PanelAlertKind.FirstAzlantiLoaded,
                    PanelTone.Problem,
                    "The original FirstAzlanti mod is also loaded. Disable it; the two mods should not be used together."));
            }

            if (compatibility.ForeignCoreOwnerCount > 0)
            {
                alerts.Add(new PanelAlert(
                    PanelAlertKind.SaveProtectionCompatibilityUnverified,
                    PanelTone.Notice,
                    OtherModsPatch(compatibility.ForeignCoreOwnerCount) + " code used by save protection; compatibility is unverified."));
            }

            if (compatibility.ForeignGameOverLoadOwnerCount > 0)
            {
                alerts.Add(new PanelAlert(
                    PanelAlertKind.GameOverLoadingCompatibilityUnverified,
                    PanelTone.Notice,
                    OtherModsPatch(compatibility.ForeignGameOverLoadOwnerCount) + " code used by game-over loading; compatibility is unverified."));
            }

            RuntimeIssue issues = snapshot.Issues;
            if ((issues & RuntimeIssue.SavePreservationFailed) != 0)
            {
                alerts.Add(new PanelAlert(
                    PanelAlertKind.SavePreservationFailed,
                    PanelTone.Problem,
                    "At the last defeat, the Last Azlanti save could not be identified, so it may have been deleted. See Troubleshooting."));
            }

            if ((issues & RuntimeIssue.RecoveryBackupFailed) != 0)
            {
                alerts.Add(new PanelAlert(
                    PanelAlertKind.RecoveryBackupFailed,
                    PanelTone.Notice,
                    "At the last defeat, the recovery backup could not be made. Save protection does not depend on it. See Troubleshooting."));
            }

            if ((issues & RuntimeIssue.GameOverLoadingFailed) != 0)
            {
                alerts.Add(new PanelAlert(
                    PanelAlertKind.GameOverLoadingFailed,
                    PanelTone.Notice,
                    "At the last defeat, game-over loading ran into an error. Save protection does not depend on it. See Troubleshooting."));
            }

            if ((issues & RuntimeIssue.CleanupFailed) != 0)
            {
                alerts.Add(new PanelAlert(
                    PanelAlertKind.CleanupFailed,
                    PanelTone.Problem,
                    "Some changes could not be undone when the mod was turned off. Restart the game before playing on."));
            }

            return alerts;
        }

        private static string OtherModsPatch(int ownerCount)
        {
            return ownerCount == 1 ? "Another mod also patches" : "Other mods also patch";
        }

        private RecoveryPanel BuildRecovery()
        {
            RecoveryDecision decision = cachedRecoveryDecision;
            if (decision == null) return null;
            string fileName = SafeFileName(decision.OriginalPath);
            switch (decision.Kind)
            {
                case RecoveryDecisionKind.ReadyToRestore:
                    return new RecoveryPanel(
                        RecoveryPanelState.Restorable,
                        PanelTone.Notice,
                        new[]
                        {
                            "A verified backup can restore " + fileName + ", which is missing from your saves.",
                            "Restoring never overwrites an existing file."
                        },
                        true,
                        recoveryConfirmed,
                        recoveryConfirmed && decision.CanRestore);
                case RecoveryDecisionKind.Rejected:
                    return new RecoveryPanel(
                        RecoveryPanelState.Blocked,
                        PanelTone.Problem,
                        new[]
                        {
                            "A pending recovery backup could not be verified, so it will not be restored.",
                            "Reason: " + decision.Message,
                            "Leave the recovery files as they are, and use your own backup if you have one."
                        },
                        false,
                        false,
                        false);
                case RecoveryDecisionKind.Restored:
                    return new RecoveryPanel(
                        RecoveryPanelState.Restored,
                        PanelTone.Normal,
                        new[] { "Restored " + fileName + " to your saves folder." },
                        false,
                        false,
                        false);
                default:
                    // No marker, or the recorded save still exists and will never be overwritten: nothing to do.
                    return null;
            }
        }

        private static string SafeFileName(string path)
        {
            try
            {
                string name = Path.GetFileName(path);
                return string.IsNullOrEmpty(name) ? "the recorded save" : name;
            }
            catch (ArgumentException)
            {
                return "the recorded save";
            }
        }

        private TroubleshootingPanel BuildTroubleshooting(RuntimeStatusSnapshot snapshot)
        {
            RecoveryDecision decision = cachedRecoveryDecision;
            CompatibilityReport compatibility = snapshot.Compatibility;
            string compatibilityDetail = !snapshot.CoreContractsInstalled
                ? "not checked (core preservation is not installed)"
                : (string.IsNullOrEmpty(compatibility.Detail)
                    ? "no other patch owners or FirstAzlanti assemblies detected"
                    : compatibility.Detail);

            List<PanelDetail> details = new List<PanelDetail>
            {
                new PanelDetail("Mod enabled", YesNo(snapshot.ModEnabled)),
                new PanelDetail("Core preservation", FormatState(snapshot.CoreProtectionState)),
                new PanelDetail("Core patches installed", YesNo(snapshot.CoreContractsInstalled)),
                new PanelDetail("Game-over loading controls", FormatState(snapshot.GameOverLoadControlsState)),
                new PanelDetail("Game-over loading patches installed", YesNo(snapshot.GameOverLoadContractsInstalled)),
                new PanelDetail("Game-over loading detail", snapshot.GameOverLoadControlsDetail),
                new PanelDetail("Game-over hook", snapshot.GameOverHook),
                new PanelDetail("Deletion hook", snapshot.DeletionHook),
                new PanelDetail("Game-over UI hook", snapshot.GameOverLoadHook),
                new PanelDetail("Controller UI hook", snapshot.ControllerLoadHook),
                new PanelDetail("Last Azlanti save recognized", YesNo(snapshot.LastAzlantiRecognized)),
                new PanelDetail("Latest game-over loading eligibility", snapshot.LatestGameOverLoadEligibility),
                new PanelDetail("Recovery directory", snapshot.RecoveryDirectory),
                new PanelDetail(
                    "Guarded recovery",
                    decision == null ? "not checked yet" : decision.Kind + ": " + decision.Message),
                new PanelDetail("Latest recovery", snapshot.LatestRecoveryResult),
                new PanelDetail("Latest interception", snapshot.LatestInterceptionResult),
                new PanelDetail("Latest error", snapshot.LatestError),
                new PanelDetail("Compatibility", compatibilityDetail)
            };

            return new TroubleshootingPanel(
                new PanelToggle(PanelSetting.VerboseDiagnostics, VerboseDiagnosticsLabel, settings.VerboseDiagnostics, true),
                details);
        }

        private static string YesNo(bool value)
        {
            return value ? "yes" : "no";
        }

        private static string FormatState(RuntimeFeatureState state)
        {
            return state.ToString().ToUpperInvariant();
        }
    }
}
