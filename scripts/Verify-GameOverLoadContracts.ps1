[CmdletBinding()]
param(
    [string] $GamePathProps,
    [string] $OutputPath = 'artifacts\qualification\game-over-load-contracts.json'
)

. (Join-Path $PSScriptRoot 'Common.ps1')
$root = Get-RepositoryRoot
if (-not $GamePathProps) { $GamePathProps = Join-Path $root 'GamePath.props' }
$configuration = Get-KingmakerConfiguration $GamePathProps
$assemblyPath = Join-Path $configuration.ManagedDir 'Assembly-CSharp.dll'
$ummPath = Join-Path $configuration.UnityModManagerDir 'UnityModManager.dll'
$harmonyPath = Join-Path $configuration.UnityModManagerDir '0Harmony12.dll'
$modDll = Join-Path $root 'artifacts\bin\Release\KingmakerLastAzlantiPreserver\KingmakerLastAzlantiPreserver.dll'
Assert-FileExists $modDll 'Built Last Azlanti Preserver DLL'

$resolverDirectories = @(
    $configuration.ManagedDir
    $configuration.UnityModManagerDir
    (Split-Path -Parent $modDll)
)
$resolver = [ResolveEventHandler]{
    param($sender, $eventArgs)
    $simpleName = [Reflection.AssemblyName]::new($eventArgs.Name).Name
    if (-not $simpleName -or $simpleName.IndexOfAny([IO.Path]::GetInvalidFileNameChars()) -ge 0) {
        return $null
    }

    foreach ($directory in $resolverDirectories) {
        $candidate = Join-Path $directory ($simpleName + '.dll')
        if (Test-Path -LiteralPath $candidate) {
            return [Reflection.Assembly]::LoadFrom($candidate)
        }
    }

    return $null
}
[AppDomain]::CurrentDomain.add_AssemblyResolve($resolver)

function Format-Method([Reflection.MethodBase] $Method) {
    $parameters = @($Method.GetParameters() | ForEach-Object { $_.ParameterType.FullName }) -join ', '
    $name = if ($Method -is [Reflection.ConstructorInfo]) { '.ctor' } else { $Method.Name }
    return "$($Method.DeclaringType.FullName).$name($parameters)"
}

function Format-Field([Reflection.FieldInfo] $Field) {
    return "$($Field.DeclaringType.FullName).$($Field.Name) : $($Field.FieldType.FullName)"
}

function Get-PublicInstanceMethod([Type] $Type, [string] $Name, [Type[]] $Parameters) {
    $method = $Type.GetMethod(
        $Name,
        [Reflection.BindingFlags]'Public,Instance',
        $null,
        $Parameters,
        $null)
    if (-not $method) { throw "Required method missing: $($Type.FullName).$Name" }
    return $method
}

function Get-StaticPatchMethod([Reflection.Assembly] $Assembly, [string] $TypeName, [string] $MethodName) {
    $type = $Assembly.GetType($TypeName, $true)
    $method = $type.GetMethod($MethodName, [Reflection.BindingFlags]'Public,Static')
    if (-not $method) { throw "Patch method missing: $TypeName.$MethodName" }
    return $method
}

function Test-PatchOwned(
    [object] $Harmony,
    [Reflection.MethodBase] $Target,
    [Reflection.MethodInfo] $PatchMethod,
    [string] $Kind,
    [string] $Owner,
    [Reflection.MethodInfo] $GetPatchInfo
) {
    $info = $GetPatchInfo.Invoke($Harmony, @($Target))
    if (-not $info) { return $false }
    $patches = if ($Kind -eq 'prefix') { @($info.Prefixes) } else { @($info.Postfixes) }
    foreach ($patch in $patches) {
        if ($patch.owner -eq $Owner -and $patch.patch -eq $PatchMethod) { return $true }
    }
    return $false
}

function Apply-PatchSpec(
    [object] $Harmony,
    [pscustomobject] $Spec,
    [Reflection.MethodInfo] $PatchMethodApi,
    [Reflection.ConstructorInfo] $HarmonyMethodConstructor
) {
    $harmonyMethod = $HarmonyMethodConstructor.Invoke(@($Spec.PatchMethod))
    try {
        if ($Spec.Kind -eq 'prefix') {
            [void] $PatchMethodApi.Invoke($Harmony, @($Spec.Target, $harmonyMethod, $null, $null))
        }
        else {
            [void] $PatchMethodApi.Invoke($Harmony, @($Spec.Target, $null, $harmonyMethod, $null))
        }
    }
    catch {
        throw "Harmony failed to apply $($Spec.Kind) $($Spec.PatchMethod.Name) to $(Format-Method $Spec.Target): $($_.Exception.Message)"
    }
}

function Assert-PatchSpecsOwned(
    [object] $Harmony,
    [object[]] $Specs,
    [string] $Owner,
    [Reflection.MethodInfo] $GetPatchInfo
) {
    foreach ($spec in $Specs) {
        if (-not (Test-PatchOwned $Harmony $spec.Target $spec.PatchMethod $spec.Kind $Owner $GetPatchInfo)) {
            throw "Harmony owner $Owner is missing $($spec.Kind) $($spec.PatchMethod.Name) on $(Format-Method $spec.Target)."
        }
    }
}

$coreHarmony = $null
$optionalHarmony = $null
$coreOwner = 'KingmakerLastAzlantiPreserver.ContractVerification.Core'
$optionalOwner = 'KingmakerLastAzlantiPreserver.ContractVerification.GameOverLoadControls'
try {
    $ummIdentity = [Reflection.AssemblyName]::GetAssemblyName($ummPath)
    $ummHash = Get-Sha256 $ummPath
    $ummMvid = Get-AssemblyMvid $ummPath
    if ($ummIdentity.Name -ne 'UnityModManager' -or
        $ummIdentity.Version.ToString() -ne '0.33.0.0' -or
        $ummHash -ne '63e5baf7b1738e4091b5fd17ccb738ecdb4d1dbf246061dfd55dc52835d52691' -or
        $ummMvid -ne '54059519-2754-445a-b5ee-fdb9326336e2') {
        throw "The installed Unity Mod Manager identity/hash/MVID does not match the owner-approved 0.33.0 candidate environment."
    }

    $harmonyIdentity = [Reflection.AssemblyName]::GetAssemblyName($harmonyPath)
    $harmonyHash = Get-Sha256 $harmonyPath
    if ($harmonyIdentity.Name -ne '0Harmony12' -or
        $harmonyIdentity.Version.ToString() -ne '1.2.0.1' -or
        $harmonyHash -ne 'aa1cd48317254985d8b700cc74953477d1b40c3022ce9aa4c95ed2b8327e1292') {
        throw 'The installed legacy Harmony identity/hash does not match the verified 1.2.0.1 contract.'
    }

    $assembly = [Reflection.Assembly]::LoadFrom($assemblyPath)
    $harmonyAssembly = [Reflection.Assembly]::LoadFrom($harmonyPath)
    if ($harmonyAssembly.ManifestModule.ModuleVersionId.ToString('D') -ne '918c071f-383e-46dc-a374-6879300cbe15') {
        throw 'The installed legacy Harmony MVID does not match the verified 1.2.0.1 contract.'
    }
    $modAssembly = [Reflection.Assembly]::LoadFrom($modDll)

    $coreResolverType = $modAssembly.GetType(
        'KingmakerLastAzlantiPreserver.Integration.KingmakerContractResolver',
        $true)
    $coreResolver = [Activator]::CreateInstance($coreResolverType)
    $coreContracts = $coreResolverType.GetMethod('Resolve').Invoke($coreResolver, @())

    $optionalResolverType = $modAssembly.GetType(
        'KingmakerLastAzlantiPreserver.Integration.GameOverLoadContractResolver',
        $true)
    $optionalResolver = [Activator]::CreateInstance($optionalResolverType)
    $optionalResolve = $optionalResolverType.GetMethod(
        'Resolve',
        [Reflection.BindingFlags]'Public,Instance',
        $null,
        [Type[]]@($coreContracts.GetType()),
        $null)
    if (-not $optionalResolve) { throw 'The exact optional contract resolver entrypoint is missing.' }
    $optionalContracts = $optionalResolve.Invoke($optionalResolver, @($coreContracts))

    if ($optionalContracts.LegacyPreShow.MetadataToken -ne 0x060040AA -or
        $optionalContracts.LegacyCanvasPreShow.MetadataToken -ne 0x060043FE -or
        $optionalContracts.LegacyLoadLastSave.MetadataToken -ne 0x060040AD -or
        $optionalContracts.LegacyLoadGame.MetadataToken -ne 0x060040AE -or
        $optionalContracts.ConsoleMenuConstructor.MetadataToken -ne 0x0600600B -or
        $optionalContracts.ConsoleLoadLastPredicate.MetadataToken -ne 0x0600B7E3 -or
        $optionalContracts.ConsoleLoadPredicate.MetadataToken -ne 0x0600B7E4) {
        throw 'One or more canonical UI metadata tokens do not match the 2.1.7b contract.'
    }

    if ($optionalContracts.LegacyEndlessView.MetadataToken -ne 0x04002D6A -or
        $optionalContracts.LegacyLoadLastSaveButton.MetadataToken -ne 0x04002BE5 -or
        $optionalContracts.LegacyLoadGameButton.MetadataToken -ne 0x04002BE6 -or
        $optionalContracts.ConsoleLoadLastSaveVm.MetadataToken -ne 0x04003FE7 -or
        $optionalContracts.ConsoleLoadVm.MetadataToken -ne 0x04003FE8) {
        throw 'One or more canonical loading-control field tokens do not match the 2.1.7b contract.'
    }

    $harmonyType = $harmonyAssembly.GetType('Harmony12.HarmonyInstance', $true)
    $harmonyMethodType = $harmonyAssembly.GetType('Harmony12.HarmonyMethod', $true)
    $createHarmony = $harmonyType.GetMethod('Create', [Reflection.BindingFlags]'Public,Static')
    $publicInstance = [Reflection.BindingFlags]'Public,Instance'
    $harmonyMethodConstructor = $harmonyMethodType.GetConstructor(
        $publicInstance,
        $null,
        [Type[]]@([Reflection.MethodInfo]),
        $null)
    $patchApi = Get-PublicInstanceMethod $harmonyType 'Patch' ([Type[]]@(
        [Reflection.MethodBase],
        $harmonyMethodType,
        $harmonyMethodType,
        $harmonyMethodType))
    $getPatchInfo = Get-PublicInstanceMethod $harmonyType 'GetPatchInfo' ([Type[]]@([Reflection.MethodBase]))

    $corePatchType = 'KingmakerLastAzlantiPreserver.Patches.GameOverContextPatch'
    $deletePatchType = 'KingmakerLastAzlantiPreserver.Patches.SaveDeletionPatch'
    $optionalPatchType = 'KingmakerLastAzlantiPreserver.Patches.GameOverLoadControlsPatch'
    $coreSpecs = @(
        [pscustomobject]@{ Target = $coreContracts.GameOverActivate; Kind = 'prefix'; PatchMethod = Get-StaticPatchMethod $modAssembly $corePatchType 'Prefix' }
        [pscustomobject]@{ Target = $coreContracts.GameOverActivate; Kind = 'postfix'; PatchMethod = Get-StaticPatchMethod $modAssembly $corePatchType 'Postfix' }
        [pscustomobject]@{ Target = $coreContracts.GameOverDeactivate; Kind = 'prefix'; PatchMethod = Get-StaticPatchMethod $modAssembly $corePatchType 'DeactivatePrefix' }
        [pscustomobject]@{ Target = $coreContracts.GameModeOnActivate; Kind = 'postfix'; PatchMethod = Get-StaticPatchMethod $modAssembly $corePatchType 'GameModeOnActivatePostfix' }
        [pscustomobject]@{ Target = $coreContracts.DeleteSave; Kind = 'prefix'; PatchMethod = Get-StaticPatchMethod $modAssembly $deletePatchType 'Prefix' }
    )
    $optionalSpecs = @(
        [pscustomobject]@{ Target = $optionalContracts.LegacyCanvasPreShow; Kind = 'postfix'; PatchMethod = Get-StaticPatchMethod $modAssembly $optionalPatchType 'LegacyCanvasPreShowPostfix' }
        [pscustomobject]@{ Target = $optionalContracts.LegacyLoadLastSave; Kind = 'prefix'; PatchMethod = Get-StaticPatchMethod $modAssembly $optionalPatchType 'LegacyLoadLastPrefix' }
        [pscustomobject]@{ Target = $optionalContracts.LegacyLoadGame; Kind = 'prefix'; PatchMethod = Get-StaticPatchMethod $modAssembly $optionalPatchType 'LegacyLoadGamePrefix' }
        [pscustomobject]@{ Target = $optionalContracts.LegacyRestartGame; Kind = 'prefix'; PatchMethod = Get-StaticPatchMethod $modAssembly $optionalPatchType 'LegacyRestartPrefix' }
        [pscustomobject]@{ Target = $optionalContracts.LegacyMainMenu; Kind = 'prefix'; PatchMethod = Get-StaticPatchMethod $modAssembly $optionalPatchType 'LegacyMainMenuPrefix' }
        [pscustomobject]@{ Target = $optionalContracts.ConsoleMenuConstructor; Kind = 'postfix'; PatchMethod = Get-StaticPatchMethod $modAssembly $optionalPatchType 'ConsoleConstructorPostfix' }
        [pscustomobject]@{ Target = $optionalContracts.ConsoleLoadLastPredicate; Kind = 'prefix'; PatchMethod = Get-StaticPatchMethod $modAssembly $optionalPatchType 'ConsolePredicatePrefix' }
        [pscustomobject]@{ Target = $optionalContracts.ConsoleLoadPredicate; Kind = 'prefix'; PatchMethod = Get-StaticPatchMethod $modAssembly $optionalPatchType 'ConsolePredicatePrefix' }
        [pscustomobject]@{ Target = $optionalContracts.ConsoleLoadLastSave; Kind = 'prefix'; PatchMethod = Get-StaticPatchMethod $modAssembly $optionalPatchType 'ConsoleLoadLastPrefix' }
        [pscustomobject]@{ Target = $optionalContracts.ConsoleLoad; Kind = 'prefix'; PatchMethod = Get-StaticPatchMethod $modAssembly $optionalPatchType 'ConsoleLoadGamePrefix' }
        [pscustomobject]@{ Target = $optionalContracts.ConsoleNewGame; Kind = 'prefix'; PatchMethod = Get-StaticPatchMethod $modAssembly $optionalPatchType 'ConsoleNewGamePrefix' }
        [pscustomobject]@{ Target = $optionalContracts.ConsoleMainMenu; Kind = 'prefix'; PatchMethod = Get-StaticPatchMethod $modAssembly $optionalPatchType 'ConsoleMainMenuPrefix' }
        [pscustomobject]@{ Target = $optionalContracts.ConsoleDispose; Kind = 'prefix'; PatchMethod = Get-StaticPatchMethod $modAssembly $optionalPatchType 'ConsoleDisposePrefix' }
        [pscustomobject]@{ Target = $optionalContracts.NativeLoadGame; Kind = 'prefix'; PatchMethod = Get-StaticPatchMethod $modAssembly $optionalPatchType 'NativeLoadPrefix' }
        [pscustomobject]@{ Target = $optionalContracts.DeleteSave; Kind = 'postfix'; PatchMethod = Get-StaticPatchMethod $modAssembly $optionalPatchType 'DeleteSavePostfix' }
    )

    $coreHarmony = $createHarmony.Invoke($null, @($coreOwner))
    foreach ($spec in $coreSpecs) {
        Apply-PatchSpec $coreHarmony $spec $patchApi $harmonyMethodConstructor
    }
    Assert-PatchSpecsOwned $coreHarmony $coreSpecs $coreOwner $getPatchInfo

    $optionalHarmony = $createHarmony.Invoke($null, @($optionalOwner))
    foreach ($spec in $optionalSpecs) {
        Apply-PatchSpec $optionalHarmony $spec $patchApi $harmonyMethodConstructor
    }
    Assert-PatchSpecsOwned $optionalHarmony $optionalSpecs $optionalOwner $getPatchInfo

    $optionalHarmony.UnpatchAll($optionalOwner)
    Assert-PatchSpecsOwned $coreHarmony $coreSpecs $coreOwner $getPatchInfo
    foreach ($spec in $optionalSpecs) {
        if (Test-PatchOwned $optionalHarmony $spec.Target $spec.PatchMethod $spec.Kind $optionalOwner $getPatchInfo) {
            throw "Optional patch ownership remained after isolated unpatch: $(Format-Method $spec.Target)."
        }
    }

    $verifiedRelationships = @(
        'EndlessGameOverView.PreShow -> SettingsRoot.Instance.OnlyOneSave.CurrentValue'
        'EndlessGameOverView.PreShow -> m_LoadLastSaveButton/m_LoadGameButton -> UnityEngine.UI.Button.interactable'
        'EndlessGameOverView.PreShow -> SaveManager.GetLatestSave(DlcType.Endless)'
        'EndlessGameOverView.OnLoadLastSave -> SaveManager.GetLatestSave(DlcType) -> Game.LoadGame(SaveInfo)'
        'EndlessGameOverView.OnLoadGame generated callback -> ISaveLoadWindowUIHandler.HandleOpenSaveLoadWindow(ScreenType)'
        'EndlessGameOverMenuPartVm constructor -> OnlyOneSave/canLoad/LoadLastSaveVm/LoadVm'
        'Endless console load predicates -> canLoad, with load-last also selecting GetLatestSave(DlcType.Endless)'
        'EndlessGameOverMenuPartVm.OnButtonLoadLastSave -> SaveManager.GetLatestSave() -> Game.LoadGame(SaveInfo)'
        'EndlessGameOverMenuPartVm.OnButtonLoad generated callback -> ISaveLoadManagerUIHandler.HandleOpen(mode, bool)'
        'GameOverCanvas.PreShow -> EndlessGameOverView.PreShow'
        'GameOverCanvas.IsEndless -> Game.Player.StartPreset.DlcCampaign'
        'Game.DoStartMode -> create/push current mode -> OnStart -> OnActivate -> HandleGameModeChanged'
        'HandleGameModeChanged -> IGameModeHandler.OnGameModeStart -> BaseGameOverCanvas.PreShow'
        'SaveLoadWindow.HandleHardcodeMainMenuSaveLoad -> Game.LoadGame(SaveInfo)'
        'CommonUiLoadService.Load generated action -> Game.LoadGame(SaveInfo)'
        'Native load callbacks contain no OnlyOneSave rejection guard'
    )

    $report = [ordered]@{
        status = 'passed'
        target = 'Pathfinder: Kingmaker 2.1.7b'
        assembly_csharp = [ordered]@{
            path = $assemblyPath
            identity = [Reflection.AssemblyName]::GetAssemblyName($assemblyPath).FullName
            sha256 = Get-Sha256 $assemblyPath
            mvid = $assembly.ManifestModule.ModuleVersionId.ToString('D')
        }
        unity_mod_manager = [ordered]@{
            path = $ummPath
            identity = $ummIdentity.FullName
            sha256 = $ummHash
            mvid = $ummMvid
        }
        legacy_harmony = [ordered]@{
            path = $harmonyPath
            identity = $harmonyIdentity.FullName
            sha256 = $harmonyHash
            mvid = $harmonyAssembly.ManifestModule.ModuleVersionId.ToString('D')
        }
        exact_ui_contract = [ordered]@{
            legacy_type = $optionalContracts.LegacyPreShow.DeclaringType.FullName
            legacy_lifecycle = Format-Method $optionalContracts.LegacyPreShow
            patched_lifecycle = Format-Method $optionalContracts.LegacyCanvasPreShow
            exact_endless_view_field = Format-Field $optionalContracts.LegacyEndlessView
            legacy_fields = @(
                Format-Field $optionalContracts.LegacyLoadLastSaveButton
                Format-Field $optionalContracts.LegacyLoadGameButton
            )
            legacy_callbacks = @(
                Format-Method $optionalContracts.LegacyLoadLastSave
                Format-Method $optionalContracts.LegacyLoadGame
                Format-Method $optionalContracts.LegacyRestartGame
                Format-Method $optionalContracts.LegacyMainMenu
            )
            controller_type = $optionalContracts.ConsoleMenuConstructor.DeclaringType.FullName
            controller_lifecycle = Format-Method $optionalContracts.ConsoleMenuConstructor
            controller_fields = @(
                Format-Field $optionalContracts.ConsoleLoadLastSaveVm
                Format-Field $optionalContracts.ConsoleLoadVm
            )
            controller_predicates = @(
                Format-Method $optionalContracts.ConsoleLoadLastPredicate
                Format-Method $optionalContracts.ConsoleLoadPredicate
            )
            controller_callbacks = @(
                Format-Method $optionalContracts.ConsoleLoadLastSave
                Format-Method $optionalContracts.ConsoleLoad
                Format-Method $optionalContracts.ConsoleNewGame
                Format-Method $optionalContracts.ConsoleMainMenu
                Format-Method $optionalContracts.ConsoleDispose
            )
            native_load = Format-Method $optionalContracts.NativeLoadGame
            game_mode_entry = Format-Method $optionalContracts.GameDoStartMode
            game_mode_notification = Format-Method $optionalContracts.GameHandleGameModeChanged
            game_over_view_dispatch = Format-Method $optionalContracts.BaseGameOverOnModeStart
            verified_il_relationships = $verifiedRelationships
            patch_targets = @($optionalSpecs | ForEach-Object { Format-Method $_.Target })
        }
        harmony_ownership = [ordered]@{
            core_owner = $coreOwner
            core_patch_count = $coreSpecs.Count
            core_targets = @($coreSpecs | ForEach-Object { "$($_.Kind): $(Format-Method $_.Target)" })
            optional_owner = $optionalOwner
            optional_patch_count = $optionalSpecs.Count
            optional_targets = @($optionalSpecs | ForEach-Object { "$($_.Kind): $(Format-Method $_.Target)" })
            core_owned_after_application = $true
            optional_owned_after_application = $true
            optional_unpatch_removed_only_optional_owner = $true
            core_owned_after_optional_unpatch = $true
        }
    }

    $resolvedOutput = if ([IO.Path]::IsPathRooted($OutputPath)) {
        $OutputPath
    }
    else {
        Join-Path $root $OutputPath
    }
    Write-JsonFile $resolvedOutput $report 12
    Write-Host "Game-over load contract verification passed: $resolvedOutput"
    Write-Host "UI lifecycle: $($report.exact_ui_contract.legacy_lifecycle)"
    Write-Host "Patched UI lifecycle: $($report.exact_ui_contract.patched_lifecycle)"
    Write-Host "Controller lifecycle: $($report.exact_ui_contract.controller_lifecycle)"
    Write-Host "Harmony ownership: core=$($coreSpecs.Count), optional=$($optionalSpecs.Count), isolation=verified"
}
finally {
    if ($optionalHarmony) {
        try { $optionalHarmony.UnpatchAll($optionalOwner) }
        catch { Write-Warning "Optional contract-verification unpatch failed: $($_.Exception.Message)" }
    }
    if ($coreHarmony) {
        try { $coreHarmony.UnpatchAll($coreOwner) }
        catch { Write-Warning "Core contract-verification unpatch failed: $($_.Exception.Message)" }
    }
    [AppDomain]::CurrentDomain.remove_AssemblyResolve($resolver)
}
