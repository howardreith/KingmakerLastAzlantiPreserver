using System;
using System.IO;
using System.Linq;
using System.Security.Cryptography;
using KingmakerLastAzlantiPreserver.Preservation;
using KingmakerLastAzlantiPreserver.Recovery;

namespace KingmakerLastAzlantiPreserver.Tests
{
    internal static class RecoverySnapshotTests
    {
        public static void SnapshotCopiesExactBytesAndHashesMatch()
        {
            using (Fixture fixture = new Fixture())
            {
                byte[] bytes = Bytes(131072, 17);
                string source = fixture.CreateSave("IronMan_1.zks", bytes);
                SnapshotResult result = fixture.Snapshot(source, "campaign-a");
                AssertEx.True(result.Succeeded, result.Message);
                byte[] copied = File.ReadAllBytes(fixture.Service.GetSnapshotPath(result.Metadata.RecoveryId));
                AssertEx.SequenceEqual(bytes, copied);
                AssertEx.Equal(Hash(source), result.Metadata.SourceSha256);
                AssertEx.Equal(result.Metadata.SourceSha256, result.Metadata.RecoverySha256);
            }
        }

        public static void SnapshotReplacementKeepsOneCurrentCopyWithoutHistory()
        {
            using (Fixture fixture = new Fixture())
            {
                string source = fixture.CreateSave("IronMan_1.zks", Bytes(4096, 1));
                SnapshotResult first = fixture.Snapshot(source, "campaign-a");
                AssertEx.True(first.Succeeded, first.Message);
                File.WriteAllBytes(source, Bytes(8192, 2));
                File.SetLastWriteTimeUtc(source, DateTime.UtcNow.AddSeconds(2));
                SnapshotResult second = fixture.Snapshot(source, "campaign-a");
                AssertEx.True(second.Succeeded, second.Message);
                AssertEx.Equal(first.Metadata.RecoveryId, second.Metadata.RecoveryId);
                AssertEx.Equal(1, Directory.GetFiles(fixture.RecoveryRoot, "snapshot.bin", SearchOption.AllDirectories).Length);
                AssertEx.False(Directory.GetDirectories(fixture.RecoveryRoot).Any(path => Path.GetFileName(path).StartsWith(".", StringComparison.Ordinal)));
                AssertEx.SequenceEqual(Bytes(8192, 2), File.ReadAllBytes(fixture.Service.GetSnapshotPath(second.Metadata.RecoveryId)));
            }
        }

        public static void FailedCopyLeavesPriorValidRecoveryIntact()
        {
            using (Fixture fixture = new Fixture())
            {
                byte[] original = Bytes(2048, 3);
                string source = fixture.CreateSave("IronMan_1.zks", original);
                SnapshotResult first = fixture.Snapshot(source, "campaign-a");
                AssertEx.True(first.Succeeded, first.Message);
                string snapshotPath = fixture.Service.GetSnapshotPath(first.Metadata.RecoveryId);
                byte[] prior = File.ReadAllBytes(snapshotPath);
                using (FileStream locked = new FileStream(source, FileMode.Open, FileAccess.ReadWrite, FileShare.None))
                {
                    SnapshotResult failed = fixture.Snapshot(source, "campaign-a");
                    AssertEx.False(failed.Succeeded);
                }

                AssertEx.SequenceEqual(prior, File.ReadAllBytes(snapshotPath));
            }
        }

        public static void SnapshotNeverDeletesSource()
        {
            using (Fixture fixture = new Fixture())
            {
                string source = fixture.CreateSave("IronMan_1.zks", Bytes(1024, 4));
                SnapshotResult result = fixture.Snapshot(source, "campaign-a");
                AssertEx.True(result.Succeeded, result.Message);
                AssertEx.True(File.Exists(source));
            }
        }

        public static void MissingOrZeroByteSourceIsRejected()
        {
            using (Fixture fixture = new Fixture())
            {
                string zero = fixture.CreateSave("IronMan_1.zks", new byte[0]);
                AssertEx.False(fixture.Snapshot(zero, "campaign-a").Succeeded);
                string missing = Path.Combine(fixture.SaveRoot, "IronMan_2.zks");
                AssertEx.False(fixture.Snapshot(missing, "campaign-b").Succeeded);
            }
        }

        public static void ExistingLiveFileIsNeverOverwritten()
        {
            using (Fixture fixture = new Fixture())
            {
                byte[] live = Bytes(1024, 5);
                string source = fixture.CreateSave("IronMan_1.zks", live);
                SnapshotResult snapshot = fixture.Snapshot(source, "campaign-a");
                Guid operation = fixture.Mark(snapshot);
                byte[] changed = Bytes(1024, 6);
                File.WriteAllBytes(source, changed);
                RecoveryDecision decision = fixture.Service.CompleteGameOver(snapshot.Metadata.RecoveryId, operation);
                AssertEx.Equal(RecoveryDecisionKind.OriginalStillExists, decision.Kind);
                AssertEx.SequenceEqual(changed, File.ReadAllBytes(source));
                AssertEx.Equal(RecoveryDecisionKind.NoPendingMarker, fixture.Service.GetLatestGuardedDecision().Kind);
            }
        }

        public static void MissingLiveFileWithValidPendingMarkerIsRestored()
        {
            using (Fixture fixture = new Fixture())
            {
                byte[] bytes = Bytes(32768, 7);
                string source = fixture.CreateSave("IronMan_1.zks", bytes);
                SnapshotResult snapshot = fixture.Snapshot(source, "campaign-a");
                Guid operation = fixture.Mark(snapshot);
                File.Delete(source);
                RecoveryDecision decision = fixture.Service.CompleteGameOver(snapshot.Metadata.RecoveryId, operation);
                AssertEx.Equal(RecoveryDecisionKind.Restored, decision.Kind, decision.Message);
                AssertEx.SequenceEqual(bytes, File.ReadAllBytes(source));
            }
        }

        public static void MissingLiveFileWithoutPendingMarkerIsNotRestored()
        {
            using (Fixture fixture = new Fixture())
            {
                string source = fixture.CreateSave("IronMan_1.zks", Bytes(1024, 8));
                SnapshotResult snapshot = fixture.Snapshot(source, "campaign-a");
                File.Delete(source);
                RecoveryDecision decision = fixture.Service.GetLatestGuardedDecision();
                AssertEx.Equal(RecoveryDecisionKind.NoPendingMarker, decision.Kind);
                AssertEx.False(File.Exists(source));
                AssertEx.True(File.Exists(fixture.Service.GetSnapshotPath(snapshot.Metadata.RecoveryId)));
            }
        }

        public static void InvalidMetadataIsRejected()
        {
            using (Fixture fixture = new Fixture())
            {
                string source = fixture.CreateSave("IronMan_1.zks", Bytes(1024, 9));
                SnapshotResult snapshot = fixture.Snapshot(source, "campaign-a");
                fixture.Mark(snapshot);
                File.Delete(source);
                File.WriteAllText(fixture.Service.GetMetadataPath(snapshot.Metadata.RecoveryId), "{not-valid-json");
                RecoveryDecision decision = fixture.Service.GetLatestGuardedDecision();
                AssertEx.Equal(RecoveryDecisionKind.Rejected, decision.Kind);
                AssertEx.False(File.Exists(source));
            }
        }

        public static void HashMismatchIsRejected()
        {
            using (Fixture fixture = new Fixture())
            {
                string source = fixture.CreateSave("IronMan_1.zks", Bytes(1024, 10));
                SnapshotResult snapshot = fixture.Snapshot(source, "campaign-a");
                fixture.Mark(snapshot);
                File.Delete(source);
                File.AppendAllText(fixture.Service.GetSnapshotPath(snapshot.Metadata.RecoveryId), "tampered");
                RecoveryDecision decision = fixture.Service.GetLatestGuardedDecision();
                AssertEx.Equal(RecoveryDecisionKind.Rejected, decision.Kind);
                AssertEx.False(File.Exists(source));
            }
        }

        public static void ManualDeletionDoesNotCreateMarkerOrResurrectSave()
        {
            using (Fixture fixture = new Fixture())
            {
                string source = fixture.CreateSave("IronMan_1.zks", Bytes(1024, 11));
                SnapshotResult snapshot = fixture.Snapshot(source, "campaign-a");
                AssertEx.True(snapshot.Succeeded, snapshot.Message);
                File.Delete(source);
                RecoveryDecision decision = fixture.Service.GetLatestGuardedDecision();
                AssertEx.Equal(RecoveryDecisionKind.NoPendingMarker, decision.Kind);
                AssertEx.False(File.Exists(source));
            }
        }

        public static void PathTraversalAndDirectoryTargetsAreRejected()
        {
            using (Fixture fixture = new Fixture())
            {
                string outside = Path.Combine(fixture.Root, "outside.zks");
                File.WriteAllBytes(outside, Bytes(100, 12));
                AssertEx.False(fixture.Snapshot(outside, "campaign-outside").Succeeded);
                string directory = Path.Combine(fixture.SaveRoot, "directory.zks");
                Directory.CreateDirectory(directory);
                AssertEx.False(fixture.Snapshot(directory, "campaign-directory").Succeeded);
            }
        }

        public static void MultipleCampaignsHaveSeparateCurrentSnapshotsWithoutHistories()
        {
            using (Fixture fixture = new Fixture())
            {
                string firstPath = fixture.CreateSave("IronMan_1.zks", Bytes(2048, 13));
                string secondPath = fixture.CreateSave("IronMan_2.zks", Bytes(4096, 14));
                SnapshotResult first = fixture.Snapshot(firstPath, "campaign-a");
                SnapshotResult second = fixture.Snapshot(secondPath, "campaign-b");
                AssertEx.True(first.Succeeded && second.Succeeded);
                AssertEx.False(string.Equals(first.Metadata.RecoveryId, second.Metadata.RecoveryId, StringComparison.Ordinal));
                AssertEx.Equal(2, Directory.GetFiles(fixture.RecoveryRoot, "snapshot.bin", SearchOption.AllDirectories).Length);
                AssertEx.Equal(2, Directory.GetDirectories(fixture.RecoveryRoot).Length);
            }
        }

        public static void GuardedRecoveryRequiresExplicitConfirmation()
        {
            using (Fixture fixture = new Fixture())
            {
                string source = fixture.CreateSave("IronMan_1.zks", Bytes(1024, 15));
                SnapshotResult snapshot = fixture.Snapshot(source, "campaign-a");
                fixture.Mark(snapshot);
                File.Delete(source);
                RecoveryDecision decision = fixture.Service.TryGuardedRestore(snapshot.Metadata.RecoveryId, false);
                AssertEx.Equal(RecoveryDecisionKind.Rejected, decision.Kind);
                AssertEx.False(File.Exists(source));
            }
        }

        public static void GuardedRecoveryRestoresAfterExplicitConfirmation()
        {
            using (Fixture fixture = new Fixture())
            {
                byte[] bytes = Bytes(4096, 16);
                string source = fixture.CreateSave("IronMan_1.zks", bytes);
                SnapshotResult snapshot = fixture.Snapshot(source, "campaign-a");
                fixture.Mark(snapshot);
                File.Delete(source);
                RecoveryDecision decision = fixture.Service.TryGuardedRestore(snapshot.Metadata.RecoveryId, true);
                AssertEx.Equal(RecoveryDecisionKind.Restored, decision.Kind, decision.Message);
                AssertEx.SequenceEqual(bytes, File.ReadAllBytes(source));
            }
        }

        private static byte[] Bytes(int count, int seed)
        {
            byte[] result = new byte[count];
            Random random = new Random(seed);
            random.NextBytes(result);
            return result;
        }

        private static string Hash(string path)
        {
            using (FileStream stream = File.OpenRead(path))
            using (SHA256 sha = SHA256.Create())
            {
                return BitConverter.ToString(sha.ComputeHash(stream)).Replace("-", string.Empty).ToLowerInvariant();
            }
        }

        private sealed class Fixture : IDisposable
        {
            public Fixture()
            {
                Root = Path.Combine(Path.GetTempPath(), "KingmakerLastAzlantiPreserver.Tests", Guid.NewGuid().ToString("N"));
                SaveRoot = Path.Combine(Root, "Saved Games");
                RecoveryRoot = Path.Combine(Root, "LastAzlantiPreserver", "Recovery");
                Directory.CreateDirectory(SaveRoot);
                Service = new RecoverySnapshotService(SaveRoot, RecoveryRoot);
            }

            public string Root { get; }
            public string SaveRoot { get; }
            public string RecoveryRoot { get; }
            public RecoverySnapshotService Service { get; }

            public string CreateSave(string fileName, byte[] bytes)
            {
                string path = Path.Combine(SaveRoot, fileName);
                File.WriteAllBytes(path, bytes);
                return path;
            }

            public SnapshotResult Snapshot(string path, string gameId)
            {
                return Service.CreateSnapshot(
                    new SaveIdentity(path, gameId, "Disposable campaign", Path.GetFileNameWithoutExtension(path), true),
                    DateTime.UtcNow);
            }

            public Guid Mark(SnapshotResult snapshot)
            {
                AssertEx.True(snapshot.Succeeded, snapshot.Message);
                Guid operation = Guid.NewGuid();
                Service.CreatePendingMarker(snapshot.Metadata, operation, DateTime.UtcNow);
                return operation;
            }

            public void Dispose()
            {
                string expected = Path.Combine(Path.GetTempPath(), "KingmakerLastAzlantiPreserver.Tests");
                if (Directory.Exists(Root) && Root.StartsWith(expected, StringComparison.OrdinalIgnoreCase))
                {
                    Directory.Delete(Root, true);
                }
            }
        }
    }
}
