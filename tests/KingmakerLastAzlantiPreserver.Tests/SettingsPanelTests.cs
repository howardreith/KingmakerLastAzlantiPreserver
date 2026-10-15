using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Xml;
using System.Xml.Serialization;
using KingmakerLastAzlantiPreserver.Integration;
using KingmakerLastAzlantiPreserver.Preservation;
using KingmakerLastAzlantiPreserver.Recovery;
using KingmakerLastAzlantiPreserver.UI;

namespace KingmakerLastAzlantiPreserver.Tests
{
    internal static class SettingsPanelTests
    {
        private const string GameOverHook = "Kingmaker.Controllers.GameOverIronmanController.Activate()";
        private const string DeletionHook = "Kingmaker.EntitySystem.Persistence.SaveManager.DeleteSave(Kingmaker.EntitySystem.Persistence.SaveInfo)";
        private const string LoadHook = "Kingmaker.UI.GameOver.GameOverCanvas.PreShow()";
        private const string ControllerHook = "Kingmaker.UI.MVVM.EndlessGameOverMenuPartVm..ctor()";
        private const string RecoveryDirectory = @"D:\KingmakerData\LastAzlantiPreserver\Recovery";

        public static void HealthyMainMenuPanelIsCompactWithTroubleshootingCollapsed()
        {
            Harness harness = Harness.Healthy();
            SettingsPanelModel model = harness.Draw();

            AssertEx.True(
                model.Settings.Select(toggle => toggle.Label).SequenceEqual(new[]
                {
                    "Keep your Last Azlanti save after defeat",
                    "Allow loading from the game-over screen",
                    "Keep a hidden recovery backup"
                }),
                "The default panel must show exactly the three player-facing settings.");
            AssertEx.True(model.Settings.All(toggle => toggle.Value && toggle.Enabled));
            AssertEx.Equal("Last Azlanti's normal saving restrictions remain unchanged.", model.Explanation);
            AssertEx.True(model.Status.All(line => line.Status == PanelFeatureStatus.Ready));
            AssertEx.Equal(3, model.Status.Count);

            // At the main menu no recognized campaign is normal, not an alert.
            AssertEx.Equal(0, model.Alerts.Count);
            AssertEx.False(string.IsNullOrEmpty(model.Context));
            AssertEx.True(model.Recovery == null);
            AssertEx.False(model.TroubleshootingExpanded);
            AssertEx.Equal("Show troubleshooting", model.TroubleshootingButtonLabel);

            string visible = VisibleText(model);
            AssertNotVisible(visible, ReadMetadata("Name"), "duplicate name heading");
            AssertNotVisible(visible, ReadMetadata("Version"), "duplicate version heading");
            foreach (string technical in new[] { GameOverHook, DeletionHook, LoadHook, ControllerHook, RecoveryDirectory, "Verbose diagnostics", "Latest", "Harmony", "none" })
            {
                AssertNotVisible(visible, technical, "troubleshooting detail");
            }

            AssertEx.True(VisibleLines(model).Count <= 10, "The healthy default panel grew beyond ten rows.");
        }

        public static void RecognizedLastAzlantiCampaignIsReportedWithoutClaimingProtection()
        {
            Harness harness = Harness.Healthy();
            harness.Status.SetLastAzlantiRecognized(true);
            SettingsPanelModel recognized = harness.Draw();
            harness.Status.SetLastAzlantiRecognized(false);
            SettingsPanelModel idle = harness.Draw();

            AssertEx.False(string.Equals(recognized.Context, idle.Context, StringComparison.Ordinal));
            AssertEx.True(recognized.Context.IndexOf("recognized", StringComparison.OrdinalIgnoreCase) >= 0);
            AssertEx.Equal(0, recognized.Alerts.Count);
            AssertEx.True(recognized.Status.All(line => line.Status == PanelFeatureStatus.Ready));
            string visible = VisibleText(recognized);
            AssertNotVisible(visible, "protected", "per-save protection claim");
            AssertNotVisible(visible, "backed up", "per-save backup claim");
        }

        public static void DisabledPreservationIsReportedAsOffNotAsFailure()
        {
            Harness harness = Harness.Healthy();
            harness.Settings.PreserveLastAzlantiSaveOnGameOver = false;
            harness.Status.SetCoreProtection(RuntimeFeatureState.Disabled, true, GameOverHook, DeletionHook);
            harness.Status.SetGameOverLoadControls(RuntimeFeatureState.Disabled, true, LoadHook, ControllerHook, "Core preservation is disabled.");
            SettingsPanelModel model = harness.Draw();

            AssertEx.Equal(PanelFeatureStatus.Off, Status(model, PanelFeature.SaveProtection));
            AssertEx.Equal(PanelFeatureStatus.NeedsSaveProtection, Status(model, PanelFeature.GameOverLoading));
            AssertEx.Equal(PanelFeatureStatus.NeedsSaveProtection, Status(model, PanelFeature.RecoveryBackup));
            AssertEx.Equal(0, model.Alerts.Count, "A deliberately disabled setting is not a problem.");
            AssertEx.False(Toggle(model, PanelSetting.GameOverLoading).Enabled);
            AssertEx.True(Toggle(model, PanelSetting.PreserveSave).Enabled);

            harness.Panel.SetSetting(PanelSetting.GameOverLoading, false);
            AssertEx.True(harness.Settings.EnableGameOverLoadControls, "A disabled toggle must not change its setting.");
            AssertEx.Equal(0, harness.SettingsChangedCount);
        }

        public static void UnavailableCorePreservationIsAVisibleProblem()
        {
            Harness harness = Harness.Healthy();
            const string failure = "InvalidOperationException: Assembly-CSharp does not match the supported 2.1.7b contract.";
            harness.Status.SetCoreProtection(RuntimeFeatureState.Unavailable, false, "unresolved", "unresolved");
            harness.Status.SetGameOverLoadControls(RuntimeFeatureState.Unavailable, false, "unresolved", "unresolved", "Core preservation is unavailable: " + failure);
            harness.Status.SetError(failure);
            SettingsPanelModel model = harness.Draw();

            AssertEx.True(model.Status.All(line => line.Status == PanelFeatureStatus.Unavailable));
            AssertEx.Equal(1, model.Alerts.Count);
            AssertEx.Equal(PanelAlertKind.SaveProtectionUnavailable, model.Alerts[0].Kind);
            AssertEx.Equal(PanelTone.Problem, model.Alerts[0].Tone);
            AssertEx.False(model.TroubleshootingExpanded, "The problem must be visible while Troubleshooting is collapsed.");
            AssertEx.False(Toggle(model, PanelSetting.GameOverLoading).Enabled);
            AssertNotVisible(VisibleText(model), failure, "raw failure detail");

            harness.Panel.ToggleTroubleshooting();
            AssertEx.Equal(failure, Detail(harness.Draw(), "Latest error"));
        }

        public static void UnavailableGameOverLoadingDoesNotReportCoreFailure()
        {
            Harness harness = Harness.Healthy();
            harness.Status.SetGameOverLoadControls(
                RuntimeFeatureState.Unavailable,
                false,
                "unresolved",
                "unresolved",
                "MissingMethodException: EndlessGameOverView.PreShow()");
            SettingsPanelModel model = harness.Draw();

            AssertEx.Equal(PanelFeatureStatus.Ready, Status(model, PanelFeature.SaveProtection));
            AssertEx.Equal(PanelFeatureStatus.Unavailable, Status(model, PanelFeature.GameOverLoading));
            AssertEx.Equal(PanelFeatureStatus.Ready, Status(model, PanelFeature.RecoveryBackup));
            AssertEx.Equal(1, model.Alerts.Count);
            AssertEx.Equal(PanelAlertKind.GameOverLoadingUnavailable, model.Alerts[0].Kind);
            AssertEx.Equal(PanelTone.Notice, model.Alerts[0].Tone);
            AssertEx.True(model.Alerts[0].Text.IndexOf("Save protection is not affected", StringComparison.Ordinal) >= 0);
        }

        public static void OtherPatchOwnersShowCompactUnverifiedNotice()
        {
            Harness harness = Harness.Healthy();
            string detail =
                "Another Harmony owner patches the optional game-over loading target Kingmaker.Game.LoadGame(Kingmaker.EntitySystem.Persistence.SaveInfo): Example.OtherMod. Compatibility is unqualified. " +
                "Another Harmony owner patches the optional game-over loading target Kingmaker.EntitySystem.Persistence.SaveManager.DeleteSave(Kingmaker.EntitySystem.Persistence.SaveInfo): Example.ThirdMod. Compatibility is unqualified.";
            harness.Status.SetCompatibility(new CompatibilityReport(false, 0, 2, detail));
            SettingsPanelModel model = harness.Draw();

            AssertEx.Equal(1, model.Alerts.Count);
            PanelAlert notice = model.Alerts[0];
            AssertEx.Equal(PanelAlertKind.GameOverLoadingCompatibilityUnverified, notice.Kind);
            AssertEx.Equal(PanelTone.Notice, notice.Tone);
            AssertEx.True(notice.Text.IndexOf("game-over loading", StringComparison.OrdinalIgnoreCase) >= 0);
            AssertEx.True(notice.Text.IndexOf("unverified", StringComparison.OrdinalIgnoreCase) >= 0);
            AssertEx.True(notice.Text.Length < 100, "The default compatibility notice must stay compact.");
            foreach (string forbidden in new[] { "conflict", "incompatible", "Example.OtherMod", "LoadGame", "Harmony" })
            {
                AssertNotVisible(notice.Text, forbidden, "compatibility notice wording");
            }

            AssertEx.True(model.Status.All(line => line.Status == PanelFeatureStatus.Ready), "Detection alone does not change availability.");
            harness.Panel.ToggleTroubleshooting();
            AssertEx.Equal(detail, Detail(harness.Draw(), "Compatibility"), "The complete technical report must remain in Troubleshooting.");

            harness.Status.SetCompatibility(new CompatibilityReport(true, 1, 0, "Original FirstAzlanti functionality is loaded (FirstAzlanti). Disable it before testing."));
            SettingsPanelModel other = harness.Draw();
            AssertEx.True(other.Alerts.Any(alert => alert.Kind == PanelAlertKind.FirstAzlantiLoaded && alert.Tone == PanelTone.Problem));
            AssertEx.True(other.Alerts.Any(alert => alert.Kind == PanelAlertKind.SaveProtectionCompatibilityUnverified && alert.Tone == PanelTone.Notice));
            AssertEx.False(other.Alerts.Any(alert => alert.Kind == PanelAlertKind.GameOverLoadingCompatibilityUnverified));
        }

        public static void NoPendingRecoveryShowsNoRecoveryControls()
        {
            Harness harness = Harness.Healthy();
            SettingsPanelModel model = harness.Draw();
            AssertEx.True(model.Recovery == null);
            string visible = VisibleText(model);
            AssertNotVisible(visible, RecoveryPanel.ConfirmationLabel, "recovery confirmation");
            AssertNotVisible(visible, RecoveryPanel.RestoreButtonLabel, "restore action");
            AssertNotVisible(visible, "pending", "no-pending-marker report");
            AssertNotVisible(visible, TroubleshootingPanel.RefreshButtonLabel, "refresh control");

            harness.Panel.ToggleTroubleshooting();
            SettingsPanelModel expanded = harness.Draw();
            AssertEx.True(Detail(expanded, "Guarded recovery").IndexOf("No pending", StringComparison.Ordinal) >= 0);
            AssertEx.True(VisibleText(expanded).IndexOf(TroubleshootingPanel.RefreshButtonLabel, StringComparison.Ordinal) >= 0);

            harness.Decision = new RecoveryDecision(
                RecoveryDecisionKind.OriginalStillExists,
                "The recorded original save exists; recovery will not overwrite it.",
                new string('a', 64),
                @"D:\KingmakerData\Saved Games\IronMan_1.zks",
                false);
            harness.Panel.RefreshRecovery();
            AssertEx.True(harness.Draw().Recovery == null, "A recovery whose save still exists needs no attention.");
        }

        public static void PendingRecoveryRestoresOnlyAfterExplicitConfirmation()
        {
            using (RecoveryFixture fixture = new RecoveryFixture())
            {
                byte[] bytes = Enumerable.Range(0, 4096).Select(index => (byte)(index * 7)).ToArray();
                string source = fixture.CreatePendingRecoveryForMissingSave("IronMan_1.zks", bytes);
                Harness harness = Harness.Healthy(fixture.Service.GetLatestGuardedDecision, fixture.Service.TryGuardedRestore);
                SettingsPanelModel model = harness.Draw();

                AssertEx.False(model.TroubleshootingExpanded);
                AssertEx.True(model.Recovery != null, "A pending recovery must be visible with Troubleshooting collapsed.");
                AssertEx.Equal(RecoveryPanelState.Restorable, model.Recovery.State);
                AssertEx.True(model.Recovery.Lines[0].IndexOf("IronMan_1.zks", StringComparison.Ordinal) >= 0);
                AssertEx.True(model.Recovery.ShowConfirmation);
                AssertEx.False(model.Recovery.Confirmed);
                AssertEx.False(model.Recovery.RestoreEnabled);

                // Opening, redrawing, expanding, or an unconfirmed action never restores.
                harness.Panel.ToggleTroubleshooting();
                harness.Draw();
                harness.Panel.ToggleTroubleshooting();
                harness.Panel.RestoreRecovery();
                AssertEx.False(File.Exists(source));

                harness.Panel.SetRecoveryConfirmed(true);
                model = harness.Draw();
                AssertEx.True(model.Recovery.Confirmed);
                AssertEx.True(model.Recovery.RestoreEnabled);
                harness.Panel.RestoreRecovery();

                AssertEx.SequenceEqual(bytes, File.ReadAllBytes(source));
                model = harness.Draw();
                AssertEx.Equal(RecoveryPanelState.Restored, model.Recovery.State);
                AssertEx.False(model.Recovery.ShowConfirmation);
                AssertEx.True(harness.Status.Snapshot().LatestRecoveryResult.IndexOf("restored", StringComparison.OrdinalIgnoreCase) >= 0);

                harness.Advance(TimeSpan.FromMinutes(2));
                AssertEx.True(harness.Draw().Recovery == null, "A completed recovery leaves nothing pending.");
            }
        }

        public static void BlockedRecoveryIsShownWithoutRestoreControls()
        {
            using (RecoveryFixture fixture = new RecoveryFixture())
            {
                string source = fixture.CreatePendingRecoveryForMissingSave("IronMan_1.zks", new byte[] { 1, 2, 3, 4, 5, 6, 7, 8 });
                File.AppendAllText(fixture.Service.GetSnapshotPath(fixture.LastRecoveryId), "tampered");
                int restoreCalls = 0;
                Harness harness = Harness.Healthy(
                    fixture.Service.GetLatestGuardedDecision,
                    (id, confirmed) =>
                    {
                        restoreCalls++;
                        return fixture.Service.TryGuardedRestore(id, confirmed);
                    });
                SettingsPanelModel model = harness.Draw();

                AssertEx.True(model.Recovery != null, "A blocked recovery must not be hidden.");
                AssertEx.Equal(RecoveryPanelState.Blocked, model.Recovery.State);
                AssertEx.Equal(PanelTone.Problem, model.Recovery.Tone);
                AssertEx.False(model.Recovery.ShowConfirmation);
                AssertEx.False(model.Recovery.RestoreEnabled);
                AssertEx.True(model.Recovery.Lines.Any(line => line.IndexOf("SHA-256", StringComparison.Ordinal) >= 0), "The blocking reason must be shown.");
                AssertNotVisible(VisibleText(model), RecoveryPanel.ConfirmationLabel, "confirmation for a blocked recovery");

                harness.Panel.SetRecoveryConfirmed(true);
                harness.Panel.RestoreRecovery();
                AssertEx.Equal(0, restoreCalls);
                AssertEx.False(File.Exists(source));
            }

            Harness unreadable = Harness.Healthy(() => { throw new IOException("The recovery root is not readable."); }, null);
            SettingsPanelModel unreadableModel = unreadable.Draw();
            AssertEx.Equal(RecoveryPanelState.Blocked, unreadableModel.Recovery.State);
            AssertEx.True(unreadableModel.Recovery.Lines.Any(line => line.IndexOf("not readable", StringComparison.Ordinal) >= 0));
        }

        public static void RecoveryStatusIsCachedBetweenDraws()
        {
            Harness harness = Harness.Healthy();
            for (int index = 0; index < 50; index++) harness.Draw();
            harness.Panel.ToggleTroubleshooting();
            for (int index = 0; index < 50; index++) harness.Draw();
            AssertEx.Equal(1, harness.DecisionReads, "Drawing or expanding the panel must reuse the cached recovery status.");

            harness.Advance(TimeSpan.FromSeconds(61));
            harness.Draw();
            AssertEx.Equal(2, harness.DecisionReads);
            harness.Panel.RefreshRecovery();
            AssertEx.Equal(3, harness.DecisionReads);
        }

        public static void TroubleshootingExpansionRevealsDiagnosticsWithoutChangingSettings()
        {
            Harness harness = Harness.Healthy();
            harness.Status.SetCompatibility(new CompatibilityReport(false, 0, 0, string.Empty));
            string before = Serialize(harness.Settings);
            AssertEx.True(
                ElementNames(before).SequenceEqual(new[]
                {
                    "PreserveLastAzlantiSaveOnGameOver",
                    "EnableGameOverLoadControls",
                    "MaintainHiddenRecoverySnapshot",
                    "VerboseDiagnostics"
                }),
                "Settings.xml keys must remain unchanged: " + string.Join(", ", ElementNames(before)));

            harness.Panel.ToggleTroubleshooting();
            SettingsPanelModel expanded = harness.Draw();
            AssertEx.True(expanded.TroubleshootingExpanded);
            AssertEx.Equal("Hide troubleshooting", expanded.TroubleshootingButtonLabel);
            AssertEx.Equal(PanelSetting.VerboseDiagnostics, expanded.Troubleshooting.VerboseDiagnostics.Setting);
            AssertEx.False(expanded.Troubleshooting.VerboseDiagnostics.Value);
            string visible = VisibleText(expanded);
            foreach (string diagnostic in new[] { GameOverHook, DeletionHook, LoadHook, ControllerHook, RecoveryDirectory, "Latest recovery", "Latest interception", "Latest error", "Last Azlanti save recognized", "patches installed" })
            {
                AssertEx.True(visible.IndexOf(diagnostic, StringComparison.Ordinal) >= 0, "Troubleshooting is missing: " + diagnostic);
            }

            AssertEx.Equal(before, Serialize(harness.Settings), "Expanding Troubleshooting must not change saved settings.");
            AssertEx.Equal(3, expanded.Settings.Count, "Verbose diagnostics belongs to Troubleshooting only.");

            harness.Panel.SetSetting(PanelSetting.VerboseDiagnostics, true);
            Settings reloaded = Deserialize(Serialize(harness.Settings));
            AssertEx.True(reloaded.VerboseDiagnostics);
            AssertEx.True(reloaded.PreserveLastAzlantiSaveOnGameOver && reloaded.EnableGameOverLoadControls && reloaded.MaintainHiddenRecoverySnapshot);

            harness.Panel.ToggleTroubleshooting();
            AssertEx.False(harness.Draw().TroubleshootingExpanded);
        }

        public static void PlayerSettingsKeepTheirBackingFieldsAndDefaults()
        {
            Harness harness = Harness.Healthy();
            AssertEx.True(Toggle(harness.Draw(), PanelSetting.PreserveSave).Value);
            AssertEx.False(new Settings().VerboseDiagnostics);

            harness.Panel.SetSetting(PanelSetting.RecoveryBackup, false);
            AssertEx.False(harness.Settings.MaintainHiddenRecoverySnapshot);
            AssertEx.Equal(0, harness.SettingsChangedCount);

            harness.Panel.SetSetting(PanelSetting.GameOverLoading, false);
            AssertEx.False(harness.Settings.EnableGameOverLoadControls);
            AssertEx.Equal(1, harness.SettingsChangedCount);

            harness.Panel.SetSetting(PanelSetting.PreserveSave, false);
            AssertEx.False(harness.Settings.PreserveLastAzlantiSaveOnGameOver);
            AssertEx.Equal(2, harness.SettingsChangedCount);
            harness.Panel.SetSetting(PanelSetting.PreserveSave, false);
            AssertEx.Equal(2, harness.SettingsChangedCount, "An unchanged value must not trigger a feature refresh.");

            Settings reloaded = Deserialize(Serialize(harness.Settings));
            AssertEx.False(reloaded.PreserveLastAzlantiSaveOnGameOver);
            AssertEx.False(reloaded.EnableGameOverLoadControls);
            AssertEx.False(reloaded.MaintainHiddenRecoverySnapshot);
        }

        public static void DefeatProblemsAreVisibleUntilTheNextDefeat()
        {
            Harness harness = Harness.Healthy();
            harness.Status.SetError("Game-over save recognition failed: SettingsRoot.Instance.OnlyOneSave is false.");
            AssertEx.Equal(0, harness.Draw().Alerts.Count, "An ordinary campaign's game over is not a problem.");

            harness.Status.SetError("Recovery snapshot failed: IOException: There is not enough space on the disk.", RuntimeIssue.RecoveryBackupFailed);
            SettingsPanelModel backupFailed = harness.Draw();
            AssertEx.Equal(1, backupFailed.Alerts.Count);
            AssertEx.Equal(PanelAlertKind.RecoveryBackupFailed, backupFailed.Alerts[0].Kind);
            AssertEx.Equal(PanelTone.Notice, backupFailed.Alerts[0].Tone);
            AssertEx.Equal(PanelFeatureStatus.Ready, Status(backupFailed, PanelFeature.SaveProtection));

            harness.Status.SetError("Game-over save recognition failed: IronMan SaveInfo.FolderName is empty.", RuntimeIssue.SavePreservationFailed);
            SettingsPanelModel preservationFailed = harness.Draw();
            AssertEx.True(preservationFailed.Alerts.Any(alert => alert.Kind == PanelAlertKind.SavePreservationFailed && alert.Tone == PanelTone.Problem));

            harness.Status.ClearDefeatIssues();
            AssertEx.Equal(0, harness.Draw().Alerts.Count);
            harness.Panel.ToggleTroubleshooting();
            AssertEx.True(Detail(harness.Draw(), "Latest error").IndexOf("FolderName", StringComparison.Ordinal) >= 0);

            harness.Status.SetError("Cleanup failure during remove core Harmony ownership.", RuntimeIssue.CleanupFailed);
            harness.Status.ClearDefeatIssues();
            AssertEx.True(harness.Draw().Alerts.Any(alert => alert.Kind == PanelAlertKind.CleanupFailed), "Cleanup problems persist until restart.");
        }

        public static void TurnedOffModMakesNoFeatureClaims()
        {
            Harness harness = new Harness(null, null);
            SettingsPanelModel model = harness.Draw();
            AssertEx.Equal(0, model.Status.Count);
            AssertEx.Equal(0, model.Alerts.Count);
            AssertEx.True(model.Context.IndexOf("turned off", StringComparison.Ordinal) >= 0);
            AssertEx.Equal(3, model.Settings.Count);
        }

        private static PanelFeatureStatus Status(SettingsPanelModel model, PanelFeature feature)
        {
            return model.Status.Single(line => line.Feature == feature).Status;
        }

        private static PanelToggle Toggle(SettingsPanelModel model, PanelSetting setting)
        {
            return model.Settings.Single(toggle => toggle.Setting == setting);
        }

        private static string Detail(SettingsPanelModel model, string label)
        {
            AssertEx.True(model.Troubleshooting != null, "Troubleshooting is collapsed.");
            return model.Troubleshooting.Details.Single(detail => detail.Label == label).Value;
        }

        // Everything the renderer draws for this model, in order.
        private static List<string> VisibleLines(SettingsPanelModel model)
        {
            List<string> lines = new List<string>();
            lines.AddRange(model.Settings.Select(toggle => toggle.Label));
            lines.Add(model.Explanation);
            lines.AddRange(model.Status.Select(line => line.Text));
            if (!string.IsNullOrEmpty(model.Context)) lines.Add(model.Context);
            lines.AddRange(model.Alerts.Select(alert => alert.Text));
            if (model.Recovery != null)
            {
                lines.Add(RecoveryPanel.Heading);
                lines.AddRange(model.Recovery.Lines);
                if (model.Recovery.ShowConfirmation)
                {
                    lines.Add(RecoveryPanel.ConfirmationLabel);
                    lines.Add(RecoveryPanel.RestoreButtonLabel);
                }

                lines.Add(RecoveryPanel.CheckAgainButtonLabel);
            }

            lines.Add(model.TroubleshootingButtonLabel);
            if (model.Troubleshooting != null)
            {
                lines.Add(model.Troubleshooting.VerboseDiagnostics.Label);
                lines.AddRange(model.Troubleshooting.Details.Select(detail => detail.Label + ": " + detail.Value));
                lines.Add(TroubleshootingPanel.RefreshButtonLabel);
            }

            return lines;
        }

        private static string VisibleText(SettingsPanelModel model)
        {
            return string.Join("\n", VisibleLines(model).ToArray());
        }

        private static void AssertNotVisible(string visible, string text, string what)
        {
            AssertEx.False(
                visible.IndexOf(text, StringComparison.OrdinalIgnoreCase) >= 0,
                "Unexpected " + what + " is visible: " + text);
        }

        private static string ReadMetadata(string field)
        {
            Type metadata = typeof(Settings).Assembly.GetType("KingmakerLastAzlantiPreserver.ProductMetadata", true);
            return (string)metadata.GetField(field, BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Static).GetValue(null);
        }

        private static string Serialize(Settings settings)
        {
            XmlSerializer serializer = new XmlSerializer(typeof(Settings));
            using (StringWriter writer = new StringWriter())
            {
                serializer.Serialize(writer, settings);
                return writer.ToString();
            }
        }

        private static Settings Deserialize(string value)
        {
            XmlSerializer serializer = new XmlSerializer(typeof(Settings));
            using (StringReader reader = new StringReader(value))
            {
                return (Settings)serializer.Deserialize(reader);
            }
        }

        private static string[] ElementNames(string xml)
        {
            XmlDocument document = new XmlDocument();
            document.LoadXml(xml);
            return document.DocumentElement.ChildNodes.OfType<XmlElement>().Select(element => element.LocalName).ToArray();
        }

        private sealed class Harness
        {
            private DateTime now = new DateTime(2026, 10, 15, 12, 0, 0, DateTimeKind.Utc);

            public Harness(Func<RecoveryDecision> getRecoveryDecision, Func<string, bool, RecoveryDecision> restore)
            {
                Settings = new Settings();
                Status = new RuntimeStatus();
                Status.SetRecoveryDirectory(RecoveryDirectory);
                Decision = new RecoveryDecision(
                    RecoveryDecisionKind.NoPendingMarker,
                    "No pending game-over recovery marker exists.",
                    string.Empty,
                    string.Empty,
                    false);
                Func<RecoveryDecision> source = getRecoveryDecision ?? (() => Decision);
                Panel = new SettingsPanel(
                    Settings,
                    Status,
                    () =>
                    {
                        DecisionReads++;
                        return source();
                    },
                    restore ?? ((id, confirmed) => { throw new InvalidOperationException("Restore was not expected."); }),
                    () => SettingsChangedCount++,
                    () => now);
            }

            public Settings Settings { get; }
            public RuntimeStatus Status { get; }
            public SettingsPanel Panel { get; }
            public RecoveryDecision Decision { get; set; }
            public int DecisionReads { get; private set; }
            public int SettingsChangedCount { get; private set; }

            public static Harness Healthy(
                Func<RecoveryDecision> getRecoveryDecision = null,
                Func<string, bool, RecoveryDecision> restore = null)
            {
                Harness harness = new Harness(getRecoveryDecision, restore);
                harness.Status.SetModEnabled(true);
                harness.Status.SetCoreProtection(RuntimeFeatureState.Available, true, GameOverHook, DeletionHook);
                harness.Status.SetGameOverLoadControls(
                    RuntimeFeatureState.Available,
                    true,
                    LoadHook,
                    ControllerHook,
                    "Exact PC and controller UI patches are installed.");
                harness.Status.SetGameOverLoadEligibility("The current game mode is not GameOver.");
                return harness;
            }

            // One IMGUI layout pass: the timed refresh, then a model built from cached state.
            public SettingsPanelModel Draw()
            {
                Panel.RefreshRecoveryIfDue();
                return Panel.Build();
            }

            public void Advance(TimeSpan elapsed)
            {
                now = now.Add(elapsed);
            }
        }

        private sealed class RecoveryFixture : IDisposable
        {
            private readonly string root;

            public RecoveryFixture()
            {
                root = Path.Combine(Path.GetTempPath(), "KingmakerLastAzlantiPreserver.Tests", Guid.NewGuid().ToString("N"));
                SaveRoot = Path.Combine(root, "Saved Games");
                Directory.CreateDirectory(SaveRoot);
                Service = new RecoverySnapshotService(SaveRoot, Path.Combine(root, "LastAzlantiPreserver", "Recovery"));
            }

            public string SaveRoot { get; }
            public RecoverySnapshotService Service { get; }
            public string LastRecoveryId { get; private set; }

            // The interrupted-game-over shape: a validated snapshot and pending marker whose live save is gone.
            public string CreatePendingRecoveryForMissingSave(string fileName, byte[] bytes)
            {
                string path = Path.Combine(SaveRoot, fileName);
                File.WriteAllBytes(path, bytes);
                DateTime gameOver = DateTime.UtcNow;
                SnapshotResult snapshot = Service.CreateSnapshot(
                    new SaveIdentity(path, "disposable-campaign", "Disposable campaign", Path.GetFileNameWithoutExtension(path), true),
                    gameOver);
                AssertEx.True(snapshot.Succeeded, snapshot.Message);
                Service.CreatePendingMarker(snapshot.Metadata, Guid.NewGuid(), gameOver);
                LastRecoveryId = snapshot.Metadata.RecoveryId;
                File.Delete(path);
                return path;
            }

            public void Dispose()
            {
                string expected = Path.Combine(Path.GetTempPath(), "KingmakerLastAzlantiPreserver.Tests");
                if (Directory.Exists(root) && root.StartsWith(expected, StringComparison.OrdinalIgnoreCase))
                {
                    Directory.Delete(root, true);
                }
            }
        }
    }
}
