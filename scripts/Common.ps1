Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:RepositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))

function Get-RepositoryRoot {
    return $script:RepositoryRoot
}

function Assert-FileExists([string] $Path, [string] $Label) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "$Label was not found: $Path" }
}

function Assert-DirectoryExists([string] $Path, [string] $Label) {
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) { throw "$Label was not found: $Path" }
}

function Assert-PathWithin([string] $Path, [string] $Parent, [string] $Label) {
    $fullPath = [IO.Path]::GetFullPath($Path).TrimEnd('\','/')
    $fullParent = [IO.Path]::GetFullPath($Parent).TrimEnd('\','/')
    if (-not $fullPath.StartsWith($fullParent + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw "$Label escaped its allowed parent: $fullPath"
    }
}

function Get-KingmakerConfiguration([string] $PropsPath = (Join-Path $script:RepositoryRoot 'GamePath.props')) {
    Assert-FileExists $PropsPath 'GamePath.props'
    [xml] $xml = Get-Content -LiteralPath $PropsPath -Raw
    $group = @($xml.Project.PropertyGroup) | Where-Object { $_.KingmakerInstallDir } | Select-Object -First 1
    if (-not $group) { throw 'GamePath.props does not define KingmakerInstallDir.' }
    $install = [Environment]::ExpandEnvironmentVariables([string] $group.KingmakerInstallDir)
    $managed = [string] $group.KingmakerManagedDir
    if (-not $managed) { $managed = Join-Path $install 'Kingmaker_Data\Managed' }
    $managed = $managed.Replace('$(KingmakerInstallDir)', $install)
    $umm = [string] $group.UnityModManagerDir
    if (-not $umm) { $umm = Join-Path $managed 'UnityModManager' }
    $umm = $umm.Replace('$(KingmakerManagedDir)', $managed).Replace('$(KingmakerInstallDir)', $install)
    $configuration = [pscustomobject]@{
        InstallDir = [IO.Path]::GetFullPath($install)
        ManagedDir = [IO.Path]::GetFullPath($managed)
        UnityModManagerDir = [IO.Path]::GetFullPath($umm)
        ModsDir = [IO.Path]::GetFullPath((Join-Path $install 'Mods'))
    }
    Assert-FileExists (Join-Path $configuration.ManagedDir 'Assembly-CSharp.dll') 'Kingmaker Assembly-CSharp.dll'
    Assert-FileExists (Join-Path $configuration.UnityModManagerDir 'UnityModManager.dll') 'UnityModManager.dll'
    Assert-FileExists (Join-Path $configuration.UnityModManagerDir '0Harmony12.dll') '0Harmony12.dll'
    return $configuration
}

function Get-Sha256([string] $Path) {
    Assert-FileExists $Path 'Hash input'
    $stream = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
    try {
        $sha256 = [Security.Cryptography.SHA256]::Create()
        try { $bytes = $sha256.ComputeHash($stream) }
        finally { $sha256.Dispose() }
    }
    finally { $stream.Dispose() }
    return ([BitConverter]::ToString($bytes)).Replace('-', '').ToLowerInvariant()
}

function Get-AssemblyMvid([string] $AssemblyPath) {
    $assembly = [Reflection.Assembly]::ReflectionOnlyLoadFrom($AssemblyPath)
    return $assembly.ManifestModule.ModuleVersionId.ToString('D')
}

function Invoke-MSBuild([string[]] $Arguments) {
    $dotnet = Get-Command dotnet -ErrorAction SilentlyContinue
    if (-not $dotnet) { throw '.NET SDK is required to run MSBuild.' }
    & $dotnet.Source msbuild @Arguments
    if ($LASTEXITCODE -ne 0) { throw "MSBuild failed with exit code $LASTEXITCODE." }
}

function Get-GitMetadata {
    $branch = (& git -C $script:RepositoryRoot branch --show-current).Trim()
    try {
        $commit = (& git -C $script:RepositoryRoot rev-parse --verify HEAD 2>$null).Trim()
        if (-not $commit) { $commit = 'UNBORN' }
    }
    catch { $commit = 'UNBORN' }
    $status = (& git -C $script:RepositoryRoot status --porcelain) -join "`n"
    return [pscustomobject]@{ Branch = $branch; Commit = $commit; Dirty = [bool] $status }
}

function Write-JsonFile([string] $Path, [object] $Value, [int] $Depth = 8) {
    $parent = Split-Path -Parent $Path
    if ($parent) { [IO.Directory]::CreateDirectory($parent) | Out-Null }
    $Value | ConvertTo-Json -Depth $Depth | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Assert-RepositorySafety {
    $root = Get-RepositoryRoot
    $info = Get-Content -LiteralPath (Join-Path $root 'Info.json') -Raw | ConvertFrom-Json
    if ($info.Id -ne 'KingmakerLastAzlantiPreserver' -or
        $info.AssemblyName -ne 'KingmakerLastAzlantiPreserver.dll' -or
        $info.EntryMethod -ne 'KingmakerLastAzlantiPreserver.Main.Load' -or
        $info.Version -ne '0.1.0') {
        throw 'Info.json product identity is inconsistent.'
    }

    $trackedCandidates = Get-ChildItem -LiteralPath $root -File -Recurse | Where-Object {
        $_.FullName -notmatch '[\\/](\.git|artifacts|bin|obj)[\\/]' -and $_.Name -ne 'GamePath.props'
    }
    foreach ($file in $trackedCandidates) {
        if ($file.Extension -in @('.dll','.exe','.zks','.zip','.sav','.save','.log','.pdb','.assets')) {
            throw "Forbidden repository file: $($file.FullName)"
        }
        if ($file.Length -lt 2MB -and $file.Extension -in @('.cs','.ps1','.md','.json','.props','.csproj','.sln','.txt','.editorconfig','.gitattributes','.gitignore')) {
            $text = Get-Content -LiteralPath $file.FullName -Raw
            if ($text -match '(?i)C:\\Users\\') { throw "Personal absolute path found in $($file.FullName)" }
            if ($text -match '(?i)C:\\Program Files \(x86\)\\Steam\\steamapps\\common\\Pathfinder Kingmaker') {
                throw "Installed-game absolute path found in committed candidate $($file.FullName)"
            }
        }
    }

    [xml] $project = Get-Content -LiteralPath (Join-Path $root 'src\KingmakerLastAzlantiPreserver\KingmakerLastAzlantiPreserver.csproj') -Raw
    $namespace = [Xml.XmlNamespaceManager]::new($project.NameTable)
    $namespace.AddNamespace('msb', 'http://schemas.microsoft.com/developer/msbuild/2003')
    foreach ($node in @($project.SelectNodes('//msb:Reference[msb:HintPath]', $namespace))) {
        if ([string] $node.Private -ne 'False') { throw "Local reference must use Private=False: $($node.Include)" }
    }
}
