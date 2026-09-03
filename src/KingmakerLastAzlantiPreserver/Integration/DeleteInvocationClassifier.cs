using System;
using System.Diagnostics;
using System.Reflection;

namespace KingmakerLastAzlantiPreserver.Integration
{
    public sealed class DeleteInvocationClassifier
    {
        public bool IsExplicitLoadUiDeletionOnStack()
        {
            return ContainsMethod("Kingmaker.UI.SaveLoadWindow.SaveSlot", "TryDeleteMySave") ||
                ContainsMethod("Kingmaker.UI.SaveLoadWindow.SaveSlotInject", "TryDeleteMySave") ||
                ContainsMethod(
                    "Kingmaker.UI._ConsoleUI.SaveLoadManager.ViewModel.SaveLoadManagerVM",
                    "ExecuteDeleteSave");
        }

        private static bool ContainsMethod(string declaringType, string methodName)
        {
            StackFrame[] frames = new StackTrace(false).GetFrames();
            if (frames == null) return false;
            for (int index = 0; index < frames.Length; index++)
            {
                MethodBase method = frames[index].GetMethod();
                if (method == null) continue;
                if (method.DeclaringType != null &&
                    string.Equals(method.DeclaringType.FullName, declaringType, StringComparison.Ordinal) &&
                    string.Equals(method.Name, methodName, StringComparison.Ordinal))
                {
                    return true;
                }
            }

            return false;
        }
    }
}
