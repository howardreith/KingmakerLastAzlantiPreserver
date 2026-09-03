using System;
using Kingmaker.EntitySystem.Persistence;
using KingmakerLastAzlantiPreserver.Logging;
using KingmakerLastAzlantiPreserver.Preservation;

namespace KingmakerLastAzlantiPreserver.Patches
{
    internal static class PatchBridge
    {
        private static readonly object Gate = new object();
        private static GameOverPreservationCoordinator coordinator;
        private static IModLogger logger;

        public static void Initialize(GameOverPreservationCoordinator value, IModLogger modLogger)
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

        public static void BeginGameOver(out PreservationContext state)
        {
            state = null;
            try
            {
                GameOverPreservationCoordinator current = GetCoordinator();
                if (current != null) state = current.BeginGameOver();
            }
            catch (Exception exception)
            {
                LogException("Begin Last Azlanti game-over preservation", exception);
            }
        }

        public static void CompleteGameOver(PreservationContext state)
        {
            try
            {
                GameOverPreservationCoordinator current = GetCoordinator();
                if (current != null) current.CompleteGameOver(state, "Activate postfix");
            }
            catch (Exception exception)
            {
                LogException("Complete Last Azlanti game-over preservation", exception);
            }
        }

        public static void CompleteFromDeactivate()
        {
            try
            {
                GameOverPreservationCoordinator current = GetCoordinator();
                if (current != null) current.CompleteCurrentIfAny("Deactivate safety cleanup");
            }
            catch (Exception exception)
            {
                LogException("Deactivate Last Azlanti preservation cleanup", exception);
            }
        }

        public static void CompleteFromGameModeActivation()
        {
            try
            {
                GameOverPreservationCoordinator current = GetCoordinator();
                if (current != null) current.CompleteCurrentIfAny("GameMode.OnActivate exception-path cleanup");
            }
            catch (Exception exception)
            {
                LogException("GameMode activation preservation cleanup", exception);
            }
        }

        public static bool ShouldSuppressDeletion(SaveInfo saveInfo)
        {
            try
            {
                GameOverPreservationCoordinator current = GetCoordinator();
                return current != null && current.ShouldSuppressDeletion(saveInfo);
            }
            catch (Exception exception)
            {
                LogException("Evaluate Last Azlanti deletion", exception);
                return false;
            }
        }

        private static GameOverPreservationCoordinator GetCoordinator()
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
