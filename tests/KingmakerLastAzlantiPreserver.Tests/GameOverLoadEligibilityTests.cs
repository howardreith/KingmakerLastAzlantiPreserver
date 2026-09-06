using KingmakerLastAzlantiPreserver.Integration;

namespace KingmakerLastAzlantiPreserver.Tests
{
    internal static class GameOverLoadEligibilityTests
    {
        public static void MatchingLivePreservedSaveIsEligible()
        {
            AssertEx.True(Evaluate(MatchingRequest()).Allowed);
        }

        public static void DisabledSettingIsIneligible()
        {
            GameOverLoadEligibilityRequest request = MatchingRequest();
            request.LoadControlsEnabled = false;
            AssertEx.False(Evaluate(request).Allowed);
        }

        public static void DisabledModOrUnavailableCoreIsIneligible()
        {
            GameOverLoadEligibilityRequest request = MatchingRequest();
            request.ModEnabled = false;
            AssertEx.False(Evaluate(request).Allowed);
            request = MatchingRequest();
            request.CoreProtectionAvailable = false;
            AssertEx.False(Evaluate(request).Allowed);
        }

        public static void DisabledCorePreservationSettingIsIneligible()
        {
            GameOverLoadEligibilityRequest request = MatchingRequest();
            request.PreservationEnabled = false;
            AssertEx.False(Evaluate(request).Allowed);
        }

        public static void NonGameOverOrNonEndlessScreenIsIneligible()
        {
            GameOverLoadEligibilityRequest request = MatchingRequest();
            request.GameOverModeActive = false;
            AssertEx.False(Evaluate(request).Allowed);
            request = MatchingRequest();
            request.EndlessCampaignActive = false;
            AssertEx.False(Evaluate(request).Allowed);
        }

        public static void OnlyOneSaveDisabledIsIneligible()
        {
            GameOverLoadEligibilityRequest request = MatchingRequest();
            request.OnlyOneSaveEnabled = false;
            AssertEx.False(Evaluate(request).Allowed);
        }

        public static void OrdinaryNativeActionsPassThroughWhenOnlyOneSaveIsOff()
        {
            GameOverLoadEligibilityRequest request = MatchingRequest();
            request.OnlyOneSaveEnabled = false;
            GameOverLoadEligibilityPolicy policy = new GameOverLoadEligibilityPolicy();
            GameOverLoadEligibilityDecision decision = policy.Evaluate(request);
            AssertEx.False(decision.Allowed);
            AssertEx.True(policy.ShouldRunNativeAction(decision, true, false));
        }

        public static void InvalidLastAzlantiActionFailsClosedAfterRevalidation()
        {
            GameOverLoadEligibilityRequest request = MatchingRequest();
            request.SourceExists = false;
            GameOverLoadEligibilityPolicy policy = new GameOverLoadEligibilityPolicy();
            GameOverLoadEligibilityDecision decision = policy.Evaluate(request);
            AssertEx.False(decision.Allowed);
            AssertEx.False(policy.ShouldRunNativeAction(decision, true, true));
            AssertEx.False(policy.ShouldRunNativeAction(decision, false, false));
            AssertEx.False(policy.ShouldRunNativeAction(null, true, true));
        }

        public static void NullCurrentSaveIsIneligible()
        {
            GameOverLoadEligibilityRequest request = MatchingRequest();
            request.CurrentSavePresent = false;
            AssertEx.False(Evaluate(request).Allowed);
        }

        public static void NonIronManCurrentSaveIsIneligible()
        {
            GameOverLoadEligibilityRequest request = MatchingRequest();
            request.CurrentSaveIsIronMan = false;
            AssertEx.False(Evaluate(request).Allowed);
        }

        public static void EmptyFolderNameOrNativeUnsavedStateIsIneligible()
        {
            GameOverLoadEligibilityRequest request = MatchingRequest();
            request.FolderNamePresent = false;
            AssertEx.False(Evaluate(request).Allowed);
            request = MatchingRequest();
            request.CurrentSaveIsActuallySaved = false;
            AssertEx.False(Evaluate(request).Allowed);
        }

        public static void EmptyGameIdIsIneligible()
        {
            GameOverLoadEligibilityRequest request = MatchingRequest();
            request.GameIdPresent = false;
            AssertEx.False(Evaluate(request).Allowed);
        }

        public static void OutOfRootSaveIsIneligible()
        {
            GameOverLoadEligibilityRequest request = MatchingRequest();
            request.PathIsDirectChildOfSaveRoot = false;
            AssertEx.False(Evaluate(request).Allowed);
        }

        public static void MissingLiveSourceIsIneligible()
        {
            GameOverLoadEligibilityRequest request = MatchingRequest();
            request.SourceExists = false;
            AssertEx.False(Evaluate(request).Allowed);
        }

        public static void MissingOrMismatchedOperationIsIneligible()
        {
            GameOverLoadEligibilityRequest request = MatchingRequest();
            request.OperationExists = false;
            AssertEx.False(Evaluate(request).Allowed);
            request = MatchingRequest();
            request.OperationMatchesCurrentSave = false;
            AssertEx.False(Evaluate(request).Allowed);
        }

        public static void StaleOperationIsIneligible()
        {
            GameOverLoadEligibilityRequest request = MatchingRequest();
            request.OperationIsFresh = false;
            AssertEx.False(Evaluate(request).Allowed);
        }

        public static void MissingOrMismatchedNativeSelectionIsIneligible()
        {
            GameOverLoadEligibilityRequest request = MatchingRequest();
            request.NativeSelectionPresent = false;
            AssertEx.False(Evaluate(request).Allowed);
            request = MatchingRequest();
            request.NativeSelectionMatchesOperation = false;
            AssertEx.False(Evaluate(request).Allowed);
        }

        public static void SaveInvalidatedAfterBindingCannotUseCachedEligibility()
        {
            GameOverLoadEligibilityRequest request = MatchingRequest();
            AssertEx.True(Evaluate(request).Allowed);
            request.SourceExists = false;
            AssertEx.False(Evaluate(request).Allowed);
            request = MatchingRequest();
            AssertEx.True(Evaluate(request).Allowed);
            request.OperationMatchesCurrentSave = false;
            AssertEx.False(Evaluate(request).Allowed);
            request = MatchingRequest();
            AssertEx.True(Evaluate(request).Allowed);
            request.CurrentSaveIsActuallySaved = false;
            AssertEx.False(Evaluate(request).Allowed);
        }

        private static GameOverLoadEligibilityDecision Evaluate(GameOverLoadEligibilityRequest request)
        {
            return new GameOverLoadEligibilityPolicy().Evaluate(request);
        }

        private static GameOverLoadEligibilityRequest MatchingRequest()
        {
            return new GameOverLoadEligibilityRequest
            {
                ModEnabled = true,
                CoreProtectionAvailable = true,
                PreservationEnabled = true,
                LoadControlsEnabled = true,
                GameOverModeActive = true,
                EndlessCampaignActive = true,
                OnlyOneSaveEnabled = true,
                CurrentSavePresent = true,
                CurrentSaveIsIronMan = true,
                CurrentSaveIsActuallySaved = true,
                FolderNamePresent = true,
                GameIdPresent = true,
                PathIsDirectChildOfSaveRoot = true,
                SourceExists = true,
                OperationExists = true,
                OperationIsFresh = true,
                OperationMatchesCurrentSave = true,
                NativeSelectionPresent = true,
                NativeSelectionMatchesOperation = true
            };
        }
    }
}
