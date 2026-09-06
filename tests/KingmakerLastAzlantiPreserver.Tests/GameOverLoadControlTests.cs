using KingmakerLastAzlantiPreserver.Integration;

namespace KingmakerLastAzlantiPreserver.Tests
{
    internal static class GameOverLoadControlTests
    {
        private sealed class FakeControl
        {
            public bool Enabled;
            public int Writes;
        }

        public static void NegativeEligibilityLeavesVanillaAndUnrelatedControlsUntouched()
        {
            FakeControl loadLast = new FakeControl { Enabled = false };
            FakeControl loadGame = new FakeControl { Enabled = false };
            FakeControl startAgain = new FakeControl { Enabled = true };
            ScopedControlElevation elevation = CreateElevation();
            elevation.ObserveAfterVanilla(new object(), loadLast, loadGame);
            elevation.Apply(false);
            AssertEx.False(loadLast.Enabled);
            AssertEx.False(loadGame.Enabled);
            AssertEx.True(startAgain.Enabled);
            AssertEx.Equal(0, loadLast.Writes);
            AssertEx.Equal(0, loadGame.Writes);
            AssertEx.Equal(0, startAgain.Writes);
        }

        public static void PositiveEligibilityElevatesOnlyTwoLoadingControls()
        {
            FakeControl loadLast = new FakeControl { Enabled = false };
            FakeControl loadGame = new FakeControl { Enabled = false };
            FakeControl mainMenu = new FakeControl { Enabled = true };
            ScopedControlElevation elevation = CreateElevation();
            elevation.ObserveAfterVanilla(new object(), loadLast, loadGame);
            elevation.Apply(true);
            AssertEx.True(loadLast.Enabled);
            AssertEx.True(loadGame.Enabled);
            AssertEx.True(mainMenu.Enabled);
            AssertEx.Equal(1, loadLast.Writes);
            AssertEx.Equal(1, loadGame.Writes);
            AssertEx.Equal(0, mainMenu.Writes);
        }

        public static void DisablingAfterElevationRestoresOnlyOwnedStates()
        {
            FakeControl loadLast = new FakeControl { Enabled = false };
            FakeControl loadGame = new FakeControl { Enabled = false };
            FakeControl startAgain = new FakeControl { Enabled = true };
            ScopedControlElevation elevation = CreateElevation();
            elevation.ObserveAfterVanilla(new object(), loadLast, loadGame);
            elevation.Apply(true);
            startAgain.Enabled = false;
            elevation.Apply(false);
            AssertEx.False(loadLast.Enabled);
            AssertEx.False(loadGame.Enabled);
            AssertEx.False(startAgain.Enabled, "An unrelated native control was overwritten.");
            AssertEx.Equal(2, loadLast.Writes);
            AssertEx.Equal(2, loadGame.Writes);
            AssertEx.Equal(0, startAgain.Writes);
        }

        public static void DifferentViewNeverReceivesStaleRestoration()
        {
            object firstView = new object();
            object secondView = new object();
            FakeControl firstLoadLast = new FakeControl { Enabled = false };
            FakeControl firstLoadGame = new FakeControl { Enabled = false };
            FakeControl secondLoadLast = new FakeControl { Enabled = true };
            FakeControl secondLoadGame = new FakeControl { Enabled = true };
            ScopedControlElevation elevation = CreateElevation();
            elevation.ObserveAfterVanilla(firstView, firstLoadLast, firstLoadGame);
            elevation.Apply(true);
            elevation.ObserveAfterVanilla(secondView, secondLoadLast, secondLoadGame);
            AssertEx.False(firstLoadLast.Enabled);
            AssertEx.False(firstLoadGame.Enabled);
            elevation.Apply(false);
            AssertEx.True(secondLoadLast.Enabled);
            AssertEx.True(secondLoadGame.Enabled);
        }

        public static void RebindingSameViewUsesFreshVanillaBaseline()
        {
            object view = new object();
            FakeControl loadLast = new FakeControl { Enabled = false };
            FakeControl loadGame = new FakeControl { Enabled = false };
            ScopedControlElevation elevation = CreateElevation();
            elevation.ObserveAfterVanilla(view, loadLast, loadGame);
            elevation.Apply(true);
            loadLast.Enabled = false;
            loadGame.Enabled = false;
            elevation.ObserveAfterVanilla(view, loadLast, loadGame);
            elevation.Apply(false);
            AssertEx.False(loadLast.Enabled);
            AssertEx.False(loadGame.Enabled);
        }

        public static void PartialElevationFailureRestoresBothVanillaStates()
        {
            FakeControl loadLast = new FakeControl { Enabled = false };
            FakeControl loadGame = new FakeControl { Enabled = false };
            ScopedControlElevation elevation = new ScopedControlElevation(
                control => ((FakeControl)control).Enabled,
                (control, value) =>
                {
                    FakeControl fake = (FakeControl)control;
                    if (ReferenceEquals(fake, loadGame) && value) throw new System.InvalidOperationException("simulated write failure");
                    fake.Enabled = value;
                    fake.Writes++;
                });
            elevation.ObserveAfterVanilla(new object(), loadLast, loadGame);
            AssertEx.Throws<System.InvalidOperationException>(() => elevation.Apply(true));
            AssertEx.False(loadLast.Enabled);
            AssertEx.False(loadGame.Enabled);
            AssertEx.False(elevation.IsElevated);
        }

        private static ScopedControlElevation CreateElevation()
        {
            return new ScopedControlElevation(
                control => ((FakeControl)control).Enabled,
                (control, value) =>
                {
                    FakeControl fake = (FakeControl)control;
                    fake.Enabled = value;
                    fake.Writes++;
                });
        }
    }
}
