namespace KingmakerLastAzlantiPreserver.Preservation
{
    public sealed class PreservationRequest
    {
        public bool FeatureEnabled { get; set; }
        public bool OnlyOneSaveEnabled { get; set; }
        public bool TargetIsIronMan { get; set; }
        public bool ContextExists { get; set; }
        public bool ContextIsFresh { get; set; }
        public bool ContextThreadMatches { get; set; }
        public bool ExplicitLoadUiDeletionIsOnStack { get; set; }
        public bool TargetMatchesContext { get; set; }
    }
}
