using System;
using System.IO;
using Kingmaker;
using Kingmaker.EntitySystem.Persistence;
using Kingmaker.UI.SettingsUI;
using KingmakerLastAzlantiPreserver.Preservation;

namespace KingmakerLastAzlantiPreserver.Integration
{
    public sealed class ActiveSaveResolver
    {
        private readonly KingmakerContracts contracts;
        private readonly string saveRoot;

        public ActiveSaveResolver(KingmakerContracts contracts, string saveRoot)
        {
            this.contracts = contracts ?? throw new ArgumentNullException(nameof(contracts));
            this.saveRoot = NormalizeDirectory(saveRoot);
        }

        public string SaveRoot => saveRoot;

        public bool TryResolveForGameOver(out SaveInfo saveInfo, out SaveIdentity identity, out string error)
        {
            saveInfo = null;
            identity = null;
            error = null;
            try
            {
                if (!IsOnlyOneSaveEnabled())
                {
                    error = "SettingsRoot.Instance.OnlyOneSave is false.";
                    return false;
                }

                Game game = Game.Instance;
                if (game == null || game.SaveManager == null)
                {
                    error = "Game.Instance.SaveManager is unavailable.";
                    return false;
                }

                saveInfo = game.SaveManager.GetIronmanSave();
                return TryCreateIdentity(saveInfo, out identity, out error);
            }
            catch (Exception exception)
            {
                error = exception.GetType().Name + ": " + exception.Message;
                return false;
            }
        }

        public bool TryCreateIdentity(SaveInfo saveInfo, out SaveIdentity identity, out string error)
        {
            identity = null;
            error = null;
            if (saveInfo == null)
            {
                error = "SaveInfo is null.";
                return false;
            }

            if (saveInfo.Type != SaveInfo.SaveType.IronMan)
            {
                error = "SaveInfo.Type is " + saveInfo.Type + ", not IronMan.";
                return false;
            }

            if (string.IsNullOrWhiteSpace(saveInfo.FolderName))
            {
                error = "IronMan SaveInfo.FolderName is empty.";
                return false;
            }

            string fullPath;
            try
            {
                fullPath = Path.GetFullPath(saveInfo.FolderName);
            }
            catch (Exception exception)
            {
                error = "IronMan save path is invalid: " + exception.Message;
                return false;
            }

            if (!IsDirectChild(fullPath, saveRoot))
            {
                error = "IronMan save is not a direct child of Kingmaker's resolved save directory.";
                return false;
            }

            identity = new SaveIdentity(
                fullPath,
                saveInfo.GameId,
                saveInfo.GameName,
                saveInfo.Name,
                true);
            return true;
        }

        public bool IsCurrentLastAzlantiRecognized()
        {
            try
            {
                if (!IsOnlyOneSaveEnabled()) return false;
                Game game = Game.Instance;
                if (game == null || game.SaveManager == null) return false;
                SaveInfo saveInfo = contracts.IronmanSaveField.GetValue(game.SaveManager) as SaveInfo;
                SaveIdentity identity;
                string error;
                return TryCreateIdentity(saveInfo, out identity, out error);
            }
            catch
            {
                return false;
            }
        }

        public bool IsOnlyOneSaveEnabled()
        {
            SettingsRoot.SettingsListScreen settings = SettingsRoot.Instance;
            return settings != null && settings.OnlyOneSave != null && settings.OnlyOneSave.CurrentValue;
        }

        public void RefreshSaveList()
        {
            Game game = Game.Instance;
            if (game != null && game.SaveManager != null)
            {
                game.SaveManager.UpdateSaveListIfNeeded(true);
            }
        }

        private static string NormalizeDirectory(string path)
        {
            string full = Path.GetFullPath(path);
            return full.TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
        }

        private static bool IsDirectChild(string path, string parent)
        {
            string directory = Path.GetDirectoryName(Path.GetFullPath(path));
            return string.Equals(NormalizeDirectory(directory), NormalizeDirectory(parent), StringComparison.OrdinalIgnoreCase);
        }
    }
}
