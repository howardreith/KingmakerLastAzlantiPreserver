[CmdletBinding()]
param([ValidateSet('Debug','Release')][string] $Configuration = 'Release')

. (Join-Path $PSScriptRoot 'Common.ps1')
$root = Get-RepositoryRoot
$dll = Join-Path $root "artifacts\bin\$Configuration\KingmakerLastAzlantiPreserver\KingmakerLastAzlantiPreserver.dll"
Assert-FileExists $dll 'Built mod DLL'
$loaderReceiptPath = Join-Path $root 'artifacts\qualification\build.json'
Assert-FileExists $loaderReceiptPath 'Build receipt with pinned loader references'
$receiptBytes = [IO.File]::ReadAllBytes($loaderReceiptPath)
$loaderReceipt = [Text.Encoding]::UTF8.GetString($receiptBytes).TrimStart([char]0xFEFF) | ConvertFrom-Json
Assert-PinnedBuildReceipt $loaderReceipt $dll $Configuration
$packageInputs = Get-PackageInputFingerprint
$packageRules = Get-PackageRuleFingerprint

$packageDirectory = Join-Path $root 'artifacts\packages'
$zipPath = Join-Path $packageDirectory 'KingmakerLastAzlantiPreserver-0.1.4.zip'
Assert-PathWithin $zipPath $root 'Package path'
# Staging, the new archive and its validation report live in a folder private to this invocation. The accepted ZIP and
# its records are replaced only after the new archive passed validation and its archived documents match the repository
# files verified before staging; any failure leaves the previous ZIP and records exactly as they were.
$private = Join-Path $root ('artifacts\.package-' + [Guid]::NewGuid().ToString('N'))
$keepPrivate = $false
Assert-PathWithin $private $root 'Private package folder'
try {
    $stageRoot = Join-Path $private 'staging'
    $stage = Join-Path $stageRoot 'KingmakerLastAzlantiPreserver'
    [IO.Directory]::CreateDirectory((Join-Path $stage 'licenses')) | Out-Null
    Copy-Item -LiteralPath $dll -Destination (Join-Path $stage 'KingmakerLastAzlantiPreserver.dll')
    foreach ($name in @('Info.json','LICENSE','README.md','THIRD-PARTY-NOTICES.md')) {
        Copy-Item -LiteralPath (Join-Path $root $name) -Destination (Join-Path $stage $name)
    }
    Copy-Item -LiteralPath (Join-Path $root 'licenses\FIRST-AZLANTI-MIT.txt') -Destination (Join-Path $stage 'licenses\FIRST-AZLANTI-MIT.txt')

    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $newZip = Join-Path $private 'KingmakerLastAzlantiPreserver-0.1.4.zip'
    $zipStream = [IO.File]::Open($newZip, [IO.FileMode]::CreateNew, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
    try {
        $archive = [IO.Compression.ZipArchive]::new($zipStream, [IO.Compression.ZipArchiveMode]::Create, $true)
        try {
            $files = Get-ChildItem -LiteralPath $stageRoot -File -Recurse | Sort-Object { $_.FullName.Substring($stageRoot.Length + 1) }
            foreach ($file in $files) {
                $entryName = $file.FullName.Substring($stageRoot.Length + 1).Replace('\','/')
                $entry = $archive.CreateEntry($entryName, [IO.Compression.CompressionLevel]::Optimal)
                $entry.LastWriteTime = [DateTimeOffset]::new(2000, 1, 1, 0, 0, 0, [TimeSpan]::Zero)
                $source = [IO.File]::OpenRead($file.FullName)
                $output = $entry.Open()
                try { $source.CopyTo($output) }
                finally { $output.Dispose(); $source.Dispose() }
            }
        }
        finally { $archive.Dispose() }
    }
    finally { $zipStream.Dispose() }

    # The archived DLL must be the exact DLL the receipt describes, read back from the new archive.
    $report = Join-Path $private 'package-validation.json'
    & (Join-Path $PSScriptRoot 'Validate-Package.ps1') -PackagePath $newZip -ExpectedDllSha256 $loaderReceipt.dll_sha256 -ReportPath $report
    $validated = Get-Content -LiteralPath $report -Raw | ConvertFrom-Json
    $newZipSha = Get-Sha256 $newZip
    if ([string] $validated.dll_sha256 -cne $loaderReceipt.dll_sha256 -or $newZipSha -cne [string] $validated.package_sha256) {
        throw 'Package records disagree; the package was not accepted.'
    }
    # The packaged documents, read back from the validated archive bytes, must be the repository files verified before
    # staging (a file restaged meanwhile cannot reach the package).
    if ((Get-PackageInputFingerprintFromArchive $newZip) -cne $packageInputs) {
        throw 'Package files changed during staging; the archived documents differ from the verified repository files. The package was not accepted.'
    }
    $result = [ordered]@{
        status = 'passed'
        package_path = $zipPath
        package_sha256 = $newZipSha
        dll_sha256 = [string] $validated.dll_sha256
        build_inputs_sha256 = $loaderReceipt.build_inputs_sha256
        package_inputs_sha256 = $packageInputs
        package_rules_sha256 = $packageRules
        producing_commit = $loaderReceipt.source_commit
        producing_dirty = $loaderReceipt.source_dirty
        producing_configuration = $loaderReceipt.configuration
        validated_package_sha256 = $validated.package_sha256
        validated_dll_sha256 = $validated.dll_sha256
    }
    # The validation receipt names the published archive (package_path, the established field, and package); both records
    # are prepared privately before any public file changes.
    $validated | Add-Member -NotePropertyName package_path -NotePropertyValue $zipPath -Force
    $validated | Add-Member -NotePropertyName package -NotePropertyValue $zipPath -Force
    $validationFinal = Join-Path $private 'package-validation.final.json'
    $resultFinal = Join-Path $private 'package.final.json'
    Write-JsonFile $validationFinal $validated
    Write-JsonFile $resultFinal $result
    # Publication of the set {ZIP, package-validation.json, package.json}: one publisher at a time (an exclusive lock file
    # removed when its handle closes); backup acquisition, placement and rollback are one recovery scope that tracks
    # exactly the files this invocation moved and placed; if restoration itself fails, the backups are kept and named.
    [IO.Directory]::CreateDirectory($packageDirectory) | Out-Null
    $qualification = Join-Path $root 'artifacts\qualification'
    [IO.Directory]::CreateDirectory($qualification) | Out-Null
    $publishLock = Enter-PackagePublishLock $packageDirectory
    try {
        $previous = Join-Path $private 'previous'; New-Item -ItemType Directory -Path $previous | Out-Null
        $pairs = @(@($newZip, $zipPath), @($validationFinal, (Join-Path $qualification 'package-validation.json')), @($resultFinal, (Join-Path $qualification 'package.json')))
        $moved = New-Object System.Collections.Generic.List[string]
        $placed = New-Object System.Collections.Generic.List[string]
        try {
            foreach ($pair in $pairs) {
                if (Test-Path -LiteralPath $pair[1]) { [IO.File]::Move($pair[1], (Join-Path $previous ([IO.Path]::GetFileName($pair[1])))); $moved.Add($pair[1]) }
            }
            foreach ($pair in $pairs) {
                [IO.File]::Move($pair[0], $pair[1]); $placed.Add($pair[1])
                if ($pair[1] -ceq $zipPath -and (Get-Sha256 $zipPath) -cne $newZipSha) { throw 'The published package differs from the validated archive.' }
            }
        }
        catch {
            $failure = $_
            $unrestored = @()
            for ($i = $placed.Count - 1; $i -ge 0; $i--) { try { [IO.File]::Delete($placed[$i]) } catch { $unrestored += $placed[$i] } }
            for ($i = $moved.Count - 1; $i -ge 0; $i--) {
                try { [IO.File]::Move((Join-Path $previous ([IO.Path]::GetFileName($moved[$i]))), $moved[$i]) } catch { $unrestored += $moved[$i] }
            }
            if ($unrestored.Count -gt 0) {
                $keepPrivate = $true
                throw "Publication failed ($($failure.Exception.Message)) and the previous package set could not be fully restored ($($unrestored -join ', ')); the previous files are kept in $previous."
            }
            throw $failure
        }
    }
    finally { $publishLock.Dispose() }
}
finally {
    if (-not $keepPrivate -and [IO.Directory]::Exists($private)) { [IO.Directory]::Delete($private, $true) }
}
Write-Host "Package: $zipPath"
Write-Host "Package SHA-256: $($result.package_sha256)"
