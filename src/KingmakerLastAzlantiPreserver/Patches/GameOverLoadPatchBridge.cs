using System;
using KingmakerLastAzlantiPreserver.Integration;
using KingmakerLastAzlantiPreserver.Logging;

namespace KingmakerLastAzlantiPreserver.Patches
{
    internal static class GameOverLoadPatchBridge
    {
        private static readonly object Gate = new object();
        private static GameOverLoadControlCoordinator coordinator;
        private static IModLogger logger;

        public static void Initialize(GameOverLoadControlCoordinator value, IModLogger modLogger)
        {
            lock (Gate)
            {
                coordinator = value;
                logger = modLogger;
            }
        }

        public static void Clear()
        {
            lock (Gate)
            {
                coordinator = null;
                logger = null;
            }
        }

        public static void LegacyCanvasPreShow(object canvas)
        {
            Invoke("Elevate legacy game-over loading controls", current => current.OnLegacyCanvasPreShow(canvas));
        }

        public static void ConsoleMenuConstructed(object viewModel)
        {
            Invoke("Elevate console game-over loading controls", current => current.OnConsoleMenuConstructed(viewModel));
        }

        public static void ConsoleMenuDisposed(object viewModel)
        {
            Invoke("Release console game-over loading controls", current => current.OnConsoleMenuDisposed(viewModel));
        }

        public static bool TryOverrideConsolePredicate(ref bool result)
        {
            try
            {
                GameOverLoadControlCoordinator current = GetCoordinator();
                if (current == null) return true;
                bool elevatedResult;
                if (!current.TryOverrideConsolePredicate(out elevatedResult)) return true;
                result = elevatedResult;
                return false;
            }
            catch (Exception exception)
            {
                LogException("Evaluate console game-over loading control", exception);
                return true;
            }
        }

        public static bool BeforeLoadLastSave(GameOverLoadSurface surface)
        {
            try
            {
                GameOverLoadControlCoordinator current = GetCoordinator();
                return current == null || current.BeforeLoadLastSave(surface);
            }
            catch (Exception exception)
            {
                LogException("Revalidate native game-over Load Last Save action", exception);
                return false;
            }
        }

        public static bool BeforeOpenLoadGame(GameOverLoadSurface surface)
        {
            try
            {
                GameOverLoadControlCoordinator current = GetCoordinator();
                return current == null || current.BeforeOpenLoadGame(surface);
            }
            catch (Exception exception)
            {
                LogException("Revalidate native game-over Load Game action", exception);
                return false;
            }
        }

        public static void NativeLoadStarted()
        {
            Invoke("Clear game-over loading state for native load", current => current.OnNativeLoadStarted());
        }

        public static void NativeDeleteCompleted()
        {
            Invoke("Revalidate game-over loading controls after native deletion", current => current.OnNativeDeleteCompleted());
        }

        public static void LeaveGameOver(string reason)
        {
            Invoke("Clear game-over loading state", current => current.LeaveGameOver(reason));
        }

        private static void Invoke(string operation, Action<GameOverLoadControlCoordinator> action)
        {
            try
            {
                GameOverLoadControlCoordinator current = GetCoordinator();
                if (current != null) action(current);
            }
            catch (Exception exception)
            {
                LogException(operation, exception);
            }
        }

        private static GameOverLoadControlCoordinator GetCoordinator()
        {
            lock (Gate) return coordinator;
        }

        private static void LogException(string operation, Exception exception)
        {
            IModLogger current;
            lock (Gate) current = logger;
            current?.Exception(operation, exception);
        }
    }
}
