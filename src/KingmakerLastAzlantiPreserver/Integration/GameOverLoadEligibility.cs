namespace KingmakerLastAzlantiPreserver.Integration
{
    public enum GameOverLoadSurface
    {
        LegacyEndless,
        ConsoleEndless
    }

    public sealed class GameOverLoadEligibilityRequest
    {
        public bool ModEnabled { get; set; }
        public bool CoreProtectionAvailable { get; set; }
        public bool PreservationEnabled { get; set; }
        public bool LoadControlsEnabled { get; set; }
        public bool GameOverModeActive { get; set; }
        public bool EndlessCampaignActive { get; set; }
        public bool OnlyOneSaveEnabled { get; set; }
        public bool CurrentSavePresent { get; set; }
        public bool CurrentSaveIsIronMan { get; set; }
        public bool CurrentSaveIsActuallySaved { get; set; }
        public bool FolderNamePresent { get; set; }
        public bool GameIdPresent { get; set; }
        public bool PathIsDirectChildOfSaveRoot { get; set; }
        public bool SourceExists { get; set; }
        public bool OperationExists { get; set; }
        public bool OperationIsFresh { get; set; }
        public bool OperationMatchesCurrentSave { get; set; }
        public bool NativeSelectionPresent { get; set; }
        public bool NativeSelectionMatchesOperation { get; set; }
    }

    public sealed class GameOverLoadEligibilityDecision
    {
        private GameOverLoadEligibilityDecision(bool allowed, string reason)
        {
            Allowed = allowed;
            Reason = reason ?? string.Empty;
        }

        public bool Allowed { get; }
        public string Reason { get; }

        public static GameOverLoadEligibilityDecision Allow(string reason)
        {
            return new GameOverLoadEligibilityDecision(true, reason);
        }

        public static GameOverLoadEligibilityDecision Reject(string reason)
        {
            return new GameOverLoadEligibilityDecision(false, reason);
        }
    }

    public sealed class GameOverLoadEligibilityPolicy
    {
        public GameOverLoadEligibilityDecision Evaluate(GameOverLoadEligibilityRequest request)
        {
            if (request == null) return GameOverLoadEligibilityDecision.Reject("No eligibility request was supplied.");
            if (!request.ModEnabled) return GameOverLoadEligibilityDecision.Reject("The mod is disabled.");
            if (!request.CoreProtectionAvailable) return GameOverLoadEligibilityDecision.Reject("Core preservation is unavailable.");
            if (!request.PreservationEnabled) return GameOverLoadEligibilityDecision.Reject("Core preservation is disabled.");
            if (!request.LoadControlsEnabled) return GameOverLoadEligibilityDecision.Reject("Game-over loading controls are disabled.");
            if (!request.GameOverModeActive) return GameOverLoadEligibilityDecision.Reject("The current game mode is not GameOver.");
            if (!request.EndlessCampaignActive) return GameOverLoadEligibilityDecision.Reject("The current game-over screen is not the standalone endless campaign.");
            if (!request.OnlyOneSaveEnabled) return GameOverLoadEligibilityDecision.Reject("Only One Save is not enabled.");
            if (!request.CurrentSavePresent) return GameOverLoadEligibilityDecision.Reject("The current native save is unavailable.");
            if (!request.CurrentSaveIsIronMan) return GameOverLoadEligibilityDecision.Reject("The current native save is not IronMan.");
            if (!request.FolderNamePresent) return GameOverLoadEligibilityDecision.Reject("The current native save has no FolderName.");
            if (!request.GameIdPresent) return GameOverLoadEligibilityDecision.Reject("The current native save has no campaign GameId.");
            if (!request.CurrentSaveIsActuallySaved) return GameOverLoadEligibilityDecision.Reject("SaveInfo.IsActuallySaved is false.");
            if (!request.PathIsDirectChildOfSaveRoot) return GameOverLoadEligibilityDecision.Reject("The current native save is outside Kingmaker's resolved save root.");
            if (!request.SourceExists) return GameOverLoadEligibilityDecision.Reject("The live native source save does not exist.");
            if (!request.OperationExists) return GameOverLoadEligibilityDecision.Reject("No verified preserved game-over operation exists.");
            if (!request.OperationIsFresh) return GameOverLoadEligibilityDecision.Reject("The verified game-over operation is stale.");
            if (!request.OperationMatchesCurrentSave) return GameOverLoadEligibilityDecision.Reject("The current save does not match the preserved game-over operation.");
            if (!request.NativeSelectionPresent) return GameOverLoadEligibilityDecision.Reject("Kingmaker's native load-last selection is unavailable.");
            if (!request.NativeSelectionMatchesOperation) return GameOverLoadEligibilityDecision.Reject("Kingmaker's native load-last selection does not match the preserved operation.");

            return GameOverLoadEligibilityDecision.Allow("The preserved live Last Azlanti save is eligible for native game-over loading.");
        }

        public bool ShouldRunNativeAction(
            GameOverLoadEligibilityDecision eligibility,
            bool onlyOneSaveStateAvailable,
            bool onlyOneSaveEnabled)
        {
            if (eligibility == null || !onlyOneSaveStateAvailable) return false;
            return eligibility.Allowed || !onlyOneSaveEnabled;
        }
    }
}
