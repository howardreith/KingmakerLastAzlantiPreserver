using System;
using KingmakerLastAzlantiPreserver.Preservation;

namespace KingmakerLastAzlantiPreserver.Tests
{
    internal static class PreservationPolicyTests
    {
        public static void DisabledFeaturePassesThrough()
        {
            PreservationRequest request = MatchingRequest();
            request.FeatureEnabled = false;
            AssertEx.False(Evaluate(request).SuppressDeletion);
        }

        public static void OnlyOneSaveDisabledPassesThrough()
        {
            PreservationRequest request = MatchingRequest();
            request.OnlyOneSaveEnabled = false;
            AssertEx.False(Evaluate(request).SuppressDeletion);
        }

        public static void NonIronManSavePassesThrough()
        {
            PreservationRequest request = MatchingRequest();
            request.TargetIsIronMan = false;
            AssertEx.False(Evaluate(request).SuppressDeletion);
        }

        public static void IronManOutsideGameOverPassesThrough()
        {
            PreservationRequest request = MatchingRequest();
            request.ContextExists = false;
            AssertEx.False(Evaluate(request).SuppressDeletion);
        }

        public static void DeliberateLoadScreenDeletionPassesThrough()
        {
            PreservationRequest request = MatchingRequest();
            request.ExplicitLoadUiDeletionIsOnStack = true;
            AssertEx.False(Evaluate(request).SuppressDeletion);
        }

        public static void MatchingGameOverDeletionIsBlocked()
        {
            AssertEx.True(Evaluate(MatchingRequest()).SuppressDeletion);
        }

        public static void UnrelatedIronManSavePassesThrough()
        {
            PreservationRequest request = MatchingRequest();
            request.TargetMatchesContext = false;
            AssertEx.False(Evaluate(request).SuppressDeletion);
        }

        public static void StaleContextPassesThrough()
        {
            PreservationRequest request = MatchingRequest();
            request.ContextIsFresh = false;
            AssertEx.False(Evaluate(request).SuppressDeletion);
        }

        public static void DifferentThreadPassesThrough()
        {
            PreservationRequest request = MatchingRequest();
            request.ContextThreadMatches = false;
            AssertEx.False(Evaluate(request).SuppressDeletion);
        }

        public static void ContextIsClearedAfterExceptionUnwinds()
        {
            PreservationContextTracker tracker = new PreservationContextTracker();
            PreservationContext context = tracker.Begin(
                new SaveIdentity("C:\\Temp\\Saved Games\\IronMan_1.zks", "game", "name", "save", true),
                DateTime.UtcNow,
                1);
            try
            {
                throw new InvalidOperationException("simulated Activate failure");
            }
            catch (InvalidOperationException)
            {
                PreservationContext orphaned = tracker.SweepIfOrphaned(DateTime.UtcNow, true);
                AssertEx.True(ReferenceEquals(context, orphaned));
            }

            AssertEx.True(tracker.Current == null, "The exception watchdog must clear the context.");
        }

        public static void CrossThreadWatchdogWaitsForContextExpiry()
        {
            DateTime started = new DateTime(2026, 1, 1, 0, 0, 0, DateTimeKind.Utc);
            PreservationContextTracker tracker = new PreservationContextTracker();
            PreservationContext context = tracker.Begin(
                new SaveIdentity("C:\\Temp\\Saved Games\\IronMan_1.zks", "game", "name", "save", true),
                started,
                99);

            AssertEx.True(tracker.SweepIfOrphaned(started.AddSeconds(1), false) == null);
            AssertEx.True(ReferenceEquals(context, tracker.Current));
            AssertEx.True(ReferenceEquals(context, tracker.SweepIfOrphaned(started.AddSeconds(31), false)));
            AssertEx.True(tracker.Current == null);
        }

        private static PreservationDecision Evaluate(PreservationRequest request)
        {
            return new PreservationPolicy().Evaluate(request);
        }

        private static PreservationRequest MatchingRequest()
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
    }
}
