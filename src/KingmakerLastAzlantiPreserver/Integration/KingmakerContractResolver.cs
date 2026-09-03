using System;
using System.IO;
using System.Reflection;
using System.Security.Cryptography;
using Kingmaker.Controllers;
using Kingmaker.EntitySystem.Persistence;
using Kingmaker.GameModes;
using Kingmaker.UI.SettingsUI;

namespace KingmakerLastAzlantiPreserver.Integration
{
    public sealed class KingmakerContractResolver
    {
        private const BindingFlags InstanceFlags = BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance;

        public KingmakerContracts Resolve()
        {
            Assembly assembly = typeof(GameOverIronmanController).Assembly;
            string mvid = assembly.ManifestModule.ModuleVersionId.ToString("D");
            if (!string.Equals(mvid, ProductMetadata.SupportedAssemblyMvid, StringComparison.OrdinalIgnoreCase))
            {
                throw new InvalidOperationException(
                    "Unsupported Assembly-CSharp MVID " + mvid + "; expected " + ProductMetadata.SupportedAssemblyMvid + ".");
            }

            string assemblyPath = Path.GetFullPath(assembly.Location);
            string sha256 = ComputeSha256(assemblyPath);
            if (!string.Equals(sha256, ProductMetadata.SupportedAssemblySha256, StringComparison.OrdinalIgnoreCase))
            {
                throw new InvalidOperationException(
                    "Unsupported Assembly-CSharp SHA-256 " + sha256 + "; expected " + ProductMetadata.SupportedAssemblySha256 + ".");
            }

            MethodInfo activate = RequireMethod(
                typeof(GameOverIronmanController),
                "Activate",
                typeof(void),
                Type.EmptyTypes);
            MethodInfo deactivate = RequireMethod(
                typeof(GameOverIronmanController),
                "Deactivate",
                typeof(void),
                Type.EmptyTypes);
            MethodInfo gameModeOnActivate = RequireMethod(
                typeof(GameMode),
                "OnActivate",
                typeof(void),
                Type.EmptyTypes);
            MethodInfo controllerActivate = RequireMethod(
                typeof(IController),
                "Activate",
                typeof(void),
                Type.EmptyTypes);
            MethodInfo deleteSave = RequireMethod(
                typeof(SaveManager),
                "DeleteSave",
                typeof(void),
                new[] { typeof(SaveInfo) });
            MethodInfo getIronmanSave = RequireMethod(
                typeof(SaveManager),
                "GetIronmanSave",
                typeof(SaveInfo),
                Type.EmptyTypes);
            MethodInfo resetLoading = RequireMethod(
                typeof(LoadingProcess),
                "ResetManualLoadingScreen",
                typeof(void),
                Type.EmptyTypes);
            MethodInfo updateSaveList = RequireMethod(
                typeof(SaveManager),
                "UpdateSaveListIfNeeded",
                typeof(void),
                new[] { typeof(bool) });
            FieldInfo ironmanSaveField = typeof(SaveManager).GetField("m_IronmanSave", InstanceFlags);
            if (ironmanSaveField == null || ironmanSaveField.FieldType != typeof(SaveInfo))
            {
                throw new MissingFieldException(typeof(SaveManager).FullName, "m_IronmanSave : SaveInfo");
            }

            if ((int)SaveInfo.SaveType.IronMan != 5)
            {
                throw new InvalidOperationException("SaveInfo.SaveType.IronMan no longer has the observed value 5.");
            }

            PropertyInfo settingsInstance = typeof(SettingsRoot).GetProperty(
                "Instance",
                BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Static);
            FieldInfo onlyOneSave = typeof(SettingsRoot.SettingsListScreen).GetField(
                "OnlyOneSave",
                InstanceFlags);
            PropertyInfo currentValue = typeof(SettingsEntityBool).GetProperty(
                "CurrentValue",
                InstanceFlags);
            if (settingsInstance == null || settingsInstance.PropertyType != typeof(SettingsRoot.SettingsListScreen) ||
                onlyOneSave == null || onlyOneSave.FieldType != typeof(SettingsEntityBool) ||
                currentValue == null || currentValue.PropertyType != typeof(bool))
            {
                throw new MissingMemberException("SettingsRoot.Instance.OnlyOneSave.CurrentValue contract was not available.");
            }

            if (!ContainsCall(activate, getIronmanSave) || !ContainsCall(activate, deleteSave) || !ContainsCall(activate, resetLoading))
            {
                throw new InvalidOperationException(
                    "GameOverIronmanController.Activate no longer has the exact GetIronmanSave -> DeleteSave and ResetManualLoadingScreen relationship.");
            }

            MethodBody gameModeBody = gameModeOnActivate.GetMethodBody();
            if (gameModeBody == null || gameModeBody.ExceptionHandlingClauses.Count == 0 ||
                !ContainsCall(gameModeOnActivate, controllerActivate))
            {
                throw new InvalidOperationException(
                    "GameMode.OnActivate no longer catches controller activation failures around IController.Activate.");
            }

            return new KingmakerContracts(
                activate,
                deactivate,
                gameModeOnActivate,
                deleteSave,
                getIronmanSave,
                resetLoading,
                updateSaveList,
                ironmanSaveField,
                sha256,
                mvid);
        }

        private static MethodInfo RequireMethod(Type type, string name, Type returnType, Type[] parameterTypes)
        {
            MethodInfo method = type.GetMethod(name, InstanceFlags, null, parameterTypes, null);
            if (method == null || method.IsStatic || method.ReturnType != returnType)
            {
                throw new MissingMethodException(type.FullName, name);
            }

            return method;
        }

        private static bool ContainsCall(MethodInfo caller, MethodInfo target)
        {
            MethodBody body = caller.GetMethodBody();
            if (body == null) return false;
            byte[] bytes = body.GetILAsByteArray();
            byte[] token = BitConverter.GetBytes(target.MetadataToken);
            for (int offset = 0; offset <= bytes.Length - 5; offset++)
            {
                if ((bytes[offset] != 0x28 && bytes[offset] != 0x6f) ||
                    bytes[offset + 1] != token[0] || bytes[offset + 2] != token[1] ||
                    bytes[offset + 3] != token[2] || bytes[offset + 4] != token[3])
                {
                    continue;
                }

                return true;
            }

            return false;
        }

        private static string ComputeSha256(string path)
        {
            using (FileStream stream = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete))
            using (SHA256 hash = SHA256.Create())
            {
                return BitConverter.ToString(hash.ComputeHash(stream)).Replace("-", string.Empty).ToLowerInvariant();
            }
        }
    }
}
