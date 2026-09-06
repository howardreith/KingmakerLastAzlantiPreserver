using System;
using System.Collections.Generic;
using System.Reflection;

namespace KingmakerLastAzlantiPreserver.Integration
{
    public sealed class GameOverLoadContracts
    {
        public GameOverLoadContracts(
            MethodInfo legacyPreShow,
            MethodInfo legacyCanvasPreShow,
            FieldInfo legacyEndlessView,
            MethodInfo legacyLoadLastSave,
            MethodInfo legacyLoadGame,
            MethodInfo legacyRestartGame,
            MethodInfo legacyMainMenu,
            FieldInfo legacyLoadLastSaveButton,
            FieldInfo legacyLoadGameButton,
            PropertyInfo buttonInteractable,
            ConstructorInfo consoleMenuConstructor,
            MethodInfo consoleLoadLastPredicate,
            MethodInfo consoleLoadPredicate,
            MethodInfo consoleLoadLastSave,
            MethodInfo consoleLoad,
            MethodInfo consoleNewGame,
            MethodInfo consoleMainMenu,
            MethodInfo consoleDispose,
            FieldInfo consoleLoadLastSaveVm,
            FieldInfo consoleLoadVm,
            MethodInfo consoleEntityRefresh,
            MethodInfo gameDoStartMode,
            MethodInfo gameHandleGameModeChanged,
            MethodInfo baseGameOverOnModeStart,
            MethodInfo nativeLoadGame,
            MethodInfo deleteSave)
        {
            LegacyPreShow = legacyPreShow ?? throw new ArgumentNullException(nameof(legacyPreShow));
            LegacyCanvasPreShow = legacyCanvasPreShow ?? throw new ArgumentNullException(nameof(legacyCanvasPreShow));
            LegacyEndlessView = legacyEndlessView ?? throw new ArgumentNullException(nameof(legacyEndlessView));
            LegacyLoadLastSave = legacyLoadLastSave ?? throw new ArgumentNullException(nameof(legacyLoadLastSave));
            LegacyLoadGame = legacyLoadGame ?? throw new ArgumentNullException(nameof(legacyLoadGame));
            LegacyRestartGame = legacyRestartGame ?? throw new ArgumentNullException(nameof(legacyRestartGame));
            LegacyMainMenu = legacyMainMenu ?? throw new ArgumentNullException(nameof(legacyMainMenu));
            LegacyLoadLastSaveButton = legacyLoadLastSaveButton ?? throw new ArgumentNullException(nameof(legacyLoadLastSaveButton));
            LegacyLoadGameButton = legacyLoadGameButton ?? throw new ArgumentNullException(nameof(legacyLoadGameButton));
            ButtonInteractable = buttonInteractable ?? throw new ArgumentNullException(nameof(buttonInteractable));
            ConsoleMenuConstructor = consoleMenuConstructor ?? throw new ArgumentNullException(nameof(consoleMenuConstructor));
            ConsoleLoadLastPredicate = consoleLoadLastPredicate ?? throw new ArgumentNullException(nameof(consoleLoadLastPredicate));
            ConsoleLoadPredicate = consoleLoadPredicate ?? throw new ArgumentNullException(nameof(consoleLoadPredicate));
            ConsoleLoadLastSave = consoleLoadLastSave ?? throw new ArgumentNullException(nameof(consoleLoadLastSave));
            ConsoleLoad = consoleLoad ?? throw new ArgumentNullException(nameof(consoleLoad));
            ConsoleNewGame = consoleNewGame ?? throw new ArgumentNullException(nameof(consoleNewGame));
            ConsoleMainMenu = consoleMainMenu ?? throw new ArgumentNullException(nameof(consoleMainMenu));
            ConsoleDispose = consoleDispose ?? throw new ArgumentNullException(nameof(consoleDispose));
            ConsoleLoadLastSaveVm = consoleLoadLastSaveVm ?? throw new ArgumentNullException(nameof(consoleLoadLastSaveVm));
            ConsoleLoadVm = consoleLoadVm ?? throw new ArgumentNullException(nameof(consoleLoadVm));
            ConsoleEntityRefresh = consoleEntityRefresh ?? throw new ArgumentNullException(nameof(consoleEntityRefresh));
            GameDoStartMode = gameDoStartMode ?? throw new ArgumentNullException(nameof(gameDoStartMode));
            GameHandleGameModeChanged = gameHandleGameModeChanged ?? throw new ArgumentNullException(nameof(gameHandleGameModeChanged));
            BaseGameOverOnModeStart = baseGameOverOnModeStart ?? throw new ArgumentNullException(nameof(baseGameOverOnModeStart));
            NativeLoadGame = nativeLoadGame ?? throw new ArgumentNullException(nameof(nativeLoadGame));
            DeleteSave = deleteSave ?? throw new ArgumentNullException(nameof(deleteSave));
        }

        public MethodInfo LegacyPreShow { get; }
        public MethodInfo LegacyCanvasPreShow { get; }
        public FieldInfo LegacyEndlessView { get; }
        public MethodInfo LegacyLoadLastSave { get; }
        public MethodInfo LegacyLoadGame { get; }
        public MethodInfo LegacyRestartGame { get; }
        public MethodInfo LegacyMainMenu { get; }
        public FieldInfo LegacyLoadLastSaveButton { get; }
        public FieldInfo LegacyLoadGameButton { get; }
        public PropertyInfo ButtonInteractable { get; }
        public ConstructorInfo ConsoleMenuConstructor { get; }
        public MethodInfo ConsoleLoadLastPredicate { get; }
        public MethodInfo ConsoleLoadPredicate { get; }
        public MethodInfo ConsoleLoadLastSave { get; }
        public MethodInfo ConsoleLoad { get; }
        public MethodInfo ConsoleNewGame { get; }
        public MethodInfo ConsoleMainMenu { get; }
        public MethodInfo ConsoleDispose { get; }
        public FieldInfo ConsoleLoadLastSaveVm { get; }
        public FieldInfo ConsoleLoadVm { get; }
        public MethodInfo ConsoleEntityRefresh { get; }
        public MethodInfo GameDoStartMode { get; }
        public MethodInfo GameHandleGameModeChanged { get; }
        public MethodInfo BaseGameOverOnModeStart { get; }
        public MethodInfo NativeLoadGame { get; }
        public MethodInfo DeleteSave { get; }

        public string PrimaryPatchTargetDisplay => FormatMethod(LegacyCanvasPreShow);
        public string ControllerPatchTargetDisplay => FormatMethod(ConsoleMenuConstructor);

        public IReadOnlyList<MethodBase> PatchTargets => new MethodBase[]
        {
            LegacyCanvasPreShow,
            LegacyLoadLastSave,
            LegacyLoadGame,
            LegacyRestartGame,
            LegacyMainMenu,
            ConsoleMenuConstructor,
            ConsoleLoadLastPredicate,
            ConsoleLoadPredicate,
            ConsoleLoadLastSave,
            ConsoleLoad,
            ConsoleNewGame,
            ConsoleMainMenu,
            ConsoleDispose,
            NativeLoadGame,
            DeleteSave
        };

        public static string FormatMethod(MethodBase method)
        {
            ParameterInfo[] parameters = method.GetParameters();
            string[] names = new string[parameters.Length];
            for (int index = 0; index < parameters.Length; index++)
            {
                names[index] = parameters[index].ParameterType.FullName;
            }

            string methodName = method is ConstructorInfo ? ".ctor" : method.Name;
            return method.DeclaringType.FullName + "." + methodName + "(" + string.Join(", ", names) + ")";
        }
    }
}
