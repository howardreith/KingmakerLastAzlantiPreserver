[CmdletBinding()]
param([string] $KingmakerInstallDir)

. (Join-Path $PSScriptRoot 'Common.ps1')
$root = Get-RepositoryRoot
$target = Join-Path $root 'GamePath.props'
if (Test-Path -LiteralPath $target) { throw "GamePath.props already exists: $target" }

if (-not $KingmakerInstallDir) {
    $steamRoots = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($key in @('HKCU:\Software\Valve\Steam','HKLM:\SOFTWARE\WOW6432Node\Valve\Steam','HKLM:\SOFTWARE\Valve\Steam')) {
        if (-not (Test-Path -LiteralPath $key)) { continue }
        $value = Get-ItemProperty -LiteralPath $key
        foreach ($name in @('SteamPath','InstallPath')) {
            $candidate = [string] $value.$name
            if ($candidate) { [void] $steamRoots.Add($candidate) }
        }
    }

    $libraries = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($steamRoot in $steamRoots) {
        [void] $libraries.Add($steamRoot)
        $libraryFile = Join-Path $steamRoot 'steamapps\libraryfolders.vdf'
        if (-not (Test-Path -LiteralPath $libraryFile)) { continue }
        foreach ($match in [regex]::Matches((Get-Content -LiteralPath $libraryFile -Raw), '"path"\s+"([^"]+)"')) {
            [void] $libraries.Add($match.Groups[1].Value.Replace('\\','\'))
        }
    }

    foreach ($library in $libraries) {
        $manifest = Join-Path $library 'steamapps\appmanifest_640820.acf'
        if (-not (Test-Path -LiteralPath $manifest)) { continue }
        $manifestText = Get-Content -LiteralPath $manifest -Raw
        $installMatch = [regex]::Match($manifestText, '"installdir"\s+"([^"]+)"')
        if (-not $installMatch.Success) { continue }
        $candidate = Join-Path $library ('steamapps\common\' + $installMatch.Groups[1].Value)
        if (Test-Path -LiteralPath (Join-Path $candidate 'Kingmaker_Data\Managed\Assembly-CSharp.dll')) {
            $KingmakerInstallDir = $candidate
            break
        }
    }
}

if (-not $KingmakerInstallDir) { throw 'Kingmaker app 640820 was not discovered; pass -KingmakerInstallDir explicitly.' }
$KingmakerInstallDir = [IO.Path]::GetFullPath($KingmakerInstallDir)
Assert-FileExists (Join-Path $KingmakerInstallDir 'Kingmaker_Data\Managed\Assembly-CSharp.dll') 'Kingmaker Assembly-CSharp.dll'

[xml] $xml = Get-Content -LiteralPath (Join-Path $root 'GamePath.props.example') -Raw
$group = @($xml.Project.PropertyGroup) | Select-Object -First 1
$group.KingmakerInstallDir = $KingmakerInstallDir
$xml.Save($target)
Write-Host "Created ignored local configuration: $target"
Write-Host 'Discovered and validated Pathfinder: Kingmaker app 640820.'
