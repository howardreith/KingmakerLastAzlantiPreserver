using Kingmaker.EntitySystem.Persistence;

namespace KingmakerLastAzlantiPreserver.Patches
{
    public static class SaveDeletionPatch
    {
        public static bool Prefix(SaveInfo saveInfo)
        {
            return !PatchBridge.ShouldSuppressDeletion(saveInfo);
        }
    }
}
