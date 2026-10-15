namespace KingmakerLastAzlantiPreserver.Integration
{
    public sealed class CompatibilityReport
    {
        public static readonly CompatibilityReport None = new CompatibilityReport(false, 0, 0, string.Empty);

        public CompatibilityReport(
            bool firstAzlantiLoaded,
            int foreignCoreOwnerCount,
            int foreignGameOverLoadOwnerCount,
            string detail)
        {
            FirstAzlantiLoaded = firstAzlantiLoaded;
            ForeignCoreOwnerCount = foreignCoreOwnerCount;
            ForeignGameOverLoadOwnerCount = foreignGameOverLoadOwnerCount;
            Detail = detail ?? string.Empty;
        }

        public bool FirstAzlantiLoaded { get; }

        // Distinct non-mod Harmony owners on core or optional targets. Detection only; never proof of a conflict.
        public int ForeignCoreOwnerCount { get; }
        public int ForeignGameOverLoadOwnerCount { get; }

        // The complete technical report, also written to the UMM log.
        public string Detail { get; }
    }
}
