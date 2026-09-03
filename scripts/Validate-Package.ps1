[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string] $PackagePath,
    [string] $ReportPath = 'artifacts\qualification\package-validation.json'
)

. (Join-Path $PSScriptRoot 'Common.ps1')
$root = Get-RepositoryRoot
$PackagePath = [IO.Path]::GetFullPath($PackagePath)
Assert-FileExists $PackagePath 'Package ZIP'
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
$archive = [IO.Compression.ZipFile]::OpenRead($PackagePath)
try {
    $files = @($archive.Entries | Where-Object { $_.FullName -and -not $_.FullName.EndsWith('/') })
    $names = @($files | ForEach-Object { $_.FullName.Replace('\','/') } | Sort-Object)
    if ($files.Count -ne $allowed.Count) { throw "Expected exactly $($allowed.Count) package files; found $($files.Count)." }
    if (@(Compare-Object ($allowed | Sort-Object) $names).Count -ne 0) { throw 'Package allowlist mismatch.' }
    foreach ($entry in $files) {
        $segments = @($entry.FullName.Replace('\','/').Split('/'))
        if ($entry.Length -le 0 -or $segments -contains '..' -or $segments -contains '.' -or $segments -contains '' -or
            [IO.Path]::IsPathRooted($entry.FullName) -or $entry.FullName.Contains(':')) {
            throw "Unsafe or empty package entry: $($entry.FullName)"
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
        $assemblyName = [Reflection.AssemblyName]::GetAssemblyName($temporaryDll)
        if ($assemblyName.Name -ne 'KingmakerLastAzlantiPreserver' -or $assemblyName.Version.ToString() -ne '0.1.0.0') {
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
    package_sha256 = Get-Sha256 $PackagePath
    entry_count = $allowed.Count
    entries = $allowed
    assembly_name = $assemblyName.Name
    assembly_version = $assemblyName.Version.ToString()
}
$resolvedReport = if ([IO.Path]::IsPathRooted($ReportPath)) { $ReportPath } else { Join-Path $root $ReportPath }
Write-JsonFile $resolvedReport $result
Write-Host "Package validation passed: $PackagePath"
