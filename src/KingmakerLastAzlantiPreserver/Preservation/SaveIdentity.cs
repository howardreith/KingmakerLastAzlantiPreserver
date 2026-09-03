using System;
using System.IO;

namespace KingmakerLastAzlantiPreserver.Preservation
{
    public sealed class SaveIdentity : IEquatable<SaveIdentity>
    {
        public SaveIdentity(
            string fullPath,
            string gameId,
            string gameName,
            string saveName,
            bool isIronMan)
        {
            FullPath = string.IsNullOrWhiteSpace(fullPath) ? string.Empty : Path.GetFullPath(fullPath);
            GameId = gameId ?? string.Empty;
            GameName = gameName ?? string.Empty;
            SaveName = saveName ?? string.Empty;
            IsIronMan = isIronMan;
        }

        public string FullPath { get; }
        public string FileName => string.IsNullOrWhiteSpace(FullPath) ? string.Empty : Path.GetFileName(FullPath);
        public string GameId { get; }
        public string GameName { get; }
        public string SaveName { get; }
        public bool IsIronMan { get; }

        public bool Equals(SaveIdentity other)
        {
            if (ReferenceEquals(other, null)) return false;
            if (!string.Equals(FullPath, other.FullPath, StringComparison.OrdinalIgnoreCase)) return false;
            return string.IsNullOrEmpty(GameId) || string.IsNullOrEmpty(other.GameId) ||
                string.Equals(GameId, other.GameId, StringComparison.Ordinal);
        }

        public override bool Equals(object obj) => Equals(obj as SaveIdentity);

        public override int GetHashCode()
        {
            return StringComparer.OrdinalIgnoreCase.GetHashCode(FullPath ?? string.Empty);
        }

        public override string ToString()
        {
            return FileName + (string.IsNullOrEmpty(GameId) ? string.Empty : " [" + GameId + "]");
        }
    }
}
