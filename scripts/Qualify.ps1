[CmdletBinding()]
param(
    [switch] $Build,
    [switch] $Test,
    [switch] $VerifyContracts,
    [switch] $Package,
    [switch] $Install,
    [ValidateSet('Debug','Release')][string] $Configuration = 'Release'
)

. (Join-Path $PSScriptRoot 'Common.ps1')
$root = Get-RepositoryRoot
Assert-RepositorySafety
if ($Build) { & (Join-Path $PSScriptRoot 'Build-Local.ps1') -Configuration $Configuration }
if ($Test) { & (Join-Path $PSScriptRoot 'Test.ps1') -Configuration $Configuration }
if ($VerifyContracts) {
    & (Join-Path $PSScriptRoot 'Verify-KingmakerContracts.ps1') -DllPath (Join-Path $root "artifacts\bin\$Configuration\KingmakerLastAzlantiPreserver\KingmakerLastAzlantiPreserver.dll")
}
if ($Package) { & (Join-Path $PSScriptRoot 'Package.ps1') -Configuration $Configuration }
if ($Install) {
    if (-not $Package) { throw '-Install requires -Package in the same qualification run.' }
    & (Join-Path $PSScriptRoot 'Install.ps1')
}

$configurationData = Get-KingmakerConfiguration -AllowMissingLoader
$gameAssembly = Join-Path $configurationData.ManagedDir 'Assembly-CSharp.dll'
$git = Get-GitMetadata
$projectStateText = Get-Content -LiteralPath (Join-Path $root 'PROJECT-STATE.md') -Raw
$runtimeQualification = if ($projectStateText -match '(?im)^- Runtime qualification: \*\*passed\*\*') {
    'RUNTIME-QUALIFIED according to the committed disposable-campaign evidence record'
}
else {
    'NOT RUNTIME-QUALIFIED; disposable Last Azlanti campaign smoke test required'
}
$buildReportPath = Join-Path $root 'artifacts\qualification\build.json'
$testReportPath = Join-Path $root 'artifacts\qualification\tests.json'
$contractReportPath = Join-Path $root 'artifacts\qualification\contracts.json'
$uiContractReportPath = Join-Path $root 'artifacts\qualification\game-over-load-contracts.json'
$packageReportPath = Join-Path $root 'artifacts\qualification\package.json'
$validationReportPath = Join-Path $root 'artifacts\qualification\package-validation.json'
$installReportPath = Join-Path $root 'artifacts\qualification\install.json'
$buildReport = if (Test-Path -LiteralPath $buildReportPath) { Get-Content -LiteralPath $buildReportPath -Raw | ConvertFrom-Json } else { $null }
$testReport = if (Test-Path -LiteralPath $testReportPath) { Get-Content -LiteralPath $testReportPath -Raw | ConvertFrom-Json } else { $null }
$contractReport = if (Test-Path -LiteralPath $contractReportPath) { Get-Content -LiteralPath $contractReportPath -Raw | ConvertFrom-Json } else { $null }
$uiContractReport = if (Test-Path -LiteralPath $uiContractReportPath) { Get-Content -LiteralPath $uiContractReportPath -Raw | ConvertFrom-Json } else { $null }
$packageReport = if (Test-Path -LiteralPath $packageReportPath) { Get-Content -LiteralPath $packageReportPath -Raw | ConvertFrom-Json } else { $null }
$validationReport = if (Test-Path -LiteralPath $validationReportPath) { Get-Content -LiteralPath $validationReportPath -Raw | ConvertFrom-Json } else { $null }
$installReport = if (Test-Path -LiteralPath $installReportPath) { Get-Content -LiteralPath $installReportPath -Raw | ConvertFrom-Json } else { $null }
# Credit earlier records only when they describe the current candidate: a well-formed build receipt matching the selected
# configuration's DLL on disk and the current build inputs; contract records (of any format) naming that DLL, the current
# game assembly and the loader components now configured; and a package whose ZIP, package record and validation record
# describe that DLL and whose copied repository files are unchanged. Anything else is reported as not current.
function Get-RecordField($Object, [string[]] $Path) {
    foreach ($name in $Path) {
        if ($null -eq $Object -or -not $Object.PSObject.Properties[$name]) { return $null }
        $Object = $Object.$name
    }
    return $Object
}
$selectedDll = Join-Path $root "artifacts\bin\$Configuration\KingmakerLastAzlantiPreserver\KingmakerLastAzlantiPreserver.dll"
$buildCurrent = $false
$buildProblem = 'no build record or DLL for this configuration'
if ($buildReport -and (Test-Path -LiteralPath $selectedDll)) {
    try { Assert-PinnedBuildReceipt $buildReport $selectedDll $Configuration; $buildCurrent = $true; $buildProblem = $null }
    catch { $buildProblem = $_.Exception.Message }
}
if (-not $buildCurrent) { $buildReport = $null }
$currentDllSha = if ($buildCurrent) { [string] $buildReport.dll_sha256 } else { $null }
function Get-OptionalSha256([string] $Path) { if (Test-Path -LiteralPath $Path) { return Get-Sha256 $Path } return 'missing' }
$currentGameSha = Get-Sha256 $gameAssembly
$currentUmmSha = Get-OptionalSha256 (Join-Path $configurationData.UnityModManagerDir 'UnityModManager.dll')
$currentHarmony2Sha = Get-OptionalSha256 (Join-Path $configurationData.UnityModManagerDir '0Harmony.dll')
$currentHarmony12Sha = Get-OptionalSha256 (Join-Path $configurationData.UnityModManagerDir '0Harmony12.dll')
# Both contract records must come from one binding-aware verification (same run, loaded product and Harmony2 recorded)
# under the loader components configured now; earlier-format or mixed records are not current.
$contractsCurrent = [bool]($currentDllSha -and $contractReport -and $uiContractReport -and
    [string] (Get-RecordField $contractReport @('verification_run_id')) -and
    [string] (Get-RecordField $contractReport @('verification_run_id')) -eq [string] (Get-RecordField $uiContractReport @('verification_run_id')) -and
    [string] (Get-RecordField $contractReport @('mod_dll_loaded_mvid')) -and [string] (Get-RecordField $uiContractReport @('mod_dll', 'loaded_mvid')) -and
    [string] (Get-RecordField $uiContractReport @('harmony2', 'loaded_mvid')) -and
    [string] (Get-RecordField $contractReport @('unity_mod_manager_sha256')) -eq $currentUmmSha -and
    [string] (Get-RecordField $contractReport @('legacy_harmony_sha256')) -eq $currentHarmony12Sha -and
    [string] (Get-RecordField $contractReport @('harmony2_sha256')) -eq $currentHarmony2Sha -and
    [string] (Get-RecordField $contractReport @('mod_dll_sha256')) -eq $currentDllSha -and
    [string] (Get-RecordField $uiContractReport @('mod_dll', 'sha256')) -eq $currentDllSha -and
    [string] (Get-RecordField $contractReport @('assembly_sha256')) -eq $currentGameSha -and
    [string] (Get-RecordField $uiContractReport @('assembly_csharp', 'sha256')) -eq $currentGameSha -and
    [string] (Get-RecordField $uiContractReport @('unity_mod_manager', 'sha256')) -eq $currentUmmSha -and
    [string] (Get-RecordField $uiContractReport @('harmony2', 'sha256')) -eq $currentHarmony2Sha -and
    [string] (Get-RecordField $uiContractReport @('legacy_harmony', 'sha256')) -eq $currentHarmony12Sha)
if (-not $contractsCurrent) { $contractReport = $null; $uiContractReport = $null }
$packageCurrent = $false
$recordedPackagePath = [string] (Get-RecordField $packageReport @('package_path'))
if ($currentDllSha -and $packageReport -and $validationReport -and $recordedPackagePath -and (Test-Path -LiteralPath $recordedPackagePath)) {
    $zipSha = Get-Sha256 $recordedPackagePath
    $packageCurrent = $zipSha -eq [string] (Get-RecordField $packageReport @('package_sha256')) -and
        $zipSha -eq [string] (Get-RecordField $validationReport @('package_sha256')) -and
        [string] (Get-RecordField $packageReport @('dll_sha256')) -eq $currentDllSha -and
        [string] (Get-RecordField $validationReport @('dll_sha256')) -eq $currentDllSha -and
        [string] (Get-RecordField $packageReport @('package_inputs_sha256')) -eq (Get-PackageInputFingerprint) -and
        [string] (Get-RecordField $packageReport @('build_inputs_sha256')) -eq [string] $buildReport.build_inputs_sha256 -and
        [string] (Get-RecordField $packageReport @('package_rules_sha256')) -eq (Get-PackageRuleFingerprint)
}
if (-not $packageCurrent) { $packageReport = $null; $validationReport = $null }
# A test record counts only for the production DLL it ran against.
# A test record counts only when the tests ran in this qualification (-Test) against the current DLL; skipped tests are
# reported as not run, so a cached result never carries over to another loader configuration or suite.
$testsCurrent = [bool]($Test -and $currentDllSha -and $testReport -and [string] (Get-RecordField $testReport @('dll_sha256')) -eq $currentDllSha -and [string] (Get-RecordField $testReport @('status')) -eq 'passed')
if (-not $testsCurrent) { $testReport = $null }
# The stages requested in this run must have produced current evidence for the same candidate.
$stageProblems = @()
if (($Build -or $Test -or $VerifyContracts -or $Package) -and -not $buildCurrent) { $stageProblems += "build record not current ($buildProblem)" }
if ($Test -and -not $testsCurrent) { $stageProblems += 'tests did not run against the current DLL' }
if ($VerifyContracts -and -not $contractsCurrent) { $stageProblems += 'contract records are not a current verification of this DLL and loader' }
if ($Package -and -not $packageCurrent) { $stageProblems += 'package is not current for this DLL' }
$installMatchesCandidate = $false
if ($installReport -and $buildReport -and
    $installReport.status -eq 'passed' -and
    -not [string]::IsNullOrWhiteSpace([string] $installReport.dll_sha256) -and
    [string]::Equals(
        [string] $installReport.dll_sha256,
        [string] $buildReport.dll_sha256,
        [StringComparison]::OrdinalIgnoreCase)) {
    $installMatchesCandidate = $true
}

$summary = [ordered]@{
    status = if ($stageProblems.Count -eq 0) { 'non-runtime-qualification-passed' } else { 'failed: ' + ($stageProblems -join '; ') }
    branch = $git.Branch
    commit_sha = $git.Commit
    dirty = $git.Dirty
    assembly_csharp_sha256 = if ($contractReport) { $contractReport.assembly_sha256 } else { Get-Sha256 $gameAssembly }
    assembly_csharp_mvid = if ($contractReport) { $contractReport.assembly_mvid } else { Get-AssemblyMvid $gameAssembly }
    game_over_hook = if ($contractReport) { $contractReport.game_over_hook } else { 'not verified in this run' }
    deletion_hook = if ($contractReport) { $contractReport.deletion_hook } else { 'not verified in this run' }
    game_over_view_lifecycle = if ($uiContractReport) { $uiContractReport.exact_ui_contract.legacy_lifecycle } else { 'not verified in this run' }
    game_over_ui_hook = if ($uiContractReport) { $uiContractReport.exact_ui_contract.patched_lifecycle } else { 'not verified in this run' }
    controller_ui_hook = if ($uiContractReport) { $uiContractReport.exact_ui_contract.controller_lifecycle } else { 'not verified in this run' }
    unity_mod_manager_identity = if ($uiContractReport) { $uiContractReport.unity_mod_manager.identity } else { 'not verified in this run' }
    unity_mod_manager_sha256 = if ($uiContractReport) { $uiContractReport.unity_mod_manager.sha256 } else { 'not verified in this run' }
    legacy_harmony_identity = if ($uiContractReport) { $uiContractReport.legacy_harmony.identity } else { 'not verified in this run' }
    legacy_harmony_sha256 = if ($uiContractReport) { $uiContractReport.legacy_harmony.sha256 } else { 'not verified in this run' }
    loader_profile = if ($uiContractReport) { $uiContractReport.loader_profile } else { 'not verified in this run' }
    harmony2_identity = if ($uiContractReport) { $uiContractReport.harmony2.identity } else { 'not verified in this run' }
    harmony2_sha256 = if ($uiContractReport) { $uiContractReport.harmony2.sha256 } else { 'not verified in this run' }
    contracts_verified_dll_sha256 = if ($uiContractReport) { $uiContractReport.mod_dll.sha256 } else { 'not verified for the current DLL' }
    core_patch_ownership = if ($uiContractReport) { $uiContractReport.harmony_ownership.core_owned_after_application } else { $false }
    optional_patch_ownership = if ($uiContractReport) { $uiContractReport.harmony_ownership.optional_owned_after_application } else { $false }
    optional_unpatch_preserved_core = if ($uiContractReport) { $uiContractReport.harmony_ownership.core_owned_after_optional_unpatch } else { $false }
    test_count = if ($testReport) { $testReport.total } else { 0 }
    test_result = if ($testReport) { $testReport.status } elseif (-not $Test) { 'not run in this qualification' } else { 'not run for the current DLL' }
    compiler_warning_count = if ($buildReport) { $buildReport.compiler_warnings } else { $null }
    compiler_error_count = if ($buildReport) { $buildReport.compiler_errors } else { $null }
    dll_path = if ($buildReport) { $buildReport.dll_path } else { $null }
    dll_sha256 = if ($buildReport) { $buildReport.dll_sha256 } else { $null }
    package_path = if ($packageReport) { $packageReport.package_path } else { $null }
    package_sha256 = if ($packageReport) { $packageReport.package_sha256 } else { $null }
    package_validation = if ($validationReport) { $validationReport.status } else { 'not run for the current DLL' }
    build_inputs_sha256 = if ($buildReport) { $buildReport.build_inputs_sha256 } else { $null }
    build_record_current = $buildCurrent
    build_record_problem = $buildProblem
    contracts_current_for_candidate = $contractsCurrent
    package_current_for_candidate = $packageCurrent
    installation_matches_candidate = $installMatchesCandidate
    installed_target = if ($installMatchesCandidate) {
        $installReport.target
    }
    elseif ($installReport) {
        'existing install evidence is for a different DLL; this candidate is not yet recorded as installed'
    }
    else {
        'not installed in this run/session'
    }
    runtime_qualification = $runtimeQualification
}
Write-JsonFile (Join-Path $root 'artifacts\qualification\qualification-summary.json') $summary

Write-Host '=== Last Azlanti Preserver non-runtime qualification ==='
Write-Host "Branch: $($summary.branch)"
Write-Host "Commit SHA: $($summary.commit_sha)"
Write-Host "Working tree dirty: $($summary.dirty)"
Write-Host "Assembly-CSharp SHA-256: $($summary.assembly_csharp_sha256)"
Write-Host "Assembly-CSharp MVID: $($summary.assembly_csharp_mvid)"
Write-Host "Game-over hook: $($summary.game_over_hook)"
Write-Host "Deletion hook: $($summary.deletion_hook)"
Write-Host "Game-over view lifecycle: $($summary.game_over_view_lifecycle)"
Write-Host "Game-over UI hook: $($summary.game_over_ui_hook)"
Write-Host "Controller UI hook: $($summary.controller_ui_hook)"
Write-Host "Unity Mod Manager: $($summary.unity_mod_manager_identity)"
Write-Host "Legacy Harmony: $($summary.legacy_harmony_identity)"
Write-Host "Loader profile: $($summary.loader_profile); Harmony2: $($summary.harmony2_identity) $($summary.harmony2_sha256)"
Write-Host "Contracts verified on DLL: $($summary.contracts_verified_dll_sha256)"
Write-Host "Build record current: $($summary.build_record_current) $($summary.build_record_problem)"
Write-Host "Harmony ownership core/optional/isolation: $($summary.core_patch_ownership)/$($summary.optional_patch_ownership)/$($summary.optional_unpatch_preserved_core)"
Write-Host "Tests: $($summary.test_count) ($($summary.test_result))"
Write-Host "Compiler warnings/errors: $($summary.compiler_warning_count)/$($summary.compiler_error_count)"
Write-Host "DLL: $($summary.dll_path)"
Write-Host "DLL SHA-256: $($summary.dll_sha256)"
Write-Host "Package: $($summary.package_path)"
Write-Host "Package SHA-256: $($summary.package_sha256)"
Write-Host "Package validation: $($summary.package_validation)"
Write-Host "Installation matches candidate: $($summary.installation_matches_candidate)"
Write-Host "Installed target: $($summary.installed_target)"
Write-Host "Runtime qualification: $($summary.runtime_qualification)"
if ($stageProblems.Count -gt 0) { throw "Qualification failed: $($stageProblems -join '; ')" }
