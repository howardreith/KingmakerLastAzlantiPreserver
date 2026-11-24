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
$stageRoot = Join-Path $root 'artifacts\staging'
$stage = Join-Path $stageRoot 'KingmakerLastAzlantiPreserver'
Assert-PathWithin $stageRoot $root 'Package staging root'
if (Test-Path -LiteralPath $stageRoot) { Remove-Item -LiteralPath $stageRoot -Recurse -Force }
[IO.Directory]::CreateDirectory((Join-Path $stage 'licenses')) | Out-Null
Copy-Item -LiteralPath $dll -Destination (Join-Path $stage 'KingmakerLastAzlantiPreserver.dll')
foreach ($name in @('Info.json','LICENSE','README.md','THIRD-PARTY-NOTICES.md')) {
    Copy-Item -LiteralPath (Join-Path $root $name) -Destination (Join-Path $stage $name)
}
Copy-Item -LiteralPath (Join-Path $root 'licenses\FIRST-AZLANTI-MIT.txt') -Destination (Join-Path $stage 'licenses\FIRST-AZLANTI-MIT.txt')

$packageDirectory = Join-Path $root 'artifacts\packages'
[IO.Directory]::CreateDirectory($packageDirectory) | Out-Null
$zipPath = Join-Path $packageDirectory 'KingmakerLastAzlantiPreserver-0.1.3.zip'
Assert-PathWithin $zipPath $root 'Package path'
if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Force }

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
if ((Get-PackageInputFingerprint $stage) -cne $packageInputs) { throw 'Package files changed during staging; the package was not built.' }
$zipStream = [IO.File]::Open($zipPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
try {
    $archive = [IO.Compression.ZipArchive]::new($zipStream, [IO.Compression.ZipArchiveMode]::Create, $true)
    try {
        $files = Get-ChildItem -LiteralPath $stageRoot -File -Recurse | Sort-Object { $_.FullName.Substring($stageRoot.Length + 1) }
        foreach ($file in $files) {
            $entryName = $file.FullName.Substring($stageRoot.Length + 1).Replace('\','/')
            $entry = $archive.CreateEntry($entryName, [IO.Compression.CompressionLevel]::Optimal)
            $entry.LastWriteTime = [DateTimeOffset]::new(2000, 1, 1, 0, 0, 0, [TimeSpan]::Zero)
            $input = [IO.File]::OpenRead($file.FullName)
            $output = $entry.Open()
            try { $input.CopyTo($output) }
            finally { $output.Dispose(); $input.Dispose() }
        }
    }
    finally { $archive.Dispose() }
}
finally { $zipStream.Dispose() }

# The archived DLL must be the exact DLL the receipt describes, read back from the produced ZIP.
& (Join-Path $PSScriptRoot 'Validate-Package.ps1') -PackagePath $zipPath -ExpectedDllSha256 $loaderReceipt.dll_sha256
$validated = Get-Content -LiteralPath (Join-Path $root 'artifacts\qualification\package-validation.json') -Raw | ConvertFrom-Json
$result = [ordered]@{
    status = 'passed'
    package_path = $zipPath
    package_sha256 = Get-Sha256 $zipPath
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
if ($result.dll_sha256 -cne $loaderReceipt.dll_sha256 -or (Get-Sha256 $zipPath) -cne [string] $validated.package_sha256) {
    throw 'Package records disagree; the package was not accepted.'
}
Write-JsonFile (Join-Path $root 'artifacts\qualification\package.json') $result
Write-Host "Package: $zipPath"
Write-Host "Package SHA-256: $($result.package_sha256)"
