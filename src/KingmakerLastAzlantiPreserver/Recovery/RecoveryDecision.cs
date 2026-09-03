namespace KingmakerLastAzlantiPreserver.Recovery
{
    public enum RecoveryDecisionKind
    {
        NoPendingMarker,
        OriginalStillExists,
        ReadyToRestore,
        Restored,
        Rejected
    }

    public sealed class RecoveryDecision
    {
        public RecoveryDecision(
            RecoveryDecisionKind kind,
            string message,
            string recoveryId,
            string originalPath,
            bool canRestore)
        {
            Kind = kind;
            Message = message ?? string.Empty;
            RecoveryId = recoveryId ?? string.Empty;
            OriginalPath = originalPath ?? string.Empty;
            CanRestore = canRestore;
        }

        public RecoveryDecisionKind Kind { get; }
        public string Message { get; }
        public string RecoveryId { get; }
        public string OriginalPath { get; }
        public bool CanRestore { get; }
    }

    public sealed class SnapshotResult
    {
        private SnapshotResult(bool succeeded, string message, RecoveryMetadata metadata)
        {
            Succeeded = succeeded;
            Message = message ?? string.Empty;
            Metadata = metadata;
        }

        public bool Succeeded { get; }
        public string Message { get; }
        public RecoveryMetadata Metadata { get; }

        public static SnapshotResult Success(string message, RecoveryMetadata metadata)
        {
            return new SnapshotResult(true, message, metadata);
        }

        public static SnapshotResult Failure(string message)
        {
            return new SnapshotResult(false, message, null);
        }
    }
}
