using System;
using KingmakerLastAzlantiPreserver.Logging;

namespace KingmakerLastAzlantiPreserver.Integration
{
    public sealed class GameOverLoadControlCoordinator
    {
        private readonly GameOverLoadContracts contracts;
        private readonly GameOverLoadEligibilityService eligibility;
        private readonly IModLogger logger;
        private readonly ScopedControlElevation legacyElevation;
        private object consoleMenuViewModel;

        public GameOverLoadControlCoordinator(
            GameOverLoadContracts contracts,
            GameOverLoadEligibilityService eligibility,
            IModLogger logger)
        {
            this.contracts = contracts ?? throw new ArgumentNullException(nameof(contracts));
            this.eligibility = eligibility ?? throw new ArgumentNullException(nameof(eligibility));
            this.logger = logger ?? throw new ArgumentNullException(nameof(logger));
            legacyElevation = new ScopedControlElevation(ReadLegacyInteractable, WriteLegacyInteractable);
            this.eligibility.ControlsShouldRestore += RestoreAndForgetControls;
        }

        public void OnLegacyCanvasPreShow(object canvas)
        {
            if (canvas == null) return;
            object view = contracts.LegacyEndlessView.GetValue(canvas);
            if (view == null) return;
            object loadLast = contracts.LegacyLoadLastSaveButton.GetValue(view);
            object loadGame = contracts.LegacyLoadGameButton.GetValue(view);
            legacyElevation.ObserveAfterVanilla(view, loadLast, loadGame);
            ApplyLegacyEligibility();
        }

        public void OnConsoleMenuConstructed(object viewModel)
        {
            consoleMenuViewModel = viewModel;
            RefreshConsoleControls();
        }

        public void OnConsoleMenuDisposed(object viewModel)
        {
            if (ReferenceEquals(consoleMenuViewModel, viewModel)) consoleMenuViewModel = null;
        }

        public bool TryOverrideConsolePredicate(out bool result)
        {
            GameOverLoadEligibilityDecision decision = eligibility.Evaluate(GameOverLoadSurface.ConsoleEndless);
            result = decision.Allowed;
            return decision.Allowed;
        }

        public bool BeforeLoadLastSave(GameOverLoadSurface surface)
        {
            GameOverLoadEligibilityDecision decision = eligibility.Evaluate(surface);
            bool shouldRunNative = eligibility.ShouldRunNativeAction(decision);
            if (!decision.Allowed)
            {
                TryRefreshAfterRejectedAction();
                return shouldRunNative;
            }

            OnNativeLoadStarted();
            return true;
        }

        public bool BeforeOpenLoadGame(GameOverLoadSurface surface)
        {
            GameOverLoadEligibilityDecision decision = eligibility.Evaluate(surface);
            if (!decision.Allowed) TryRefreshAfterRejectedAction();
            return eligibility.ShouldRunNativeAction(decision);
        }

        public void OnNativeLoadStarted()
        {
            eligibility.NativeLoadStarted();
            RestoreAndForgetControls();
        }

        public void OnNativeDeleteCompleted()
        {
            eligibility.ClearGameOverOperation("a native save deletion completed");
            RestoreAndForgetControls();
        }

        public void LeaveGameOver(string reason)
        {
            eligibility.ClearGameOverOperation(reason);
            RestoreAndForgetControls();
        }

        public void RefreshCurrentControls()
        {
            ApplyLegacyEligibility();
            RefreshConsoleControls();
        }

        public void RestoreAndForgetControls()
        {
            try
            {
                legacyElevation.Detach(null);
            }
            catch (Exception exception)
            {
                logger.Exception("Restore native desktop game-over loading controls", exception);
            }

            if (consoleMenuViewModel != null)
            {
                try
                {
                    RefreshConsoleControls();
                }
                catch (Exception exception)
                {
                    logger.Exception("Restore native console game-over loading controls", exception);
                }
            }

            consoleMenuViewModel = null;
        }

        public void Release()
        {
            eligibility.ControlsShouldRestore -= RestoreAndForgetControls;
            RestoreAndForgetControls();
        }

        private void ApplyLegacyEligibility()
        {
            if (legacyElevation.Owner == null) return;
            GameOverLoadEligibilityDecision decision = eligibility.Evaluate(GameOverLoadSurface.LegacyEndless);
            legacyElevation.Apply(decision.Allowed);
        }

        private void RefreshConsoleControls()
        {
            if (consoleMenuViewModel == null) return;
            object loadLast = contracts.ConsoleLoadLastSaveVm.GetValue(consoleMenuViewModel);
            object loadGame = contracts.ConsoleLoadVm.GetValue(consoleMenuViewModel);
            if (loadLast != null) contracts.ConsoleEntityRefresh.Invoke(loadLast, null);
            if (loadGame != null) contracts.ConsoleEntityRefresh.Invoke(loadGame, null);
        }

        private void TryRefreshAfterRejectedAction()
        {
            try
            {
                RefreshCurrentControls();
            }
            catch (Exception exception)
            {
                logger.Exception("Restore game-over loading controls after rejected action", exception);
            }
        }

        private bool ReadLegacyInteractable(object control)
        {
            return (bool)contracts.ButtonInteractable.GetValue(control, null);
        }

        private void WriteLegacyInteractable(object control, bool value)
        {
            contracts.ButtonInteractable.SetValue(control, value, null);
        }
    }
}
