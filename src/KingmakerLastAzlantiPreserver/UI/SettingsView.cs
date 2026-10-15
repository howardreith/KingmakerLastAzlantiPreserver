using System;
using KingmakerLastAzlantiPreserver.Integration;
using KingmakerLastAzlantiPreserver.Recovery;
using UnityEngine;
using UnityModManagerNet;

namespace KingmakerLastAzlantiPreserver.UI
{
    public sealed class SettingsView
    {
        private static readonly Color NoticeColor = new Color(1f, 0.82f, 0.35f);
        private static readonly Color ProblemColor = new Color(1f, 0.5f, 0.45f);
        private readonly SettingsPanel panel;
        private GUIStyle wrappedLabel;

        public SettingsView(
            Settings settings,
            RuntimeStatus status,
            Func<RecoveryDecision> getRecoveryDecision,
            Func<string, bool, RecoveryDecision> restore,
            Action settingsChanged)
        {
            panel = new SettingsPanel(settings, status, getRecoveryDecision, restore, settingsChanged);
        }

        public void Draw()
        {
            // State that changes the control layout is refreshed only on Layout so every pass of one
            // IMGUI event draws the same controls; user actions take effect from the next pass.
            Event current = Event.current;
            if (current == null || current.type == EventType.Layout) panel.RefreshRecoveryIfDue();
            SettingsPanelModel model = panel.Build();
            if (wrappedLabel == null) wrappedLabel = new GUIStyle(GUI.skin.label) { wordWrap = true };

            for (int index = 0; index < model.Settings.Count; index++) DrawToggle(model.Settings[index]);
            GUILayout.Label(model.Explanation, wrappedLabel);

            GUILayout.Space(6f);
            for (int index = 0; index < model.Status.Count; index++) GUILayout.Label(model.Status[index].Text, wrappedLabel);
            if (!string.IsNullOrEmpty(model.Context)) GUILayout.Label(model.Context, wrappedLabel);
            for (int index = 0; index < model.Alerts.Count; index++)
            {
                DrawLine(model.Alerts[index].Text, model.Alerts[index].Tone);
            }

            if (model.Recovery != null) DrawRecovery(model.Recovery);

            GUILayout.Space(6f);
            if (GUILayout.Button(model.TroubleshootingButtonLabel, GUILayout.ExpandWidth(false))) panel.ToggleTroubleshooting();
            if (model.Troubleshooting != null) DrawTroubleshooting(model.Troubleshooting);
        }

        private void DrawRecovery(RecoveryPanel recovery)
        {
            GUILayout.Space(6f);
            GUILayout.Label(RecoveryPanel.Heading, UnityModManager.UI.bold ?? GUI.skin.label);
            for (int index = 0; index < recovery.Lines.Count; index++)
            {
                DrawLine(recovery.Lines[index], index == 0 ? recovery.Tone : PanelTone.Normal);
            }

            if (recovery.ShowConfirmation)
            {
                bool confirmed = GUILayout.Toggle(recovery.Confirmed, RecoveryPanel.ConfirmationLabel);
                if (confirmed != recovery.Confirmed) panel.SetRecoveryConfirmed(confirmed);
            }

            GUILayout.BeginHorizontal();
            if (recovery.ShowConfirmation)
            {
                bool oldEnabled = GUI.enabled;
                GUI.enabled = oldEnabled && recovery.RestoreEnabled;
                if (GUILayout.Button(RecoveryPanel.RestoreButtonLabel, GUILayout.ExpandWidth(false))) panel.RestoreRecovery();
                GUI.enabled = oldEnabled;
            }

            if (GUILayout.Button(RecoveryPanel.CheckAgainButtonLabel, GUILayout.ExpandWidth(false))) panel.RefreshRecovery();
            GUILayout.FlexibleSpace();
            GUILayout.EndHorizontal();
        }

        private void DrawTroubleshooting(TroubleshootingPanel troubleshooting)
        {
            DrawToggle(troubleshooting.VerboseDiagnostics);
            for (int index = 0; index < troubleshooting.Details.Count; index++)
            {
                PanelDetail detail = troubleshooting.Details[index];
                GUILayout.Label(detail.Label + ": " + detail.Value, wrappedLabel);
            }

            if (GUILayout.Button(TroubleshootingPanel.RefreshButtonLabel, GUILayout.ExpandWidth(false))) panel.RefreshRecovery();
        }

        private void DrawToggle(PanelToggle toggle)
        {
            bool oldEnabled = GUI.enabled;
            GUI.enabled = oldEnabled && toggle.Enabled;
            bool value = GUILayout.Toggle(toggle.Value, toggle.Label);
            GUI.enabled = oldEnabled;
            if (value != toggle.Value) panel.SetSetting(toggle.Setting, value);
        }

        private void DrawLine(string text, PanelTone tone)
        {
            Color oldColor = GUI.contentColor;
            if (tone == PanelTone.Notice) GUI.contentColor = NoticeColor;
            else if (tone == PanelTone.Problem) GUI.contentColor = ProblemColor;
            GUILayout.Label(text, wrappedLabel);
            GUI.contentColor = oldColor;
        }
    }
}
