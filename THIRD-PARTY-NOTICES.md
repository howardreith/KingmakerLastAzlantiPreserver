# Third-party notices

## FirstAzlanti from KingmakerFumi

Last Azlanti Preserver was informed by the pinned `FirstAzlanti/Main.cs` implementation at commit `a2e16e29998ff1e784f00ac1b8e0bc4c85c47e91`, copyright 2020 Truinto, licensed under MIT.

Adapted concepts are limited to identifying `GameOverIronmanController.Activate` as the Last Azlanti game-over seam, recognizing `SaveManager.SaveRoutine` as an autosave seam worth inspecting, and preserving the native `LoadingProcess.ResetManualLoadingScreen` behavior. The new implementation does not copy the upstream broad `Activate` skip or its adjacent game-visible backup scheme: it keeps `Activate` running, scopes a patch at the exact `SaveManager.DeleteSave(SaveInfo)` call, and writes one validated snapshot outside the save scan directory.

The complete upstream MIT notice is packaged at `licenses/FIRST-AZLANTI-MIT.txt`.
