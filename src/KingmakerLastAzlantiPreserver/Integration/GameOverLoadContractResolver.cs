using System;
using System.Collections.Generic;
using System.Reflection;
using System.Reflection.Emit;
using Kingmaker;
using Kingmaker.Blueprints.Area;
using Kingmaker.Blueprints.Root;
using Kingmaker.Controllers;
using Kingmaker.EntitySystem.Persistence;
using Kingmaker.GameModes;
using Kingmaker.UI.SettingsUI;

namespace KingmakerLastAzlantiPreserver.Integration
{
    public sealed class GameOverLoadContractResolver
    {
        private const BindingFlags InstanceFlags = BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance;
        private static readonly OpCode[] OneByteOpCodes = new OpCode[0x100];
        private static readonly OpCode[] TwoByteOpCodes = new OpCode[0x100];

        static GameOverLoadContractResolver()
        {
            FieldInfo[] fields = typeof(OpCodes).GetFields(BindingFlags.Public | BindingFlags.Static);
            for (int index = 0; index < fields.Length; index++)
            {
                if (fields[index].FieldType != typeof(OpCode)) continue;
                OpCode opCode = (OpCode)fields[index].GetValue(null);
                ushort value = unchecked((ushort)opCode.Value);
                if (value < 0x100)
                {
                    OneByteOpCodes[value] = opCode;
                }
                else if ((value & 0xff00) == 0xfe00)
                {
                    TwoByteOpCodes[value & 0xff] = opCode;
                }
            }
        }

        public GameOverLoadContracts Resolve(KingmakerContracts coreContracts)
        {
            if (coreContracts == null) throw new ArgumentNullException(nameof(coreContracts));
            Assembly assembly = typeof(GameOverIronmanController).Assembly;
            if (!string.Equals(assembly.ManifestModule.ModuleVersionId.ToString("D"), coreContracts.AssemblyMvid, StringComparison.OrdinalIgnoreCase))
            {
                throw new InvalidOperationException("The optional UI contract assembly does not match the verified core assembly.");
            }

            Type legacyType = RequireType(assembly, "Kingmaker.UI.EndlessGameOver.EndlessGameOverView", 0x02000855);
            MethodInfo legacyPreShow = RequireMethod(legacyType, "PreShow", typeof(void), Type.EmptyTypes, 0x060040AA);
            MethodInfo legacyLoadLast = RequireMethod(legacyType, "OnLoadLastSave", typeof(void), Type.EmptyTypes, 0x060040AD);
            MethodInfo legacyLoadGame = RequireMethod(legacyType, "OnLoadGame", typeof(void), Type.EmptyTypes, 0x060040AE);
            MethodInfo legacyRestart = RequireMethod(legacyType, "OnRestartGame", typeof(void), Type.EmptyTypes, 0x060040AC);
            MethodInfo legacyMainMenu = RequireMethod(legacyType, "OnMainMenu", typeof(void), Type.EmptyTypes, 0x060040AF);
            FieldInfo legacyLoadLastButton = RequireField(legacyType, "m_LoadLastSaveButton", "UnityEngine.UI.Button", 0x04002BE5);
            FieldInfo legacyLoadGameButton = RequireField(legacyType, "m_LoadGameButton", "UnityEngine.UI.Button", 0x04002BE6);
            PropertyInfo interactable = RequireProperty(legacyLoadLastButton.FieldType, "interactable", typeof(bool), true);

            Type consoleType = RequireType(assembly, "Kingmaker.UI._ConsoleUI.Endless.GameOver.EndlessGameOverMenuPartVm", 0x02000B72);
            ConstructorInfo consoleConstructor = RequireConstructor(consoleType, Type.EmptyTypes, 0x0600600B);
            MethodInfo consoleLoadLast = RequireMethod(consoleType, "OnButtonLoadLastSave", typeof(void), Type.EmptyTypes, 0x0600600D);
            MethodInfo consoleLoad = RequireMethod(consoleType, "OnButtonLoad", typeof(void), Type.EmptyTypes, 0x0600600E);
            MethodInfo consoleNewGame = RequireMethod(consoleType, "OnButtonNewGame", typeof(void), Type.EmptyTypes, 0x0600600C);
            MethodInfo consoleMainMenu = RequireMethod(consoleType, "OnButtonMainMenu", typeof(void), Type.EmptyTypes, 0x0600600F);
            MethodInfo consoleDispose = RequireMethod(consoleType, "DisposeImplementation", typeof(void), Type.EmptyTypes, 0x06006010);
            FieldInfo consoleLoadLastVm = RequireField(consoleType, "LoadLastSaveVm", "Kingmaker.UI._ConsoleUI.ContextMenu.ContextMenuEntityVM", 0x04003FE7);
            FieldInfo consoleLoadVm = RequireField(consoleType, "LoadVm", "Kingmaker.UI._ConsoleUI.ContextMenu.ContextMenuEntityVM", 0x04003FE8);
            MethodInfo consoleRefresh = RequireMethod(consoleLoadLastVm.FieldType, "Refresh", typeof(void), Type.EmptyTypes, null);

            Type consoleClosure = RequireType(
                assembly,
                "Kingmaker.UI._ConsoleUI.Endless.GameOver.EndlessGameOverMenuPartVm+<>c__DisplayClass4_0",
                0x02001ED2);
            FieldInfo canLoad = RequireField(consoleClosure, "canLoad", typeof(bool).FullName, 0x0400862D);
            MethodInfo consoleLoadLastPredicate = RequireMethod(consoleClosure, "<.ctor>b__2", typeof(bool), Type.EmptyTypes, 0x0600B7E3);
            MethodInfo consoleLoadPredicate = RequireMethod(consoleClosure, "<.ctor>b__4", typeof(bool), Type.EmptyTypes, 0x0600B7E4);

            MethodInfo getLatest = RequireMethod(typeof(SaveManager), "GetLatestSave", typeof(SaveInfo), Type.EmptyTypes, null);
            MethodInfo getLatestDlc = RequireMethod(typeof(SaveManager), "GetLatestSave", typeof(SaveInfo), new[] { typeof(DlcType) }, null);
            MethodInfo nativeLoad = RequireMethod(typeof(Game), "LoadGame", typeof(void), new[] { typeof(SaveInfo) }, null);
            if (nativeLoad.GetParameters()[0].Name != "saveInfo")
            {
                throw new InvalidOperationException("Game.LoadGame(SaveInfo) parameter binding changed.");
            }

            PropertyInfo settingsInstance = RequireProperty(typeof(SettingsRoot), "Instance", typeof(SettingsRoot.SettingsListScreen), false);
            FieldInfo onlyOneSave = RequireField(typeof(SettingsRoot.SettingsListScreen), "OnlyOneSave", typeof(SettingsEntityBool).FullName, null);
            PropertyInfo currentValue = RequireProperty(typeof(SettingsEntityBool), "CurrentValue", typeof(bool), false);
            MethodInfo setInteractable = interactable.GetSetMethod(true);
            RequireReference(legacyPreShow, settingsInstance.GetGetMethod(true), "SettingsRoot.Instance");
            RequireReference(legacyPreShow, onlyOneSave, "OnlyOneSave");
            RequireReference(legacyPreShow, currentValue.GetGetMethod(true), "OnlyOneSave.CurrentValue");
            RequireReference(legacyPreShow, legacyLoadLastButton, "m_LoadLastSaveButton");
            RequireReference(legacyPreShow, legacyLoadGameButton, "m_LoadGameButton");
            RequireReference(legacyPreShow, setInteractable, "Button.interactable setter");
            RequireReference(legacyPreShow, getLatestDlc, "GetLatestSave(DlcType)");
            RequireReference(legacyLoadLast, getLatestDlc, "native endless latest-save selection");
            RequireReference(legacyLoadLast, nativeLoad, "Game.LoadGame(SaveInfo)");
            RejectReference(legacyLoadLast, currentValue.GetGetMethod(true), "legacy load-last callback gained an Only One Save guard");
            RejectReference(legacyLoadGame, currentValue.GetGetMethod(true), "legacy load-window callback gained an Only One Save guard");

            Type legacyLambdaType = RequireType(assembly, "Kingmaker.UI.EndlessGameOver.EndlessGameOverView+<>c", 0x02001CA7);
            Type legacyHandler = RequireType(assembly, "Kingmaker.PubSubSystem.ISaveLoadWindowUIHandler", null);
            Type legacyScreenType = RequireType(assembly, "Kingmaker.UI.SaveLoadWindow.SaveLoadWindow+ScreenType", null);
            MethodInfo legacyOpenLambda = RequireMethod(legacyLambdaType, "<OnLoadGame>b__18_0", typeof(void), new[] { legacyHandler }, 0x0600B0E6);
            MethodInfo legacyOpen = RequireMethod(legacyHandler, "HandleOpenSaveLoadWindow", typeof(void), new[] { legacyScreenType }, null);
            RequireReference(legacyLoadGame, legacyOpenLambda, "legacy load-window callback delegate");
            RequireReference(legacyOpenLambda, legacyOpen, "native legacy load-window handler");

            RequireReference(consoleConstructor, onlyOneSave, "console OnlyOneSave field");
            RequireReference(consoleConstructor, currentValue.GetGetMethod(true), "console OnlyOneSave.CurrentValue");
            RequireReference(consoleConstructor, canLoad, "console canLoad closure");
            RequireReference(consoleConstructor, consoleLoadLastVm, "console LoadLastSaveVm");
            RequireReference(consoleConstructor, consoleLoadVm, "console LoadVm");
            RequireReference(consoleLoadLastPredicate, canLoad, "console load-last canLoad predicate");
            RequireReference(consoleLoadLastPredicate, getLatestDlc, "console load-last visible eligibility selection");
            RequireReference(consoleLoadPredicate, canLoad, "console load-window canLoad predicate");
            RequireReference(consoleLoadLast, getLatest, "console native latest-save selection");
            RequireReference(consoleLoadLast, nativeLoad, "console Game.LoadGame(SaveInfo)");
            RejectReference(consoleLoadLast, currentValue.GetGetMethod(true), "console load-last callback gained an Only One Save guard");
            RejectReference(consoleLoad, currentValue.GetGetMethod(true), "console load-window callback gained an Only One Save guard");

            Type consoleLambdaType = RequireType(assembly, "Kingmaker.UI._ConsoleUI.Endless.GameOver.EndlessGameOverMenuPartVm+<>c", 0x02001ED3);
            Type consoleHandler = RequireType(assembly, "Kingmaker.UI._ConsoleUI.SaveLoadManager.ISaveLoadManagerUIHandler", null);
            Type consoleMode = RequireType(assembly, "Kingmaker.UI._ConsoleUI.SaveLoadManager.ViewModel.SaveLoadManagerMode", null);
            MethodInfo consoleOpenLambda = RequireMethod(consoleLambdaType, "<OnButtonLoad>b__7_0", typeof(void), new[] { consoleHandler }, 0x0600B7E7);
            MethodInfo consoleOpen = RequireMethod(consoleHandler, "HandleOpen", typeof(void), new[] { consoleMode, typeof(bool) }, null);
            RequireReference(consoleLoad, consoleOpenLambda, "console load-window callback delegate");
            RequireReference(consoleOpenLambda, consoleOpen, "native console load-window handler");

            Type gameOverCanvas = RequireType(assembly, "Kingmaker.UI.Canvases.GameOverCanvas", 0x020008A1);
            MethodInfo canvasPreShow = RequireMethod(gameOverCanvas, "PreShow", typeof(void), Type.EmptyTypes, 0x060043FE);
            PropertyInfo isEndless = RequireProperty(gameOverCanvas, "IsEndless", typeof(bool), false);
            FieldInfo endlessView = RequireField(
                gameOverCanvas,
                "m_EndlessGameOverView",
                legacyType.FullName,
                0x04002D6A);
            FieldInfo startPreset = RequireField(typeof(Player), "StartPreset", typeof(BlueprintAreaPreset).FullName, null);
            FieldInfo dlcCampaign = RequireField(typeof(BlueprintAreaPreset), "DlcCampaign", typeof(DlcType).FullName, null);
            RequireReference(canvasPreShow, isEndless.GetGetMethod(true), "GameOverCanvas IsEndless dispatch predicate");
            RequireReference(canvasPreShow, endlessView, "GameOverCanvas exact endless-view field");
            RequireReference(canvasPreShow, legacyPreShow, "GameOverCanvas endless PreShow dispatch");
            RequireReference(isEndless.GetGetMethod(true), startPreset, "GameOverCanvas current StartPreset");
            RequireReference(isEndless.GetGetMethod(true), dlcCampaign, "GameOverCanvas StartPreset.DlcCampaign");

            Type legacySaveLoadWindow = RequireType(assembly, "Kingmaker.UI.SaveLoadWindow.SaveLoadWindow", null);
            MethodInfo hardcodedLoad = RequireMethod(legacySaveLoadWindow, "HandleHardcodeMainMenuSaveLoad", typeof(void), new[] { typeof(SaveInfo) }, null);
            RequireReference(hardcodedLoad, nativeLoad, "legacy game-over save-window load");

            Type commonLoadService = RequireType(assembly, "Kingmaker.UI._ConsoleUI.LoadService.CommonUiLoadService", null);
            Type commonLoadClosure = RequireType(assembly, "Kingmaker.UI._ConsoleUI.LoadService.CommonUiLoadService+<>c__DisplayClass2_0", null);
            MethodInfo commonLoad = RequireMethod(commonLoadService, "Load", typeof(void), new[] { typeof(SaveInfo) }, null);
            MethodInfo commonLoadAction = RequireMethod(commonLoadClosure, "<Load>b__0", typeof(void), Type.EmptyTypes, 0x0600B621);
            RequireReference(commonLoad, commonLoadAction, "console native load action");
            RequireReference(commonLoadAction, nativeLoad, "console save-window Game.LoadGame(SaveInfo)");

            MethodInfo doStartMode = RequireMethod(
                typeof(Game),
                "DoStartMode",
                typeof(void),
                new[] { typeof(GameModeType) },
                0x06000CBF);
            MethodInfo handleModeChanged = RequireMethod(
                typeof(Game),
                "HandleGameModeChanged",
                typeof(void),
                new[] { typeof(GameModeType), typeof(GameModeType) },
                0x06000CC3);
            FieldInfo gameModes = RequireField(
                typeof(Game),
                "m_GameModes",
                typeof(Stack<GameMode>).FullName,
                0x040006AD);
            MethodInfo createMode = RequireMethod(
                typeof(GameModesFactory),
                "Create",
                typeof(GameMode),
                new[] { typeof(GameModeType) },
                0x06007E07);
            MethodInfo pushMode = RequireMethod(
                gameModes.FieldType,
                "Push",
                typeof(void),
                new[] { typeof(GameMode) },
                null);
            MethodInfo onStart = RequireMethod(typeof(GameMode), "OnStart", typeof(void), Type.EmptyTypes, 0x06007E04);
            RequireOrderedReferences(
                doStartMode,
                new MemberInfo[] { createMode, pushMode, onStart, coreContracts.GameModeOnActivate, handleModeChanged },
                "new mode creation/push -> OnStart -> OnActivate -> game-mode-changed notification");

            Type gameModeHandler = RequireType(assembly, "Kingmaker.PubSubSystem.IGameModeHandler", null);
            MethodInfo onGameModeStart = RequireMethod(
                gameModeHandler,
                "OnGameModeStart",
                typeof(void),
                new[] { typeof(GameModeType) },
                null);
            Type modeChangedClosure = RequireType(assembly, "Kingmaker.Game+<>c__DisplayClass152_0", 0x02001811);
            MethodInfo startModeEvent = RequireMethod(
                modeChangedClosure,
                "<HandleGameModeChanged>b__2",
                typeof(void),
                new[] { gameModeHandler },
                0x0600A2FF);
            RequireReference(handleModeChanged, startModeEvent, "game-mode start EventBus callback");
            RequireReference(startModeEvent, onGameModeStart, "IGameModeHandler.OnGameModeStart notification");

            Type baseGameOverCanvas = RequireType(assembly, "Kingmaker.UI.Canvases.BaseGameOverCanvas", 0x020008A0);
            MethodInfo baseOnModeStart = RequireMethod(
                baseGameOverCanvas,
                "OnGameModeStart",
                typeof(void),
                new[] { typeof(GameModeType) },
                0x060043F2);
            MethodInfo basePreShow = RequireMethod(baseGameOverCanvas, "PreShow", typeof(void), Type.EmptyTypes, 0x060043F4);
            RequireReference(baseOnModeStart, basePreShow, "GameOver-mode canvas PreShow dispatch");

            return new GameOverLoadContracts(
                legacyPreShow,
                canvasPreShow,
                endlessView,
                legacyLoadLast,
                legacyLoadGame,
                legacyRestart,
                legacyMainMenu,
                legacyLoadLastButton,
                legacyLoadGameButton,
                interactable,
                consoleConstructor,
                consoleLoadLastPredicate,
                consoleLoadPredicate,
                consoleLoadLast,
                consoleLoad,
                consoleNewGame,
                consoleMainMenu,
                consoleDispose,
                consoleLoadLastVm,
                consoleLoadVm,
                consoleRefresh,
                doStartMode,
                handleModeChanged,
                baseOnModeStart,
                nativeLoad,
                coreContracts.DeleteSave);
        }

        private static Type RequireType(Assembly assembly, string name, int? token)
        {
            Type type = assembly.GetType(name, false);
            if (type == null) throw new TypeLoadException("Required optional UI type missing: " + name);
            RequireToken(type, token);
            return type;
        }

        private static MethodInfo RequireMethod(Type type, string name, Type returnType, Type[] parameters, int? token)
        {
            MethodInfo method = type.GetMethod(name, InstanceFlags | BindingFlags.Static, null, parameters, null);
            if (method == null || method.ReturnType != returnType)
            {
                throw new MissingMethodException(type.FullName, name);
            }

            RequireToken(method, token);
            return method;
        }

        private static ConstructorInfo RequireConstructor(Type type, Type[] parameters, int? token)
        {
            ConstructorInfo constructor = type.GetConstructor(InstanceFlags, null, parameters, null);
            if (constructor == null) throw new MissingMethodException(type.FullName, ".ctor");
            RequireToken(constructor, token);
            return constructor;
        }

        private static FieldInfo RequireField(Type type, string name, string fieldTypeName, int? token)
        {
            FieldInfo field = type.GetField(name, InstanceFlags | BindingFlags.Static);
            if (field == null || !string.Equals(field.FieldType.FullName, fieldTypeName, StringComparison.Ordinal))
            {
                throw new MissingFieldException(type.FullName, name + " : " + fieldTypeName);
            }

            RequireToken(field, token);
            return field;
        }

        private static PropertyInfo RequireProperty(Type type, string name, Type propertyType, bool requireSetter)
        {
            PropertyInfo property = type.GetProperty(name, InstanceFlags | BindingFlags.Static);
            if (property == null || property.PropertyType != propertyType || property.GetGetMethod(true) == null ||
                (requireSetter && property.GetSetMethod(true) == null))
            {
                throw new MissingMemberException(type.FullName, name);
            }

            return property;
        }

        private static void RequireToken(MemberInfo member, int? expected)
        {
            if (expected.HasValue && member.MetadataToken != expected.Value)
            {
                string display = member.DeclaringType != null
                    ? member.DeclaringType.FullName + "." + member.Name
                    : (member as Type)?.FullName ?? member.Name;
                throw new InvalidOperationException(display +
                    " metadata token changed from 0x" + expected.Value.ToString("X8") + ".");
            }
        }

        private static void RequireReference(MethodBase caller, MemberInfo target, string relationship)
        {
            if (!ContainsReference(caller, target))
            {
                throw new InvalidOperationException("Optional UI contract lost the " + relationship + " IL relationship.");
            }
        }

        private static void RejectReference(MethodBase caller, MemberInfo target, string relationship)
        {
            if (ContainsReference(caller, target))
            {
                throw new InvalidOperationException("Optional UI contract changed: " + relationship + ".");
            }
        }

        private static bool ContainsReference(MethodBase caller, MemberInfo target)
        {
            return FindReferenceOffset(caller, target) >= 0;
        }

        private static void RequireOrderedReferences(
            MethodBase caller,
            MemberInfo[] targets,
            string relationship)
        {
            int previousOffset = -1;
            for (int index = 0; index < targets.Length; index++)
            {
                int offset = FindReferenceOffset(caller, targets[index]);
                if (offset < 0 || offset <= previousOffset)
                {
                    throw new InvalidOperationException("Optional UI contract lost the ordered " + relationship + " IL relationship.");
                }

                previousOffset = offset;
            }
        }

        private static int FindReferenceOffset(MethodBase caller, MemberInfo target)
        {
            MethodBody body = caller.GetMethodBody();
            if (body == null) return -1;
            byte[] bytes = body.GetILAsByteArray();
            Type[] typeArguments = caller.DeclaringType != null && caller.DeclaringType.IsGenericType
                ? caller.DeclaringType.GetGenericArguments()
                : null;
            Type[] methodArguments = caller.IsGenericMethod ? caller.GetGenericArguments() : null;
            int offset = 0;
            while (offset < bytes.Length)
            {
                int instructionOffset = offset;
                OpCode opCode;
                if (!TryReadOpCode(bytes, ref offset, out opCode))
                {
                    throw new InvalidOperationException("Invalid IL opcode in " + caller.DeclaringType.FullName + "." + caller.Name + ".");
                }

                int operandOffset = offset;
                int operandSize = GetOperandSize(opCode.OperandType, bytes, operandOffset);
                if (operandSize == int.MaxValue || operandSize > bytes.Length - operandOffset)
                {
                    throw new InvalidOperationException("Truncated IL operand in " + caller.DeclaringType.FullName + "." + caller.Name + ".");
                }

                if (IsMemberTokenOperand(opCode.OperandType))
                {
                    int token = BitConverter.ToInt32(bytes, operandOffset);
                    try
                    {
                        MemberInfo resolved = caller.Module.ResolveMember(token, typeArguments, methodArguments);
                        if (MembersMatch(resolved, target)) return instructionOffset;
                    }
                    catch (ArgumentException)
                    {
                    }
                    catch (BadImageFormatException)
                    {
                    }
                }

                offset += operandSize;
            }

            return -1;
        }

        private static bool TryReadOpCode(byte[] bytes, ref int offset, out OpCode opCode)
        {
            byte first = bytes[offset++];
            if (first != 0xfe)
            {
                opCode = OneByteOpCodes[first];
                return opCode.Size == 1;
            }

            if (offset >= bytes.Length)
            {
                opCode = default(OpCode);
                return false;
            }

            opCode = TwoByteOpCodes[bytes[offset++]];
            return opCode.Size == 2;
        }

        private static int GetOperandSize(OperandType operandType, byte[] bytes, int operandOffset)
        {
            switch (operandType)
            {
                case OperandType.InlineNone:
                    return 0;
                case OperandType.ShortInlineBrTarget:
                case OperandType.ShortInlineI:
                case OperandType.ShortInlineVar:
                    return 1;
                case OperandType.InlineVar:
                    return 2;
                case OperandType.InlineBrTarget:
                case OperandType.InlineField:
                case OperandType.InlineI:
                case OperandType.InlineMethod:
                case OperandType.InlineSig:
                case OperandType.InlineString:
                case OperandType.InlineTok:
                case OperandType.InlineType:
                case OperandType.ShortInlineR:
                    return 4;
                case OperandType.InlineI8:
                case OperandType.InlineR:
                    return 8;
                case OperandType.InlineSwitch:
                    if (operandOffset + 4 > bytes.Length) return int.MaxValue;
                    int count = BitConverter.ToInt32(bytes, operandOffset);
                    if (count < 0 || count > (bytes.Length - operandOffset - 4) / 4) return int.MaxValue;
                    return 4 + (count * 4);
                default:
                    throw new InvalidOperationException("Unsupported IL operand type " + operandType + ".");
            }
        }

        private static bool IsMemberTokenOperand(OperandType operandType)
        {
            return operandType == OperandType.InlineField ||
                operandType == OperandType.InlineMethod ||
                operandType == OperandType.InlineTok ||
                operandType == OperandType.InlineType;
        }

        private static bool MembersMatch(MemberInfo left, MemberInfo right)
        {
            if (left == null || right == null) return false;
            if (left.Module == right.Module && left.MetadataToken == right.MetadataToken) return true;
            if (!string.Equals(left.Name, right.Name, StringComparison.Ordinal) ||
                left.DeclaringType == null || right.DeclaringType == null ||
                !string.Equals(left.DeclaringType.FullName, right.DeclaringType.FullName, StringComparison.Ordinal))
            {
                return false;
            }

            MethodBase leftMethod = left as MethodBase;
            MethodBase rightMethod = right as MethodBase;
            if (leftMethod != null && rightMethod != null)
            {
                MethodInfo leftInfo = leftMethod as MethodInfo;
                MethodInfo rightInfo = rightMethod as MethodInfo;
                if ((leftInfo == null) != (rightInfo == null) ||
                    (leftInfo != null && leftInfo.ReturnType != rightInfo.ReturnType))
                {
                    return false;
                }

                ParameterInfo[] leftParameters = leftMethod.GetParameters();
                ParameterInfo[] rightParameters = rightMethod.GetParameters();
                if (leftParameters.Length != rightParameters.Length) return false;
                for (int index = 0; index < leftParameters.Length; index++)
                {
                    if (!string.Equals(
                        leftParameters[index].ParameterType.FullName,
                        rightParameters[index].ParameterType.FullName,
                        StringComparison.Ordinal))
                    {
                        return false;
                    }
                }

                return true;
            }

            FieldInfo leftField = left as FieldInfo;
            FieldInfo rightField = right as FieldInfo;
            return leftField != null && rightField != null &&
                string.Equals(leftField.FieldType.FullName, rightField.FieldType.FullName, StringComparison.Ordinal);
        }
    }
}
