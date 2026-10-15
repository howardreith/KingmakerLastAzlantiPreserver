using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using KingmakerLastAzlantiPreserver.Recovery;

namespace KingmakerLastAzlantiPreserver.Tests
{
    internal static class RecoveryFormatCompatibilityTests
    {
        // Captured verbatim from the published v0.1.1 DLL (SHA-256 5be7a3691fbdde8ea4d351d8a7aee6adb78a5b401c9ac896435748ba99c0e85b,
        // the dll_sha256 in the v0.1.1 release manifest). It created a snapshot and pending marker for a 50,000-byte
        // Random(42) IronMan_1.zks in a temporary save root. Only the machine-specific save path and the RecoveryId
        // derived from it are tokenized; every other byte is the published writer's output.
        private const string PublishedV011Metadata =
            "{\"FormatVersion\":1,\"RecoveryId\":\"{RECOVERY_ID}\",\"OriginalFullPath\":\"{SAVE_PATH}\"," +
            "\"OriginalFileName\":\"IronMan_1.zks\",\"SourceLength\":50000,\"SourceLastWriteUtc\":\"2026-10-15T22:01:26.5082912Z\"," +
            "\"SourceSha256\":\"b77e5378c8c080122e7c2b213f24c5a117b24d1686f8241a9f0f75a062b9bde0\"," +
            "\"RecoverySha256\":\"b77e5378c8c080122e7c2b213f24c5a117b24d1686f8241a9f0f75a062b9bde0\"," +
            "\"GameId\":\"campaign-a\",\"GameName\":\"Disposable campaign\",\"SaveName\":\"IronMan_1\",\"SaveType\":\"IronMan\"," +
            "\"GameOverTimestampUtc\":\"2026-10-15T22:01:26.5172841Z\",\"ModVersion\":\"0.1.1\"}";

        private const string PublishedV011Marker =
            "{\"FormatVersion\":1,\"RecoveryId\":\"{RECOVERY_ID}\",\"OperationId\":\"c55ebb77-826e-4f48-9f49-e1d59936222a\"," +
            "\"OriginalFullPath\":\"{SAVE_PATH}\",\"SourceSha256\":\"b77e5378c8c080122e7c2b213f24c5a117b24d1686f8241a9f0f75a062b9bde0\"," +
            "\"CreatedUtc\":\"2026-10-15T22:01:27.5172841Z\"}";

        private const string PublishedSha256 = "b77e5378c8c080122e7c2b213f24c5a117b24d1686f8241a9f0f75a062b9bde0";
        private const string GameId = "campaign-a";

        public static void PublishedV011PendingRecoveryRestoresWithExactBytes()
        {
            using (Fixture fixture = new Fixture())
            {
                byte[] bytes = PublishedSaveBytes();
                AssertEx.Equal(PublishedSha256, Sha256(bytes), "The fixture bytes must be the published writer's source.");
                string recoveryId = fixture.Write(PublishedV011Metadata, PublishedV011Marker, bytes);

                RecoveryDecision unconfirmed = fixture.Service.TryGuardedRestore(recoveryId, false);
                AssertEx.Equal(RecoveryDecisionKind.Rejected, unconfirmed.Kind);
                AssertEx.False(File.Exists(fixture.SavePath));

                RecoveryDecision pending = fixture.Service.GetLatestGuardedDecision();
                AssertEx.Equal(RecoveryDecisionKind.ReadyToRestore, pending.Kind, pending.Message);
                AssertEx.True(pending.CanRestore);

                RecoveryDecision restored = fixture.Service.TryGuardedRestore(recoveryId, true);
                AssertEx.Equal(RecoveryDecisionKind.Restored, restored.Kind, restored.Message);
                AssertEx.SequenceEqual(bytes, File.ReadAllBytes(fixture.SavePath));
                AssertEx.Equal(PublishedSha256, Sha256(File.ReadAllBytes(fixture.SavePath)));
                AssertEx.Equal(1, Directory.GetFiles(fixture.SaveRoot).Length, "Restore must leave only the original save.");
                AssertEx.Equal(RecoveryDecisionKind.NoPendingMarker, fixture.Service.GetLatestGuardedDecision().Kind);
            }
        }

        public static void NewerWriterReleaseWithSupportedFormatIsNotRejected()
        {
            foreach (string writer in new[] { "0.2.0", "1.0.0-beta.1", "12.4.0.7" })
            {
                using (Fixture fixture = new Fixture())
                {
                    byte[] bytes = PublishedSaveBytes();
                    string recoveryId = fixture.Write(
                        PublishedV011Metadata.Replace("\"ModVersion\":\"0.1.1\"", "\"ModVersion\":\"" + writer + "\""),
                        PublishedV011Marker,
                        bytes);
                    RecoveryDecision decision = fixture.Service.TryGuardedRestore(recoveryId, true);
                    AssertEx.Equal(RecoveryDecisionKind.Restored, decision.Kind, writer + ": " + decision.Message);
                    AssertEx.SequenceEqual(bytes, File.ReadAllBytes(fixture.SavePath));
                }
            }
        }

        public static void UnsupportedOrMismatchedRecoveryFormatsAreRejected()
        {
            const string supported = "{\"FormatVersion\":1,";
            Tuple<string, string, string>[] cases =
            {
                Tuple.Create("metadata format 2", PublishedV011Metadata.Replace(supported, "{\"FormatVersion\":2,"), PublishedV011Marker),
                Tuple.Create("marker format 2", PublishedV011Metadata, PublishedV011Marker.Replace(supported, "{\"FormatVersion\":2,")),
                Tuple.Create("both format 2", PublishedV011Metadata.Replace(supported, "{\"FormatVersion\":2,"), PublishedV011Marker.Replace(supported, "{\"FormatVersion\":2,")),
                Tuple.Create("metadata format missing", PublishedV011Metadata.Replace(supported, "{"), PublishedV011Marker),
                Tuple.Create("marker format missing", PublishedV011Metadata, PublishedV011Marker.Replace(supported, "{")),
                Tuple.Create("metadata format 0", PublishedV011Metadata.Replace(supported, "{\"FormatVersion\":0,"), PublishedV011Marker)
            };
            foreach (Tuple<string, string, string> item in cases)
            {
                AssertNotRestored(item.Item1, item.Item2, item.Item3);
            }
        }

        public static void MissingOrMalformedWriterVersionIsRejected()
        {
            const string published = ",\"ModVersion\":\"0.1.1\"}";
            string[] metadata =
            {
                PublishedV011Metadata.Replace(published, "}"),
                PublishedV011Metadata.Replace(published, ",\"ModVersion\":\"\"}"),
                PublishedV011Metadata.Replace(published, ",\"ModVersion\":\"latest\"}"),
                PublishedV011Metadata.Replace(published, ",\"ModVersion\":\"0.1.1; rm\"}"),
                PublishedV011Metadata.Replace(published, ",\"ModVersion\":\"1\"}")
            };
            for (int index = 0; index < metadata.Length; index++)
            {
                AssertEx.False(string.Equals(metadata[index], PublishedV011Metadata, StringComparison.Ordinal), "Case " + index + " was not applied.");
                AssertNotRestored("writer version case " + index, metadata[index], PublishedV011Marker);
            }
        }

        public static void PublishedFormatRecoveryStillRequiresIdentityAndIntegrity()
        {
            const string otherSha = "0000000000000000000000000000000000000000000000000000000000000001";
            AssertNotRestored("tampered snapshot byte", PublishedV011Metadata, PublishedV011Marker, bytes => bytes[1234] ^= 0x5A);
            AssertNotRestored("truncated snapshot", PublishedV011Metadata, PublishedV011Marker, null, bytes => bytes.Take(49999).ToArray());
            AssertNotRestored(
                "metadata hash disagrees with snapshot",
                PublishedV011Metadata.Replace("\"RecoverySha256\":\"" + PublishedSha256 + "\"", "\"RecoverySha256\":\"" + otherSha + "\""),
                PublishedV011Marker);
            AssertNotRestored(
                "marker hash disagrees with metadata",
                PublishedV011Metadata,
                PublishedV011Marker.Replace("\"SourceSha256\":\"" + PublishedSha256 + "\"", "\"SourceSha256\":\"" + otherSha + "\""));
            AssertNotRestored(
                "marker recovery identity mismatch",
                PublishedV011Metadata,
                PublishedV011Marker.Replace("\"RecoveryId\":\"{RECOVERY_ID}\"", "\"RecoveryId\":\"" + new string('a', 64) + "\""));
            AssertNotRestored(
                "campaign identity no longer derives the recovery id",
                PublishedV011Metadata.Replace("\"GameId\":\"campaign-a\"", "\"GameId\":\"campaign-b\""),
                PublishedV011Marker);
            AssertNotRestored(
                "marker created outside the game-over window",
                PublishedV011Metadata,
                PublishedV011Marker.Replace("2026-10-15T22:01:27.5172841Z", "2026-10-15T22:11:27.5172841Z"));
            AssertNotRestored("missing pending marker", PublishedV011Metadata, null);

            using (Fixture fixture = new Fixture())
            {
                string outside = Path.Combine(fixture.Root, "Elsewhere", "IronMan_1.zks");
                string recoveryId = fixture.Write(PublishedV011Metadata, PublishedV011Marker, PublishedSaveBytes(), outside);
                RecoveryDecision decision = fixture.Service.TryGuardedRestore(recoveryId, true);
                AssertEx.Equal(RecoveryDecisionKind.Rejected, decision.Kind, decision.Message);
                AssertEx.False(File.Exists(outside));
                AssertEx.False(Directory.Exists(Path.GetDirectoryName(outside)));
            }
        }

        public static void EvaluatingPublishedFormatRecoveryNeverRewritesOrOverwrites()
        {
            using (Fixture fixture = new Fixture())
            {
                string recoveryId = fixture.Write(PublishedV011Metadata, PublishedV011Marker, PublishedSaveBytes());
                Dictionary<string, Tuple<byte[], DateTime>> before = fixture.CaptureRecoveryFiles(recoveryId);

                AssertEx.Equal(RecoveryDecisionKind.ReadyToRestore, fixture.Service.GetLatestGuardedDecision().Kind);
                AssertEx.Equal(RecoveryDecisionKind.Rejected, fixture.Service.TryGuardedRestore(recoveryId, false).Kind);
                AssertUnchanged(before, fixture.CaptureRecoveryFiles(recoveryId));

                byte[] live = Encoding.ASCII.GetBytes("a live save that recovery must never replace");
                File.WriteAllBytes(fixture.SavePath, live);
                DateTime liveWrite = File.GetLastWriteTimeUtc(fixture.SavePath);
                AssertEx.Equal(RecoveryDecisionKind.OriginalStillExists, fixture.Service.GetLatestGuardedDecision().Kind);
                AssertEx.Equal(RecoveryDecisionKind.OriginalStillExists, fixture.Service.TryGuardedRestore(recoveryId, true).Kind);
                AssertEx.SequenceEqual(live, File.ReadAllBytes(fixture.SavePath));
                AssertEx.Equal(liveWrite, File.GetLastWriteTimeUtc(fixture.SavePath));
                AssertEx.Equal(1, Directory.GetFiles(fixture.SaveRoot).Length);
                AssertUnchanged(before, fixture.CaptureRecoveryFiles(recoveryId));
            }
        }

        private static void AssertNotRestored(
            string label,
            string metadata,
            string marker,
            Action<byte[]> mutateSnapshot = null,
            Func<byte[], byte[]> replaceSnapshot = null)
        {
            using (Fixture fixture = new Fixture())
            {
                byte[] bytes = PublishedSaveBytes();
                mutateSnapshot?.Invoke(bytes);
                if (replaceSnapshot != null) bytes = replaceSnapshot(bytes);
                string recoveryId = fixture.Write(metadata, marker, bytes);
                Dictionary<string, Tuple<byte[], DateTime>> before = fixture.CaptureRecoveryFiles(recoveryId);

                RecoveryDecision latest = fixture.Service.GetLatestGuardedDecision();
                AssertEx.False(latest.CanRestore, label + ": evaluation offered restoration: " + latest.Message);
                RecoveryDecision guarded = fixture.Service.TryGuardedRestore(recoveryId, true);
                AssertEx.True(
                    guarded.Kind == RecoveryDecisionKind.Rejected || guarded.Kind == RecoveryDecisionKind.NoPendingMarker,
                    label + ": expected rejection, got " + guarded.Kind + ": " + guarded.Message);
                AssertEx.False(File.Exists(fixture.SavePath), label + ": a save was restored.");
                AssertEx.Equal(0, Directory.GetFiles(fixture.SaveRoot).Length, label + ": the save root was written.");
                AssertUnchanged(before, fixture.CaptureRecoveryFiles(recoveryId));
            }
        }

        private static void AssertUnchanged(
            Dictionary<string, Tuple<byte[], DateTime>> before,
            Dictionary<string, Tuple<byte[], DateTime>> after)
        {
            AssertEx.Equal(before.Count, after.Count, "Recovery files were added or removed.");
            foreach (KeyValuePair<string, Tuple<byte[], DateTime>> entry in before)
            {
                AssertEx.True(after.ContainsKey(entry.Key), entry.Key + " disappeared.");
                AssertEx.SequenceEqual(entry.Value.Item1, after[entry.Key].Item1, entry.Key + " was rewritten.");
                AssertEx.Equal(entry.Value.Item2, after[entry.Key].Item2, entry.Key + " timestamp changed.");
            }
        }

        private static byte[] PublishedSaveBytes()
        {
            byte[] bytes = new byte[50000];
            new Random(42).NextBytes(bytes);
            return bytes;
        }

        private static string Sha256(byte[] bytes)
        {
            using (SHA256 sha256 = SHA256.Create())
            {
                return BitConverter.ToString(sha256.ComputeHash(bytes)).Replace("-", string.Empty).ToLowerInvariant();
            }
        }

        private sealed class Fixture : IDisposable
        {
            private static readonly Encoding Utf8WithoutBom = new UTF8Encoding(false);

            public Fixture()
            {
                Root = Path.Combine(Path.GetTempPath(), "KingmakerLastAzlantiPreserver.Tests", Guid.NewGuid().ToString("N"));
                SaveRoot = Path.Combine(Root, "Saved Games");
                RecoveryRoot = Path.Combine(Root, "LastAzlantiPreserver", "Recovery");
                SavePath = Path.Combine(SaveRoot, "IronMan_1.zks");
                Directory.CreateDirectory(SaveRoot);
                Service = new RecoverySnapshotService(SaveRoot, RecoveryRoot);
            }

            public string Root { get; }
            public string SaveRoot { get; }
            public string RecoveryRoot { get; }
            public string SavePath { get; }
            public RecoverySnapshotService Service { get; }

            // Lays the files out exactly as v0.1.1 did: Recovery/<id>/{snapshot.bin,metadata.json,pending.json}.
            public string Write(string metadata, string marker, byte[] snapshot, string originalPath = null)
            {
                string path = originalPath ?? SavePath;
                string recoveryId = PublishedRecoveryId(path);
                string directory = Path.Combine(RecoveryRoot, recoveryId);
                Directory.CreateDirectory(directory);
                File.WriteAllBytes(Path.Combine(directory, "snapshot.bin"), snapshot);
                File.WriteAllText(Path.Combine(directory, "metadata.json"), Fill(metadata, path, recoveryId), Utf8WithoutBom);
                if (marker != null)
                {
                    File.WriteAllText(Path.Combine(directory, "pending.json"), Fill(marker, path, recoveryId), Utf8WithoutBom);
                }

                return recoveryId;
            }

            public Dictionary<string, Tuple<byte[], DateTime>> CaptureRecoveryFiles(string recoveryId)
            {
                Dictionary<string, Tuple<byte[], DateTime>> files = new Dictionary<string, Tuple<byte[], DateTime>>(StringComparer.OrdinalIgnoreCase);
                foreach (string file in Directory.GetFiles(RecoveryRoot, "*", SearchOption.AllDirectories))
                {
                    files[file] = Tuple.Create(File.ReadAllBytes(file), File.GetLastWriteTimeUtc(file));
                }

                return files;
            }

            public void Dispose()
            {
                string expected = Path.Combine(Path.GetTempPath(), "KingmakerLastAzlantiPreserver.Tests");
                if (Directory.Exists(Root) && Root.StartsWith(expected, StringComparison.OrdinalIgnoreCase))
                {
                    Directory.Delete(Root, true);
                }
            }

            // The published identity contract: lowercase SHA-256 of the upper-cased full path, a newline, and the game ID.
            private static string PublishedRecoveryId(string path)
            {
                string material = Path.GetFullPath(path).ToUpperInvariant() + "\n" + GameId;
                using (SHA256 sha256 = SHA256.Create())
                {
                    return BitConverter.ToString(sha256.ComputeHash(Encoding.UTF8.GetBytes(material)))
                        .Replace("-", string.Empty)
                        .ToLowerInvariant();
                }
            }

            // DataContractJsonSerializer escapes backslash, quote and forward slash in strings.
            private static string Fill(string template, string path, string recoveryId)
            {
                string escaped = path.Replace("\\", "\\\\").Replace("\"", "\\\"").Replace("/", "\\/");
                return template.Replace("{SAVE_PATH}", escaped).Replace("{RECOVERY_ID}", recoveryId);
            }
        }
    }
}
