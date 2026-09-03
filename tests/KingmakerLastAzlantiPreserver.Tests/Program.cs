using System;
using System.Collections.Generic;

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
