using System;

namespace KingmakerLastAzlantiPreserver.Preservation
{
    public sealed class PreservationContext
    {
        public PreservationContext(
            Guid operationId,
            SaveIdentity saveIdentity,
            DateTime startedUtc,
            DateTime expiresUtc,
            int managedThreadId)
        {
            OperationId = operationId;
            SaveIdentity = saveIdentity ?? throw new ArgumentNullException(nameof(saveIdentity));
            StartedUtc = startedUtc;
            ExpiresUtc = expiresUtc;
            ManagedThreadId = managedThreadId;
        }

        public Guid OperationId { get; }
        public SaveIdentity SaveIdentity { get; }
        public DateTime StartedUtc { get; }
        public DateTime ExpiresUtc { get; }
        public int ManagedThreadId { get; }
        public bool RecoveryMarkerCreated { get; internal set; }
        public string RecoveryId { get; internal set; }
        public int InterceptionCount { get; internal set; }

        public bool IsFresh(DateTime utcNow)
        {
            return utcNow >= StartedUtc.AddSeconds(-1) && utcNow <= ExpiresUtc;
        }
    }
}
