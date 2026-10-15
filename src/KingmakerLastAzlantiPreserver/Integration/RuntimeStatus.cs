using System;

namespace KingmakerLastAzlantiPreserver.Integration
{
    public enum RuntimeFeatureState
    {
        Disabled,
        Available,
        Unavailable
    }

    // Problems the player should see without opening diagnostics. Detail text stays in LatestError.
    [Flags]
    public enum RuntimeIssue
    {
        None = 0,
        SavePreservationFailed = 1,
        RecoveryBackupFailed = 2,
        GameOverLoadingFailed = 4,
        CleanupFailed = 8
    }

    public sealed class RuntimeStatus
    {
        private const RuntimeIssue DefeatIssues =
            RuntimeIssue.SavePreservationFailed | RuntimeIssue.RecoveryBackupFailed | RuntimeIssue.GameOverLoadingFailed;

        private readonly object gate = new object();
        private bool modEnabled;
        private RuntimeFeatureState coreProtectionState = RuntimeFeatureState.Disabled;
        private RuntimeFeatureState gameOverLoadControlsState = RuntimeFeatureState.Disabled;
        private bool coreContractsInstalled;
        private bool gameOverLoadContractsInstalled;
        private bool lastAzlantiRecognized;
        private string gameOverHook = "unresolved";
        private string deletionHook = "unresolved";
        private string gameOverLoadHook = "unresolved";
        private string controllerLoadHook = "unresolved";
        private string gameOverLoadControlsDetail = "disabled";
        private string latestGameOverLoadEligibility = "none";
        private string recoveryDirectory = "unresolved";
        private string latestRecoveryResult = "none";
        private string latestInterceptionResult = "none";
        private string latestError = "none";
        private RuntimeIssue issues;
        private CompatibilityReport compatibility = CompatibilityReport.None;

        public RuntimeStatusSnapshot Snapshot()
        {
            lock (gate)
            {
                return new RuntimeStatusSnapshot(
                    modEnabled,
                    coreProtectionState,
                    gameOverLoadControlsState,
                    coreContractsInstalled,
                    gameOverLoadContractsInstalled,
                    lastAzlantiRecognized,
                    gameOverHook,
                    deletionHook,
                    gameOverLoadHook,
                    controllerLoadHook,
                    gameOverLoadControlsDetail,
                    latestGameOverLoadEligibility,
                    recoveryDirectory,
                    latestRecoveryResult,
                    latestInterceptionResult,
                    latestError,
                    issues,
                    compatibility);
            }
        }

        public void SetModEnabled(bool value)
        {
            lock (gate) modEnabled = value;
        }

        public void SetCoreProtection(
            RuntimeFeatureState state,
            bool contractsInstalled,
            string resolvedGameOverHook,
            string resolvedDeletionHook)
        {
            lock (gate)
            {
                coreProtectionState = state;
                coreContractsInstalled = contractsInstalled;
                gameOverHook = resolvedGameOverHook ?? "unresolved";
                deletionHook = resolvedDeletionHook ?? "unresolved";
            }
        }

        public void SetGameOverLoadControls(
            RuntimeFeatureState state,
            bool contractsInstalled,
            string resolvedGameOverLoadHook,
            string resolvedControllerLoadHook,
            string detail)
        {
            lock (gate)
            {
                gameOverLoadControlsState = state;
                gameOverLoadContractsInstalled = contractsInstalled;
                gameOverLoadHook = resolvedGameOverLoadHook ?? "unresolved";
                controllerLoadHook = resolvedControllerLoadHook ?? "unresolved";
                gameOverLoadControlsDetail = string.IsNullOrWhiteSpace(detail) ? "none" : detail;
            }
        }

        public void SetGameOverLoadEligibility(string value)
        {
            lock (gate) latestGameOverLoadEligibility = string.IsNullOrWhiteSpace(value) ? "none" : value;
        }

        public void SetLastAzlantiRecognized(bool value)
        {
            lock (gate) lastAzlantiRecognized = value;
        }

        public void SetRecoveryDirectory(string value)
        {
            lock (gate) recoveryDirectory = value ?? "unresolved";
        }

        public void SetRecoveryResult(string value)
        {
            lock (gate) latestRecoveryResult = value ?? "none";
        }

        public void SetInterceptionResult(string value)
        {
            lock (gate) latestInterceptionResult = value ?? "none";
        }

        public void SetError(string value)
        {
            lock (gate) latestError = string.IsNullOrWhiteSpace(value) ? "none" : value;
        }

        public void SetError(string value, RuntimeIssue issue)
        {
            lock (gate)
            {
                latestError = string.IsNullOrWhiteSpace(value) ? "none" : value;
                issues |= issue;
            }
        }

        // A new game over replaces the outcome of the previous one; persistent issues remain.
        public void ClearDefeatIssues()
        {
            lock (gate) issues &= ~DefeatIssues;
        }

        public void SetCompatibility(CompatibilityReport value)
        {
            lock (gate) compatibility = value ?? CompatibilityReport.None;
        }
    }

    public sealed class RuntimeStatusSnapshot
    {
        public RuntimeStatusSnapshot(
            bool modEnabled,
            RuntimeFeatureState coreProtectionState,
            RuntimeFeatureState gameOverLoadControlsState,
            bool coreContractsInstalled,
            bool gameOverLoadContractsInstalled,
            bool lastAzlantiRecognized,
            string gameOverHook,
            string deletionHook,
            string gameOverLoadHook,
            string controllerLoadHook,
            string gameOverLoadControlsDetail,
            string latestGameOverLoadEligibility,
            string recoveryDirectory,
            string latestRecoveryResult,
            string latestInterceptionResult,
            string latestError,
            RuntimeIssue issues,
            CompatibilityReport compatibility)
        {
            ModEnabled = modEnabled;
            CoreProtectionState = coreProtectionState;
            GameOverLoadControlsState = gameOverLoadControlsState;
            CoreContractsInstalled = coreContractsInstalled;
            GameOverLoadContractsInstalled = gameOverLoadContractsInstalled;
            LastAzlantiRecognized = lastAzlantiRecognized;
            GameOverHook = gameOverHook;
            DeletionHook = deletionHook;
            GameOverLoadHook = gameOverLoadHook;
            ControllerLoadHook = controllerLoadHook;
            GameOverLoadControlsDetail = gameOverLoadControlsDetail;
            LatestGameOverLoadEligibility = latestGameOverLoadEligibility;
            RecoveryDirectory = recoveryDirectory;
            LatestRecoveryResult = latestRecoveryResult;
            LatestInterceptionResult = latestInterceptionResult;
            LatestError = latestError;
            Issues = issues;
            Compatibility = compatibility ?? CompatibilityReport.None;
        }

        public bool ModEnabled { get; }
        public RuntimeFeatureState CoreProtectionState { get; }
        public RuntimeFeatureState GameOverLoadControlsState { get; }
        public bool CoreContractsInstalled { get; }
        public bool GameOverLoadContractsInstalled { get; }
        public bool ProtectionAvailable => CoreProtectionState == RuntimeFeatureState.Available;
        public bool LastAzlantiRecognized { get; }
        public string GameOverHook { get; }
        public string DeletionHook { get; }
        public string GameOverLoadHook { get; }
        public string ControllerLoadHook { get; }
        public string GameOverLoadControlsDetail { get; }
        public string LatestGameOverLoadEligibility { get; }
        public string RecoveryDirectory { get; }
        public string LatestRecoveryResult { get; }
        public string LatestInterceptionResult { get; }
        public string LatestError { get; }
        public RuntimeIssue Issues { get; }
        public CompatibilityReport Compatibility { get; }
        public string CompatibilityWarning => Compatibility.Detail;
    }
}
