namespace KingmakerLastAzlantiPreserver.Preservation
{
    public sealed class PreservationPolicy
    {
        public PreservationDecision Evaluate(PreservationRequest request)
        {
            if (request == null) return PreservationDecision.Allow("No preservation request was supplied.");
            if (!request.FeatureEnabled) return PreservationDecision.Allow("Preservation is disabled.");
            if (!request.OnlyOneSaveEnabled) return PreservationDecision.Allow("Only One Save is not enabled.");
            if (!request.TargetIsIronMan) return PreservationDecision.Allow("The target is not an IronMan save.");
            if (!request.ContextExists) return PreservationDecision.Allow("No game-over preservation context exists.");
            if (!request.ContextIsFresh) return PreservationDecision.Allow("The game-over context is stale.");
            if (!request.ContextThreadMatches) return PreservationDecision.Allow("The deletion is on a different thread.");
            if (request.ExplicitLoadUiDeletionIsOnStack) return PreservationDecision.Allow("The deletion came from the load-game UI.");
            if (!request.TargetMatchesContext) return PreservationDecision.Allow("The target is not the active game-over save.");

            return PreservationDecision.Suppress("Blocked the matching Last Azlanti game-over deletion.");
        }
    }
}
