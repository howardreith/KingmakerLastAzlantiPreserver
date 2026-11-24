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

# -AllowMissingLoader: game paths only (build, packaging and qualification summaries do not need the runtime loader).
function Get-KingmakerConfiguration([string] $PropsPath = (Join-Path $script:RepositoryRoot 'GamePath.props'), [switch] $AllowMissingLoader) {
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
    if (-not $AllowMissingLoader) {
        Assert-FileExists (Join-Path $configuration.UnityModManagerDir 'UnityModManager.dll') 'UnityModManager.dll'
        Assert-FileExists (Join-Path $configuration.UnityModManagerDir '0Harmony12.dll') '0Harmony12.dll'
    }
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

# Reads a compiler-input list written by the WriteCompilerReferenceList target (the intermediate directory, then every Csc
# argument) into path-free identities in a canonical order: kind reference/compile/file-option with the file's name
# (repository-relative, obj:<name> for generated files in the intermediate directory, otherwise the file name) and
# SHA-256; kind option for every other argument verbatim; kind output for output locations (file name only).
function ConvertFrom-CompilerInputList([string] $ListPath) {
    $rootPrefix = [IO.Path]::GetFullPath($script:RepositoryRoot).TrimEnd('\') + '\'
    $lines = @(Get-Content -LiteralPath $ListPath -Encoding UTF8 | Where-Object { $_ })
    if ($lines.Count -lt 4 -or -not $lines[0].StartsWith('intermediate|') -or -not $lines[1].StartsWith('project|') -or -not $lines[2].StartsWith('compiler|')) { throw "Compiler input list is malformed: $ListPath" }
    $objPrefix = [IO.Path]::GetFullPath($lines[0].Substring('intermediate|'.Length)).TrimEnd('\') + '\'
    $projectDirectory = $lines[1].Substring('project|'.Length)
    # Csc arguments name files relative to the project directory.
    function Resolve-InputPath([string] $Path) { return [IO.Path]::GetFullPath([IO.Path]::Combine($projectDirectory, $Path.Trim('"'))) }
    function Get-InputName([string] $Path) {
        $full = Resolve-InputPath $Path
        # MSBuild's generated target-framework attribute file lives in the intermediate or the temporary directory.
        if ([IO.Path]::GetFileName($full) -like '*.AssemblyAttributes.cs') { return 'generated:' + [IO.Path]::GetFileName($full) }
        if ($full.StartsWith($objPrefix, [StringComparison]::OrdinalIgnoreCase)) { return 'obj:' + $full.Substring($objPrefix.Length).Replace('\', '/') }
        if ($full.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) { return $full.Substring($rootPrefix.Length).Replace('\', '/') }
        return [IO.Path]::GetFileName($full)
    }
    function Get-InputDigest([string] $Path) { $full = Resolve-InputPath $Path; if (Test-Path -LiteralPath $full -PathType Leaf) { return Get-Sha256 $full } else { return 'absent' } }
    $outputSwitches = @('out', 'pdb', 'refout', 'doc', 'errorlog', 'generatedfilesout')
    $fileSwitches = @('win32res', 'win32icon', 'win32manifest', 'keyfile', 'ruleset', 'appconfig', 'analyzer', 'a', 'additionalfile', 'analyzerconfig', 'embed', 'sourcelink', 'addmodule')
    $resourceSwitches = @('resource', 'res', 'linkresource', 'linkres')
    # The effective compiler binary (and, without /noconfig, the implicit csc.rsp beside it) is an input.
    $compiler = $lines[2].Substring('compiler|'.Length)
    $compilerEntry = [ordered]@{ kind = 'compiler'; name = [IO.Path]::GetFileName($compiler); sha256 = $(if (Test-Path -LiteralPath $compiler -PathType Leaf) { Get-Sha256 $compiler } else { 'absent' }) }
    $cscArgs = @($lines[3..($lines.Count - 1)] | ForEach-Object { if (-not $_.StartsWith('arg|')) { throw "Compiler input list is malformed: $_" }; $_.Substring(4) })
    $implicit = @()
    if ($cscArgs -notcontains '/noconfig') {
        $rsp = Join-Path (Split-Path -Parent $compiler) 'csc.rsp'
        $implicit += [ordered]@{ kind = 'response-file'; name = 'implicit:csc.rsp'; sha256 = $(if (Test-Path -LiteralPath $rsp -PathType Leaf) { Get-Sha256 $rsp } else { 'absent' }) }
    }
    $entries = foreach ($line in @($cscArgs | ForEach-Object { 'arg|' + $_ })) {
        if (-not $line.StartsWith('arg|')) { throw "Compiler input list is malformed: $line" }
        $arg = $line.Substring(4)
        # Forms whose material files the inventory cannot name are refused, not recorded as text: an explicit response
        # file (its contents can name further sources, resources or references), linked (embedded-interop) references
        # and wildcard source recursion.
        if ($arg.StartsWith('@')) { throw "Unsupported compiler input: the response file $arg can name files the build receipt cannot bind; remove it from the project or local configuration." }
        $m = [regex]::Match($arg, '^[/-]([A-Za-z0-9_+-]+?)(?::(.*))?$')
        if (-not $m.Success) { [ordered]@{ kind = 'compile'; name = Get-InputName $arg; sha256 = Get-InputDigest $arg }; continue }
        $switch = $m.Groups[1].Value.ToLowerInvariant(); $value = $m.Groups[2].Value
        if (@('link', 'l', 'recurse') -ccontains $switch) { throw "Unsupported compiler input: $arg (linked references and wildcard source recursion are not supported by the build receipt); remove it from the project or local configuration." }
        if ($outputSwitches -ccontains $switch) { [ordered]@{ kind = 'output'; name = "/$switch" + ':' + [IO.Path]::GetFileName($value.Trim('"')); sha256 = '' } }
        elseif ($switch -ceq 'reference' -or $switch -ceq 'r') {
            $alias, $path = if ($value -match '^[A-Za-z_][A-Za-z0-9_]*=') { $value -split '=', 2 } else { $null, $value }
            [ordered]@{ kind = 'reference'; name = $(if ($alias) { "$alias=" } else { '' }) + (Get-InputName $path); sha256 = Get-InputDigest $path }
        }
        elseif ($resourceSwitches -ccontains $switch) {
            $path, $rest = $value -split ',', 2
            [ordered]@{ kind = 'file-option'; name = "/$switch" + ':' + (Get-InputName $path) + $(if ($rest) { ',' + $rest } else { '' }); sha256 = Get-InputDigest $path }
        }
        elseif ($fileSwitches -ccontains $switch -and $value) { [ordered]@{ kind = 'file-option'; name = "/$switch" + ':' + (Get-InputName $value); sha256 = Get-InputDigest $value } }
        else { [ordered]@{ kind = 'option'; name = $arg.Replace($objPrefix.TrimEnd('\'), 'obj:'); sha256 = '' } }
    }
    # Argument order is kept: the inventory is the compiler, any implicit response file, then every argument as passed.
    return @(@($compilerEntry) + $implicit + @($entries))
}

# Structural comparison of two compiler inventories: the same number of entries and, entry by entry in order, the same
# kind, name and digest (each a string, compared ordinally). Returns $null when equal, otherwise the first difference.
function Get-CompilerInventoryDifference($Recorded, $Current) {
    $a = @($Recorded); $b = @($Current)
    if ($a.Count -ne $b.Count) { return "entry count $($a.Count) vs $($b.Count)" }
    for ($i = 0; $i -lt $a.Count; $i++) {
        foreach ($field in @('kind', 'name', 'sha256')) {
            $x = if ($a[$i] -is [Collections.IDictionary]) { $a[$i][$field] } else { $a[$i].$field }
            $y = if ($b[$i] -is [Collections.IDictionary]) { $b[$i][$field] } else { $b[$i].$field }
            if (-not ($x -is [string]) -or -not ($y -is [string]) -or -not [string]::Equals($x, $y, [StringComparison]::Ordinal)) { return "entry $i $field" }
        }
    }
    return $null
}

# Validates the shape of a recorded compiler inventory (as read back from JSON).
function Assert-CompilerInventoryShape($Inventory) {
    $entries = @($Inventory)
    if ($entries.Count -eq 0) { throw 'Build receipt compiler_references is empty; rebuild first.' }
    foreach ($entry in $entries) {
        foreach ($field in @('kind', 'name', 'sha256')) {
            if ($null -eq $entry -or -not $entry.PSObject.Properties[$field] -or -not ($entry.$field -is [string])) { throw "Build receipt compiler input field $field must be a string; rebuild first." }
        }
        if ($entry.name -match '[\x00-\x1f]') { throw "Build receipt compiler input name contains a control character: $($entry.kind); rebuild first." }
        $valid = if ($entry.kind -ceq 'option' -or $entry.kind -ceq 'output') { $entry.sha256 -ceq '' -and $entry.name.Length -gt 0 } else {
            @('reference', 'compile', 'file-option', 'compiler', 'response-file') -ccontains $entry.kind -and ($entry.sha256 -cmatch '^[0-9a-f]{64}$' -or $entry.sha256 -ceq 'absent') }
        if (-not $valid) { throw "Build receipt compiler input is malformed: $($entry.kind) $($entry.name); rebuild first." }
    }
    if (@($entries | Where-Object { $_.kind -ceq 'reference' }).Count -eq 0) { throw 'Build receipt compiler inventory names no references; rebuild first.' }
    # An input the helper cannot identify (a missing compiler, response file, source or file-valued input) refuses reuse.
    if (@($entries | Where-Object { $_.sha256 -ceq 'absent' }).Count -ne 0) { throw "Build receipt compiler inventory has an unidentified input ($(@($entries | Where-Object { $_.sha256 -ceq 'absent' } | ForEach-Object { $_.name }) -join ', ')); rebuild first." }
}

# The compiler inputs for a configuration as MSBuild itself evaluates them: the exact Csc command line from a
# SkipCompilerExecution pass through CoreCompile in a fresh intermediate directory (references, sources including generated
# ones, every option, file-valued inputs by content). Needs the game assemblies and pins, not the runtime loader.
function Get-CompilerReferenceIdentities([string] $Configuration) {
    $id = [Guid]::NewGuid().ToString('N')
    $list = Join-Path ([IO.Path]::GetTempPath()) ("klap-compiler-references-$id.txt")
    $obj = Join-Path ([IO.Path]::GetTempPath()) ("klap-compiler-references-$id\")
    $project = Join-Path $script:RepositoryRoot 'src\KingmakerLastAzlantiPreserver\KingmakerLastAzlantiPreserver.csproj'
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = $null | & dotnet msbuild $project /nologo /v:q /nr:false '/t:PrepareResources;Compile' /p:SkipCompilerExecution=true `
            "/p:Configuration=$Configuration" /p:Platform=AnyCPU "/p:CompilerReferenceListPath=$list" "/p:IntermediateOutputPath=$obj" "/p:OutputPath=$($obj)bin" 2>&1 | ForEach-Object { "$_" }
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $list)) { throw "Could not resolve the compiler references: $($output -join ' ')" }
        return @(ConvertFrom-CompilerInputList $list)
    }
    finally {
        $ErrorActionPreference = $previous
        Remove-Item -LiteralPath $list -Force -ErrorAction SilentlyContinue
        if ([IO.Directory]::Exists($obj)) { [IO.Directory]::Delete($obj, $true) }
    }
}

function Get-BuildInputFingerprint([string] $Configuration = 'Release', $CompilerInputs = $null) {
    $root = $script:RepositoryRoot
    # Also the production build wrapper (Build-Local.ps1 and Common.ps1 choose the MSBuild invocation) and the identity of
    # every assembly Csc receives for the configuration, as resolved by MSBuild (so GamePath.props is read only by MSBuild).
    $paths = @('src', 'Directory.Build.props', '.editorconfig', 'Info.json', 'LoaderReferences.targets',
        'scripts/loader-reference-pins.json', 'scripts/Get-PinnedLoaderReferences.ps1', 'scripts/Build-Local.ps1', 'scripts/Common.ps1')
    $files = @(& git -C $root ls-files --cached --others --exclude-standard -- @paths)
    if ($LASTEXITCODE -ne 0) { throw 'git ls-files failed while fingerprinting build inputs.' }
    $lines = @(foreach ($file in ($files | Sort-Object -Unique)) {
        $full = Join-Path $root $file
        if (Test-Path -LiteralPath $full -PathType Leaf) { $file + "`t" + (Get-Sha256 $full) }
    })
    if ($null -eq $CompilerInputs) { $CompilerInputs = @(Get-CompilerReferenceIdentities $Configuration) }
    foreach ($input in @($CompilerInputs)) { $lines += 'compiler-' + [string]$input.kind + ':' + [string]$input.name + "`t" + [string]$input.sha256 }
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
    # Types first: an array or Boolean would make PowerShell's comparison operators filter or coerce instead of compare.
    foreach ($field in @('dll_sha256', 'build_inputs_sha256')) {
        if (-not ($Receipt.$field -is [string]) -or $Receipt.$field -cnotmatch '^[0-9a-f]{64}$') { throw "Build receipt $field must be a lowercase SHA-256 string; rebuild first." }
    }
    if (-not ($Receipt.configuration -is [string])) { throw 'Build receipt configuration must be a string; rebuild first.' }
    foreach ($entry in @($Receipt.loader_references)) {
        foreach ($field in @('file', 'version', 'assembly_version', 'sha256', 'source')) {
            if ($null -eq $entry -or -not $entry.PSObject.Properties[$field] -or -not ($entry.$field -is [string])) { throw "Build receipt loader reference field $field must be a string; rebuild first." }
        }
    }
    if ($Receipt.dll_sha256 -ne (Get-Sha256 $DllPath)) { throw 'Build receipt does not match the mod DLL; rebuild first.' }
    if ($Configuration -and $Receipt.configuration -cne $Configuration) { throw "Build receipt is for configuration $($Receipt.configuration), not $Configuration; rebuild first." }
    # The receipt's recorded compiler inventory (captured from the production compile) must be well formed and equal the
    # inventory MSBuild evaluates now; the fingerprint is then computed from that same inventory.
    if (-not $Receipt.PSObject.Properties['compiler_references']) { throw 'Build receipt has no compiler_references; rebuild first.' }
    Assert-CompilerInventoryShape $Receipt.compiler_references
    $currentInventory = @(Get-CompilerReferenceIdentities $Receipt.configuration)
    $difference = Get-CompilerInventoryDifference $Receipt.compiler_references $currentInventory
    if ($difference) {
        throw "Build inputs changed since this DLL was built: the receipt compiler inputs differ from the inputs MSBuild resolves now ($difference; references, sources or compiler settings); rebuild first."
    }
    if ($Receipt.build_inputs_sha256 -cne (Get-BuildInputFingerprint $Receipt.configuration $currentInventory)) { throw 'Build inputs changed since this DLL was built (source, manifest or loader pins); rebuild first.' }
    $pins = @(Get-PinnedReferenceDefinitions)
    $recorded = @($Receipt.loader_references)
    if ($recorded.Count -ne $pins.Count) { throw 'Build receipt has an unexpected loader reference count; rebuild first.' }
    foreach ($pin in $pins) {
        $matches = @($recorded | Where-Object { $_.file -ceq $pin.File })
        if ($matches.Count -ne 1 -or $matches[0].version -cne $pin.Version -or $matches[0].assembly_version -cne $pin.Version -or
            $matches[0].sha256 -cne $pin.Sha256 -or $matches[0].source -cne $pin.Url) {
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
# The private copy, its validation report and their cleanup are preflight work, not installation: they also run under
# -WhatIf (only live Mods changes stay behind ShouldProcess).
function Expand-ValidatedPackage([string] $PackagePath, [string] $Destination) {
    $WhatIfPreference = $false
    $private = Join-Path ([IO.Path]::GetTempPath()) ('KingmakerLastAzlantiPreserver-package-' + [Guid]::NewGuid().ToString('N'))
    [void][IO.Directory]::CreateDirectory($private)
    try {
        $copy = Join-Path $private 'package.zip'
        [IO.File]::Copy($PackagePath, $copy)
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
    finally { if ([IO.Directory]::Exists($private)) { [IO.Directory]::Delete($private, $true) } }
}

# The non-DLL files a package copies from the repository (manifest, documentation, licences). A package is current only
# while these still hash the same as when it was built.
function Get-PackageInputFingerprint([string] $Directory = $script:RepositoryRoot) {
    $lines = foreach ($file in @('Info.json', 'LICENSE', 'README.md', 'THIRD-PARTY-NOTICES.md', 'licenses/FIRST-AZLANTI-MIT.txt')) {
        $file + "`t" + (Get-Sha256 (Join-Path $Directory $file))
    }
    $hasher = [Security.Cryptography.SHA256]::Create()
    try { $digest = $hasher.ComputeHash([Text.Encoding]::UTF8.GetBytes(($lines -join "`n"))) }
    finally { $hasher.Dispose() }
    return ([BitConverter]::ToString($digest)).Replace('-', '').ToLowerInvariant()
}

# The same fingerprint computed from the documents inside a package archive (entries under KingmakerLastAzlantiPreserver/).
function Get-PackageInputFingerprintFromArchive([string] $ZipPath) {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [IO.Compression.ZipFile]::OpenRead($ZipPath)
    try {
        $lines = foreach ($file in @('Info.json', 'LICENSE', 'README.md', 'THIRD-PARTY-NOTICES.md', 'licenses/FIRST-AZLANTI-MIT.txt')) {
            $entry = $archive.GetEntry('KingmakerLastAzlantiPreserver/' + $file)
            if ($null -eq $entry) { throw "Package archive has no $file." }
            $stream = $entry.Open(); $hasher = [Security.Cryptography.SHA256]::Create()
            try { $file + "`t" + ([BitConverter]::ToString($hasher.ComputeHash($stream))).Replace('-', '').ToLowerInvariant() }
            finally { $hasher.Dispose(); $stream.Dispose() }
        }
    }
    finally { $archive.Dispose() }
    $hasher = [Security.Cryptography.SHA256]::Create()
    try { $digest = $hasher.ComputeHash([Text.Encoding]::UTF8.GetBytes(($lines -join "`n"))) }
    finally { $hasher.Dispose() }
    return ([BitConverter]::ToString($digest)).Replace('-', '').ToLowerInvariant()
}

# The packaging rules a package was produced and validated under; a changed rule withdraws credit from older packages.
function Get-PackageRuleFingerprint {
    $lines = foreach ($file in @('scripts/Package.ps1', 'scripts/Validate-Package.ps1')) { $file + "`t" + (Get-Sha256 (Join-Path $script:RepositoryRoot $file)) }
    $hasher = [Security.Cryptography.SHA256]::Create()
    try { $digest = $hasher.ComputeHash([Text.Encoding]::UTF8.GetBytes(($lines -join "`n"))) }
    finally { $hasher.Dispose() }
    return ([BitConverter]::ToString($digest)).Replace('-', '').ToLowerInvariant()
}

# Checks that the loader assemblies bound in this process are the configured files (a reused host would otherwise keep
# the first profile's Harmony12/Harmony2 while reporting a second profile's identities).
function Assert-LoadedLoaderStack([string] $Harmony12Path, [string] $Harmony2Path) {
    foreach ($pair in @(@('0Harmony12', $Harmony12Path), @('0Harmony', $Harmony2Path))) {
        $loaded = @([AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { -not $_.IsDynamic -and $_.GetName().Name -ceq $pair[0] })
        if ($loaded.Count -ne 1 -or -not [string]::Equals([IO.Path]::GetFullPath($loaded[0].Location), [IO.Path]::GetFullPath($pair[1]), [StringComparison]::OrdinalIgnoreCase)) {
            throw "Loaded Harmony binding mismatch: $($pair[0]) is bound from $(@($loaded | ForEach-Object Location) -join ', ') but the configured file is $($pair[1]). Run each loader profile in its own process."
        }
    }
}

# Checks that an assembly loaded into this process is the selected file: LoadFrom returns an already-loaded assembly with
# the same identity, so a second DLL with the product identity would otherwise be verified as the first.
function Assert-LoadedAssemblyIs([Reflection.Assembly] $Assembly, [string] $Path) {
    $expectedPath = [IO.Path]::GetFullPath($Path)
    # Read out of process: a reflection-only load in this host would itself refuse a second same-identity assembly.
    $expectedMvid = (Get-AssemblyMetadataIdentity ([IO.File]::ReadAllBytes($expectedPath))).Mvid
    if (-not [string]::Equals([IO.Path]::GetFullPath($Assembly.Location), $expectedPath, [StringComparison]::OrdinalIgnoreCase) -or
        $Assembly.ManifestModule.ModuleVersionId.ToString('D') -ne $expectedMvid) {
        throw "Loaded assembly binding mismatch: requested $expectedPath (MVID $expectedMvid) but this process has $($Assembly.Location) (MVID $($Assembly.ManifestModule.ModuleVersionId)). Run each candidate in its own process."
    }
}
