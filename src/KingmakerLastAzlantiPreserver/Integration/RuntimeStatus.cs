namespace KingmakerLastAzlantiPreserver.Integration
{
    public enum RuntimeFeatureState
    {
        Disabled,
        Available,
        Unavailable
    }

    public sealed class RuntimeStatus
    {
        private readonly object gate = new object();
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
        private string compatibilityWarning = string.Empty;

        public RuntimeStatusSnapshot Snapshot()
        {
            lock (gate)
            {
                return new RuntimeStatusSnapshot(
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
                    compatibilityWarning);
            }
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

        public void SetCompatibilityWarning(string value)
        {
            lock (gate) compatibilityWarning = value ?? string.Empty;
        }
    }

    public sealed class RuntimeStatusSnapshot
    {
        public RuntimeStatusSnapshot(
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
            string compatibilityWarning)
        {
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
            CompatibilityWarning = compatibilityWarning;
        }

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
        public string CompatibilityWarning { get; }
    }
}
