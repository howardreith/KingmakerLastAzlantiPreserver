using System;

namespace KingmakerLastAzlantiPreserver.Preservation
{
    public sealed class PreservationContextTracker
    {
        private static readonly TimeSpan MaximumLifetime = TimeSpan.FromSeconds(30);
        private readonly object gate = new object();
        private PreservationContext current;

        public PreservationContext Begin(SaveIdentity saveIdentity, DateTime utcNow, int managedThreadId)
        {
            if (saveIdentity == null) throw new ArgumentNullException(nameof(saveIdentity));
            lock (gate)
            {
                current = new PreservationContext(
                    Guid.NewGuid(),
                    saveIdentity,
                    utcNow,
                    utcNow.Add(MaximumLifetime),
                    managedThreadId);
                return current;
            }
        }

        public PreservationContext Current
        {
            get
            {
                lock (gate) return current;
            }
        }

        public bool IsCurrent(PreservationContext context)
        {
            lock (gate) return ReferenceEquals(current, context);
        }

        public void End(PreservationContext context)
        {
            lock (gate)
            {
                if (ReferenceEquals(current, context)) current = null;
            }
        }

        public PreservationContext SweepIfOrphaned(DateTime utcNow, bool scopeIsKnownToHaveEnded)
        {
            lock (gate)
            {
                if (current == null) return null;
                if (!scopeIsKnownToHaveEnded && current.IsFresh(utcNow)) return null;
                PreservationContext orphaned = current;
                current = null;
                return orphaned;
            }
        }
    }
}
