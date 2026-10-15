using System.Collections.Generic;

namespace KingmakerLastAzlantiPreserver.UI
{
    public enum PanelSetting
    {
        PreserveSave,
        GameOverLoading,
        RecoveryBackup,
        VerboseDiagnostics
    }

    public enum PanelFeature
    {
        SaveProtection,
        GameOverLoading,
        RecoveryBackup
    }

    public enum PanelFeatureStatus
    {
        Ready,
        Off,
        NeedsSaveProtection,
        Unavailable
    }

    public enum PanelTone
    {
        Normal,
        Notice,
        Problem
    }

    public enum PanelAlertKind
    {
        SaveProtectionUnavailable,
        GameOverLoadingUnavailable,
        FirstAzlantiLoaded,
        SaveProtectionCompatibilityUnverified,
        GameOverLoadingCompatibilityUnverified,
        SavePreservationFailed,
        RecoveryBackupFailed,
        GameOverLoadingFailed,
        CleanupFailed
    }

    public enum RecoveryPanelState
    {
        Restorable,
        Blocked,
        Restored
    }

    public sealed class PanelToggle
    {
        public PanelToggle(PanelSetting setting, string label, bool value, bool enabled)
        {
            Setting = setting;
            Label = label;
            Value = value;
            Enabled = enabled;
        }

        public PanelSetting Setting { get; }
        public string Label { get; }
        public bool Value { get; }
        public bool Enabled { get; }
    }

    public sealed class PanelStatusLine
    {
        public PanelStatusLine(PanelFeature feature, PanelFeatureStatus status, string text)
        {
            Feature = feature;
            Status = status;
            Text = text;
        }

        public PanelFeature Feature { get; }
        public PanelFeatureStatus Status { get; }
        public string Text { get; }
    }

    public sealed class PanelAlert
    {
        public PanelAlert(PanelAlertKind kind, PanelTone tone, string text)
        {
            Kind = kind;
            Tone = tone;
            Text = text;
        }

        public PanelAlertKind Kind { get; }
        public PanelTone Tone { get; }
        public string Text { get; }
    }

    public sealed class PanelDetail
    {
        public PanelDetail(string label, string value)
        {
            Label = label;
            Value = value;
        }

        public string Label { get; }
        public string Value { get; }
    }

    public sealed class RecoveryPanel
    {
        public const string Heading = "Recovery";
        public const string ConfirmationLabel = "I confirm: restore this save to its original location";
        public const string RestoreButtonLabel = "Restore save";
        public const string CheckAgainButtonLabel = "Check again";

        public RecoveryPanel(
            RecoveryPanelState state,
            PanelTone tone,
            IReadOnlyList<string> lines,
            bool showConfirmation,
            bool confirmed,
            bool restoreEnabled)
        {
            State = state;
            Tone = tone;
            Lines = lines;
            ShowConfirmation = showConfirmation;
            Confirmed = confirmed;
            RestoreEnabled = restoreEnabled;
        }

        public RecoveryPanelState State { get; }
        public PanelTone Tone { get; }
        public IReadOnlyList<string> Lines { get; }

        // The confirmation and restore action exist only for a validated, restorable recovery.
        public bool ShowConfirmation { get; }
        public bool Confirmed { get; }
        public bool RestoreEnabled { get; }
    }

    public sealed class TroubleshootingPanel
    {
        public const string RefreshButtonLabel = "Refresh recovery status";

        public TroubleshootingPanel(PanelToggle verboseDiagnostics, IReadOnlyList<PanelDetail> details)
        {
            VerboseDiagnostics = verboseDiagnostics;
            Details = details;
        }

        public PanelToggle VerboseDiagnostics { get; }
        public IReadOnlyList<PanelDetail> Details { get; }
    }

    public sealed class SettingsPanelModel
    {
        public SettingsPanelModel(
            IReadOnlyList<PanelToggle> settings,
            string explanation,
            IReadOnlyList<PanelStatusLine> status,
            string context,
            IReadOnlyList<PanelAlert> alerts,
            RecoveryPanel recovery,
            string troubleshootingButtonLabel,
            TroubleshootingPanel troubleshooting)
        {
            Settings = settings;
            Explanation = explanation;
            Status = status;
            Context = context;
            Alerts = alerts;
            Recovery = recovery;
            TroubleshootingButtonLabel = troubleshootingButtonLabel;
            Troubleshooting = troubleshooting;
        }

        public IReadOnlyList<PanelToggle> Settings { get; }
        public string Explanation { get; }
        public IReadOnlyList<PanelStatusLine> Status { get; }

        // One neutral line about the mod or current campaign; null when nothing applies.
        public string Context { get; }

        // Always visible, whether or not Troubleshooting is expanded.
        public IReadOnlyList<PanelAlert> Alerts { get; }

        // Null when no recovery needs attention.
        public RecoveryPanel Recovery { get; }

        public string TroubleshootingButtonLabel { get; }

        // Null while Troubleshooting is collapsed.
        public TroubleshootingPanel Troubleshooting { get; }
        public bool TroubleshootingExpanded => Troubleshooting != null;
    }
}
