using System;
using System.Threading;
using Kingmaker.EntitySystem.Persistence;
using KingmakerLastAzlantiPreserver.Integration;
using KingmakerLastAzlantiPreserver.Logging;
using KingmakerLastAzlantiPreserver.Recovery;

namespace KingmakerLastAzlantiPreserver.Preservation
{
    public sealed class GameOverPreservationCoordinator
    {
        private readonly Settings settings;
        private readonly ActiveSaveResolver activeSaveResolver;
        private readonly DeleteInvocationClassifier invocationClassifier;
        private readonly PreservationContextTracker contextTracker;
        private readonly PreservationPolicy policy;
        private readonly RecoverySnapshotService recovery;
        private readonly RuntimeStatus status;
        private readonly IModLogger logger;

        public GameOverPreservationCoordinator(
            Settings settings,
            ActiveSaveResolver activeSaveResolver,
            DeleteInvocationClassifier invocationClassifier,
            PreservationContextTracker contextTracker,
            PreservationPolicy policy,
            RecoverySnapshotService recovery,
            RuntimeStatus status,
            IModLogger logger)
        {
            this.settings = settings ?? throw new ArgumentNullException(nameof(settings));
            this.activeSaveResolver = activeSaveResolver ?? throw new ArgumentNullException(nameof(activeSaveResolver));
            this.invocationClassifier = invocationClassifier ?? throw new ArgumentNullException(nameof(invocationClassifier));
            this.contextTracker = contextTracker ?? throw new ArgumentNullException(nameof(contextTracker));
            this.policy = policy ?? throw new ArgumentNullException(nameof(policy));
            this.recovery = recovery ?? throw new ArgumentNullException(nameof(recovery));
            this.status = status ?? throw new ArgumentNullException(nameof(status));
            this.logger = logger ?? throw new ArgumentNullException(nameof(logger));
        }

        public PreservationContext BeginGameOver()
        {
            if (!settings.PreserveLastAzlantiSaveOnGameOver)
            {
                status.SetInterceptionResult("Preservation disabled; vanilla game-over behavior is unchanged.");
                return null;
            }

            SaveInfo saveInfo;
            SaveIdentity identity;
            string error;
            if (!activeSaveResolver.TryResolveForGameOver(out saveInfo, out identity, out error))
            {
                status.SetLastAzlantiRecognized(false);
                status.SetError("Game-over save recognition failed: " + error);
                logger.Warning("Protection did not establish a context: " + error);
                return null;
            }

            status.SetLastAzlantiRecognized(true);
            DateTime now = DateTime.UtcNow;
            PreservationContext context = contextTracker.Begin(identity, now, Thread.CurrentThread.ManagedThreadId);
            logger.Verbose("Entered scoped game-over context for " + identity + ".");

            if (!settings.MaintainHiddenRecoverySnapshot)
            {
                status.SetRecoveryResult("Hidden recovery snapshot disabled; core deletion interception remains enabled.");
                return context;
            }

            SnapshotResult snapshot = recovery.CreateSnapshot(identity, now);
            status.SetRecoveryResult(snapshot.Message);
            if (!snapshot.Succeeded)
            {
                status.SetError(snapshot.Message);
                return context;
            }

            try
            {
                recovery.CreatePendingMarker(snapshot.Metadata, context.OperationId, now);
                context.RecoveryId = snapshot.Metadata.RecoveryId;
                context.RecoveryMarkerCreated = true;
                status.SetRecoveryResult(snapshot.Message + " Pending marker created.");
            }
            catch (Exception exception)
            {
                string message = "Snapshot exists, but its pending marker could not be created: " + exception.Message;
                status.SetRecoveryResult(message);
                status.SetError(message);
                logger.Exception("Create game-over recovery marker", exception);
            }

            return context;
        }

        public bool ShouldSuppressDeletion(SaveInfo saveInfo)
        {
            PreservationContext context = contextTracker.Current;
            SaveIdentity targetIdentity;
            string identityError;
            bool targetResolved = activeSaveResolver.TryCreateIdentity(saveInfo, out targetIdentity, out identityError);
            DateTime now = DateTime.UtcNow;
            PreservationRequest request = new PreservationRequest
            {
                FeatureEnabled = settings.PreserveLastAzlantiSaveOnGameOver,
                OnlyOneSaveEnabled = activeSaveResolver.IsOnlyOneSaveEnabled(),
                TargetIsIronMan = saveInfo != null && saveInfo.Type == SaveInfo.SaveType.IronMan,
                ContextExists = context != null,
                ContextIsFresh = context != null && context.IsFresh(now),
                ContextThreadMatches = context != null && context.ManagedThreadId == Thread.CurrentThread.ManagedThreadId,
                ExplicitLoadUiDeletionIsOnStack = invocationClassifier.IsExplicitLoadUiDeletionOnStack(),
                TargetMatchesContext = context != null && targetResolved && context.SaveIdentity.Equals(targetIdentity)
            };

            PreservationDecision decision = policy.Evaluate(request);
            status.SetInterceptionResult(decision.Reason);
            if (!decision.SuppressDeletion)
            {
                logger.Verbose("DeleteSave passed through: " + decision.Reason +
                    (targetResolved ? string.Empty : " Identity: " + identityError));
                return false;
            }

            context.InterceptionCount++;
            logger.Info("Preserved Last Azlanti save by suppressing only the scoped game-over DeleteSave call: " + context.SaveIdentity.FileName);
            return true;
        }

        public void CompleteGameOver(PreservationContext context, string source)
        {
            if (context == null || !contextTracker.IsCurrent(context)) return;
            try
            {
                CompleteRecovery(context, source);
            }
            finally
            {
                contextTracker.End(context);
                logger.Verbose("Cleared game-over context from " + source + ".");
            }
        }

        public void CompleteCurrentIfAny(string source)
        {
            CompleteGameOver(contextTracker.Current, source);
        }

        public void WatchdogCleanup()
        {
            PreservationContext current = contextTracker.Current;
            if (current == null) return;
            bool scopeKnownEnded = current.ManagedThreadId == Thread.CurrentThread.ManagedThreadId;
            PreservationContext orphaned = contextTracker.SweepIfOrphaned(
                DateTime.UtcNow,
                scopeKnownEnded);
            if (orphaned == null) return;
            CompleteRecovery(orphaned, "exception/stale-context watchdog");
            logger.Warning("Cleared an orphaned game-over context from the UMM update watchdog.");
        }

        private void CompleteRecovery(PreservationContext context, string source)
        {
            if (!context.RecoveryMarkerCreated || string.IsNullOrEmpty(context.RecoveryId)) return;
            RecoveryDecision decision = recovery.CompleteGameOver(context.RecoveryId, context.OperationId);
            status.SetRecoveryResult(decision.Message + " [" + source + "]");
            if (decision.Kind == RecoveryDecisionKind.Restored)
            {
                activeSaveResolver.RefreshSaveList();
                logger.Warning(decision.Message);
            }
            else
            {
                logger.Verbose(decision.Message);
            }
        }
    }
}
