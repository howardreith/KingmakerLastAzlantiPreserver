using System;

namespace KingmakerLastAzlantiPreserver.Preservation
{
    public interface IGameOverPreservationOutcomeSink
    {
        void BeginGameOverOperation();
        void RecordSuppressedGameOver(Guid operationId, SaveIdentity saveIdentity, DateTime completedUtc);
        void ClearGameOverOperation(string reason);
    }

    public sealed class NullGameOverPreservationOutcomeSink : IGameOverPreservationOutcomeSink
    {
        public void BeginGameOverOperation()
        {
        }

        public void RecordSuppressedGameOver(Guid operationId, SaveIdentity saveIdentity, DateTime completedUtc)
        {
        }

        public void ClearGameOverOperation(string reason)
        {
        }
    }
}
