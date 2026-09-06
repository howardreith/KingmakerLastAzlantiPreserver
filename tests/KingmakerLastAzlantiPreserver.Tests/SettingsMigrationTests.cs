using System.IO;
using System.Xml.Serialization;

namespace KingmakerLastAzlantiPreserver.Tests
{
    internal static class SettingsMigrationTests
    {
        public static void MissingGameOverLoadSettingMigratesToEnabled()
        {
            Settings settings = new Settings();
            AssertEx.True(settings.EnableGameOverLoadControls);
            string serialized = Serialize(settings);
            const string element = "  <EnableGameOverLoadControls>true</EnableGameOverLoadControls>\r\n";
            string legacy = serialized.Replace(element, string.Empty);
            if (legacy == serialized)
            {
                legacy = serialized.Replace("  <EnableGameOverLoadControls>true</EnableGameOverLoadControls>\n", string.Empty);
            }

            AssertEx.False(legacy == serialized, "The migration fixture did not remove the new setting element.");
            Settings migrated = Deserialize(legacy);
            AssertEx.True(migrated.EnableGameOverLoadControls);
        }

        public static void ExplicitlySavedFalseGameOverLoadSettingIsPreserved()
        {
            Settings settings = new Settings { EnableGameOverLoadControls = false };
            Settings loaded = Deserialize(Serialize(settings));
            AssertEx.False(loaded.EnableGameOverLoadControls);
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
    }
}
