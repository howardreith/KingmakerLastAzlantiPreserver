using System;
using KingmakerLastAzlantiPreserver.Logging;
using UnityModManagerNet;

namespace KingmakerLastAzlantiPreserver
{
    public static class Main
    {
        private static CompositionRoot root;
        private static Settings settings;

        public static bool Load(UnityModManager.ModEntry modEntry)
        {
            if (modEntry == null) return false;
            try
            {
                settings = UnityModManager.ModSettings.Load<Settings>(modEntry) ?? new Settings();
                UmmLogger logger = new UmmLogger(modEntry.Logger, () => settings != null && settings.VerboseDiagnostics);
                root = new CompositionRoot(settings, logger);
                modEntry.OnToggle = OnToggle;
                modEntry.OnGUI = OnGui;
                modEntry.OnUpdate = OnUpdate;
                modEntry.OnSaveGUI = OnSaveGui;
                modEntry.OnUnload = OnUnload;
                logger.Info(ProductMetadata.Name + " " + ProductMetadata.Version +
                    " loaded. Runtime qualification remains pending until the disposable-campaign smoke test is completed.");
                return true;
            }
            catch (Exception exception)
            {
                modEntry.Logger.LogException("Load Last Azlanti Preserver", exception);
                root = null;
                settings = null;
                return false;
            }
        }

        private static bool OnToggle(UnityModManager.ModEntry modEntry, bool value)
        {
            try
            {
                return root != null && root.SetEnabled(value);
            }
            catch (Exception exception)
            {
                modEntry.Logger.LogException("Toggle Last Azlanti Preserver", exception);
                return false;
            }
        }

        private static void OnGui(UnityModManager.ModEntry modEntry)
        {
            try
            {
                root?.DrawGui();
            }
            catch (Exception exception)
            {
                modEntry.Logger.LogException("Draw Last Azlanti Preserver settings", exception);
            }
        }

        private static void OnUpdate(UnityModManager.ModEntry modEntry, float deltaTime)
        {
            try
            {
                root?.Update();
            }
            catch (Exception exception)
            {
                modEntry.Logger.LogException("Update Last Azlanti Preserver", exception);
            }
        }

        private static void OnSaveGui(UnityModManager.ModEntry modEntry)
        {
            try
            {
                root?.Save(modEntry);
            }
            catch (Exception exception)
            {
                modEntry.Logger.LogException("Save Last Azlanti Preserver settings", exception);
            }
        }

        private static bool OnUnload(UnityModManager.ModEntry modEntry)
        {
            try
            {
                bool result = root == null || root.TryUnload();
                if (result)
                {
                    root = null;
                    settings = null;
                }

                return result;
            }
            catch (Exception exception)
            {
                modEntry.Logger.LogException("Unload Last Azlanti Preserver", exception);
                return false;
            }
        }
    }
}
