using System;
using System.Reflection;

namespace KingmakerLastAzlantiPreserver.Tests
{
    internal static class ProductIdentityTests
    {
        public static void StableModIdentifiersSurviveBranding()
        {
            Assembly assembly = typeof(Settings).Assembly;
            AssertEx.Equal("KingmakerLastAzlantiPreserver", assembly.GetName().Name);
            AssertEx.Equal("KingmakerLastAzlantiPreserver", ReadMetadata("Id"));
            AssertEx.Equal("KingmakerLastAzlantiPreserver.Core", ReadMetadata("CoreHarmonyId"));
            AssertEx.Equal("KingmakerLastAzlantiPreserver.GameOverLoadControls", ReadMetadata("GameOverLoadHarmonyId"));

            Type main = assembly.GetType("KingmakerLastAzlantiPreserver.Main", true);
            MethodInfo load = main.GetMethod("Load", BindingFlags.Public | BindingFlags.Static);
            AssertEx.True(load != null, "The UMM EntryMethod KingmakerLastAzlantiPreserver.Main.Load is missing.");
            AssertEx.Equal(typeof(bool), load.ReturnType);
            ParameterInfo[] parameters = load.GetParameters();
            AssertEx.Equal(1, parameters.Length);
            AssertEx.Equal("UnityModManagerNet.UnityModManager+ModEntry", parameters[0].ParameterType.FullName);
        }

        public static void DisplayedNameAndVersionMatchBrandedCandidate()
        {
            AssertEx.Equal("Mr. Bard's Second to Last Azlanti", ReadMetadata("Name"));
            AssertEx.Equal("0.1.2", ReadMetadata("Version"));
            AssertEx.Equal(new Version(0, 1, 2, 0), typeof(Settings).Assembly.GetName().Version);
        }

        private static string ReadMetadata(string field)
        {
            Type metadata = typeof(Settings).Assembly.GetType("KingmakerLastAzlantiPreserver.ProductMetadata", true);
            FieldInfo info = metadata.GetField(field, BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Static);
            AssertEx.True(info != null, "ProductMetadata." + field + " is missing.");
            return (string)info.GetValue(null);
        }
    }
}
