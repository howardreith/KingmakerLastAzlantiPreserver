using System.Runtime.Serialization;

namespace KingmakerLastAzlantiPreserver.Recovery
{
    [DataContract]
    public sealed class RecoveryMetadata
    {
        public const int CurrentFormatVersion = 1;

        [DataMember(Order = 1)] public int FormatVersion { get; set; }
        [DataMember(Order = 2)] public string RecoveryId { get; set; }
        [DataMember(Order = 3)] public string OriginalFullPath { get; set; }
        [DataMember(Order = 4)] public string OriginalFileName { get; set; }
        [DataMember(Order = 5)] public long SourceLength { get; set; }
        [DataMember(Order = 6)] public string SourceLastWriteUtc { get; set; }
        [DataMember(Order = 7)] public string SourceSha256 { get; set; }
        [DataMember(Order = 8)] public string RecoverySha256 { get; set; }
        [DataMember(Order = 9)] public string GameId { get; set; }
        [DataMember(Order = 10)] public string GameName { get; set; }
        [DataMember(Order = 11)] public string SaveName { get; set; }
        [DataMember(Order = 12)] public string SaveType { get; set; }
        [DataMember(Order = 13)] public string GameOverTimestampUtc { get; set; }
        [DataMember(Order = 14)] public string ModVersion { get; set; }
    }

    [DataContract]
    internal sealed class RecoveryMarker
    {
        [DataMember(Order = 1)] public int FormatVersion { get; set; }
        [DataMember(Order = 2)] public string RecoveryId { get; set; }
        [DataMember(Order = 3)] public string OperationId { get; set; }
        [DataMember(Order = 4)] public string OriginalFullPath { get; set; }
        [DataMember(Order = 5)] public string SourceSha256 { get; set; }
        [DataMember(Order = 6)] public string CreatedUtc { get; set; }
    }
}
