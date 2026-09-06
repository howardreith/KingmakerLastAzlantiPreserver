using System;
using System.Collections.Generic;
using System.IO;
using System.Reflection;

namespace KingmakerLastAzlantiPreserver.Tests
{
    internal static class Program
    {
        private sealed class TestCase
        {
            public TestCase(string name, Action body)
            {
                Name = name;
                Body = body;
            }

            public string Name { get; }
            public Action Body { get; }
        }

        private static int Main()
        {
            ResolveEventHandler resolver = ResolveConfiguredReference;
            AppDomain.CurrentDomain.AssemblyResolve += resolver;
            try
            {
                return RunTests();
            }
            finally
            {
                AppDomain.CurrentDomain.AssemblyResolve -= resolver;
            }
        }

        private static Assembly ResolveConfiguredReference(object sender, ResolveEventArgs args)
        {
            string configuredDirectories = Environment.GetEnvironmentVariable("KMLAP_TEST_REFERENCE_DIRS");
            if (string.IsNullOrWhiteSpace(configuredDirectories))
            {
                return null;
            }

            string simpleName = new AssemblyName(args.Name).Name;
            if (string.IsNullOrWhiteSpace(simpleName) ||
                simpleName.IndexOfAny(Path.GetInvalidFileNameChars()) >= 0)
            {
                return null;
            }

            string fileName = simpleName + ".dll";
            string[] directories = configuredDirectories.Split(new[] { Path.PathSeparator }, StringSplitOptions.RemoveEmptyEntries);
            for (int index = 0; index < directories.Length; index++)
            {
                string candidate = Path.Combine(directories[index], fileName);
                if (File.Exists(candidate))
                {
                    return Assembly.LoadFrom(candidate);
                }
            }

            return null;
        }

        private static int RunTests()
        {
            List<TestCase> tests = new List<TestCase>
            {
                new TestCase(nameof(PreservationPolicyTests.DisabledFeaturePassesThrough), PreservationPolicyTests.DisabledFeaturePassesThrough),
                new TestCase(nameof(PreservationPolicyTests.OnlyOneSaveDisabledPassesThrough), PreservationPolicyTests.OnlyOneSaveDisabledPassesThrough),
                new TestCase(nameof(PreservationPolicyTests.NonIronManSavePassesThrough), PreservationPolicyTests.NonIronManSavePassesThrough),
                new TestCase(nameof(PreservationPolicyTests.IronManOutsideGameOverPassesThrough), PreservationPolicyTests.IronManOutsideGameOverPassesThrough),
                new TestCase(nameof(PreservationPolicyTests.DeliberateLoadScreenDeletionPassesThrough), PreservationPolicyTests.DeliberateLoadScreenDeletionPassesThrough),
                new TestCase(nameof(PreservationPolicyTests.MatchingGameOverDeletionIsBlocked), PreservationPolicyTests.MatchingGameOverDeletionIsBlocked),
                new TestCase(nameof(PreservationPolicyTests.UnrelatedIronManSavePassesThrough), PreservationPolicyTests.UnrelatedIronManSavePassesThrough),
                new TestCase(nameof(PreservationPolicyTests.StaleContextPassesThrough), PreservationPolicyTests.StaleContextPassesThrough),
                new TestCase(nameof(PreservationPolicyTests.DifferentThreadPassesThrough), PreservationPolicyTests.DifferentThreadPassesThrough),
                new TestCase(nameof(PreservationPolicyTests.ContextIsClearedAfterExceptionUnwinds), PreservationPolicyTests.ContextIsClearedAfterExceptionUnwinds),
                new TestCase(nameof(PreservationPolicyTests.CrossThreadWatchdogWaitsForContextExpiry), PreservationPolicyTests.CrossThreadWatchdogWaitsForContextExpiry),
                new TestCase(nameof(GameOverLoadEligibilityTests.MatchingLivePreservedSaveIsEligible), GameOverLoadEligibilityTests.MatchingLivePreservedSaveIsEligible),
                new TestCase(nameof(GameOverLoadEligibilityTests.DisabledSettingIsIneligible), GameOverLoadEligibilityTests.DisabledSettingIsIneligible),
                new TestCase(nameof(GameOverLoadEligibilityTests.DisabledModOrUnavailableCoreIsIneligible), GameOverLoadEligibilityTests.DisabledModOrUnavailableCoreIsIneligible),
                new TestCase(nameof(GameOverLoadEligibilityTests.DisabledCorePreservationSettingIsIneligible), GameOverLoadEligibilityTests.DisabledCorePreservationSettingIsIneligible),
                new TestCase(nameof(GameOverLoadEligibilityTests.NonGameOverOrNonEndlessScreenIsIneligible), GameOverLoadEligibilityTests.NonGameOverOrNonEndlessScreenIsIneligible),
                new TestCase(nameof(GameOverLoadEligibilityTests.OnlyOneSaveDisabledIsIneligible), GameOverLoadEligibilityTests.OnlyOneSaveDisabledIsIneligible),
                new TestCase(nameof(GameOverLoadEligibilityTests.OrdinaryNativeActionsPassThroughWhenOnlyOneSaveIsOff), GameOverLoadEligibilityTests.OrdinaryNativeActionsPassThroughWhenOnlyOneSaveIsOff),
                new TestCase(nameof(GameOverLoadEligibilityTests.InvalidLastAzlantiActionFailsClosedAfterRevalidation), GameOverLoadEligibilityTests.InvalidLastAzlantiActionFailsClosedAfterRevalidation),
                new TestCase(nameof(GameOverLoadEligibilityTests.NullCurrentSaveIsIneligible), GameOverLoadEligibilityTests.NullCurrentSaveIsIneligible),
                new TestCase(nameof(GameOverLoadEligibilityTests.NonIronManCurrentSaveIsIneligible), GameOverLoadEligibilityTests.NonIronManCurrentSaveIsIneligible),
                new TestCase(nameof(GameOverLoadEligibilityTests.EmptyFolderNameOrNativeUnsavedStateIsIneligible), GameOverLoadEligibilityTests.EmptyFolderNameOrNativeUnsavedStateIsIneligible),
                new TestCase(nameof(GameOverLoadEligibilityTests.EmptyGameIdIsIneligible), GameOverLoadEligibilityTests.EmptyGameIdIsIneligible),
                new TestCase(nameof(GameOverLoadEligibilityTests.OutOfRootSaveIsIneligible), GameOverLoadEligibilityTests.OutOfRootSaveIsIneligible),
                new TestCase(nameof(GameOverLoadEligibilityTests.MissingLiveSourceIsIneligible), GameOverLoadEligibilityTests.MissingLiveSourceIsIneligible),
                new TestCase(nameof(GameOverLoadEligibilityTests.MissingOrMismatchedOperationIsIneligible), GameOverLoadEligibilityTests.MissingOrMismatchedOperationIsIneligible),
                new TestCase(nameof(GameOverLoadEligibilityTests.StaleOperationIsIneligible), GameOverLoadEligibilityTests.StaleOperationIsIneligible),
                new TestCase(nameof(GameOverLoadEligibilityTests.MissingOrMismatchedNativeSelectionIsIneligible), GameOverLoadEligibilityTests.MissingOrMismatchedNativeSelectionIsIneligible),
                new TestCase(nameof(GameOverLoadEligibilityTests.SaveInvalidatedAfterBindingCannotUseCachedEligibility), GameOverLoadEligibilityTests.SaveInvalidatedAfterBindingCannotUseCachedEligibility),
                new TestCase(nameof(GameOverLoadOutcomeTests.ExactIdentityRejectsDifferentCampaignAtSamePath), GameOverLoadOutcomeTests.ExactIdentityRejectsDifferentCampaignAtSamePath),
                new TestCase(nameof(GameOverLoadOutcomeTests.BeginningNextOperationClearsPriorOutcome), GameOverLoadOutcomeTests.BeginningNextOperationClearsPriorOutcome),
                new TestCase(nameof(GameOverLoadOutcomeTests.LeavingGameOverClearsOutcome), GameOverLoadOutcomeTests.LeavingGameOverClearsOutcome),
                new TestCase(nameof(GameOverLoadOutcomeTests.OutcomeExpiresAndCannotBecomeAStaleGrant), GameOverLoadOutcomeTests.OutcomeExpiresAndCannotBecomeAStaleGrant),
                new TestCase(nameof(GameOverLoadOutcomeTests.LoadWindowCancelRetainsSameOperationUntilTerminalBoundary), GameOverLoadOutcomeTests.LoadWindowCancelRetainsSameOperationUntilTerminalBoundary),
                new TestCase(nameof(GameOverLoadOutcomeTests.ActualLoadStartAgainAndMainMenuCannotInheritOutcome), GameOverLoadOutcomeTests.ActualLoadStartAgainAndMainMenuCannotInheritOutcome),
                new TestCase(nameof(GameOverLoadOutcomeTests.UiOutcomeDoesNotExtendCoreDeletionScope), GameOverLoadOutcomeTests.UiOutcomeDoesNotExtendCoreDeletionScope),
                new TestCase(nameof(GameOverLoadControlTests.NegativeEligibilityLeavesVanillaAndUnrelatedControlsUntouched), GameOverLoadControlTests.NegativeEligibilityLeavesVanillaAndUnrelatedControlsUntouched),
                new TestCase(nameof(GameOverLoadControlTests.PositiveEligibilityElevatesOnlyTwoLoadingControls), GameOverLoadControlTests.PositiveEligibilityElevatesOnlyTwoLoadingControls),
                new TestCase(nameof(GameOverLoadControlTests.DisablingAfterElevationRestoresOnlyOwnedStates), GameOverLoadControlTests.DisablingAfterElevationRestoresOnlyOwnedStates),
                new TestCase(nameof(GameOverLoadControlTests.DifferentViewNeverReceivesStaleRestoration), GameOverLoadControlTests.DifferentViewNeverReceivesStaleRestoration),
                new TestCase(nameof(GameOverLoadControlTests.RebindingSameViewUsesFreshVanillaBaseline), GameOverLoadControlTests.RebindingSameViewUsesFreshVanillaBaseline),
                new TestCase(nameof(GameOverLoadControlTests.PartialElevationFailureRestoresBothVanillaStates), GameOverLoadControlTests.PartialElevationFailureRestoresBothVanillaStates),
                new TestCase(nameof(SettingsMigrationTests.MissingGameOverLoadSettingMigratesToEnabled), SettingsMigrationTests.MissingGameOverLoadSettingMigratesToEnabled),
                new TestCase(nameof(SettingsMigrationTests.ExplicitlySavedFalseGameOverLoadSettingIsPreserved), SettingsMigrationTests.ExplicitlySavedFalseGameOverLoadSettingIsPreserved),
                new TestCase(nameof(RuntimeStatusTests.OptionalUiFailureDoesNotChangeCoreAvailability), RuntimeStatusTests.OptionalUiFailureDoesNotChangeCoreAvailability),
                new TestCase(nameof(RuntimeStatusTests.DisabledUiSettingDoesNotDisableCoreProtection), RuntimeStatusTests.DisabledUiSettingDoesNotDisableCoreProtection),
                new TestCase(nameof(RuntimeStatusTests.CoreAndOptionalHarmonyOwnersAreDistinct), RuntimeStatusTests.CoreAndOptionalHarmonyOwnersAreDistinct),
                new TestCase(nameof(RecoverySnapshotTests.SnapshotCopiesExactBytesAndHashesMatch), RecoverySnapshotTests.SnapshotCopiesExactBytesAndHashesMatch),
                new TestCase(nameof(RecoverySnapshotTests.SnapshotReplacementKeepsOneCurrentCopyWithoutHistory), RecoverySnapshotTests.SnapshotReplacementKeepsOneCurrentCopyWithoutHistory),
                new TestCase(nameof(RecoverySnapshotTests.FailedCopyLeavesPriorValidRecoveryIntact), RecoverySnapshotTests.FailedCopyLeavesPriorValidRecoveryIntact),
                new TestCase(nameof(RecoverySnapshotTests.SnapshotNeverDeletesSource), RecoverySnapshotTests.SnapshotNeverDeletesSource),
                new TestCase(nameof(RecoverySnapshotTests.MissingOrZeroByteSourceIsRejected), RecoverySnapshotTests.MissingOrZeroByteSourceIsRejected),
                new TestCase(nameof(RecoverySnapshotTests.ExistingLiveFileIsNeverOverwritten), RecoverySnapshotTests.ExistingLiveFileIsNeverOverwritten),
                new TestCase(nameof(RecoverySnapshotTests.MissingLiveFileWithValidPendingMarkerIsRestored), RecoverySnapshotTests.MissingLiveFileWithValidPendingMarkerIsRestored),
                new TestCase(nameof(RecoverySnapshotTests.MissingLiveFileWithoutPendingMarkerIsNotRestored), RecoverySnapshotTests.MissingLiveFileWithoutPendingMarkerIsNotRestored),
                new TestCase(nameof(RecoverySnapshotTests.InvalidMetadataIsRejected), RecoverySnapshotTests.InvalidMetadataIsRejected),
                new TestCase(nameof(RecoverySnapshotTests.HashMismatchIsRejected), RecoverySnapshotTests.HashMismatchIsRejected),
                new TestCase(nameof(RecoverySnapshotTests.ManualDeletionDoesNotCreateMarkerOrResurrectSave), RecoverySnapshotTests.ManualDeletionDoesNotCreateMarkerOrResurrectSave),
                new TestCase(nameof(RecoverySnapshotTests.PathTraversalAndDirectoryTargetsAreRejected), RecoverySnapshotTests.PathTraversalAndDirectoryTargetsAreRejected),
                new TestCase(nameof(RecoverySnapshotTests.MultipleCampaignsHaveSeparateCurrentSnapshotsWithoutHistories), RecoverySnapshotTests.MultipleCampaignsHaveSeparateCurrentSnapshotsWithoutHistories),
                new TestCase(nameof(RecoverySnapshotTests.GuardedRecoveryRequiresExplicitConfirmation), RecoverySnapshotTests.GuardedRecoveryRequiresExplicitConfirmation),
                new TestCase(nameof(RecoverySnapshotTests.GuardedRecoveryRestoresAfterExplicitConfirmation), RecoverySnapshotTests.GuardedRecoveryRestoresAfterExplicitConfirmation)
            };

            int failed = 0;
            for (int index = 0; index < tests.Count; index++)
            {
                try
                {
                    tests[index].Body();
                    Console.WriteLine("PASS " + tests[index].Name);
                }
                catch (Exception exception)
                {
                    failed++;
                    Console.WriteLine("FAIL " + tests[index].Name + ": " + exception);
                }
            }

            Console.WriteLine("RESULT total=" + tests.Count + " passed=" + (tests.Count - failed) + " failed=" + failed);
            return failed == 0 ? 0 : 1;
        }
    }
}
