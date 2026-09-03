[CmdletBinding(SupportsShouldProcess=$true)]
param([string] $PackagePath)

. (Join-Path $PSScriptRoot 'Common.ps1')
$root = Get-RepositoryRoot
$configuration = Get-KingmakerConfiguration
if (-not $PackagePath) { $PackagePath = Join-Path $root 'artifacts\packages\KingmakerLastAzlantiPreserver-0.1.0.zip' }
$PackagePath = [IO.Path]::GetFullPath($PackagePath)
& (Join-Path $PSScriptRoot 'Validate-Package.ps1') -PackagePath $PackagePath

$target = [IO.Path]::GetFullPath((Join-Path $configuration.ModsDir 'KingmakerLastAzlantiPreserver'))
if (-not [string]::Equals((Split-Path -Parent $target).TrimEnd('\'), $configuration.ModsDir.TrimEnd('\'), [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Install target validation failed.'
}
Write-Host "Validated install target (only): $target"
if (-not $PSCmdlet.ShouldProcess($target, 'Transactionally install Last Azlanti Preserver')) {
    Write-Host 'WhatIf completed: the package is valid and no game files were changed.'
    return
}
if (Get-Process -Name 'Kingmaker' -ErrorAction SilentlyContinue) { throw 'Exit Pathfinder: Kingmaker before installation.' }

Add-Type -AssemblyName System.IO.Compression.FileSystem
$temporaryRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$temporary = [IO.Path]::GetFullPath((Join-Path $temporaryRoot ('KingmakerLastAzlantiPreserver-install-' + [Guid]::NewGuid().ToString('N'))))
Assert-PathWithin $temporary $temporaryRoot 'Install staging directory'
[IO.Directory]::CreateDirectory($temporary) | Out-Null
try {
    [IO.Compression.ZipFile]::ExtractToDirectory($PackagePath, $temporary)
    $source = Join-Path $temporary 'KingmakerLastAzlantiPreserver'
    Assert-DirectoryExists $source 'Extracted mod directory'
    $sourceDll = Join-Path $source 'KingmakerLastAzlantiPreserver.dll'
    $sourceHash = Get-Sha256 $sourceDll
    $backup = Join-Path $temporary 'previous-installation'
    Assert-PathWithin $backup $temporary 'Install rollback directory'
    $oldMoved = $false
    try {
        [IO.Directory]::CreateDirectory($configuration.ModsDir) | Out-Null
        if (Test-Path -LiteralPath $target) {
            Move-Item -LiteralPath $target -Destination $backup
            $oldMoved = $true
        }
        Move-Item -LiteralPath $source -Destination $target
        $installedDll = Join-Path $target 'KingmakerLastAzlantiPreserver.dll'
        Assert-FileExists $installedDll 'Installed mod DLL'
        if ((Get-Sha256 $installedDll) -ne $sourceHash) { throw 'Installed DLL hash differs from the validated package.' }
    }
    catch {
        $failure = $_
        if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Recurse -Force }
        if ($oldMoved -and (Test-Path -LiteralPath $backup)) { Move-Item -LiteralPath $backup -Destination $target }
        throw "Installation failed; rollback was attempted: $($failure.Exception.Message)"
    }
    $result = [ordered]@{ status='passed'; target=$target; dll_sha256=$sourceHash; package=$PackagePath }
    Write-JsonFile (Join-Path $root 'artifacts\qualification\install.json') $result
    Write-Host "Installed only: $target"
    Write-Host "DLL SHA-256: $sourceHash"
}
finally {
    if ([IO.Directory]::Exists($temporary)) { [IO.Directory]::Delete($temporary, $true) }
}
