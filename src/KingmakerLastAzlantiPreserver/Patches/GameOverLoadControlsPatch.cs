using Kingmaker.EntitySystem.Persistence;
using KingmakerLastAzlantiPreserver.Integration;

namespace KingmakerLastAzlantiPreserver.Patches
{
    public static class GameOverLoadControlsPatch
    {
        public static void LegacyCanvasPreShowPostfix(object __instance)
        {
            GameOverLoadPatchBridge.LegacyCanvasPreShow(__instance);
        }

        public static bool LegacyLoadLastPrefix()
        {
            return GameOverLoadPatchBridge.BeforeLoadLastSave(GameOverLoadSurface.LegacyEndless);
        }

        public static bool LegacyLoadGamePrefix()
        {
            return GameOverLoadPatchBridge.BeforeOpenLoadGame(GameOverLoadSurface.LegacyEndless);
        }

        public static void LegacyRestartPrefix()
        {
            GameOverLoadPatchBridge.LeaveGameOver("native Start Again selected");
        }

        public static void LegacyMainMenuPrefix()
        {
            GameOverLoadPatchBridge.LeaveGameOver("native Main Menu selected");
        }

        public static void ConsoleConstructorPostfix(object __instance)
        {
            GameOverLoadPatchBridge.ConsoleMenuConstructed(__instance);
        }

        public static bool ConsolePredicatePrefix(ref bool __result)
        {
            return GameOverLoadPatchBridge.TryOverrideConsolePredicate(ref __result);
        }

        public static bool ConsoleLoadLastPrefix()
        {
            return GameOverLoadPatchBridge.BeforeLoadLastSave(GameOverLoadSurface.ConsoleEndless);
        }

        public static bool ConsoleLoadGamePrefix()
        {
            return GameOverLoadPatchBridge.BeforeOpenLoadGame(GameOverLoadSurface.ConsoleEndless);
        }

        public static void ConsoleNewGamePrefix()
        {
            GameOverLoadPatchBridge.LeaveGameOver("native Start Again selected");
        }

        public static void ConsoleMainMenuPrefix()
        {
            GameOverLoadPatchBridge.LeaveGameOver("native Main Menu selected");
        }

        public static void ConsoleDisposePrefix(object __instance)
        {
            GameOverLoadPatchBridge.ConsoleMenuDisposed(__instance);
        }

        public static void NativeLoadPrefix(SaveInfo saveInfo)
        {
            GameOverLoadPatchBridge.NativeLoadStarted();
        }

        public static void DeleteSavePostfix(SaveInfo saveInfo)
        {
            GameOverLoadPatchBridge.NativeDeleteCompleted();
        }
    }
}
