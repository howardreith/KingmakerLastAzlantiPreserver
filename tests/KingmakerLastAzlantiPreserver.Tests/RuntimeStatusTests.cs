using System.Reflection;
using KingmakerLastAzlantiPreserver.Integration;

namespace KingmakerLastAzlantiPreserver.Tests
{
    internal static class RuntimeStatusTests
    {
        public static void OptionalUiFailureDoesNotChangeCoreAvailability()
        {
            RuntimeStatus status = new RuntimeStatus();
            status.SetCoreProtection(RuntimeFeatureState.Available, true, "core-game-over", "core-delete");
            status.SetGameOverLoadControls(
                RuntimeFeatureState.Unavailable,
                false,
                "unresolved",
                "unresolved",
                "simulated optional patch failure");
            RuntimeStatusSnapshot snapshot = status.Snapshot();
            AssertEx.Equal(RuntimeFeatureState.Available, snapshot.CoreProtectionState);
            AssertEx.True(snapshot.CoreContractsInstalled);
            AssertEx.Equal(RuntimeFeatureState.Unavailable, snapshot.GameOverLoadControlsState);
            AssertEx.False(snapshot.GameOverLoadContractsInstalled);
        }

        public static void DisabledUiSettingDoesNotDisableCoreProtection()
        {
            RuntimeStatus status = new RuntimeStatus();
            status.SetCoreProtection(RuntimeFeatureState.Available, true, "core-game-over", "core-delete");
            status.SetGameOverLoadControls(RuntimeFeatureState.Disabled, true, "ui", "controller", "disabled");
            RuntimeStatusSnapshot snapshot = status.Snapshot();
            AssertEx.Equal(RuntimeFeatureState.Available, snapshot.CoreProtectionState);
            AssertEx.Equal(RuntimeFeatureState.Disabled, snapshot.GameOverLoadControlsState);
            AssertEx.True(snapshot.GameOverLoadContractsInstalled);
        }

        public static void CoreAndOptionalHarmonyOwnersAreDistinct()
        {
            System.Type metadata = typeof(Settings).Assembly.GetType("KingmakerLastAzlantiPreserver.ProductMetadata", true);
            string coreOwner = (string)metadata.GetField("CoreHarmonyId", BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Static).GetValue(null);
            string optionalOwner = (string)metadata.GetField("GameOverLoadHarmonyId", BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Static).GetValue(null);
            AssertEx.False(coreOwner == optionalOwner);
        }
    }
}
