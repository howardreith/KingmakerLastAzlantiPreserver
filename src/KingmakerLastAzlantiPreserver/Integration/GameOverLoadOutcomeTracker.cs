using System;
using KingmakerLastAzlantiPreserver.Preservation;

namespace KingmakerLastAzlantiPreserver.Integration
{
    public sealed class GameOverLoadOutcome
    {
        public GameOverLoadOutcome(Guid operationId, SaveIdentity saveIdentity, DateTime completedUtc, DateTime expiresUtc)
        {
            if (operationId == Guid.Empty) throw new ArgumentException("The operation identity cannot be empty.", nameof(operationId));
            OperationId = operationId;
            SaveIdentity = saveIdentity ?? throw new ArgumentNullException(nameof(saveIdentity));
            CompletedUtc = completedUtc;
            ExpiresUtc = expiresUtc;
        }

        public Guid OperationId { get; }
        public SaveIdentity SaveIdentity { get; }
        public DateTime CompletedUtc { get; }
        public DateTime ExpiresUtc { get; }

        public bool IsFresh(DateTime utcNow)
        {
            return utcNow >= CompletedUtc.AddSeconds(-1) && utcNow <= ExpiresUtc;
        }
    }

    public sealed class GameOverLoadOutcomeTracker
    {
        private static readonly TimeSpan DefaultMaximumLifetime = TimeSpan.FromHours(12);
        private readonly object gate = new object();
        private readonly TimeSpan maximumLifetime;
        private GameOverLoadOutcome current;

        public GameOverLoadOutcomeTracker()
            : this(DefaultMaximumLifetime)
        {
        }

        public GameOverLoadOutcomeTracker(TimeSpan maximumLifetime)
        {
            if (maximumLifetime <= TimeSpan.Zero) throw new ArgumentOutOfRangeException(nameof(maximumLifetime));
            this.maximumLifetime = maximumLifetime;
        }

        public void BeginNextOperation()
        {
            Clear();
        }

        public GameOverLoadOutcome Record(Guid operationId, SaveIdentity saveIdentity, DateTime completedUtc)
        {
            GameOverLoadOutcome outcome = new GameOverLoadOutcome(
                operationId,
                saveIdentity,
                completedUtc,
                completedUtc.Add(maximumLifetime));
            lock (gate)
            {
                current = outcome;
                return outcome;
            }
        }

        public GameOverLoadOutcome GetCurrent(DateTime utcNow, out bool stale)
        {
            lock (gate)
            {
                stale = current != null && !current.IsFresh(utcNow);
                if (stale)
                {
                    current = null;
                    return null;
                }

                return current;
            }
        }

        public void Clear()
        {
            lock (gate) current = null;
        }
    }
}
