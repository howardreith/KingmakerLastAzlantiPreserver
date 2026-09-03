using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;

namespace KingmakerLastAzlantiPreserver.Recovery
{
    public sealed class RecoveryMarkerStore
    {
        private const string MarkerFileName = "pending.json";
        private readonly string recoveryRoot;

        public RecoveryMarkerStore(string recoveryRoot)
        {
            this.recoveryRoot = NormalizeDirectory(recoveryRoot);
            if (Directory.Exists(this.recoveryRoot) && IsReparsePoint(this.recoveryRoot))
            {
                throw new InvalidDataException("The recovery marker root cannot be a reparse point.");
            }
        }

        internal void Create(RecoveryMetadata metadata, Guid operationId, DateTime createdUtc)
        {
            if (metadata == null) throw new ArgumentNullException(nameof(metadata));
            string directory = GetIdentityDirectory(metadata.RecoveryId);
            if (!Directory.Exists(directory)) throw new DirectoryNotFoundException(directory);
            string finalPath = Path.Combine(directory, MarkerFileName);
            string temporaryPath = Path.Combine(directory, ".pending-" + Guid.NewGuid().ToString("N") + ".tmp");
            try
            {
                RecoveryJson.Write(
                    temporaryPath,
                    new RecoveryMarker
                    {
                        FormatVersion = RecoveryMetadata.CurrentFormatVersion,
                        RecoveryId = metadata.RecoveryId,
                        OperationId = operationId.ToString("D"),
                        OriginalFullPath = metadata.OriginalFullPath,
                        SourceSha256 = metadata.SourceSha256,
                        CreatedUtc = createdUtc.ToUniversalTime().ToString("o", CultureInfo.InvariantCulture)
                    });
                ReplaceFile(temporaryPath, finalPath);
            }
            finally
            {
                DeleteKnownTemporaryFile(temporaryPath);
            }
        }

        internal bool TryRead(string recoveryId, out RecoveryMarker marker, out string error)
        {
            marker = null;
            error = null;
            string path;
            try
            {
                path = Path.Combine(GetIdentityDirectory(recoveryId), MarkerFileName);
            }
            catch (Exception exception)
            {
                error = exception.Message;
                return false;
            }

            if (!File.Exists(path))
            {
                error = "No pending game-over marker exists.";
                return false;
            }

            if (IsReparsePoint(path))
            {
                error = "The pending game-over marker cannot be a reparse point.";
                return false;
            }

            return RecoveryJson.TryRead(path, out marker, out error);
        }

        internal IReadOnlyList<RecoveryMarker> ReadAll()
        {
            List<RecoveryMarker> markers = new List<RecoveryMarker>();
            if (!Directory.Exists(recoveryRoot)) return markers;
            foreach (string directory in Directory.GetDirectories(recoveryRoot))
            {
                string recoveryId = Path.GetFileName(directory);
                if (!IsValidRecoveryId(recoveryId)) continue;
                RecoveryMarker marker;
                string error;
                if (TryRead(recoveryId, out marker, out error) && marker != null) markers.Add(marker);
            }

            return markers;
        }

        internal void Clear(string recoveryId)
        {
            string markerPath = Path.Combine(GetIdentityDirectory(recoveryId), MarkerFileName);
            if (File.Exists(markerPath))
            {
                if (IsReparsePoint(markerPath)) throw new InvalidDataException("The pending marker cannot be a reparse point.");
                File.Delete(markerPath);
            }
        }

        internal string GetIdentityDirectory(string recoveryId)
        {
            if (!IsValidRecoveryId(recoveryId)) throw new InvalidDataException("Recovery identity is invalid.");
            string path = Path.GetFullPath(Path.Combine(recoveryRoot, recoveryId));
            string expectedParent = NormalizeDirectory(Path.GetDirectoryName(path));
            if (!string.Equals(expectedParent, recoveryRoot, StringComparison.OrdinalIgnoreCase))
            {
                throw new InvalidDataException("Recovery identity escaped the recovery root.");
            }

            if (Directory.Exists(path) && IsReparsePoint(path))
            {
                throw new InvalidDataException("Recovery identity directories cannot be reparse points.");
            }

            return path;
        }

        internal static bool IsValidRecoveryId(string value)
        {
            if (string.IsNullOrEmpty(value) || value.Length != 64) return false;
            for (int index = 0; index < value.Length; index++)
            {
                char current = value[index];
                if (!((current >= '0' && current <= '9') || (current >= 'a' && current <= 'f'))) return false;
            }

            return true;
        }

        private static void ReplaceFile(string temporaryPath, string finalPath)
        {
            if (File.Exists(finalPath))
            {
                if (IsReparsePoint(finalPath)) throw new InvalidDataException("The pending marker cannot be a reparse point.");
                File.Replace(temporaryPath, finalPath, null, true);
            }
            else
            {
                File.Move(temporaryPath, finalPath);
            }
        }

        private static void DeleteKnownTemporaryFile(string path)
        {
            if (File.Exists(path) && string.Equals(Path.GetExtension(path), ".tmp", StringComparison.OrdinalIgnoreCase))
            {
                File.Delete(path);
            }
        }

        private static string NormalizeDirectory(string path)
        {
            return Path.GetFullPath(path).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
        }

        private static bool IsReparsePoint(string path)
        {
            return (File.GetAttributes(path) & FileAttributes.ReparsePoint) != 0;
        }
    }
}
