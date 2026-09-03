[CmdletBinding()]
param(
    [string] $GamePathProps,
    [string] $OutputPath = 'artifacts\qualification\contracts.json'
)

. (Join-Path $PSScriptRoot 'Common.ps1')
$root = Get-RepositoryRoot
if (-not $GamePathProps) { $GamePathProps = Join-Path $root 'GamePath.props' }
$configuration = Get-KingmakerConfiguration $GamePathProps
$assemblyPath = Join-Path $configuration.ManagedDir 'Assembly-CSharp.dll'
$resolverDirectories = @(
    $configuration.ManagedDir,
    $configuration.UnityModManagerDir,
    (Join-Path $root 'artifacts\bin\Release\KingmakerLastAzlantiPreserver')
)
$resolver = [ResolveEventHandler]{
    param($sender, $eventArgs)
    $name = [Reflection.AssemblyName]::new($eventArgs.Name).Name + '.dll'
    foreach ($directory in $resolverDirectories) {
        $candidate = Join-Path $directory $name
        if (Test-Path -LiteralPath $candidate) { return [Reflection.Assembly]::LoadFrom($candidate) }
    }
    return $null
}
[AppDomain]::CurrentDomain.add_AssemblyResolve($resolver)

function Require-Type([Reflection.Assembly] $Assembly, [string] $Name) {
    $type = $Assembly.GetType($Name, $false)
    if (-not $type) { throw "Required type missing: $Name" }
    return $type
}

function Require-Method([Type] $Type, [string] $Name, [Type] $ReturnType, [Type[]] $Parameters) {
    $flags = [Reflection.BindingFlags]'Public,NonPublic,Instance,Static'
    $method = $Type.GetMethod($Name, $flags, $null, $Parameters, $null)
    if (-not $method -or $method.ReturnType -ne $ReturnType) {
        throw "Required exact method missing: $($Type.FullName).$Name"
    }
    return $method
}

function Find-TokenOffset([Reflection.MethodBase] $Caller, [Reflection.MemberInfo] $Target) {
    $body = $Caller.GetMethodBody()
    if (-not $body) { return -1 }
    [byte[]] $bytes = $body.GetILAsByteArray()
    [byte[]] $token = [BitConverter]::GetBytes($Target.MetadataToken)
    for ($offset = 0; $offset -le $bytes.Length - 5; $offset++) {
        if ($bytes[$offset] -notin @(0x28,0x6f,0x73,0x7b,0x7e,0x80)) { continue }
        if ($bytes[$offset + 1] -eq $token[0] -and $bytes[$offset + 2] -eq $token[1] -and
            $bytes[$offset + 3] -eq $token[2] -and $bytes[$offset + 4] -eq $token[3]) { return $offset }
    }
    return -1
}

function Format-Method([Reflection.MethodBase] $Method) {
    $parameters = @($Method.GetParameters() | ForEach-Object { $_.ParameterType.FullName }) -join ', '
    return "$($Method.DeclaringType.FullName).$($Method.Name)($parameters)"
}

function Find-Callers([Reflection.Assembly] $Assembly, [Reflection.MethodInfo] $Target) {
    $results = [Collections.Generic.List[string]]::new()
    $flags = [Reflection.BindingFlags]'Public,NonPublic,Instance,Static,DeclaredOnly'
    try { $types = $Assembly.GetTypes() }
    catch [Reflection.ReflectionTypeLoadException] { $types = $_.Exception.Types | Where-Object { $null -ne $_ } }
    foreach ($type in $types) {
        foreach ($method in @($type.GetMethods($flags)) + @($type.GetConstructors($flags))) {
            if ((Find-TokenOffset $method $Target) -ge 0) { $results.Add((Format-Method $method)) }
        }
    }
    return @($results | Sort-Object)
}

$harmony = $null
try {
    $assembly = [Reflection.Assembly]::LoadFrom($assemblyPath)
    $gameOverType = Require-Type $assembly 'Kingmaker.Controllers.GameOverIronmanController'
    $saveManagerType = Require-Type $assembly 'Kingmaker.EntitySystem.Persistence.SaveManager'
    $saveInfoType = Require-Type $assembly 'Kingmaker.EntitySystem.Persistence.SaveInfo'
    $saveType = Require-Type $assembly 'Kingmaker.EntitySystem.Persistence.SaveInfo+SaveType'
    $loadingType = Require-Type $assembly 'Kingmaker.EntitySystem.Persistence.LoadingProcess'
    $settingsRootType = Require-Type $assembly 'Kingmaker.UI.SettingsUI.SettingsRoot'
    $settingsListType = Require-Type $assembly 'Kingmaker.UI.SettingsUI.SettingsRoot+SettingsListScreen'
    $settingsBoolType = Require-Type $assembly 'Kingmaker.UI.SettingsUI.SettingsEntityBool'
    $iSaverType = Require-Type $assembly 'Kingmaker.EntitySystem.Persistence.ISaver'
    $steamReplicatorType = Require-Type $assembly 'Kingmaker.EntitySystem.Persistence.SteamSavesReplicator'
    $gameModeType = Require-Type $assembly 'Kingmaker.GameModes.GameMode'
    $gameModesFactoryType = Require-Type $assembly 'Kingmaker.GameModes.GameModesFactory'
    $controllerInterface = Require-Type $assembly 'Kingmaker.Controllers.IController'

    $activate = Require-Method $gameOverType 'Activate' ([void]) @()
    $deactivate = Require-Method $gameOverType 'Deactivate' ([void]) @()
    $getIronman = Require-Method $saveManagerType 'GetIronmanSave' $saveInfoType @()
    $deleteByInfo = Require-Method $saveManagerType 'DeleteSave' ([void]) @($saveInfoType)
    $deleteByString = Require-Method $saveManagerType 'DeleteSave' ([void]) @([string])
    $saveRoutine = Require-Method $saveManagerType 'SaveRoutine' ([Collections.Generic.IEnumerator[object]]) @($saveInfoType, [bool])
    $resetLoading = Require-Method $loadingType 'ResetManualLoadingScreen' ([void]) @()
    $updateSaveList = Require-Method $saveManagerType 'UpdateSaveListIfNeeded' ([void]) @([bool])
    $clearSaver = Require-Method $iSaverType 'Clear' ([void]) @()
    $deleteSteam = Require-Method $steamReplicatorType 'DeleteSave' ([void]) @($saveInfoType)
    $setFolderName = Require-Method $saveInfoType 'set_FolderName' ([void]) @([string])
    $disposeSave = Require-Method $saveInfoType 'Dispose' ([void]) @()
    $onActivate = Require-Method $gameModeType 'OnActivate' ([void]) @()
    $interfaceActivate = Require-Method $controllerInterface 'Activate' ([void]) @()
    $initializeModes = Require-Method $gameModesFactoryType 'Initialize' ([void]) @()
    $controllerConstructor = $gameOverType.GetConstructor([Reflection.BindingFlags]'Public,NonPublic,Instance', $null, @(), $null)
    if (-not $controllerConstructor) { throw 'GameOverIronmanController constructor is missing.' }
    if ($deleteByInfo.GetParameters()[0].Name -ne 'saveInfo') {
        throw 'SaveManager.DeleteSave(SaveInfo) parameter name changed; Harmony prefix binding would be unsafe.'
    }

    $onlyOneSave = $settingsListType.GetField('OnlyOneSave', [Reflection.BindingFlags]'Public,NonPublic,Instance')
    $settingsInstance = $settingsRootType.GetProperty('Instance', [Reflection.BindingFlags]'Public,NonPublic,Static')
    $currentValue = $settingsBoolType.GetProperty('CurrentValue', [Reflection.BindingFlags]'Public,NonPublic,Instance')
    if (-not $onlyOneSave -or $onlyOneSave.FieldType -ne $settingsBoolType -or
        -not $settingsInstance -or $settingsInstance.PropertyType -ne $settingsListType -or
        -not $currentValue -or $currentValue.PropertyType -ne [bool]) {
        throw 'SettingsRoot.Instance.OnlyOneSave.CurrentValue contract is missing.'
    }
    if ([int] [Enum]::Parse($saveType, 'IronMan') -ne 5) { throw 'SaveInfo.SaveType.IronMan is not value 5.' }

    $activateBody = $activate.GetMethodBody()
    if (-not $activateBody -or $activateBody.ExceptionHandlingClauses.Count -ne 0 -or
        (Find-TokenOffset $activate $getIronman) -lt 0 -or
        (Find-TokenOffset $activate $deleteByInfo) -lt 0 -or
        (Find-TokenOffset $activate $resetLoading) -lt 0 -or
        (Find-TokenOffset $activate $onlyOneSave) -lt 0) {
        throw 'Game-over Activate no longer has the observed synchronous deletion/reset control flow.'
    }
    foreach ($requiredDeleteEffect in @($clearSaver, $deleteSteam, $setFolderName, $disposeSave)) {
        if ((Find-TokenOffset $deleteByInfo $requiredDeleteEffect) -lt 0) {
            throw "SaveManager.DeleteSave(SaveInfo) lost expected side effect: $(Format-Method $requiredDeleteEffect)"
        }
    }
    if ((Find-TokenOffset $deleteByString $deleteByInfo) -lt 0) { throw 'DeleteSave(string) no longer delegates to DeleteSave(SaveInfo).' }
    if ((Find-TokenOffset $onActivate $interfaceActivate) -lt 0 -or (Find-TokenOffset $initializeModes $controllerConstructor) -lt 0) {
        throw 'GameModesFactory/GameMode no longer synchronously activates GameOverIronmanController through IController.Activate.'
    }

    $legacySlotType = Require-Type $assembly 'Kingmaker.UI.SaveLoadWindow.SaveSlot'
    $injectedSlotType = Require-Type $assembly 'Kingmaker.UI.SaveLoadWindow.SaveSlotInject'
    $boxButtonType = Require-Type $assembly 'Kingmaker.UI.DialogMessageBoxBase+BoxButton'
    $consoleManagerType = Require-Type $assembly 'Kingmaker.UI._ConsoleUI.SaveLoadManager.ViewModel.SaveLoadManagerVM'
    $legacyDelete = Require-Method $legacySlotType 'TryDeleteMySave' ([void]) @($boxButtonType)
    $injectedDelete = Require-Method $injectedSlotType 'TryDeleteMySave' ([void]) @($boxButtonType)
    $consoleDelete = Require-Method $consoleManagerType 'ExecuteDeleteSave' ([void]) @($saveInfoType)
    if ((Find-TokenOffset $legacyDelete $deleteByInfo) -lt 0 -or
        (Find-TokenOffset $injectedDelete $deleteByInfo) -lt 0 -or
        (Find-TokenOffset $consoleDelete $deleteByString) -lt 0) {
        throw 'One or more explicit load-game UI deletion paths changed.'
    }

    $callersByInfo = Find-Callers $assembly $deleteByInfo
    $callersByString = Find-Callers $assembly $deleteByString
    $gameOverCallers = @($callersByInfo | Where-Object { $_ -match 'GameOver' })
    if ($gameOverCallers.Count -ne 1 -or $gameOverCallers[0] -ne 'Kingmaker.Controllers.GameOverIronmanController.Activate()') {
        throw "Unexpected game-over DeleteSave callers: $($gameOverCallers -join ', ')"
    }

    $patchOwnership = 'not-attempted'
    $activateReplacementKind = 'not-attempted'
    $modDll = Join-Path $root 'artifacts\bin\Release\KingmakerLastAzlantiPreserver\KingmakerLastAzlantiPreserver.dll'
    if (Test-Path -LiteralPath $modDll) {
        $harmonyAssembly = [Reflection.Assembly]::LoadFrom((Join-Path $configuration.UnityModManagerDir '0Harmony12.dll'))
        $modAssembly = [Reflection.Assembly]::LoadFrom($modDll)
        $harmonyType = $harmonyAssembly.GetType('Harmony12.HarmonyInstance', $true)
        $harmonyMethodType = $harmonyAssembly.GetType('Harmony12.HarmonyMethod', $true)
        $createHarmony = $harmonyType.GetMethod('Create', [Reflection.BindingFlags]'Public,Static')
        $harmony = $createHarmony.Invoke($null, @('KingmakerLastAzlantiPreserver.ContractVerification'))
        $publicInstance = [Reflection.BindingFlags]'Public,Instance'
        $harmonyMethodConstructor = $harmonyMethodType.GetConstructor($publicInstance, $null, [Type[]]@([Reflection.MethodInfo]), $null)
        $patchMethod = $harmonyType.GetMethod(
            'Patch',
            $publicInstance,
            $null,
            [Type[]]@([Reflection.MethodBase], $harmonyMethodType, $harmonyMethodType, $harmonyMethodType),
            $null)
        $getPatchInfo = $harmonyType.GetMethod(
            'GetPatchInfo',
            $publicInstance,
            $null,
            [Type[]]@([Reflection.MethodBase]),
            $null)
        $gameOverPatchType = $modAssembly.GetType('KingmakerLastAzlantiPreserver.Patches.GameOverContextPatch', $true)
        $deletePatchType = $modAssembly.GetType('KingmakerLastAzlantiPreserver.Patches.SaveDeletionPatch', $true)
        $prefix = $gameOverPatchType.GetMethod('Prefix', [Reflection.BindingFlags]'Public,Static')
        $postfix = $gameOverPatchType.GetMethod('Postfix', [Reflection.BindingFlags]'Public,Static')
        $deactivatePrefix = $gameOverPatchType.GetMethod('DeactivatePrefix', [Reflection.BindingFlags]'Public,Static')
        $gameModePostfix = $gameOverPatchType.GetMethod('GameModeOnActivatePostfix', [Reflection.BindingFlags]'Public,Static')
        $deletePrefix = $deletePatchType.GetMethod('Prefix', [Reflection.BindingFlags]'Public,Static')
        $harmonyPrefix = $harmonyMethodConstructor.Invoke(@($prefix))
        $harmonyPostfix = $harmonyMethodConstructor.Invoke(@($postfix))
        $harmonyDeactivatePrefix = $harmonyMethodConstructor.Invoke(@($deactivatePrefix))
        $harmonyGameModePostfix = $harmonyMethodConstructor.Invoke(@($gameModePostfix))
        $harmonyDeletePrefix = $harmonyMethodConstructor.Invoke(@($deletePrefix))
        $activateReplacement = $patchMethod.Invoke($harmony, @($activate, $harmonyPrefix, $harmonyPostfix, $null))
        $activateReplacementKind = $activateReplacement.GetType().FullName
        [void] $patchMethod.Invoke($harmony, @($deactivate, $harmonyDeactivatePrefix, $null, $null))
        [void] $patchMethod.Invoke($harmony, @($onActivate, $null, $harmonyGameModePostfix, $null))
        [void] $patchMethod.Invoke($harmony, @($deleteByInfo, $harmonyDeletePrefix, $null, $null))
        $activatePatches = $getPatchInfo.Invoke($harmony, @($activate))
        $deactivatePatches = $getPatchInfo.Invoke($harmony, @($deactivate))
        $gameModePatches = $getPatchInfo.Invoke($harmony, @($onActivate))
        $deletePatches = $getPatchInfo.Invoke($harmony, @($deleteByInfo))
        $activateOwners = @($activatePatches.Owners)
        $deactivateOwners = @($deactivatePatches.Owners)
        $gameModeOwners = @($gameModePatches.Owners)
        $deleteOwners = @($deletePatches.Owners)
        if ($activateOwners -notcontains 'KingmakerLastAzlantiPreserver.ContractVerification' -or
            $deactivateOwners -notcontains 'KingmakerLastAzlantiPreserver.ContractVerification' -or
            $gameModeOwners -notcontains 'KingmakerLastAzlantiPreserver.ContractVerification' -or
            $deleteOwners -notcontains 'KingmakerLastAzlantiPreserver.ContractVerification') {
            throw 'Harmony application completed but patch ownership was not observable.'
        }
        $patchOwnership = 'verified-after-application'
    }

    $report = [ordered]@{
        status = 'passed'
        target = 'Pathfinder: Kingmaker 2.1.7b'
        assembly_path = $assemblyPath
        assembly_sha256 = Get-Sha256 $assemblyPath
        assembly_mvid = $assembly.ManifestModule.ModuleVersionId.ToString('D')
        game_over_hook = Format-Method $activate
        deletion_hook = Format-Method $deleteByInfo
        cleanup_hook = Format-Method $deactivate
        exception_cleanup_hook = Format-Method $onActivate
        reset_hook = Format-Method $resetLoading
        save_routine = Format-Method $saveRoutine
        update_save_list = Format-Method $updateSaveList
        activate_il_length = $activateBody.GetILAsByteArray().Length
        activate_delete_call_offset = ('0x{0:X4}' -f (Find-TokenOffset $activate $deleteByInfo))
        deletion_callers_by_save_info = $callersByInfo
        deletion_callers_by_string = $callersByString
        explicit_ui_deletion_methods = @((Format-Method $legacyDelete), (Format-Method $injectedDelete), (Format-Method $consoleDelete))
        patch_ownership = $patchOwnership
        harmony_activate_replacement_kind = $activateReplacementKind
    }
    $resolvedOutput = if ([IO.Path]::IsPathRooted($OutputPath)) { $OutputPath } else { Join-Path $root $OutputPath }
    Write-JsonFile $resolvedOutput $report
    Write-Host "Contract verification passed: $resolvedOutput"
    Write-Host "Assembly-CSharp SHA-256: $($report.assembly_sha256)"
    Write-Host "Assembly-CSharp MVID: $($report.assembly_mvid)"
    Write-Host "Game-over hook: $($report.game_over_hook)"
    Write-Host "Deletion hook: $($report.deletion_hook)"
    Write-Host "Harmony ownership: $patchOwnership"
}
finally {
    if ($harmony) {
        try { $harmony.UnpatchAll('KingmakerLastAzlantiPreserver.ContractVerification') }
        catch { Write-Warning "Contract-verification unpatch failed: $($_.Exception.Message)" }
    }
    [AppDomain]::CurrentDomain.remove_AssemblyResolve($resolver)
}
