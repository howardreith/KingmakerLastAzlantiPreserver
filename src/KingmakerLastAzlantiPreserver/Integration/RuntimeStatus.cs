namespace KingmakerLastAzlantiPreserver.Integration
{
    public sealed class RuntimeStatus
    {
        private readonly object gate = new object();
        private bool protectionAvailable;
        private bool lastAzlantiRecognized;
        private string gameOverHook = "unresolved";
        private string deletionHook = "unresolved";
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
                    protectionAvailable,
                    lastAzlantiRecognized,
                    gameOverHook,
                    deletionHook,
                    recoveryDirectory,
                    latestRecoveryResult,
                    latestInterceptionResult,
                    latestError,
                    compatibilityWarning);
            }
        }

        public void SetProtection(bool available, string resolvedGameOverHook, string resolvedDeletionHook)
        {
            lock (gate)
            {
                protectionAvailable = available;
                gameOverHook = resolvedGameOverHook ?? "unresolved";
                deletionHook = resolvedDeletionHook ?? "unresolved";
            }
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
            bool protectionAvailable,
            bool lastAzlantiRecognized,
            string gameOverHook,
            string deletionHook,
            string recoveryDirectory,
            string latestRecoveryResult,
            string latestInterceptionResult,
            string latestError,
            string compatibilityWarning)
        {
            ProtectionAvailable = protectionAvailable;
            LastAzlantiRecognized = lastAzlantiRecognized;
            GameOverHook = gameOverHook;
            DeletionHook = deletionHook;
            RecoveryDirectory = recoveryDirectory;
            LatestRecoveryResult = latestRecoveryResult;
            LatestInterceptionResult = latestInterceptionResult;
            LatestError = latestError;
            CompatibilityWarning = compatibilityWarning;
        }

        public bool ProtectionAvailable { get; }
        public bool LastAzlantiRecognized { get; }
        public string GameOverHook { get; }
        public string DeletionHook { get; }
        public string RecoveryDirectory { get; }
        public string LatestRecoveryResult { get; }
        public string LatestInterceptionResult { get; }
        public string LatestError { get; }
        public string CompatibilityWarning { get; }
    }
}
