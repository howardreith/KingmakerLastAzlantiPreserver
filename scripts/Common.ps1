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
    # A detached checkout (for example an isolated test clone) has no current branch; record that explicitly.
    $branchOutput = & git -C $script:RepositoryRoot branch --show-current
    $branch = if ($branchOutput) { ([string]$branchOutput).Trim() } else { '(detached HEAD)' }
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

function Get-ExpectedProductManifest {
    # Id, AssemblyName and EntryMethod are the stable UMM identity and must never follow branding.
    return [ordered]@{
        Id = 'KingmakerLastAzlantiPreserver'
        DisplayName = "Mr. Bard's Second to Last Azlanti"
        Author = 'Mr. Bard'
        Version = '0.1.3'
        ManagerVersion = '0.31.1'
        AssemblyName = 'KingmakerLastAzlantiPreserver.dll'
        EntryMethod = 'KingmakerLastAzlantiPreserver.Main.Load'
    }
}

function Assert-ProductManifest([object] $Info, [string] $Label) {
    $expected = Get-ExpectedProductManifest
    foreach ($key in $expected.Keys) {
        if (-not ($Info.$key -is [string])) { throw "$Label $key must be a JSON string." }
        $actual = [string] $Info.$key
        if (-not [string]::Equals($actual, $expected[$key], [StringComparison]::Ordinal)) {
            throw "$Label $key is '$actual'; expected '$($expected[$key])'."
        }
    }
}

function Assert-RepositorySafety {
    $root = Get-RepositoryRoot
    $info = Get-Content -LiteralPath (Join-Path $root 'Info.json') -Raw | ConvertFrom-Json
    if ($info.Id -ne 'KingmakerLastAzlantiPreserver' -or
        $info.AssemblyName -ne 'KingmakerLastAzlantiPreserver.dll' -or
        $info.EntryMethod -ne 'KingmakerLastAzlantiPreserver.Main.Load' -or
        $info.Version -ne '0.1.3') {
        throw 'Info.json product identity is inconsistent.'
    }
    Assert-ProductManifest $info 'Info.json'

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

function Get-PinnedReferenceDefinitions([string] $Path = (Join-Path $script:RepositoryRoot 'scripts\loader-reference-pins.json')) {
    Assert-FileExists $Path 'Reference pin manifest'
    $document = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    $info = Get-Content -LiteralPath (Join-Path $script:RepositoryRoot 'Info.json') -Raw | ConvertFrom-Json
    if (-not ($info.ManagerVersion -is [string])) { throw 'Info.json ManagerVersion must be a JSON string.' }
    # The product compiles against exactly these loader assemblies; the same canonical set is enforced by
    # scripts\Get-PinnedLoaderReferences.ps1 (which MSBuild runs), so no pin can be dropped or renamed unchecked.
    $canonical = [ordered]@{ 'UnityModManager' = 'UnityModManager.dll'; '0Harmony12' = '0Harmony12.dll' }
    $references = @($document.references)
    if ($references.Count -ne $canonical.Count) { throw "The pin file must define exactly: $($canonical.Keys -join ', ')." }
    foreach ($name in $canonical.Keys) {
        $match = @($references | Where-Object { $_.Name -is [string] -and $_.Name -ceq $name })
        if ($match.Count -ne 1 -or -not ($match[0].File -is [string]) -or $match[0].File -cne $canonical[$name] -or
            -not ($match[0].Version -is [string]) -or -not ($match[0].Sha256 -is [string])) {
            throw "The pin file must define $name exactly once as $($canonical[$name])."
        }
    }
    $loader = @($references | Where-Object { $_.Name -ceq 'UnityModManager' })
    if ($loader[0].Version -cne ($info.ManagerVersion + '.0')) {
        throw 'Info.json ManagerVersion must match the pinned Unity Mod Manager baseline.'
    }
    return $references
}

function Get-PinnedReferenceDirectory { return (Join-Path $script:RepositoryRoot 'artifacts\references') }

# Ensures every pinned loader reference is present and byte-exact; a hash mismatch fails the build.
function Initialize-PinnedReferences {
    & (Join-Path $PSScriptRoot 'Get-PinnedLoaderReferences.ps1') -ReferenceDirectory (Get-PinnedReferenceDirectory)
}

function Get-PinnedReferenceIdentities {
    $directory = Get-PinnedReferenceDirectory
    foreach ($reference in (Get-PinnedReferenceDefinitions)) {
        $path = Join-Path $directory $reference.File
        if ((Get-Sha256 $path) -ne $reference.Sha256) {
            throw "Pinned reference $($reference.File) does not match its expected SHA-256."
        }
        [ordered]@{
            file = $reference.File
            version = $reference.Version
            assembly_version = [Reflection.AssemblyName]::GetAssemblyName($path).Version.ToString()
            sha256 = $reference.Sha256
            source = $reference.Url
        }
    }
}

# Material inputs of the production DLL: every tracked or new file under src\, the loader pin, verifier and
# MSBuild guard, the root build properties and the manifest. Any change invalidates an existing DLL and receipt,
# so packaging or qualification can never reuse a build made from other inputs.
function Get-BuildInputFingerprint {
    $root = $script:RepositoryRoot
    $paths = @('src', 'Directory.Build.props', '.editorconfig', 'Info.json', 'LoaderReferences.targets',
        'scripts/loader-reference-pins.json', 'scripts/Get-PinnedLoaderReferences.ps1')
    $files = @(& git -C $root ls-files --cached --others --exclude-standard -- @paths)
    if ($LASTEXITCODE -ne 0) { throw 'git ls-files failed while fingerprinting build inputs.' }
    $lines = foreach ($file in ($files | Sort-Object -Unique)) {
        $full = Join-Path $root $file
        if (Test-Path -LiteralPath $full -PathType Leaf) { $file + "`t" + (Get-Sha256 $full) }
    }
    $hasher = [Security.Cryptography.SHA256]::Create()
    try { $digest = $hasher.ComputeHash([Text.Encoding]::UTF8.GetBytes(($lines -join "`n"))) }
    finally { $hasher.Dispose() }
    return ([BitConverter]::ToString($digest)).Replace('-', '').ToLowerInvariant()
}

# Refuse to package or qualify a DLL that is not exactly the output of the current inputs and configuration,
# including an old build whose manifest was merely lowered after compilation.
function Assert-PinnedBuildReceipt($Receipt, [string] $DllPath, [string] $Configuration) {
    foreach ($field in @('dll_sha256', 'loader_references', 'build_inputs_sha256', 'configuration')) {
        if (-not $Receipt.PSObject.Properties[$field]) { throw "Build receipt has no $field; rebuild first." }
    }
    if ($Receipt.dll_sha256 -ne (Get-Sha256 $DllPath)) { throw 'Build receipt does not match the mod DLL; rebuild first.' }
    if ($Configuration -and $Receipt.configuration -cne $Configuration) { throw "Build receipt is for configuration $($Receipt.configuration), not $Configuration; rebuild first." }
    if ($Receipt.build_inputs_sha256 -cne (Get-BuildInputFingerprint)) { throw 'Build inputs changed since this DLL was built (source, manifest or loader pins); rebuild first.' }
    $pins = @(Get-PinnedReferenceDefinitions)
    $recorded = @($Receipt.loader_references)
    if ($recorded.Count -ne $pins.Count) { throw 'Build receipt has an unexpected loader reference count; rebuild first.' }
    foreach ($pin in $pins) {
        $matches = @($recorded | Where-Object { $_.file -eq $pin.File })
        if ($matches.Count -ne 1 -or $matches[0].version -ne $pin.Version -or $matches[0].assembly_version -cne $pin.Version -or
            $matches[0].sha256 -ne $pin.Sha256 -or $matches[0].source -ne $pin.Url) {
            throw "Build receipt does not match pinned reference $($pin.File); rebuild first."
        }
    }
}

# Reads a DLL's MVID and AssemblyRef table without executing it. Windows PowerShell has no metadata reader, and a
# reflection-only load refuses a second assembly with the same identity in one process (validating two packages
# in one host would fail), so it reads the metadata in a separate process that loads nothing else.
function Get-AssemblyMetadataIdentity([byte[]] $Bytes) {
    if ($PSVersionTable.PSEdition -eq 'Core') {
        Add-Type -AssemblyName System.Reflection.Metadata
        $stream = [IO.MemoryStream]::new($Bytes, $false)
        $reader = [System.Reflection.PortableExecutable.PEReader]::new($stream)
        try {
            $metadata = [System.Reflection.Metadata.PEReaderExtensions]::GetMetadataReader($reader)
            return [pscustomobject]@{
                Mvid = $metadata.GetGuid($metadata.GetModuleDefinition().Mvid).ToString()
                References = @($metadata.AssemblyReferences | ForEach-Object {
                    $reference = $metadata.GetAssemblyReference($_)
                    [pscustomobject]@{ Name = $metadata.GetString($reference.Name); Version = $reference.Version.ToString() }
                })
            }
        }
        finally { $reader.Dispose(); $stream.Dispose() }
    }
    $temporary = Join-Path ([IO.Path]::GetTempPath()) ('klap-metadata-' + [Guid]::NewGuid().ToString('N') + '.dll')
    [IO.File]::WriteAllBytes($temporary, $Bytes)
    try {
        $script = "`$a = [Reflection.Assembly]::ReflectionOnlyLoad([IO.File]::ReadAllBytes('" + $temporary.Replace("'", "''") + "')); " +
            "[pscustomobject]@{ Mvid = `$a.ManifestModule.ModuleVersionId.ToString(); References = @(`$a.GetReferencedAssemblies() | " +
            "ForEach-Object { [pscustomobject]@{ Name = `$_.Name; Version = `$_.Version.ToString() } }) } | ConvertTo-Json -Compress -Depth 4"
        $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($script))
        $previous = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try { $json = & powershell.exe -NoLogo -NoProfile -NonInteractive -EncodedCommand $encoded 2>&1 | Out-String }
        finally { $ErrorActionPreference = $previous }
        if ($LASTEXITCODE -ne 0) { throw "Packaged DLL metadata could not be read: $json" }
        $identity = $json | ConvertFrom-Json
        return [pscustomobject]@{ Mvid = [string]$identity.Mvid; References = @($identity.References) }
    }
    finally { Remove-Item -LiteralPath $temporary -Force -ErrorAction SilentlyContinue }
}

# Inspect packaged metadata as well as the build receipt: Install.ps1 also accepts
# a supplied ZIP and therefore calls Validate-Package.ps1 without Package.ps1.
function Assert-PinnedAssemblyReferences([byte[]] $Bytes) {
    $identity = Get-AssemblyMetadataIdentity $Bytes
    $references = @($identity.References)
    $observed = @()
    foreach ($pin in (Get-PinnedReferenceDefinitions)) {
        $matches = @($references | Where-Object { $_.Name -ceq $pin.Name })
        if ($matches.Count -ne 1 -or [string]$matches[0].Version -cne $pin.Version) {
            throw "Packaged DLL must reference pinned $($pin.Name) $($pin.Version); lowering Info.json alone is not sufficient."
        }
        $observed += [ordered]@{ name = $pin.Name; version = [string]$matches[0].Version }
    }
    # Returned for the validation report, so it names the exact DLL whose references were inspected.
    return [pscustomobject]@{ Mvid = $identity.Mvid; LoaderReferences = $observed }
}

# Validates a private copy of a package and extracts that same copy, so the bytes installed are the bytes that
# passed validation even if the original file changes afterwards. Returns the validated packaged DLL SHA-256.
function Expand-ValidatedPackage([string] $PackagePath, [string] $Destination) {
    $private = Join-Path ([IO.Path]::GetTempPath()) ('KingmakerLastAzlantiPreserver-package-' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $private | Out-Null
    try {
        $copy = Join-Path $private 'package.zip'
        Copy-Item -LiteralPath $PackagePath -Destination $copy
        $report = Join-Path $private 'validation.json'
        & (Join-Path $PSScriptRoot 'Validate-Package.ps1') -PackagePath $copy -ReportPath $report
        $validated = Get-Content -LiteralPath $report -Raw | ConvertFrom-Json
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [IO.Compression.ZipFile]::ExtractToDirectory($copy, $Destination)
        $dll = Join-Path $Destination 'KingmakerLastAzlantiPreserver\KingmakerLastAzlantiPreserver.dll'
        Assert-FileExists $dll 'Extracted mod DLL'
        if ((Get-Sha256 $dll) -cne [string]$validated.dll_sha256) { throw 'Extracted DLL does not match the validated package.' }
        return [string]$validated.dll_sha256
    }
    finally { Remove-Item -LiteralPath $private -Recurse -Force -ErrorAction SilentlyContinue }
}
