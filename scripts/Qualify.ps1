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
$buildReportPath = Join-Path $root 'artifacts\qualification\build.json'
$testReportPath = Join-Path $root 'artifacts\qualification\tests.json'
$contractReportPath = Join-Path $root 'artifacts\qualification\contracts.json'
$packageReportPath = Join-Path $root 'artifacts\qualification\package.json'
$validationReportPath = Join-Path $root 'artifacts\qualification\package-validation.json'
$installReportPath = Join-Path $root 'artifacts\qualification\install.json'
$buildReport = if (Test-Path -LiteralPath $buildReportPath) { Get-Content -LiteralPath $buildReportPath -Raw | ConvertFrom-Json } else { $null }
$testReport = if (Test-Path -LiteralPath $testReportPath) { Get-Content -LiteralPath $testReportPath -Raw | ConvertFrom-Json } else { $null }
$contractReport = if (Test-Path -LiteralPath $contractReportPath) { Get-Content -LiteralPath $contractReportPath -Raw | ConvertFrom-Json } else { $null }
$packageReport = if (Test-Path -LiteralPath $packageReportPath) { Get-Content -LiteralPath $packageReportPath -Raw | ConvertFrom-Json } else { $null }
$validationReport = if (Test-Path -LiteralPath $validationReportPath) { Get-Content -LiteralPath $validationReportPath -Raw | ConvertFrom-Json } else { $null }
$installReport = if (Test-Path -LiteralPath $installReportPath) { Get-Content -LiteralPath $installReportPath -Raw | ConvertFrom-Json } else { $null }

$summary = [ordered]@{
    status = 'non-runtime-qualification-passed'
    branch = $git.Branch
    commit_sha = $git.Commit
    dirty = $git.Dirty
    assembly_csharp_sha256 = if ($contractReport) { $contractReport.assembly_sha256 } else { Get-Sha256 $gameAssembly }
    assembly_csharp_mvid = if ($contractReport) { $contractReport.assembly_mvid } else { Get-AssemblyMvid $gameAssembly }
    game_over_hook = if ($contractReport) { $contractReport.game_over_hook } else { 'not verified in this run' }
    deletion_hook = if ($contractReport) { $contractReport.deletion_hook } else { 'not verified in this run' }
    test_count = if ($testReport) { $testReport.total } else { 0 }
    test_result = if ($testReport) { $testReport.status } else { 'not run' }
    compiler_warning_count = if ($buildReport) { $buildReport.compiler_warnings } else { $null }
    compiler_error_count = if ($buildReport) { $buildReport.compiler_errors } else { $null }
    dll_path = if ($buildReport) { $buildReport.dll_path } else { $null }
    dll_sha256 = if ($buildReport) { $buildReport.dll_sha256 } else { $null }
    package_path = if ($packageReport) { $packageReport.package_path } else { $null }
    package_sha256 = if ($packageReport) { $packageReport.package_sha256 } else { $null }
    package_validation = if ($validationReport) { $validationReport.status } else { 'not run' }
    installed_target = if ($installReport) { $installReport.target } else { 'not installed in this run/session' }
    runtime_qualification = 'NOT RUNTIME-QUALIFIED; disposable Last Azlanti campaign smoke test required'
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
Write-Host "Tests: $($summary.test_count) ($($summary.test_result))"
Write-Host "Compiler warnings/errors: $($summary.compiler_warning_count)/$($summary.compiler_error_count)"
Write-Host "DLL: $($summary.dll_path)"
Write-Host "DLL SHA-256: $($summary.dll_sha256)"
Write-Host "Package: $($summary.package_path)"
Write-Host "Package SHA-256: $($summary.package_sha256)"
Write-Host "Package validation: $($summary.package_validation)"
Write-Host "Installed target: $($summary.installed_target)"
Write-Host "Runtime qualification: $($summary.runtime_qualification)"
