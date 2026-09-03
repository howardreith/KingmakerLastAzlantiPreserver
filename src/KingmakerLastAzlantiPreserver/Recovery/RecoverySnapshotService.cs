using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Security.Cryptography;
using System.Text;
using KingmakerLastAzlantiPreserver.Logging;
using KingmakerLastAzlantiPreserver.Preservation;

namespace KingmakerLastAzlantiPreserver.Recovery
{
    public sealed class RecoverySnapshotService
    {
        private const string SnapshotFileName = "snapshot.bin";
        private const string MetadataFileName = "metadata.json";
        private readonly string saveRoot;
        private readonly string recoveryRoot;
        private readonly RecoveryMarkerStore markerStore;
        private readonly IModLogger logger;

        public RecoverySnapshotService(string saveRoot, string recoveryRoot, IModLogger logger = null)
        {
            this.saveRoot = NormalizeDirectory(saveRoot);
            this.recoveryRoot = NormalizeDirectory(recoveryRoot);
            this.logger = logger;
            if (IsSameOrChild(this.recoveryRoot, this.saveRoot))
            {
                throw new InvalidOperationException("The recovery root must be outside Kingmaker's normal save directory.");
            }

            if (Directory.Exists(this.recoveryRoot) && IsReparsePoint(this.recoveryRoot))
            {
                throw new InvalidOperationException("The recovery root cannot be a reparse-point directory.");
            }

            markerStore = new RecoveryMarkerStore(this.recoveryRoot);
        }

        public string RecoveryRoot => recoveryRoot;

        public SnapshotResult CreateSnapshot(SaveIdentity identity, DateTime gameOverUtc)
        {
            if (identity == null) return SnapshotResult.Failure("Save identity is missing.");
            string sourcePath;
            string validationError;
            if (!TryValidateOriginalPath(identity.FullPath, true, out sourcePath, out validationError))
            {
                return SnapshotResult.Failure(validationError);
            }

            string recoveryId = ComputeRecoveryId(sourcePath, identity.GameId);
            string finalDirectory = markerStore.GetIdentityDirectory(recoveryId);
            string stageDirectory = Path.Combine(recoveryRoot, ".stage-" + recoveryId + "-" + Guid.NewGuid().ToString("N"));
            string previousDirectory = Path.Combine(recoveryRoot, ".previous-" + recoveryId);
            try
            {
                Directory.CreateDirectory(recoveryRoot);
                EnsureOrdinaryDirectory(recoveryRoot, "recovery root");
                ReconcilePrevious(finalDirectory, previousDirectory);
                if (Directory.Exists(stageDirectory)) throw new IOException("The unique staging directory already exists.");
                Directory.CreateDirectory(stageDirectory);
                EnsureOrdinaryDirectory(stageDirectory, "recovery staging directory");

                FileInfo before = new FileInfo(sourcePath);
                if (before.Length <= 0) return SnapshotResult.Failure("The source save is empty.");
                if ((before.Attributes & FileAttributes.ReparsePoint) != 0)
                {
                    return SnapshotResult.Failure("Reparse-point save files are not accepted.");
                }

                string sourceHash = ComputeSha256(sourcePath);
                string stagedSnapshot = Path.Combine(stageDirectory, SnapshotFileName);
                CopyFileFlushed(sourcePath, stagedSnapshot);

                FileInfo after = new FileInfo(sourcePath);
                if (!after.Exists || before.Length != after.Length || before.LastWriteTimeUtc != after.LastWriteTimeUtc)
                {
                    return SnapshotResult.Failure("The source save changed while the recovery snapshot was being copied.");
                }

                FileInfo copy = new FileInfo(stagedSnapshot);
                if (!copy.Exists || copy.Length <= 0 || copy.Length != before.Length)
                {
                    return SnapshotResult.Failure("The temporary recovery copy is empty or has the wrong length.");
                }

                string recoveryHash = ComputeSha256(stagedSnapshot);
                if (!string.Equals(sourceHash, recoveryHash, StringComparison.OrdinalIgnoreCase))
                {
                    return SnapshotResult.Failure("The source and temporary recovery hashes do not match.");
                }

                RecoveryMetadata metadata = new RecoveryMetadata
                {
                    FormatVersion = RecoveryMetadata.CurrentFormatVersion,
                    RecoveryId = recoveryId,
                    OriginalFullPath = sourcePath,
                    OriginalFileName = Path.GetFileName(sourcePath),
                    SourceLength = before.Length,
                    SourceLastWriteUtc = before.LastWriteTimeUtc.ToString("o", CultureInfo.InvariantCulture),
                    SourceSha256 = sourceHash,
                    RecoverySha256 = recoveryHash,
                    GameId = identity.GameId,
                    GameName = identity.GameName,
                    SaveName = identity.SaveName,
                    SaveType = identity.IsIronMan ? "IronMan" : "Unknown",
                    GameOverTimestampUtc = gameOverUtc.ToUniversalTime().ToString("o", CultureInfo.InvariantCulture),
                    ModVersion = ProductMetadata.Version
                };
                RecoveryJson.Write(Path.Combine(stageDirectory, MetadataFileName), metadata);

                CommitDirectory(stageDirectory, finalDirectory, previousDirectory);
                string message = "Snapshot validated for " + metadata.OriginalFileName + " (SHA-256 " + recoveryHash + ").";
                logger?.Verbose(message);
                return SnapshotResult.Success(message, metadata);
            }
            catch (Exception exception)
            {
                string message = "Recovery snapshot failed: " + exception.GetType().Name + ": " + exception.Message;
                logger?.Warning(message);
                return SnapshotResult.Failure(message);
            }
            finally
            {
                TryDeleteKnownDirectory(stageDirectory);
            }
        }

        public void CreatePendingMarker(RecoveryMetadata metadata, Guid operationId, DateTime createdUtc)
        {
            ValidateMetadataIdentity(metadata);
            markerStore.Create(metadata, operationId, createdUtc);
        }

        public RecoveryDecision CompleteGameOver(string recoveryId, Guid operationId)
        {
            RecoveryDecision decision = Evaluate(recoveryId, operationId);
            if (decision.Kind == RecoveryDecisionKind.OriginalStillExists)
            {
                markerStore.Clear(recoveryId);
                return new RecoveryDecision(
                    RecoveryDecisionKind.OriginalStillExists,
                    "The original save survived; the pending marker was cleared.",
                    recoveryId,
                    decision.OriginalPath,
                    false);
            }

            if (!decision.CanRestore) return decision;
            return Restore(decision, operationId, true);
        }

        public RecoveryDecision GetLatestGuardedDecision()
        {
            IReadOnlyList<RecoveryMarker> markers = markerStore.ReadAll();
            RecoveryMarker latest = null;
            DateTime latestUtc = DateTime.MinValue;
            for (int index = 0; index < markers.Count; index++)
            {
                DateTime parsed;
                if (!DateTime.TryParse(
                    markers[index].CreatedUtc,
                    CultureInfo.InvariantCulture,
                    DateTimeStyles.AssumeUniversal | DateTimeStyles.AdjustToUniversal,
                    out parsed))
                {
                    continue;
                }

                if (latest == null || parsed > latestUtc)
                {
                    latest = markers[index];
                    latestUtc = parsed;
                }
            }

            if (latest == null)
            {
                return new RecoveryDecision(
                    RecoveryDecisionKind.NoPendingMarker,
                    "No pending game-over recovery marker exists.",
                    string.Empty,
                    string.Empty,
                    false);
            }

            Guid operationId;
            if (!Guid.TryParse(latest.OperationId, out operationId))
            {
                return Reject(latest.RecoveryId, latest.OriginalFullPath, "The pending marker operation ID is invalid.");
            }

            return Evaluate(latest.RecoveryId, operationId);
        }

        public RecoveryDecision TryGuardedRestore(string recoveryId, bool explicitlyConfirmed)
        {
            if (!explicitlyConfirmed)
            {
                return Reject(recoveryId, string.Empty, "Explicit recovery confirmation was not supplied.");
            }

            RecoveryMarker marker;
            string markerError;
            if (!markerStore.TryRead(recoveryId, out marker, out markerError))
            {
                return Reject(recoveryId, string.Empty, markerError);
            }

            Guid operationId;
            if (!Guid.TryParse(marker.OperationId, out operationId))
            {
                return Reject(recoveryId, marker.OriginalFullPath, "The pending marker operation ID is invalid.");
            }

            RecoveryDecision decision = Evaluate(recoveryId, operationId);
            return decision.CanRestore ? Restore(decision, operationId, false) : decision;
        }

        public void ClearSurvivingMarkers()
        {
            IReadOnlyList<RecoveryMarker> markers = markerStore.ReadAll();
            for (int index = 0; index < markers.Count; index++)
            {
                RecoveryMarker marker = markers[index];
                string validated;
                string error;
                if (TryValidateOriginalPath(marker.OriginalFullPath, false, out validated, out error) && File.Exists(validated))
                {
                    markerStore.Clear(marker.RecoveryId);
                }
            }
        }

        public string GetSnapshotPath(string recoveryId)
        {
            return Path.Combine(markerStore.GetIdentityDirectory(recoveryId), SnapshotFileName);
        }

        public string GetMetadataPath(string recoveryId)
        {
            return Path.Combine(markerStore.GetIdentityDirectory(recoveryId), MetadataFileName);
        }

        private RecoveryDecision Evaluate(string recoveryId, Guid operationId)
        {
            RecoveryMarker marker;
            string markerError;
            if (!markerStore.TryRead(recoveryId, out marker, out markerError))
            {
                return new RecoveryDecision(
                    RecoveryDecisionKind.NoPendingMarker,
                    markerError,
                    recoveryId,
                    string.Empty,
                    false);
            }

            if (marker.FormatVersion != RecoveryMetadata.CurrentFormatVersion ||
                !string.Equals(marker.RecoveryId, recoveryId, StringComparison.Ordinal) ||
                !string.Equals(marker.OperationId, operationId.ToString("D"), StringComparison.OrdinalIgnoreCase))
            {
                return Reject(recoveryId, marker.OriginalFullPath, "The pending marker does not match the marked operation.");
            }

            string metadataPath = GetMetadataPath(recoveryId);
            RecoveryMetadata metadata;
            string metadataError = "metadata file is missing.";
            if (!File.Exists(metadataPath) || IsReparsePoint(metadataPath) ||
                !RecoveryJson.TryRead(metadataPath, out metadata, out metadataError))
            {
                return Reject(recoveryId, marker.OriginalFullPath, "Recovery metadata is invalid: " + metadataError);
            }

            string validationError;
            if (!TryValidateMetadata(metadata, marker, out validationError))
            {
                return Reject(recoveryId, marker.OriginalFullPath, validationError);
            }

            if (File.Exists(metadata.OriginalFullPath))
            {
                return new RecoveryDecision(
                    RecoveryDecisionKind.OriginalStillExists,
                    "The recorded original save exists; recovery will not overwrite it.",
                    recoveryId,
                    metadata.OriginalFullPath,
                    false);
            }

            return new RecoveryDecision(
                RecoveryDecisionKind.ReadyToRestore,
                "A validated pending game-over recovery can restore " + metadata.OriginalFileName + ".",
                recoveryId,
                metadata.OriginalFullPath,
                true);
        }

        private RecoveryDecision Restore(RecoveryDecision decision, Guid operationId, bool automatic)
        {
            RecoveryDecision current = Evaluate(decision.RecoveryId, operationId);
            if (!current.CanRestore) return current;

            RecoveryMetadata metadata;
            string metadataError;
            if (!RecoveryJson.TryRead(GetMetadataPath(decision.RecoveryId), out metadata, out metadataError))
            {
                return Reject(decision.RecoveryId, decision.OriginalPath, "Recovery metadata could not be reread: " + metadataError);
            }

            string temporaryPath = Path.Combine(
                saveRoot,
                ".last-azlanti-preserver-restore-" + Guid.NewGuid().ToString("N") + ".tmp");
            try
            {
                if (File.Exists(metadata.OriginalFullPath))
                {
                    return new RecoveryDecision(
                        RecoveryDecisionKind.OriginalStillExists,
                        "The original save appeared before restoration; nothing was overwritten.",
                        decision.RecoveryId,
                        metadata.OriginalFullPath,
                        false);
                }

                CopyFileFlushed(GetSnapshotPath(decision.RecoveryId), temporaryPath);
                FileInfo temporary = new FileInfo(temporaryPath);
                if (!temporary.Exists || temporary.Length != metadata.SourceLength || temporary.Length <= 0 ||
                    !string.Equals(ComputeSha256(temporaryPath), metadata.RecoverySha256, StringComparison.OrdinalIgnoreCase))
                {
                    return Reject(decision.RecoveryId, metadata.OriginalFullPath, "The temporary restore copy failed validation.");
                }

                File.Move(temporaryPath, metadata.OriginalFullPath);
                markerStore.Clear(decision.RecoveryId);
                string mode = automatic ? "Automatic" : "Guarded manual";
                return new RecoveryDecision(
                    RecoveryDecisionKind.Restored,
                    mode + " recovery restored the validated save without overwriting a live file.",
                    decision.RecoveryId,
                    metadata.OriginalFullPath,
                    false);
            }
            catch (Exception exception)
            {
                return Reject(
                    decision.RecoveryId,
                    metadata.OriginalFullPath,
                    "Recovery restore failed: " + exception.GetType().Name + ": " + exception.Message);
            }
            finally
            {
                if (File.Exists(temporaryPath)) File.Delete(temporaryPath);
            }
        }

        private bool TryValidateMetadata(RecoveryMetadata metadata, RecoveryMarker marker, out string error)
        {
            error = null;
            if (metadata == null || metadata.FormatVersion != RecoveryMetadata.CurrentFormatVersion)
            {
                error = "Recovery metadata format is unsupported.";
                return false;
            }

            string originalPath;
            if (!TryValidateOriginalPath(metadata.OriginalFullPath, false, out originalPath, out error)) return false;
            DateTime sourceLastWriteUtc;
            DateTime gameOverUtc;
            DateTime markerCreatedUtc;
            if (!string.Equals(originalPath, metadata.OriginalFullPath, StringComparison.OrdinalIgnoreCase) ||
                !string.Equals(Path.GetFileName(originalPath), metadata.OriginalFileName, StringComparison.Ordinal) ||
                metadata.SourceLength <= 0 ||
                !TryParseUtc(metadata.SourceLastWriteUtc, out sourceLastWriteUtc) ||
                !TryParseUtc(metadata.GameOverTimestampUtc, out gameOverUtc) ||
                !TryParseUtc(marker.CreatedUtc, out markerCreatedUtc) ||
                markerCreatedUtc < gameOverUtc.AddSeconds(-1) ||
                markerCreatedUtc > gameOverUtc.AddMinutes(5) ||
                !IsSha256(metadata.SourceSha256) ||
                !IsSha256(metadata.RecoverySha256) ||
                !string.Equals(metadata.SaveType, "IronMan", StringComparison.Ordinal) ||
                !string.Equals(metadata.ModVersion, ProductMetadata.Version, StringComparison.Ordinal) ||
                !string.Equals(metadata.SourceSha256, metadata.RecoverySha256, StringComparison.OrdinalIgnoreCase) ||
                !string.Equals(metadata.RecoveryId, marker.RecoveryId, StringComparison.Ordinal) ||
                !string.Equals(metadata.OriginalFullPath, marker.OriginalFullPath, StringComparison.OrdinalIgnoreCase) ||
                !string.Equals(metadata.SourceSha256, marker.SourceSha256, StringComparison.OrdinalIgnoreCase) ||
                !string.Equals(ComputeRecoveryId(originalPath, metadata.GameId), metadata.RecoveryId, StringComparison.Ordinal))
            {
                error = "Recovery metadata does not match its marker or original identity.";
                return false;
            }

            string snapshotPath = GetSnapshotPath(metadata.RecoveryId);
            if (!File.Exists(snapshotPath))
            {
                error = "The recovery snapshot is missing.";
                return false;
            }

            FileInfo snapshot = new FileInfo(snapshotPath);
            if (IsReparsePoint(snapshotPath) || snapshot.Length != metadata.SourceLength || snapshot.Length <= 0 ||
                !string.Equals(ComputeSha256(snapshotPath), metadata.RecoverySha256, StringComparison.OrdinalIgnoreCase))
            {
                error = "The recovery snapshot length or SHA-256 does not match metadata.";
                return false;
            }

            return true;
        }

        private void ValidateMetadataIdentity(RecoveryMetadata metadata)
        {
            if (metadata == null || !RecoveryMarkerStore.IsValidRecoveryId(metadata.RecoveryId))
            {
                throw new InvalidDataException("Snapshot metadata identity is invalid.");
            }

            string originalPath;
            string error;
            if (!TryValidateOriginalPath(metadata.OriginalFullPath, false, out originalPath, out error) ||
                !string.Equals(ComputeRecoveryId(originalPath, metadata.GameId), metadata.RecoveryId, StringComparison.Ordinal))
            {
                throw new InvalidDataException("Snapshot metadata path is invalid: " + error);
            }
        }

        private bool TryValidateOriginalPath(string path, bool mustExist, out string fullPath, out string error)
        {
            fullPath = null;
            error = null;
            if (string.IsNullOrWhiteSpace(path))
            {
                error = "The source save path is empty.";
                return false;
            }

            try
            {
                fullPath = Path.GetFullPath(path);
            }
            catch (Exception exception)
            {
                error = "The source save path is invalid: " + exception.Message;
                return false;
            }

            string parent = NormalizeDirectory(Path.GetDirectoryName(fullPath));
            string extension = Path.GetExtension(fullPath);
            if (!string.Equals(parent, saveRoot, StringComparison.OrdinalIgnoreCase))
            {
                error = "The source save is not a direct child of Kingmaker's save directory.";
                return false;
            }

            if (!string.Equals(extension, ".zks", StringComparison.OrdinalIgnoreCase) &&
                !string.Equals(extension, ".zip", StringComparison.OrdinalIgnoreCase))
            {
                error = "The source save extension is not a Kingmaker zip-save extension.";
                return false;
            }

            if (Directory.Exists(fullPath))
            {
                error = "A recovery operation cannot target a directory.";
                return false;
            }

            if (mustExist && !File.Exists(fullPath))
            {
                error = "The source save file does not exist.";
                return false;
            }

            return true;
        }

        private static void CopyFileFlushed(string sourcePath, string destinationPath)
        {
            using (FileStream source = new FileStream(sourcePath, FileMode.Open, FileAccess.Read, FileShare.Read))
            using (FileStream destination = new FileStream(destinationPath, FileMode.CreateNew, FileAccess.Write, FileShare.None))
            {
                source.CopyTo(destination, 81920);
                destination.Flush(true);
            }
        }

        private static string ComputeSha256(string path)
        {
            using (FileStream stream = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.Read))
            using (SHA256 sha256 = SHA256.Create())
            {
                return BitConverter.ToString(sha256.ComputeHash(stream)).Replace("-", string.Empty).ToLowerInvariant();
            }
        }

        private static string ComputeRecoveryId(string fullPath, string gameId)
        {
            string material = Path.GetFullPath(fullPath).ToUpperInvariant() + "\n" + (gameId ?? string.Empty);
            using (SHA256 sha256 = SHA256.Create())
            {
                return BitConverter.ToString(sha256.ComputeHash(Encoding.UTF8.GetBytes(material)))
                    .Replace("-", string.Empty)
                    .ToLowerInvariant();
            }
        }

        private static void CommitDirectory(string stage, string final, string previous)
        {
            EnsureOrdinaryDirectory(stage, "recovery staging directory");
            bool movedPrevious = false;
            if (Directory.Exists(final))
            {
                EnsureOrdinaryDirectory(final, "current recovery directory");
                if (Directory.Exists(previous)) throw new IOException("A previous recovery transaction has not been reconciled.");
                Directory.Move(final, previous);
                movedPrevious = true;
            }

            try
            {
                Directory.Move(stage, final);
            }
            catch
            {
                if (movedPrevious && !Directory.Exists(final) && Directory.Exists(previous))
                {
                    Directory.Move(previous, final);
                }

                throw;
            }

            if (movedPrevious) TryDeleteKnownDirectory(previous);
        }

        private static void ReconcilePrevious(string final, string previous)
        {
            if (!Directory.Exists(previous)) return;
            EnsureOrdinaryDirectory(previous, "previous recovery directory");
            if (Directory.Exists(final)) EnsureOrdinaryDirectory(final, "current recovery directory");
            if (!Directory.Exists(final))
            {
                Directory.Move(previous, final);
                return;
            }

            TryDeleteKnownDirectory(previous);
            if (Directory.Exists(previous))
            {
                throw new IOException("A prior recovery transaction could not be cleaned safely.");
            }
        }

        private static void TryDeleteKnownDirectory(string directory)
        {
            if (!Directory.Exists(directory)) return;
            if (IsReparsePoint(directory)) return;
            HashSet<string> allowed = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
            {
                SnapshotFileName,
                MetadataFileName,
                "pending.json"
            };
            string[] directories = Directory.GetDirectories(directory);
            if (directories.Length != 0) return;
            string[] files = Directory.GetFiles(directory);
            for (int index = 0; index < files.Length; index++)
            {
                string name = Path.GetFileName(files[index]);
                if (!allowed.Contains(name) && !name.EndsWith(".tmp", StringComparison.OrdinalIgnoreCase)) return;
            }

            for (int index = 0; index < files.Length; index++) File.Delete(files[index]);
            Directory.Delete(directory, false);
        }

        private static bool IsSha256(string value)
        {
            if (string.IsNullOrEmpty(value) || value.Length != 64) return false;
            for (int index = 0; index < value.Length; index++)
            {
                char current = char.ToLowerInvariant(value[index]);
                if (!((current >= '0' && current <= '9') || (current >= 'a' && current <= 'f'))) return false;
            }

            return true;
        }

        private static bool TryParseUtc(string value, out DateTime utc)
        {
            if (!DateTime.TryParse(
                value,
                CultureInfo.InvariantCulture,
                DateTimeStyles.RoundtripKind,
                out utc) || utc.Kind != DateTimeKind.Utc)
            {
                utc = default(DateTime);
                return false;
            }

            return true;
        }

        private static void EnsureOrdinaryDirectory(string directory, string label)
        {
            if (!Directory.Exists(directory)) throw new DirectoryNotFoundException(directory);
            if (IsReparsePoint(directory)) throw new InvalidDataException("The " + label + " cannot be a reparse point.");
        }

        private static bool IsReparsePoint(string path)
        {
            return (File.GetAttributes(path) & FileAttributes.ReparsePoint) != 0;
        }

        private static RecoveryDecision Reject(string recoveryId, string originalPath, string message)
        {
            return new RecoveryDecision(RecoveryDecisionKind.Rejected, message, recoveryId, originalPath, false);
        }

        private static bool IsSameOrChild(string candidate, string parent)
        {
            string normalizedCandidate = NormalizeDirectory(candidate);
            string normalizedParent = NormalizeDirectory(parent);
            if (string.Equals(normalizedCandidate, normalizedParent, StringComparison.OrdinalIgnoreCase)) return true;
            string prefix = normalizedParent + Path.DirectorySeparatorChar;
            return normalizedCandidate.StartsWith(prefix, StringComparison.OrdinalIgnoreCase);
        }

        private static string NormalizeDirectory(string path)
        {
            return Path.GetFullPath(path).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
        }
    }
}
