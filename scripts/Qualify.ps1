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
if ($VerifyContracts) { & (Join-Path $PSScriptRoot 'Verify-KingmakerContracts.ps1') }
if ($Package) { & (Join-Path $PSScriptRoot 'Package.ps1') -Configuration $Configuration }
if ($Install) {
    if (-not $Package) { throw '-Install requires -Package in the same qualification run.' }
    & (Join-Path $PSScriptRoot 'Install.ps1')
}

$configurationData = Get-KingmakerConfiguration
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
    status = 'non-runtime-qualification-passed'
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
    core_patch_ownership = if ($uiContractReport) { $uiContractReport.harmony_ownership.core_owned_after_application } else { $false }
    optional_patch_ownership = if ($uiContractReport) { $uiContractReport.harmony_ownership.optional_owned_after_application } else { $false }
    optional_unpatch_preserved_core = if ($uiContractReport) { $uiContractReport.harmony_ownership.core_owned_after_optional_unpatch } else { $false }
    test_count = if ($testReport) { $testReport.total } else { 0 }
    test_result = if ($testReport) { $testReport.status } else { 'not run' }
    compiler_warning_count = if ($buildReport) { $buildReport.compiler_warnings } else { $null }
    compiler_error_count = if ($buildReport) { $buildReport.compiler_errors } else { $null }
    dll_path = if ($buildReport) { $buildReport.dll_path } else { $null }
    dll_sha256 = if ($buildReport) { $buildReport.dll_sha256 } else { $null }
    package_path = if ($packageReport) { $packageReport.package_path } else { $null }
    package_sha256 = if ($packageReport) { $packageReport.package_sha256 } else { $null }
    package_validation = if ($validationReport) { $validationReport.status } else { 'not run' }
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
