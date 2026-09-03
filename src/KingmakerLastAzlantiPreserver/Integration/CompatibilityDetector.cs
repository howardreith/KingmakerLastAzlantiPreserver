using System;
using System.Collections.Generic;
using System.Reflection;
using Harmony12;

namespace KingmakerLastAzlantiPreserver.Integration
{
    public sealed class CompatibilityDetector
    {
        public string Detect(HarmonyInstance harmony, KingmakerContracts contracts)
        {
            List<string> warnings = new List<string>();
            Assembly[] assemblies = AppDomain.CurrentDomain.GetAssemblies();
            for (int index = 0; index < assemblies.Length; index++)
            {
                string name = assemblies[index].GetName().Name ?? string.Empty;
                if (name.IndexOf("FirstAzlanti", StringComparison.OrdinalIgnoreCase) >= 0 ||
                    name.IndexOf("First Azlanti", StringComparison.OrdinalIgnoreCase) >= 0 ||
                    HasFirstAzlantiType(assemblies[index]))
                {
                    warnings.Add("Original FirstAzlanti functionality is loaded (" + name + "). Disable it before testing.");
                }
            }

            AddForeignPatchWarnings(harmony, contracts.GameOverActivate, "game-over hook", warnings);
            AddForeignPatchWarnings(harmony, contracts.DeleteSave, "save-deletion hook", warnings);
            return string.Join(" ", warnings.ToArray());
        }

        private static bool HasFirstAzlantiType(Assembly assembly)
        {
            try
            {
                Type[] types = assembly.GetTypes();
                for (int index = 0; index < types.Length; index++)
                {
                    string fullName = types[index].FullName ?? string.Empty;
                    if (fullName.IndexOf("FirstAzlanti", StringComparison.OrdinalIgnoreCase) >= 0) return true;
                }

                return false;
            }
            catch (ReflectionTypeLoadException exception)
            {
                Type[] types = exception.Types;
                for (int index = 0; index < types.Length; index++)
                {
                    string fullName = types[index] == null ? string.Empty : (types[index].FullName ?? string.Empty);
                    if (fullName.IndexOf("FirstAzlanti", StringComparison.OrdinalIgnoreCase) >= 0) return true;
                }

                return false;
            }
            catch
            {
                return false;
            }
        }

        private static void AddForeignPatchWarnings(
            HarmonyInstance harmony,
            MethodBase target,
            string label,
            ICollection<string> warnings)
        {
            Harmony12.Patches patches = harmony.GetPatchInfo(target);
            if (patches == null) return;
            foreach (string owner in patches.Owners)
            {
                if (!string.Equals(owner, ProductMetadata.Id, StringComparison.Ordinal))
                {
                    warnings.Add("Another Harmony owner patches the " + label + ": " + owner + ". Compatibility is unqualified.");
                }
            }
        }
    }
}
