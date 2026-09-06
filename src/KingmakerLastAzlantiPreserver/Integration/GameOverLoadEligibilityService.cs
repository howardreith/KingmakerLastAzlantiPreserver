using System;
using System.IO;
using Kingmaker;
using Kingmaker.Blueprints.Root;
using Kingmaker.EntitySystem.Persistence;
using Kingmaker.GameModes;
using KingmakerLastAzlantiPreserver.Logging;
using KingmakerLastAzlantiPreserver.Preservation;

namespace KingmakerLastAzlantiPreserver.Integration
{
    public sealed class GameOverLoadEligibilityService : IGameOverPreservationOutcomeSink
    {
        private readonly Settings settings;
        private readonly ActiveSaveResolver activeSaveResolver;
        private readonly GameOverLoadEligibilityPolicy policy;
        private readonly GameOverLoadOutcomeTracker outcomeTracker;
        private readonly RuntimeStatus status;
        private readonly IModLogger logger;
        private bool modEnabled;
        private bool coreProtectionAvailable;
        private bool uiContractsAvailable;
        private string lastDecisionReason = string.Empty;

        public event Action ControlsShouldRestore;

        public GameOverLoadEligibilityService(
            Settings settings,
            ActiveSaveResolver activeSaveResolver,
            GameOverLoadEligibilityPolicy policy,
            GameOverLoadOutcomeTracker outcomeTracker,
            RuntimeStatus status,
            IModLogger logger)
        {
            this.settings = settings ?? throw new ArgumentNullException(nameof(settings));
            this.activeSaveResolver = activeSaveResolver ?? throw new ArgumentNullException(nameof(activeSaveResolver));
            this.policy = policy ?? throw new ArgumentNullException(nameof(policy));
            this.outcomeTracker = outcomeTracker ?? throw new ArgumentNullException(nameof(outcomeTracker));
            this.status = status ?? throw new ArgumentNullException(nameof(status));
            this.logger = logger ?? throw new ArgumentNullException(nameof(logger));
        }

        public void SetAvailability(bool isModEnabled, bool isCoreProtectionAvailable, bool areUiContractsAvailable)
        {
            modEnabled = isModEnabled;
            coreProtectionAvailable = isCoreProtectionAvailable;
            uiContractsAvailable = areUiContractsAvailable;
            if (!modEnabled || !coreProtectionAvailable || !uiContractsAvailable)
            {
                ClearOutcomeAndNotifyControls();
            }
        }

        public void BeginGameOverOperation()
        {
            outcomeTracker.BeginNextOperation();
            NotifyControlsShouldRestore();
            SetLatestDecision("A new game-over operation began; no UI loading outcome is verified yet.");
        }

        public void RecordSuppressedGameOver(Guid operationId, SaveIdentity saveIdentity, DateTime completedUtc)
        {
            if (!modEnabled || !coreProtectionAvailable || !uiContractsAvailable ||
                !settings.PreserveLastAzlantiSaveOnGameOver || !settings.EnableGameOverLoadControls)
            {
                ClearOutcomeAndNotifyControls();
                SetLatestDecision("The scoped deletion was suppressed, but the optional game-over loading controls are not enabled and available.");
                return;
            }

            SaveInfo currentSave;
            SaveIdentity currentIdentity;
            string error;
            if (!activeSaveResolver.TryResolveForGameOver(out currentSave, out currentIdentity, out error) ||
                currentSave == null || !currentSave.IsActuallySaved ||
                string.IsNullOrWhiteSpace(currentIdentity.GameId) ||
                !saveIdentity.ExactlyEquals(currentIdentity) || !IsOrdinaryLiveFile(currentIdentity.FullPath))
            {
                ClearOutcomeAndNotifyControls();
                SetLatestDecision("The deletion was suppressed, but the live native save could not be revalidated: " + (error ?? "identity or source mismatch."));
                return;
            }

            if (!IsCurrentEndlessGameOver())
            {
                ClearOutcomeAndNotifyControls();
                SetLatestDecision("The deletion was suppressed outside the supported standalone endless game-over screen.");
                return;
            }

            outcomeTracker.Record(operationId, currentIdentity, completedUtc);
            SetLatestDecision("Recorded a verified live-save outcome for the current game-over operation.");
        }

        public void ClearGameOverOperation(string reason)
        {
            ClearOutcomeAndNotifyControls();
            SetLatestDecision("No game-over loading operation is active" +
                (string.IsNullOrWhiteSpace(reason) ? "." : ": " + reason + "."));
        }

        public GameOverLoadEligibilityDecision Evaluate(GameOverLoadSurface surface)
        {
            try
            {
                GameOverLoadEligibilityRequest request = BuildRequest(surface);
                GameOverLoadEligibilityDecision decision = policy.Evaluate(request);
                SetLatestDecision(decision.Reason);
                return decision;
            }
            catch (Exception exception)
            {
                string reason = "Eligibility evaluation failed closed: " + exception.GetType().Name + ": " + exception.Message;
                SetLatestDecision(reason);
                logger.Exception("Evaluate optional game-over loading eligibility", exception);
                return GameOverLoadEligibilityDecision.Reject(reason);
            }
        }

        public void NativeLoadStarted()
        {
            ClearGameOverOperation("Kingmaker's native load started");
        }

        public bool ShouldRunNativeAction(GameOverLoadEligibilityDecision decision)
        {
            try
            {
                bool onlyOneSaveEnabled;
                bool stateAvailable = activeSaveResolver.TryGetOnlyOneSaveEnabled(out onlyOneSaveEnabled);
                return policy.ShouldRunNativeAction(
                    decision,
                    stateAvailable,
                    onlyOneSaveEnabled);
            }
            catch (Exception exception)
            {
                logger.Exception("Recheck Kingmaker's native Only One Save action gate", exception);
                return false;
            }
        }

        private GameOverLoadEligibilityRequest BuildRequest(GameOverLoadSurface surface)
        {
            GameOverLoadEligibilityRequest request = new GameOverLoadEligibilityRequest
            {
                ModEnabled = modEnabled,
                CoreProtectionAvailable = coreProtectionAvailable,
                PreservationEnabled = settings.PreserveLastAzlantiSaveOnGameOver,
                LoadControlsEnabled = settings.EnableGameOverLoadControls
            };

            Game game = Game.Instance;
            request.GameOverModeActive = game != null && game.CurrentMode == GameModeType.GameOver;
            request.EndlessCampaignActive = IsEndlessCampaign(game);
            request.OnlyOneSaveEnabled = activeSaveResolver.IsOnlyOneSaveEnabled();

            SaveInfo currentSave = null;
            SaveIdentity currentIdentity = null;
            string identityError;
            if (game != null && game.SaveManager != null)
            {
                currentSave = game.SaveManager.GetIronmanSave();
            }

            request.CurrentSavePresent = currentSave != null;
            request.CurrentSaveIsIronMan = currentSave != null && currentSave.Type == SaveInfo.SaveType.IronMan;
            request.FolderNamePresent = currentSave != null && !string.IsNullOrWhiteSpace(currentSave.FolderName);
            request.GameIdPresent = currentSave != null && !string.IsNullOrWhiteSpace(currentSave.GameId);
            request.CurrentSaveIsActuallySaved = currentSave != null && currentSave.IsActuallySaved;
            request.PathIsDirectChildOfSaveRoot = activeSaveResolver.TryCreateIdentity(currentSave, out currentIdentity, out identityError);
            request.SourceExists = currentIdentity != null && IsOrdinaryLiveFile(currentIdentity.FullPath);

            bool stale;
            GameOverLoadOutcome outcome = outcomeTracker.GetCurrent(DateTime.UtcNow, out stale);
            request.OperationExists = outcome != null || stale;
            request.OperationIsFresh = outcome != null && !stale;
            request.OperationMatchesCurrentSave = outcome != null && currentIdentity != null &&
                outcome.SaveIdentity.ExactlyEquals(currentIdentity);

            SaveInfo nativeSelection = GetNativeSelection(game, surface);
            request.NativeSelectionPresent = nativeSelection != null;
            SaveIdentity nativeIdentity;
            string nativeIdentityError;
            bool nativeIdentityResolved = activeSaveResolver.TryCreateIdentity(
                nativeSelection,
                out nativeIdentity,
                out nativeIdentityError);
            request.NativeSelectionMatchesOperation = outcome != null && nativeIdentityResolved &&
                outcome.SaveIdentity.ExactlyEquals(nativeIdentity);
            return request;
        }

        private static SaveInfo GetNativeSelection(Game game, GameOverLoadSurface surface)
        {
            if (game == null || game.SaveManager == null) return null;
            return surface == GameOverLoadSurface.LegacyEndless
                ? game.SaveManager.GetLatestSave(DlcType.Endless)
                : game.SaveManager.GetLatestSave();
        }

        private static bool IsEndlessCampaign(Game game)
        {
            return game != null && game.Player != null && game.Player.StartPreset != null &&
                game.Player.StartPreset.DlcCampaign == DlcType.Endless;
        }

        private static bool IsCurrentEndlessGameOver()
        {
            Game game = Game.Instance;
            return game != null && game.CurrentMode == GameModeType.GameOver && IsEndlessCampaign(game);
        }

        private static bool IsOrdinaryLiveFile(string path)
        {
            if (string.IsNullOrWhiteSpace(path) || !File.Exists(path)) return false;
            FileAttributes attributes = File.GetAttributes(path);
            return (attributes & (FileAttributes.Directory | FileAttributes.ReparsePoint)) == 0;
        }

        private void SetLatestDecision(string reason)
        {
            status.SetGameOverLoadEligibility(reason);
            if (!string.Equals(lastDecisionReason, reason, StringComparison.Ordinal))
            {
                logger.Verbose("Game-over loading eligibility: " + reason);
                lastDecisionReason = reason;
            }
        }

        private void ClearOutcomeAndNotifyControls()
        {
            outcomeTracker.Clear();
            NotifyControlsShouldRestore();
        }

        private void NotifyControlsShouldRestore()
        {
            Action handler = ControlsShouldRestore;
            if (handler == null) return;
            try
            {
                handler();
            }
            catch (Exception exception)
            {
                logger.Exception("Restore optional game-over loading controls after eligibility revocation", exception);
            }
        }
    }
}
