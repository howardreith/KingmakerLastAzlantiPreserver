using KingmakerLastAzlantiPreserver.Preservation;

namespace KingmakerLastAzlantiPreserver.Patches
{
    public static class GameOverContextPatch
    {
        public static void Prefix(out PreservationContext __state)
        {
            PatchBridge.BeginGameOver(out __state);
        }

        public static void Postfix(PreservationContext __state)
        {
            PatchBridge.CompleteGameOver(__state);
        }

        public static void DeactivatePrefix()
        {
            PatchBridge.CompleteFromDeactivate();
        }

        public static void GameModeOnActivatePostfix()
        {
            PatchBridge.CompleteFromGameModeActivation();
        }
    }
}
