using UnityModManagerNet;

namespace KingmakerLastAzlantiPreserver
{
    public sealed class Settings : UnityModManager.ModSettings
    {
        public bool PreserveLastAzlantiSaveOnGameOver = true;
        public bool MaintainHiddenRecoverySnapshot = true;
        public bool VerboseDiagnostics;

        public override void Save(UnityModManager.ModEntry modEntry)
        {
            Save(this, modEntry);
        }
    }
}
