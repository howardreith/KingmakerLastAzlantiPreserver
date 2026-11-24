[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string] $PackagePath,
    [string] $ReportPath = 'artifacts\qualification\package-validation.json',
    # When packaging, the DLL SHA-256 recorded by the build receipt: the archived DLL must be exactly that DLL.
    [string] $ExpectedDllSha256
)

. (Join-Path $PSScriptRoot 'Common.ps1')
$root = Get-RepositoryRoot
$PackagePath = [IO.Path]::GetFullPath($PackagePath)
Assert-FileExists $PackagePath 'Package ZIP'
if ($PSBoundParameters.ContainsKey('ExpectedDllSha256') -and $ExpectedDllSha256 -cnotmatch '^[0-9a-f]{64}$') {
    throw 'ExpectedDllSha256 must be a lowercase SHA-256 string.'
}
# Inspect and hash one immutable private copy, so the recorded ZIP hash and the inspected contents are the same bytes
# even if the caller's file is replaced meanwhile.
$privateDirectory = Join-Path ([IO.Path]::GetTempPath()) ('klap-validate-' + [Guid]::NewGuid().ToString('N'))
$inspected = Join-Path $privateDirectory 'package.zip'
try {
[void][IO.Directory]::CreateDirectory($privateDirectory)
[IO.File]::Copy($PackagePath, $inspected)
$expectedInfo = Get-Content -LiteralPath (Join-Path $root 'Info.json') -Raw | ConvertFrom-Json
$allowed = @(
    'KingmakerLastAzlantiPreserver/Info.json',
    'KingmakerLastAzlantiPreserver/KingmakerLastAzlantiPreserver.dll',
    'KingmakerLastAzlantiPreserver/LICENSE',
    'KingmakerLastAzlantiPreserver/README.md',
    'KingmakerLastAzlantiPreserver/THIRD-PARTY-NOTICES.md',
    'KingmakerLastAzlantiPreserver/licenses/FIRST-AZLANTI-MIT.txt'
)
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead($inspected)
try {
    foreach ($directory in @($archive.Entries | Where-Object { -not $_.FullName -or $_.FullName.EndsWith('/') -or $_.FullName.EndsWith('\') })) {
        $directoryStream = $directory.Open()
        try { $decodedByte = $directoryStream.ReadByte() } finally { $directoryStream.Dispose() }
        if ($directory.Length -ne 0 -or $decodedByte -ne -1 -or
            @('KingmakerLastAzlantiPreserver/', 'KingmakerLastAzlantiPreserver/licenses/') -cnotcontains $directory.FullName) {
            throw "Unexpected or data-bearing package directory record: '$($directory.FullName)'"
        }
    }
    $files = @($archive.Entries | Where-Object { $_.FullName -and -not $_.FullName.EndsWith('/') -and -not $_.FullName.EndsWith('\') })
    $names = @($files | ForEach-Object { $_.FullName.Replace('\','/') } | Sort-Object)
    if ($files.Count -ne $allowed.Count) { throw "Expected exactly $($allowed.Count) package files; found $($files.Count)." }
    if (@(Compare-Object ($allowed | Sort-Object) $names).Count -ne 0) { throw 'Package allowlist mismatch.' }
    foreach ($entry in $files) {
        $segments = @($entry.FullName.Replace('\','/').Split('/'))
        if ($entry.Length -le 0 -or $segments -contains '..' -or $segments -contains '.' -or $segments -contains '' -or
            [IO.Path]::IsPathRooted($entry.FullName) -or $entry.FullName.Contains(':')) {
            throw "Unsafe or empty package entry: $($entry.FullName)"
        }
        $entryName = $entry.FullName.Replace('\','/')
        if ($entryName -ne 'KingmakerLastAzlantiPreserver/Info.json' -and $entryName -ne 'KingmakerLastAzlantiPreserver/KingmakerLastAzlantiPreserver.dll') {
            # Documentation and licence entries must be text: an assembly (or any binary) under an allowed text name
            # is refused, so the allow-list cannot carry a loader, Harmony or game DLL by renaming it.
            $textStream = $entry.Open()
            $textBuffer = [IO.MemoryStream]::new()
            try { $textStream.CopyTo($textBuffer); $textBytes = $textBuffer.ToArray() }
            finally { $textBuffer.Dispose(); $textStream.Dispose() }
            if (($textBytes.Length -ge 2 -and $textBytes[0] -eq 0x4D -and $textBytes[1] -eq 0x5A) -or [Array]::IndexOf($textBytes, [byte]0) -ge 0) {
                throw "Package text entry contains binary content: $entryName"
            }
            try { [void][Text.UTF8Encoding]::new($false, $true).GetString($textBytes) }
            catch { throw "Package text entry is not valid UTF-8 text: $entryName" }
        }
    }
    $infoEntry = $files | Where-Object { $_.FullName.Replace('\','/') -eq 'KingmakerLastAzlantiPreserver/Info.json' }
    $reader = [IO.StreamReader]::new($infoEntry.Open(), [Text.Encoding]::UTF8, $true)
    try { $info = $reader.ReadToEnd() | ConvertFrom-Json }
    finally { $reader.Dispose() }
    if ($info.Id -ne $expectedInfo.Id -or $info.Version -ne $expectedInfo.Version -or
        $info.AssemblyName -ne 'KingmakerLastAzlantiPreserver.dll' -or
        $info.EntryMethod -ne 'KingmakerLastAzlantiPreserver.Main.Load') {
        throw 'Packaged Info.json identity does not match the product.'
    }
    Assert-ProductManifest $info 'Packaged Info.json'
    $dllEntry = $files | Where-Object { $_.FullName.Replace('\','/') -eq 'KingmakerLastAzlantiPreserver/KingmakerLastAzlantiPreserver.dll' }
    $dllStream = $dllEntry.Open()
    $temporaryDll = [IO.Path]::Combine([IO.Path]::GetTempPath(), 'KingmakerLastAzlantiPreserver-validate-' + [Guid]::NewGuid().ToString('N') + '.dll')
    try {
        $temporaryStream = [IO.File]::Open($temporaryDll, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
        try { $dllStream.CopyTo($temporaryStream); $temporaryStream.Flush($true) }
        finally { $temporaryStream.Dispose() }
        $headerStream = [IO.File]::OpenRead($temporaryDll)
        try {
            if ($headerStream.ReadByte() -ne 0x4D -or $headerStream.ReadByte() -ne 0x5A) {
                throw 'Packaged DLL lacks an MZ header.'
            }
        }
        finally { $headerStream.Dispose() }
        $dllIdentity = Assert-PinnedAssemblyReferences ([IO.File]::ReadAllBytes($temporaryDll))
        $dllSha256 = Get-Sha256 $temporaryDll
        if ($ExpectedDllSha256 -and $dllSha256 -cne $ExpectedDllSha256) {
            throw "Archived DLL SHA-256 $dllSha256 does not match the build receipt's $ExpectedDllSha256."
        }
        $assemblyName = [Reflection.AssemblyName]::GetAssemblyName($temporaryDll)
        if ($assemblyName.Name -ne 'KingmakerLastAzlantiPreserver' -or $assemblyName.Version.ToString() -ne '0.1.3.0') {
            throw "Packaged assembly identity is invalid: $($assemblyName.FullName)"
        }
    }
    finally {
        $dllStream.Dispose()
        if ([IO.File]::Exists($temporaryDll)) { [IO.File]::Delete($temporaryDll) }
    }
}
finally { $archive.Dispose() }

$result = [ordered]@{
    status = 'passed'
    package_path = $PackagePath
    package_sha256 = Get-Sha256 $inspected
    entry_count = $allowed.Count
    entries = $allowed
    assembly_name = $assemblyName.Name
    assembly_version = $assemblyName.Version.ToString()
    manager_version = [string] $info.ManagerVersion
    dll_sha256 = $dllSha256
    dll_mvid = $dllIdentity.Mvid
    dll_loader_references = @($dllIdentity.LoaderReferences)
    display_name = [string] $info.DisplayName
    author = [string] $info.Author
}
$resolvedReport = [IO.Path]::GetFullPath($(if ([IO.Path]::IsPathRooted($ReportPath)) { $ReportPath } else { Join-Path $root $ReportPath }))
$publishedReceipt = [IO.Path]::GetFullPath((Join-Path $root 'artifacts\qualification\package-validation.json'))
if ($resolvedReport -ine $publishedReceipt) { Write-JsonFile $resolvedReport $result }
else {
    # The published validation receipt belongs to the publication of {ZIP, package-validation.json, package.json}
    # (Package.ps1). A standalone validation refreshes it only for the archive published now: under the publication lock,
    # and only when the published ZIP's bytes are the bytes validated here (its package_path then names the published
    # ZIP). Validation of any other archive, or of a published archive replaced meanwhile, leaves the receipt unchanged.
    $packageDirectory = Join-Path $root 'artifacts\packages'
    $publishedZip = Join-Path $packageDirectory 'KingmakerLastAzlantiPreserver-0.1.3.zip'
    $written = $false
    if (Test-Path -LiteralPath $publishedZip -PathType Leaf) {
        $publishLock = Enter-PackagePublishLock $packageDirectory
        try {
            if ((Get-Sha256 $publishedZip) -ceq $result.package_sha256) {
                $result.package_path = $publishedZip
                $result['package'] = $publishedZip
                $temporaryReport = $publishedReceipt + '.' + [Guid]::NewGuid().ToString('N') + '.tmp'
                try {
                    Write-JsonFile $temporaryReport $result
                    if ([IO.File]::Exists($publishedReceipt)) { [IO.File]::Replace($temporaryReport, $publishedReceipt, [NullString]::Value) } else { [IO.File]::Move($temporaryReport, $publishedReceipt) }
                    $written = $true
                }
                finally { if ([IO.File]::Exists($temporaryReport)) { [IO.File]::Delete($temporaryReport) } }
            }
        }
        finally { $publishLock.Dispose() }
    }
    if (-not $written) {
        Write-Host "Published validation receipt not written: this archive is not the published package now (artifacts\packages\KingmakerLastAzlantiPreserver-0.1.3.zip), so artifacts\qualification\package-validation.json keeps describing the published package. Pass -ReportPath to keep a report of this validation."
    }
}
Write-Host "Package validation passed: $PackagePath"
Write-Host "Packaged DLL SHA-256: $dllSha256; MVID: $($dllIdentity.Mvid); loader references: $((@($dllIdentity.LoaderReferences) | ForEach-Object { $_.name + ' ' + $_.version }) -join ', ')"
}
finally { if ([IO.Directory]::Exists($privateDirectory)) { [IO.Directory]::Delete($privateDirectory, $true) } }
