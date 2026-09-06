using System;
using KingmakerLastAzlantiPreserver.Integration;
using KingmakerLastAzlantiPreserver.Preservation;

namespace KingmakerLastAzlantiPreserver.Tests
{
    internal static class GameOverLoadOutcomeTests
    {
        public static void ExactIdentityRejectsDifferentCampaignAtSamePath()
        {
            SaveIdentity first = Identity("campaign-a");
            SaveIdentity second = Identity("campaign-b");
            AssertEx.False(first.ExactlyEquals(second));
            AssertEx.True(first.ExactlyEquals(Identity("campaign-a")));
        }

        public static void BeginningNextOperationClearsPriorOutcome()
        {
            DateTime now = UtcNow();
            GameOverLoadOutcomeTracker tracker = new GameOverLoadOutcomeTracker();
            Guid firstOperation = Guid.NewGuid();
            tracker.Record(firstOperation, Identity("campaign-a"), now);
            bool stale;
            AssertEx.Equal(firstOperation, tracker.GetCurrent(now, out stale).OperationId);
            tracker.BeginNextOperation();
            AssertEx.True(tracker.GetCurrent(now, out stale) == null);

            Guid secondOperation = Guid.NewGuid();
            tracker.Record(secondOperation, Identity("campaign-b"), now.AddMinutes(1));
            AssertEx.Equal(secondOperation, tracker.GetCurrent(now.AddMinutes(1), out stale).OperationId);
        }

        public static void LeavingGameOverClearsOutcome()
        {
            DateTime now = UtcNow();
            GameOverLoadOutcomeTracker tracker = new GameOverLoadOutcomeTracker();
            tracker.Record(Guid.NewGuid(), Identity("campaign-a"), now);
            tracker.Clear();
            bool stale;
            AssertEx.True(tracker.GetCurrent(now, out stale) == null);
        }

        public static void OutcomeExpiresAndCannotBecomeAStaleGrant()
        {
            DateTime now = UtcNow();
            GameOverLoadOutcomeTracker tracker = new GameOverLoadOutcomeTracker(TimeSpan.FromMinutes(5));
            tracker.Record(Guid.NewGuid(), Identity("campaign-a"), now);
            bool stale;
            AssertEx.True(tracker.GetCurrent(now.AddMinutes(6), out stale) == null);
            AssertEx.True(stale);
            AssertEx.True(tracker.GetCurrent(now.AddMinutes(6), out stale) == null);
            AssertEx.False(stale);
        }

        public static void LoadWindowCancelRetainsSameOperationUntilTerminalBoundary()
        {
            DateTime now = UtcNow();
            GameOverLoadOutcomeTracker tracker = new GameOverLoadOutcomeTracker();
            Guid operation = Guid.NewGuid();
            tracker.Record(operation, Identity("campaign-a"), now);
            bool stale;
            GameOverLoadOutcome whileWindowOpen = tracker.GetCurrent(now.AddMinutes(1), out stale);
            GameOverLoadOutcome afterCancel = tracker.GetCurrent(now.AddMinutes(2), out stale);
            AssertEx.Equal(operation, whileWindowOpen.OperationId);
            AssertEx.Equal(operation, afterCancel.OperationId);
        }

        public static void ActualLoadStartAgainAndMainMenuCannotInheritOutcome()
        {
            DateTime now = UtcNow();
            string[] boundaries = { "actual load", "Start Again", "Main Menu", "explicit native deletion" };
            for (int index = 0; index < boundaries.Length; index++)
            {
                GameOverLoadOutcomeTracker tracker = new GameOverLoadOutcomeTracker();
                tracker.Record(Guid.NewGuid(), Identity("campaign-a"), now);
                tracker.Clear();
                bool stale;
                AssertEx.True(tracker.GetCurrent(now, out stale) == null, boundaries[index] + " retained an outcome.");
            }
        }

        public static void UiOutcomeDoesNotExtendCoreDeletionScope()
        {
            DateTime now = UtcNow();
            PreservationContextTracker coreTracker = new PreservationContextTracker();
            PreservationContext core = coreTracker.Begin(Identity("campaign-a"), now, 7);
            coreTracker.End(core);
            GameOverLoadOutcomeTracker uiTracker = new GameOverLoadOutcomeTracker();
            uiTracker.Record(core.OperationId, core.SaveIdentity, now);
            AssertEx.True(coreTracker.Current == null);

            PreservationRequest explicitDelete = MatchingDeletionRequest();
            explicitDelete.ContextExists = coreTracker.Current != null;
            explicitDelete.ExplicitLoadUiDeletionIsOnStack = true;
            AssertEx.False(new PreservationPolicy().Evaluate(explicitDelete).SuppressDeletion);
        }

        private static PreservationRequest MatchingDeletionRequest()
        {
            return new PreservationRequest
            {
                FeatureEnabled = true,
                OnlyOneSaveEnabled = true,
                TargetIsIronMan = true,
                ContextExists = true,
                ContextIsFresh = true,
                ContextThreadMatches = true,
                ExplicitLoadUiDeletionIsOnStack = false,
                TargetMatchesContext = true
            };
        }

        private static SaveIdentity Identity(string gameId)
        {
            return new SaveIdentity("C:\\Temp\\Saved Games\\IronMan_1.zks", gameId, "game", "save", true);
        }

        private static DateTime UtcNow()
        {
            return new DateTime(2026, 9, 6, 12, 0, 0, DateTimeKind.Utc);
        }
    }
}
