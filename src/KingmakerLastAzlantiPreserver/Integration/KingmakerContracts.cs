using System.Reflection;

namespace KingmakerLastAzlantiPreserver.Integration
{
    public sealed class KingmakerContracts
    {
        public KingmakerContracts(
            MethodInfo gameOverActivate,
            MethodInfo gameOverDeactivate,
            MethodInfo gameModeOnActivate,
            MethodInfo deleteSave,
            MethodInfo getIronmanSave,
            MethodInfo resetManualLoadingScreen,
            MethodInfo updateSaveList,
            FieldInfo ironmanSaveField,
            string assemblySha256,
            string assemblyMvid)
        {
            GameOverActivate = gameOverActivate;
            GameOverDeactivate = gameOverDeactivate;
            GameModeOnActivate = gameModeOnActivate;
            DeleteSave = deleteSave;
            GetIronmanSave = getIronmanSave;
            ResetManualLoadingScreen = resetManualLoadingScreen;
            UpdateSaveList = updateSaveList;
            IronmanSaveField = ironmanSaveField;
            AssemblySha256 = assemblySha256;
            AssemblyMvid = assemblyMvid;
        }

        public MethodInfo GameOverActivate { get; }
        public MethodInfo GameOverDeactivate { get; }
        public MethodInfo GameModeOnActivate { get; }
        public MethodInfo DeleteSave { get; }
        public MethodInfo GetIronmanSave { get; }
        public MethodInfo ResetManualLoadingScreen { get; }
        public MethodInfo UpdateSaveList { get; }
        public FieldInfo IronmanSaveField { get; }
        public string AssemblySha256 { get; }
        public string AssemblyMvid { get; }

        public string GameOverHookDisplay => FormatMethod(GameOverActivate);
        public string DeletionHookDisplay => FormatMethod(DeleteSave);

        private static string FormatMethod(MethodInfo method)
        {
            ParameterInfo[] parameters = method.GetParameters();
            string[] names = new string[parameters.Length];
            for (int index = 0; index < parameters.Length; index++)
            {
                names[index] = parameters[index].ParameterType.FullName;
            }

            return method.DeclaringType.FullName + "." + method.Name + "(" + string.Join(", ", names) + ")";
        }
    }
}
