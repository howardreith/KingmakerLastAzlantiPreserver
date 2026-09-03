namespace KingmakerLastAzlantiPreserver.Preservation
{
    public sealed class PreservationDecision
    {
        private PreservationDecision(bool suppressDeletion, string reason)
        {
            SuppressDeletion = suppressDeletion;
            Reason = reason;
        }

        public bool SuppressDeletion { get; }
        public string Reason { get; }

        public static PreservationDecision Suppress(string reason) => new PreservationDecision(true, reason);
        public static PreservationDecision Allow(string reason) => new PreservationDecision(false, reason);
    }
}
