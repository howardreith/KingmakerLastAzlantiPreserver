[CmdletBinding()]
param(
    # Optional local copies of the two downloaded fixtures; otherwise they are downloaded. Both are hash-checked and
    # only ever read: the suite works on private copies.
    [string] $LegacyReleaseZip,
    [string] $WrongLoaderPackage,
    # Optional local copy of the official Lib.Harmony 2.3.1.1 package (net48 0Harmony.dll completes a disposable 0.31.1 profile).
    [string] $Harmony2Package,
    # Optional local copies of the official UnityModManager 0.33.4 and Lib.Harmony 2.4.3 packages (the newest stable
    # loader profile, used as a known-distinct disposable profile).
    [string] $NewestLoaderPackage,
    [string] $NewestHarmony2Package,
    [string] $ReportPath
)
# Failure-boundary tests for the pinned UMM 0.31.1 compile baseline, run on the committed HEAD in a temporary clone
# whose path contains a space. Every build, package and validation happens in that clone or in its own PowerShell /
# MSBuild process, so this repository's artifacts (including any package already in artifacts\packages) and the
# owner's installation are never written. Uses real files, archives, MSBuild and this repository's own scripts.
. (Join-Path $PSScriptRoot 'Common.ps1')
$source = Get-RepositoryRoot
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

# Genuine published release, compiled against UnityModManager 0.33.0.0 (its manifest says 0.33.0).
$legacyUrl = 'https://github.com/howardreith/KingmakerLastAzlantiPreserver/releases/download/v0.1.3/KingmakerLastAzlantiPreserver-0.1.3.zip'
$legacySha256 = '8b59d76d4583ed0108f1eb740c1669dbac4ea05dacb1003f728b612887d2fbed'
# Known distinct loader fixture (never the owner's install): the author's UnityModManager 0.32.4 NuGet package.
$wrongLoaderUrl = 'https://api.nuget.org/v3-flatcontainer/unitymodmanager/0.32.4/unitymodmanager.0.32.4.nupkg'
$wrongLoaderPackageSha256 = 'a8438e921ca7b0e5805f5a31c196ae65c90f236543885bea0146457d082c9ec9'
$wrongLoaderDllSha256 = '1387468bc3af41c50fe51859a3bb7af4922891aa8f13a6187e7a348ceaabfd88'
$modFolder = 'KingmakerLastAzlantiPreserver'
$Configuration = 'Release'

$commit = (& git -C $source rev-parse HEAD).Trim()
if ([bool](& git -C $source status --porcelain)) { Write-Host "NOTE: uncommitted changes are not tested; the suite tests committed HEAD $commit." }
$sourcePackagesBefore = @(Get-ChildItem -LiteralPath (Join-Path $source 'artifacts\packages') -File -ErrorAction SilentlyContinue | ForEach-Object { $_.Name + '=' + (Get-Sha256 $_.FullName) })
$temp = Join-Path ([IO.Path]::GetTempPath()) ('klap-loader-baseline-' + [Guid]::NewGuid().ToString('N'))
$base = Join-Path $temp 'clone with space'
$inputs = Join-Path $temp 'inputs'
New-Item -ItemType Directory -Path $inputs -Force | Out-Null
$cases = [Collections.Generic.List[object]]::new()
# The repository builds with `dotnet msbuild` (Build-Local.ps1 / Invoke-MSBuild); the suite uses the same engine.
$dotnet = (Get-Command dotnet -ErrorAction Stop).Source
$config = Get-KingmakerConfiguration

# Each check runs in a fresh Windows PowerShell process with an empty, closed stdin. Every output record is turned
# into text with its own ToString(), so stderr messages are never re-wrapped at console width by Out-String.
function ConvertTo-PlainText($Records) { return (@($Records | ForEach-Object { "$_" }) -join "`n") }
function Invoke-Isolated([string[]] $Arguments) {
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { $records = $null | & powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass @Arguments 2>&1 }
    finally { $ErrorActionPreference = $previous }
    return [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = (ConvertTo-PlainText $records) }
}
function Invoke-Script([string] $Text) {
    $wrapped = "try { $Text } catch { [Console]::Out.WriteLine('ERROR: ' + `$_.Exception.Message); exit 1 }"
    return Invoke-Isolated @('-EncodedCommand', [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($wrapped)))
}
function Invoke-MSBuildIsolated([string[]] $Arguments) {
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { $output = ConvertTo-PlainText ($null | & $dotnet msbuild /nologo /v:m /nr:false @Arguments 2>&1) }
    finally { $ErrorActionPreference = $previous }
    return [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = $output }
}
function Add-Case([string] $Name, [bool] $Passed, [string] $Detail) {
    $cases.Add([ordered]@{ name = $Name; passed = $Passed; detail = $Detail })
    if ($Passed) { Write-Host "PASS $Name :: $Detail" } else { Write-Host "FAIL $Name :: $Detail" }
}
function Get-Reason([string] $Output) {
    $line = @($Output -split "`r?`n" | Where-Object { $_ -match '^ERROR: |: error ' } | Select-Object -First 1)
    if (-not $line) { $line = @($Output -split "`r?`n" | Where-Object { $_ -match '(?i)must|mismatch|missing|does not|unexpected|exactly|changed|contains|rebuild|refus|not valid' -and $_ -notmatch '^PASS ' } | Select-Object -First 1) }
    if (-not $line) { $line = @($Output -split "`r?`n" | Where-Object { $_ -match '(?i)passed|Package:|SHA-256' } | Select-Object -First 1) }
    if ($line) { return $line[0].Trim() } else { return ($Output.Trim() -split "`r?`n" | Select-Object -Last 1) }
}
function Expect-Rejected([string] $Name, $Result, [string] $Pattern) {
    $ok = $Result.ExitCode -ne 0 -and ($Result.Output -replace '\s+', ' ') -match $Pattern
    $detail = if ($ok) { 'rejected: ' + (Get-Reason $Result.Output) } else { "exit $($Result.ExitCode); expected /$Pattern/; output: $($Result.Output.Trim())" }
    Add-Case $Name $ok $detail
}
function Expect-Accepted([string] $Name, $Result, [string] $Pattern) {
    $ok = $Result.ExitCode -eq 0 -and (-not $Pattern -or ($Result.Output -replace '\s+', ' ') -match $Pattern)
    $detail = if ($ok -and $Pattern) { 'accepted: ' + [regex]::Match($Result.Output, $Pattern).Value } elseif ($ok) { 'accepted' } else { "exit $($Result.ExitCode); output: $($Result.Output.Trim())" }
    Add-Case $Name $ok $detail
}
function Copy-Pins([string] $From, [string] $Destination) {
    New-Item -ItemType Directory -Force -Path $Destination | Out-Null
    foreach ($file in @('UnityModManager.dll', '0Harmony12.dll')) { Copy-Item -LiteralPath (Join-Path $From $file) -Destination $Destination }
}
function Edit-Zip([string] $From, [string] $Destination, [scriptblock] $Edit) {
    Copy-Item -LiteralPath $From -Destination $Destination
    $archive = [IO.Compression.ZipFile]::Open($Destination, [IO.Compression.ZipArchiveMode]::Update)
    try { & $Edit $archive } finally { $archive.Dispose() }
}
function Set-ZipEntryText($Archive, [string] $Name, [string] $Text) {
    $Archive.GetEntry($Name).Delete()
    $writer = [IO.StreamWriter]::new($Archive.CreateEntry($Name).Open(), [Text.UTF8Encoding]::new($false))
    try { $writer.Write($Text) } finally { $writer.Dispose() }
}
function Get-ZipEntryText($Archive, [string] $Name) {
    $reader = [IO.StreamReader]::new($Archive.GetEntry($Name).Open(), [Text.Encoding]::UTF8, $true)
    try { return $reader.ReadToEnd() } finally { $reader.Dispose() }
}
function Set-ZipEntryFile($Archive, [string] $Name, [string] $Path) {
    $existing = $Archive.GetEntry($Name)
    if ($existing) { $existing.Delete() }
    [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($Archive, $Path, $Name) | Out-Null
}
function Get-CompilerReferences([string] $Output, [string] $File) {
    $line = @($Output -split "`r?`n" | Where-Object { $_ -match 'csc\.(exe|dll)' }) -join "`n"
    return @([regex]::Matches($line, '/reference:(?:"([^"]+)"|(\S+))') | ForEach-Object {
        if ($_.Groups[1].Success) { $_.Groups[1].Value } else { $_.Groups[2].Value } } | Where-Object { [IO.Path]::GetFileName($_) -ieq $File })
}
function Edit-Json([string] $Path, [scriptblock] $Edit) {
    $j = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    & $Edit $j
    $j | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $Path -Encoding UTF8
}
function Quote([string] $Value) { return "'" + $Value.Replace("'", "''") + "'" }

try {
    # Private, verified inputs (the originals are only read).
    $legacyZip = Join-Path $inputs 'legacy-v0.1.3.zip'
    if ($LegacyReleaseZip) { Copy-Item -LiteralPath $LegacyReleaseZip -Destination $legacyZip } else { Invoke-WebRequest -Uri $legacyUrl -OutFile $legacyZip -UseBasicParsing }
    if ((Get-Sha256 $legacyZip) -ne $legacySha256) { throw 'Legacy release ZIP hash mismatch.' }
    $legacyOriginalSha = if ($LegacyReleaseZip) { Get-Sha256 $LegacyReleaseZip } else { $null }
    $wrongPackage = Join-Path $inputs 'unitymodmanager.0.32.4.nupkg'
    if ($WrongLoaderPackage) { Copy-Item -LiteralPath $WrongLoaderPackage -Destination $wrongPackage } else { Invoke-WebRequest -Uri $wrongLoaderUrl -OutFile $wrongPackage -UseBasicParsing }
    if ((Get-Sha256 $wrongPackage) -ne $wrongLoaderPackageSha256) { throw 'UnityModManager 0.32.4 package hash mismatch.' }
    $wrongDir = Join-Path $inputs 'umm-0.32.4'
    New-Item -ItemType Directory -Path $wrongDir | Out-Null
    $wrongUmm = Join-Path $wrongDir 'UnityModManager.dll'
    $archive = [IO.Compression.ZipFile]::OpenRead($wrongPackage)
    try { [IO.Compression.ZipFileExtensions]::ExtractToFile($archive.GetEntry('lib/net35/UnityModManager.dll'), $wrongUmm) }
    finally { $archive.Dispose() }
    if ((Get-Sha256 $wrongUmm) -ne $wrongLoaderDllSha256) { throw 'UnityModManager 0.32.4 DLL hash mismatch.' }
    $legacyDll = Join-Path $inputs 'legacy-v0.1.3.dll'
    $archive = [IO.Compression.ZipFile]::OpenRead($legacyZip)
    try { [IO.Compression.ZipFileExtensions]::ExtractToFile($archive.GetEntry("$modFolder/KingmakerLastAzlantiPreserver.dll"), $legacyDll) }
    finally { $archive.Dispose() }
    $installedUmm = Join-Path $config.UnityModManagerDir 'UnityModManager.dll'
    $ownerMeasurement = [ordered]@{ version = [Reflection.AssemblyName]::GetAssemblyName($installedUmm).Version.ToString(); sha256 = Get-Sha256 $installedUmm }
    Write-Host "Owner-installed UnityModManager (measured only, not used as a fixture): $($ownerMeasurement.version) $($ownerMeasurement.sha256)"

    # Disposable loader profiles, component-assembled from official NuGet packages (never the owner's install):
    # 0.31.1 = pinned UnityModManager + 0Harmony12 + Lib.Harmony 2.3.1.1 net48; 0.33.4 = UnityModManager 0.33.4 + 0Harmony12 +
    # Lib.Harmony 2.4.3 net48 (known distinct); plus a byte-identical copy of 0.31.1 at another path.
    function Get-NuGetEntry([string] $Supplied, [string] $Url, [string] $PackageSha, [string] $Entry, [string] $EntrySha, [string] $Destination) {
        $pkg = Join-Path $inputs ([IO.Path]::GetFileName($Url))
        if ($Supplied) { Copy-Item -LiteralPath $Supplied -Destination $pkg } else { Invoke-WebRequest -Uri $Url -OutFile $pkg -UseBasicParsing }
        if ((Get-Sha256 $pkg) -ne $PackageSha) { throw "$([IO.Path]::GetFileName($Url)) hash mismatch." }
        $a = [IO.Compression.ZipFile]::OpenRead($pkg)
        try { [IO.Compression.ZipFileExtensions]::ExtractToFile($a.GetEntry($Entry), $Destination) } finally { $a.Dispose() }
        if ((Get-Sha256 $Destination) -ne $EntrySha) { throw "$Entry from $([IO.Path]::GetFileName($Url)) hash mismatch." }
    }
    $sourcePins = Get-PinnedReferenceDirectory
    $profileRoot = Join-Path $temp 'profiles'
    $baselineProfile = Join-Path $profileRoot '0.31.1'
    $newestProfile = Join-Path $profileRoot '0.33.4'
    New-Item -ItemType Directory -Path $baselineProfile, $newestProfile -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $sourcePins 'UnityModManager.dll'), (Join-Path $sourcePins '0Harmony12.dll') -Destination $baselineProfile
    Get-NuGetEntry $Harmony2Package 'https://api.nuget.org/v3-flatcontainer/lib.harmony/2.3.1.1/lib.harmony.2.3.1.1.nupkg' 'b9096d3e2191ca18b803e2894511a2ee4ec6c92050e53853b46ebfeed46798aa' 'lib/net48/0Harmony.dll' '5f7ad0df1eb08e81f66d4006d3a9e5cb40fc05e381f36d7bd0513f334f6a251f' (Join-Path $baselineProfile '0Harmony.dll')
    Copy-Item -LiteralPath (Join-Path $sourcePins '0Harmony12.dll') -Destination $newestProfile
    Get-NuGetEntry $NewestLoaderPackage 'https://api.nuget.org/v3-flatcontainer/unitymodmanager/0.33.4/unitymodmanager.0.33.4.nupkg' '7cbab8edccd9db54f8a9e61fdd7969ae1e908c1f53d1509d29ad20fdfdade66b' 'lib/net35/UnityModManager.dll' 'c5ed5617457f597d7befb272f9fe311d7128c647fd427a114c197bea13475239' (Join-Path $newestProfile 'UnityModManager.dll')
    Get-NuGetEntry $NewestHarmony2Package 'https://api.nuget.org/v3-flatcontainer/lib.harmony/2.4.3/lib.harmony.2.4.3.nupkg' 'f07af11a0d62447e7e1b6e3fcf1e28fc75d9f8d1abf2d6ee79aabcdc4db43e88' 'lib/net48/0Harmony.dll' 'ddc070b57f695ece6f92c43cf82cf4d863c69685de96a99ebd9d2fa1d8fa7a19' (Join-Path $newestProfile '0Harmony.dll')
    $baselineCopy = Join-Path $temp 'profile copies\0.31.1 copy'
    New-Item -ItemType Directory -Path $baselineCopy -Force | Out-Null
    Copy-Item -Path (Join-Path $baselineProfile '*') -Destination $baselineCopy
    function Write-GamePath([string] $Path, [string] $LoaderDir, [string] $InstallDir = $config.InstallDir, [string] $ManagedDir = $config.ManagedDir, [string] $Extra = '') {
        $parent = Split-Path -Parent $Path
        if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
        $e = { param($value) [Security.SecurityElement]::Escape($value) }
        [IO.File]::WriteAllText($Path, "<Project xmlns=`"http://schemas.microsoft.com/developer/msbuild/2003`"><PropertyGroup><KingmakerInstallDir>$(& $e $InstallDir)</KingmakerInstallDir><KingmakerManagedDir>$(& $e $ManagedDir)</KingmakerManagedDir><UnityModManagerDir>$(& $e $LoaderDir)</UnityModManagerDir>$Extra</PropertyGroup></Project>")
    }
    $baselineProps = Join-Path $temp 'props 0.31.1\GamePath.props'
    $newestProps = Join-Path $temp 'props 0.33.4\GamePath.props'
    Write-GamePath $baselineProps $baselineProfile
    Write-GamePath $newestProps $newestProfile

    # Temporary clone of the committed HEAD under a path with a space; seed its ignored cache. Its local game paths start
    # on the disposable 0.31.1 baseline profile, so no check depends on the owner's installed loader.
    & git clone -q --no-hardlinks $source $base
    if ($LASTEXITCODE -ne 0) { throw 'git clone failed.' }
    & git -C $base checkout -q --detach $commit
    Write-GamePath (Join-Path $base 'GamePath.props') $baselineProfile
    # Disposable instrumented script copies made by some cases are local to the clone, never part of its status, and
    # removed right after use (they embed temporary paths that the repository's source scan refuses).
    Add-Content -LiteralPath (Join-Path $base '.git\info\exclude') -Value 'scripts/*-instrumented.ps1'
    function New-InstrumentedScript([string] $Name, [string] $After, [string] $Inject) {
        $text = [IO.File]::ReadAllText((Join-Path $base "scripts\$Name.ps1"))
        if ($text.IndexOf($After) -lt 0) { throw "Instrumentation anchor not found in $Name.ps1: $After" }
        $path = Join-Path $base "scripts\$Name-instrumented.ps1"
        $index = $text.IndexOf($After) + $After.Length
        [IO.File]::WriteAllText($path, $text.Substring(0, $index) + "`r`n" + $Inject + "`r`n" + $text.Substring($index))
        return $path
    }
    $references = Join-Path $base 'artifacts\references'
    Copy-Pins (Get-PinnedReferenceDirectory) $references
    $project = Join-Path $base 'src\KingmakerLastAzlantiPreserver\KingmakerLastAzlantiPreserver.csproj'
    $dll = Join-Path $base "artifacts\bin\$Configuration\KingmakerLastAzlantiPreserver\KingmakerLastAzlantiPreserver.dll"
    $receiptPath = Join-Path $base 'artifacts\qualification\build.json'
    $build = Invoke-Isolated @('-File', (Join-Path $base 'scripts\Build-Local.ps1'))
    if ($build.ExitCode -ne 0) { throw "Clone build failed: $($build.Output)" }
    $firstDllSha = Get-Sha256 $dll
    Copy-Item -LiteralPath $dll -Destination (Join-Path $inputs 'first-build-dll.dll')
    $firstReceipt = Join-Path $inputs 'first-build.json'
    Copy-Item -LiteralPath $receiptPath -Destination $firstReceipt
    $receipt = Get-Content -LiteralPath $receiptPath -Raw | ConvertFrom-Json
    Add-Case 'clone-build-from-detached-commit' ($receipt.source_commit -eq $commit -and -not $receipt.source_dirty -and $receipt.dll_sha256 -eq $firstDllSha) "detached clone build; receipt source_commit $($receipt.source_commit) dirty $($receipt.source_dirty) dll $firstDllSha inputs $($receipt.build_inputs_sha256)"
    $verifier = Join-Path $base 'scripts\Get-PinnedLoaderReferences.ps1'
    $pinnedUmm = [IO.Path]::GetFullPath((Join-Path $references 'UnityModManager.dll'))
    $pinnedHarmony = [IO.Path]::GetFullPath((Join-Path $references '0Harmony12.dll'))

    # 1. Reference cache: genuine bytes pass; corrupt, missing and distinct-loader bytes fail clearly.
    Expect-Accepted 'cache-genuine-verified' (Invoke-Isolated @('-File', $verifier, '-VerifyOnly', '-ReferenceDirectory', $references)) ''
    $corrupt = Join-Path $temp 'cache corrupt'
    Copy-Pins $references $corrupt
    $bytes = [IO.File]::ReadAllBytes((Join-Path $corrupt 'UnityModManager.dll'))
    $bytes[$bytes.Length - 1] = $bytes[$bytes.Length - 1] -bxor 0xFF
    [IO.File]::WriteAllBytes((Join-Path $corrupt 'UnityModManager.dll'), $bytes)
    Expect-Rejected 'cache-corrupt-rejected' (Invoke-Isolated @('-File', $verifier, '-VerifyOnly', '-ReferenceDirectory', $corrupt)) 'hash mismatch'
    $missing = Join-Path $temp 'cache missing'
    Copy-Pins $references $missing
    Remove-Item -LiteralPath (Join-Path $missing 'UnityModManager.dll')
    Expect-Rejected 'cache-missing-rejected' (Invoke-Isolated @('-File', $verifier, '-VerifyOnly', '-ReferenceDirectory', $missing)) 'reference missing'
    $wrongCache = Join-Path $temp 'cache wrong loader'
    Copy-Pins $references $wrongCache
    Copy-Item -LiteralPath $wrongUmm -Destination $wrongCache -Force
    Expect-Rejected 'cache-umm-0.32.4-fixture-rejected' (Invoke-Isolated @('-File', $verifier, '-VerifyOnly', '-ReferenceDirectory', $wrongCache)) 'hash mismatch'

    # 2. Pin definition and manifest contract, on copies of the clone's real scripts.
    function New-ManifestFixture([string] $Name, [scriptblock] $Edit) {
        $fixture = Join-Path $temp $Name
        New-Item -ItemType Directory -Force -Path (Join-Path $fixture 'scripts') | Out-Null
        Copy-Item -LiteralPath $verifier -Destination (Join-Path $fixture 'scripts')
        Copy-Item -LiteralPath (Join-Path $base 'scripts\loader-reference-pins.json') -Destination (Join-Path $fixture 'scripts')
        Copy-Item -LiteralPath (Join-Path $base 'Info.json') -Destination $fixture
        & $Edit $fixture
        return (Join-Path $fixture 'scripts\Get-PinnedLoaderReferences.ps1')
    }
    $f = New-ManifestFixture 'manifest control' { param($d) }
    Expect-Accepted 'manifest-control-accepted' (Invoke-Isolated @('-File', $f, '-VerifyOnly', '-ReferenceDirectory', $references)) ''
    $f = New-ManifestFixture 'pin harmony dropped' { param($d) Edit-Json (Join-Path $d 'scripts\loader-reference-pins.json') { param($j) $j.references = @($j.references | Where-Object Name -ne '0Harmony12') } }
    Expect-Rejected 'pin-definition-without-harmony12-rejected' (Invoke-Isolated @('-File', $f, '-VerifyOnly', '-ReferenceDirectory', $references)) 'must define exactly'
    $f = New-ManifestFixture 'pin harmony renamed' { param($d) Edit-Json (Join-Path $d 'scripts\loader-reference-pins.json') { param($j) @($j.references | Where-Object Name -eq '0Harmony12')[0].Name = 'Harmony12' } }
    Expect-Rejected 'pin-definition-misnamed-harmony12-rejected' (Invoke-Isolated @('-File', $f, '-VerifyOnly', '-ReferenceDirectory', $references)) 'must define 0Harmony12 exactly once'
    $f = New-ManifestFixture 'manifest raised' { param($d) Edit-Json (Join-Path $d 'Info.json') { param($j) $j.ManagerVersion = '0.33.0' } }
    Expect-Rejected 'manifest-above-compiler-reference-rejected' (Invoke-Isolated @('-File', $f, '-VerifyOnly', '-ReferenceDirectory', $references)) 'ManagerVersion must equal'
    $f = New-ManifestFixture 'manifest array' { param($d) Edit-Json (Join-Path $d 'Info.json') { param($j) $j.ManagerVersion = @('0.31.1') } }
    Expect-Rejected 'manifest-array-version-rejected' (Invoke-Isolated @('-File', $f, '-VerifyOnly', '-ReferenceDirectory', $references)) 'ManagerVersion must equal'
    $f = New-ManifestFixture 'pin raised' { param($d) Edit-Json (Join-Path $d 'scripts\loader-reference-pins.json') { param($j) @($j.references | Where-Object Name -eq 'UnityModManager')[0].Version = '0.33.0.0' } }
    Expect-Rejected 'compiler-pin-above-minimum-rejected' (Invoke-Isolated @('-File', $f, '-VerifyOnly', '-ReferenceDirectory', $references)) 'must equal the declared minimum'

    # 3. Direct MSBuild of the production project: corrupt cache refused; genuine cache compiles with exactly the
    #    pinned files as csc inputs (the clone path contains a space, so csc quotes them).
    $obj = Join-Path $temp 'direct-obj\'
    $out = Join-Path $temp 'direct-bin\'
    Expect-Rejected 'msbuild-corrupt-cache-rejected' (Invoke-MSBuildIsolated @($project, '/t:Build', "/p:Configuration=$Configuration",
        "/p:PinnedLoaderReferenceDir=$corrupt", "/p:IntermediateOutputPath=$obj", "/p:OutputPath=$out")) 'hash mismatch'
    $direct = Invoke-MSBuildIsolated @($project, '/t:Rebuild', '/v:n', "/p:Configuration=$Configuration", "/p:IntermediateOutputPath=$obj", "/p:OutputPath=$out")
    $umm = @(Get-CompilerReferences $direct.Output 'UnityModManager.dll')
    $h12 = @(Get-CompilerReferences $direct.Output '0Harmony12.dll')
    $ok = $direct.ExitCode -eq 0 -and $umm.Count -eq 1 -and $umm[0] -ieq $pinnedUmm -and $h12.Count -eq 1 -and $h12[0] -ieq $pinnedHarmony
    Add-Case 'msbuild-direct-compiles-against-pinned-inputs' $ok ("exit {0}; csc UnityModManager: {1}; csc 0Harmony12: {2}" -f $direct.ExitCode, ($umm -join ' | '), ($h12 -join ' | '))

    # 4. Incremental (IDE-style) builds: after an up-to-date build, changing only the manifest or a pin is refused by
    #    an ordinary incremental Build; restoring the genuine inputs is accepted again.
    $iobj = Join-Path $temp 'incremental-obj\'
    $iout = Join-Path $temp 'incremental-bin\'
    $inc = @($project, '/t:Build', "/p:Configuration=$Configuration", "/p:IntermediateOutputPath=$iobj", "/p:OutputPath=$iout")
    Expect-Accepted 'incremental-build-genuine-accepted' (Invoke-MSBuildIsolated $inc) ''
    Expect-Accepted 'incremental-build-up-to-date-accepted' (Invoke-MSBuildIsolated $inc) ''
    Edit-Json (Join-Path $base 'Info.json') { param($j) $j.ManagerVersion = '0.33.0' }
    Expect-Rejected 'incremental-build-after-manifest-only-change-rejected' (Invoke-MSBuildIsolated $inc) 'ManagerVersion must equal'
    & git -C $base checkout -q -- Info.json
    Edit-Json (Join-Path $base 'scripts\loader-reference-pins.json') { param($j) @($j.references | Where-Object Name -eq '0Harmony12')[0].Sha256 = ('0' * 64) }
    Expect-Rejected 'incremental-build-after-pin-only-change-rejected' (Invoke-MSBuildIsolated $inc) 'hash mismatch'
    & git -C $base checkout -q -- scripts/loader-reference-pins.json
    Expect-Accepted 'incremental-build-after-restore-accepted' (Invoke-MSBuildIsolated $inc) ''

    # 5. Resolved-input guard: only the canonical verified files qualify, by path and by assembly identity.
    $stray = Join-Path $temp 'stray copy'
    Copy-Pins $references $stray
    Copy-Item -LiteralPath $pinnedUmm -Destination (Join-Path $references 'UnityModManager.exe')
    Copy-Item -LiteralPath $pinnedUmm -Destination (Join-Path $references 'umm-alias.dll')
    $targets = Join-Path $base 'LoaderReferences.targets'
    function New-ProbeProject([string] $Name, [string] $UmmPath) {
        $path = Join-Path $temp "probe $Name.csproj"
        $text = @"
<Project ToolsVersion="15.0" DefaultTargets="Build" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
  <Import Project="`$(MSBuildExtensionsPath)\`$(MSBuildToolsVersion)\Microsoft.Common.props" Condition="Exists('`$(MSBuildExtensionsPath)\`$(MSBuildToolsVersion)\Microsoft.Common.props')" />
  <PropertyGroup>
    <TargetFrameworkVersion>v4.7.2</TargetFrameworkVersion>
    <OutputType>Library</OutputType>
    <OutputPath>$temp\probe bin\$Name\</OutputPath>
    <IntermediateOutputPath>$temp\probe obj\$Name\</IntermediateOutputPath>
    <ResolveAssemblyReferenceIgnoreTargetFrameworkAttributeVersionMismatch>true</ResolveAssemblyReferenceIgnoreTargetFrameworkAttributeVersionMismatch>
  </PropertyGroup>
  <Import Project="$targets" />
  <ItemGroup>
    <Reference Include="UnityModManager"><HintPath>$UmmPath</HintPath><Private>False</Private></Reference>
    <Reference Include="0Harmony12"><HintPath>$pinnedHarmony</HintPath><Private>False</Private></Reference>
  </ItemGroup>
  <Import Project="`$(MSBuildToolsPath)\Microsoft.CSharp.targets" />
</Project>
"@
        [IO.File]::WriteAllText($path, $text)
        return $path
    }
    Expect-Accepted 'resolved-input-pinned-accepted' (Invoke-MSBuildIsolated @((New-ProbeProject 'pinned' $pinnedUmm), '/t:ResolveReferences;FindReferenceAssembliesForReferences')) ''
    Expect-Rejected 'resolved-input-identical-copy-elsewhere-rejected' (Invoke-MSBuildIsolated @((New-ProbeProject 'stray' (Join-Path $stray 'UnityModManager.dll')), '/t:ResolveReferences;FindReferenceAssembliesForReferences')) 'must be the verified files'
    Expect-Rejected 'resolved-input-same-stem-file-in-pinned-dir-rejected' (Invoke-MSBuildIsolated @((New-ProbeProject 'samestem' (Join-Path $references 'UnityModManager.exe')), '/t:ResolveReferences;FindReferenceAssembliesForReferences')) 'must be the verified files'
    Expect-Rejected 'resolved-input-renamed-loader-in-pinned-dir-rejected' (Invoke-MSBuildIsolated @((New-ProbeProject 'alias' (Join-Path $references 'umm-alias.dll')), '/t:ResolveReferences;FindReferenceAssembliesForReferences')) 'must be the verified files'
    Expect-Rejected 'resolved-input-umm-0.32.4-fixture-rejected' (Invoke-MSBuildIsolated @((New-ProbeProject 'wrong' $wrongUmm), '/t:ResolveReferences;FindReferenceAssembliesForReferences')) 'must be the verified files'
    # A reference assembly substituted after resolution: ReferencePath stays valid, the Csc input does not.
    $substituted = (New-ProbeProject 'substituted' $pinnedUmm)
    $substitution = @"
  <Target Name="SubstituteLoaderReferenceAssembly" AfterTargets="ResolveAssemblyReferences" BeforeTargets="FindReferenceAssembliesForReferences">
    <ItemGroup>
      <ReferencePath Condition="'%(Filename)' == 'UnityModManager'"><ReferenceAssembly>$(Join-Path $stray 'UnityModManager.dll')</ReferenceAssembly></ReferencePath>
    </ItemGroup>
  </Target>
</Project>
"@
    [IO.File]::WriteAllText($substituted, ([IO.File]::ReadAllText($substituted).Replace('</Project>', $substitution)))
    Expect-Rejected 'resolved-input-substituted-reference-assembly-rejected' (Invoke-MSBuildIsolated @($substituted, '/t:ResolveReferences;FindReferenceAssembliesForReferences')) 'must be the verified files'
    Remove-Item -LiteralPath (Join-Path $references 'UnityModManager.exe'), (Join-Path $references 'umm-alias.dll')

    # 6. Build receipts bind the DLL bytes, configuration, material inputs and pinned identities; packaging and
    #    qualification refuse to reuse a DLL after any material input changes, and accept a matching rebuild.
    $common = Join-Path $base 'scripts\Common.ps1'
    function Test-Receipt([string] $ReceiptFile, [string] $DllFile, [string] $Config) {
        return Invoke-Script ". $(Quote $common); Assert-PinnedBuildReceipt (Get-Content -LiteralPath $(Quote $ReceiptFile) -Raw | ConvertFrom-Json) $(Quote $DllFile) $(Quote $Config)"
    }
    $package = Join-Path $base 'scripts\Package.ps1'
    $marker = 'src\KingmakerLastAzlantiPreserver\ProductMetadata.cs'
    Expect-Accepted 'receipt-matching-build-accepted' (Test-Receipt $receiptPath $dll 'Release') ''
    Expect-Rejected 'receipt-other-configuration-rejected' (Test-Receipt $receiptPath $dll 'Debug') 'not Debug'
    foreach ($mutation in @(
        @{ Name = 'production-source'; File = $marker; Text = "`r`n// loader-baseline test edit`r`n" },
        @{ Name = 'reference-helper'; File = 'scripts\Get-PinnedLoaderReferences.ps1'; Text = "`r`n# loader-baseline test edit`r`n" },
        @{ Name = 'msbuild-guard'; File = 'LoaderReferences.targets'; Text = "`r`n<!-- loader-baseline test edit -->`r`n" },
        @{ Name = 'project-file'; File = 'src\KingmakerLastAzlantiPreserver\KingmakerLastAzlantiPreserver.csproj'; Text = "`r`n<!-- loader-baseline test edit -->`r`n" })) {
        [IO.File]::AppendAllText((Join-Path $base $mutation.File), $mutation.Text)
        Expect-Rejected "package-reuse-after-$($mutation.Name)-change-rejected" (Invoke-Isolated @('-File', $package)) 'Build inputs changed'
        & git -C $base checkout -q -- ($mutation.File.Replace('\', '/'))
    }
    [IO.File]::AppendAllText((Join-Path $base $marker), "`r`n// loader-baseline test edit`r`n")
    Expect-Rejected 'qualify-package-reuse-after-source-change-rejected' (Invoke-Isolated @('-File', (Join-Path $base 'scripts\Qualify.ps1'), '-Package')) 'Build inputs changed'
    & git -C $base checkout -q -- ($marker.Replace('\', '/'))
    $packaged = Invoke-Isolated @('-File', $package)
    $zipMatch = [regex]::Match($packaged.Output, 'Package: (.+\.zip)')
    Add-Case 'package-after-restoring-identical-inputs-accepted' ($packaged.ExitCode -eq 0 -and $zipMatch.Success) ('accepted: ' + (Get-Reason $packaged.Output))
    if (-not $zipMatch.Success) { throw "Package.ps1 failed: $($packaged.Output)" }
    $candidateZip = Join-Path $inputs 'candidate.zip'
    Copy-Item -LiteralPath $zipMatch.Groups[1].Value.Trim() -Destination $candidateZip

    # A changed build (different IL) checked against the first receipt.
    [IO.File]::AppendAllText((Join-Path $base $marker), "`r`nnamespace KingmakerLastAzlantiPreserver { internal static class LoaderBaselineTestMarker { } }`r`n")
    $rebuild = Invoke-Isolated @('-File', (Join-Path $base 'scripts\Build-Local.ps1'))
    $secondDllSha = Get-Sha256 $dll
    Add-Case 'rebuild-after-source-change-accepted' ($rebuild.ExitCode -eq 0 -and $secondDllSha -ne $firstDllSha) "exit $($rebuild.ExitCode); first DLL $firstDllSha; changed-source DLL $secondDllSha"
    $second = Invoke-Isolated @('-File', $package)
    $secondMatch = [regex]::Match($second.Output, 'Package: (.+\.zip)')
    Add-Case 'package-after-matching-rebuild-accepted' ($second.ExitCode -eq 0 -and $secondMatch.Success) ('accepted: ' + (Get-Reason $second.Output))
    $secondZip = Join-Path $inputs 'changed-source-candidate.zip'
    if ($secondMatch.Success) { Copy-Item -LiteralPath $secondMatch.Groups[1].Value.Trim() -Destination $secondZip }
    Expect-Rejected 'receipt-of-first-build-for-changed-dll-rejected' (Test-Receipt $firstReceipt $dll 'Release') 'does not match the mod DLL'
    $validator = Join-Path $base 'scripts\Validate-Package.ps1'
    Expect-Rejected 'archived-dll-vs-first-receipt-rejected' (Invoke-Isolated @('-File', $validator, '-PackagePath', $secondZip, '-ExpectedDllSha256', $firstDllSha)) 'does not match the build receipt'
    & git -C $base checkout -q -- ($marker.Replace('\', '/'))
    $rebuild = Invoke-Isolated @('-File', (Join-Path $base 'scripts\Build-Local.ps1'))
    Add-Case 'rebuild-of-committed-source-reproduces-first-dll' ($rebuild.ExitCode -eq 0 -and (Get-Sha256 $dll) -eq $firstDllSha) "DLL $(Get-Sha256 $dll)"
    $conflict = Join-Path $inputs 'receipt-conflicting-version.json'
    Copy-Item -LiteralPath $receiptPath -Destination $conflict
    Edit-Json $conflict { param($j) @($j.loader_references | Where-Object file -eq 'UnityModManager.dll')[0].assembly_version = '0.33.0.0' }
    Expect-Rejected 'receipt-conflicting-observed-version-rejected' (Test-Receipt $conflict $dll 'Release') 'does not match pinned reference UnityModManager\.dll'
    $noRefs = Join-Path $inputs 'receipt-no-refs.json'
    Get-Content -LiteralPath $receiptPath -Raw | ConvertFrom-Json | Select-Object -Property * -ExcludeProperty loader_references | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $noRefs -Encoding UTF8
    Expect-Rejected 'receipt-without-loader-references-rejected' (Test-Receipt $noRefs $dll 'Release') 'no loader_references'
    $otherLoader = Join-Path $inputs 'receipt-other-loader.json'
    Copy-Item -LiteralPath $receiptPath -Destination $otherLoader
    Edit-Json $otherLoader { param($j) @($j.loader_references | Where-Object file -eq 'UnityModManager.dll')[0].sha256 = $wrongLoaderDllSha256 }
    Expect-Rejected 'receipt-recording-other-loader-rejected' (Test-Receipt $otherLoader $dll 'Release') 'does not match pinned reference UnityModManager\.dll'


    # 6b. Wrapper and resolved managed-reference changes also invalidate reuse; malformed receipt fields are refused.
    [IO.File]::AppendAllText((Join-Path $base 'scripts\Build-Local.ps1'), "`r`n# loader-baseline test edit`r`n")
    Expect-Rejected 'package-reuse-after-build-wrapper-change-rejected' (Invoke-Isolated @('-File', $package)) 'Build inputs changed'
    & git -C $base checkout -q -- scripts/Build-Local.ps1
    $gamePath = Join-Path $base 'GamePath.props'
    $gamePathOriginal = [IO.File]::ReadAllText($gamePath)
    $managedCopy = Join-Path $temp 'managed copy'
    New-Item -ItemType Directory -Path (Join-Path $managedCopy 'UnityModManager') -Force | Out-Null
    [xml] $projectXml = Get-Content -LiteralPath $project -Raw
    foreach ($hint in @($projectXml.SelectNodes("//*[local-name()='Reference']/*[local-name()='HintPath']") | ForEach-Object { $_.InnerText } | Where-Object { $_.StartsWith('$(KingmakerManagedDir)') })) {
        $name = $hint.Substring('$(KingmakerManagedDir)'.Length).TrimStart('\')
        Copy-Item -LiteralPath (Join-Path $config.ManagedDir $name) -Destination (Join-Path $managedCopy $name)
    }
    Copy-Item -LiteralPath $pinnedUmm, $pinnedHarmony -Destination (Join-Path $managedCopy 'UnityModManager')
    [IO.File]::WriteAllText($gamePath, "<Project xmlns=`"http://schemas.microsoft.com/developer/msbuild/2003`"><PropertyGroup><KingmakerInstallDir>$($config.InstallDir)</KingmakerInstallDir><KingmakerManagedDir>$managedCopy</KingmakerManagedDir><UnityModManagerDir>$(Join-Path $managedCopy 'UnityModManager')</UnityModManagerDir></PropertyGroup></Project>")
    Expect-Accepted 'package-with-identical-managed-references-elsewhere-accepted' (Invoke-Isolated @('-File', $package)) 'Package validation passed'
    $uiBytes = [IO.File]::ReadAllBytes((Join-Path $managedCopy 'UnityEngine.CoreModule.dll'))
    $uiBytes[$uiBytes.Length - 1] = $uiBytes[$uiBytes.Length - 1] -bxor 0x01
    [IO.File]::WriteAllBytes((Join-Path $managedCopy 'UnityEngine.CoreModule.dll'), $uiBytes)
    Expect-Rejected 'package-reuse-after-resolved-managed-reference-change-rejected' (Invoke-Isolated @('-File', $package)) 'Build inputs changed'
    [IO.File]::WriteAllText($gamePath, $gamePathOriginal)
    # An effective compiler setting imported from GamePath.props (checked arithmetic) is a build input; a rebuild with it
    # records it and is accepted, and removing it again needs another rebuild.
    Write-GamePath $gamePath $baselineProfile -Extra '<CheckForOverflowUnderflow>true</CheckForOverflowUnderflow>'
    Expect-Rejected 'package-reuse-after-imported-compiler-setting-change-rejected' (Invoke-Isolated @('-File', $package)) 'Build inputs changed'
    $settingBuild = Invoke-Isolated @('-File', (Join-Path $base 'scripts\Build-Local.ps1'))
    $settingReceipt = Get-Content -LiteralPath $receiptPath -Raw | ConvertFrom-Json
    $settingSha = Get-Sha256 $dll
    $checkedArithmeticDll = Join-Path $inputs 'checked-arithmetic.dll'
    Copy-Item -LiteralPath $dll -Destination $checkedArithmeticDll
    $ok = $settingBuild.ExitCode -eq 0 -and $settingSha -ne $firstDllSha -and @($settingReceipt.compiler_references | Where-Object { $_.kind -eq 'setting' -and $_.name -ceq 'CheckForOverflowUnderflow=true' }).Count -eq 1
    Add-Case 'rebuild-with-imported-compiler-setting-records-it' $ok "exit $($settingBuild.ExitCode); DLL $settingSha (committed configuration: $firstDllSha); receipt compiler inputs include CheckForOverflowUnderflow=true"
    Expect-Accepted 'package-after-rebuild-with-imported-compiler-setting-accepted' (Invoke-Isolated @('-File', $package)) 'Package validation passed'
    [IO.File]::WriteAllText($gamePath, $gamePathOriginal)
    Expect-Rejected 'package-reuse-after-imported-setting-removed-rejected' (Invoke-Isolated @('-File', $package)) 'Build inputs changed'
    $rebuild = Invoke-Isolated @('-File', (Join-Path $base 'scripts\Build-Local.ps1'))
    Add-Case 'rebuild-without-imported-setting-reproduces-first-dll' ($rebuild.ExitCode -eq 0 -and (Get-Sha256 $dll) -eq $firstDllSha) "DLL $(Get-Sha256 $dll)"
    # Build and packaging need the game assemblies and pins, not the runtime loader; the managed contract check does.
    Write-GamePath $gamePath (Join-Path $temp 'no loader here')
    $noLoader = Invoke-Isolated @('-File', (Join-Path $base 'scripts\Build-Local.ps1'))
    Add-Case 'build-local-without-runtime-loader-directory' ($noLoader.ExitCode -eq 0 -and (Get-Sha256 $dll) -eq $firstDllSha) ("exit $($noLoader.ExitCode); DLL $(Get-Sha256 $dll)" + $(if ($noLoader.ExitCode) { '; ' + (Get-Reason $noLoader.Output) } else { '' }))
    Expect-Accepted 'package-without-runtime-loader-directory' (Invoke-Isolated @('-File', $package)) 'Package validation passed'
    Expect-Rejected 'contract-check-reports-missing-runtime-loader' (Invoke-Isolated @('-File', (Join-Path $base 'scripts\Verify-KingmakerContracts.ps1'), '-OutputPath', (Join-Path $inputs 'no-loader-contracts.json'), '-GameOverOutputPath', (Join-Path $inputs 'no-loader-go.json'))) 'UnityModManager\.dll'
    [IO.File]::WriteAllText($gamePath, $gamePathOriginal)
    $savedReceipt = Join-Path $inputs 'genuine-receipt.json'
    Copy-Item -LiteralPath $receiptPath -Destination $savedReceipt -Force
    foreach ($bad in @(
        @{ Name = 'dll-digest-array'; Edit = { param($j) $j.dll_sha256 = @($j.dll_sha256) } },
        @{ Name = 'dll-digest-boolean'; Edit = { param($j) $j.dll_sha256 = $true } },
        @{ Name = 'inputs-digest-array'; Edit = { param($j) $j.build_inputs_sha256 = @($j.build_inputs_sha256, ('0' * 64)) } },
        @{ Name = 'configuration-array'; Edit = { param($j) $j.configuration = @('Release') } },
        @{ Name = 'loader-version-array'; Edit = { param($j) @($j.loader_references)[0].version = @(@($j.loader_references)[0].version) } })) {
        Copy-Item -LiteralPath $savedReceipt -Destination $receiptPath -Force
        Edit-Json $receiptPath $bad.Edit
        Expect-Rejected "package-receipt-$($bad.Name)-rejected" (Invoke-Isolated @('-File', $package)) 'must be (a lowercase SHA-256 string|a string)'
    }
    Copy-Item -LiteralPath $savedReceipt -Destination $receiptPath -Force
    Expect-Accepted 'package-genuine-receipt-accepted' (Invoke-Isolated @('-File', $package)) 'Package validation passed'

    # 7. Standalone validator on real archives: each case in its own process, and both archives in one host.
    $v = { param($zip) Invoke-Isolated @('-File', $validator, '-PackagePath', $zip) }
    Expect-Accepted 'package-candidate-accepted' (& $v $candidateZip) 'Packaged DLL SHA-256: [0-9a-f]{64}; MVID: [0-9a-f-]{36}; loader references: UnityModManager 0\.31\.1\.0, 0Harmony12 1\.2\.0\.1'
    Expect-Accepted 'package-candidate-matches-receipt-dll' (Invoke-Isolated @('-File', $validator, '-PackagePath', $candidateZip, '-ExpectedDllSha256', $firstDllSha)) 'Package validation passed'
    $p = Join-Path $inputs 'extra-harmony.zip'; Edit-Zip $candidateZip $p { param($a) Set-ZipEntryFile $a "$modFolder/0Harmony12.dll" $pinnedHarmony }
    Expect-Rejected 'package-extra-harmony-rejected' (& $v $p) 'Expected exactly \d+ package files'
    $p = Join-Path $inputs 'swap-loader.zip'; Edit-Zip $candidateZip $p { param($a) $a.GetEntry("$modFolder/README.md").Delete(); Set-ZipEntryFile $a "$modFolder/UnityModManager.dll" $pinnedUmm }
    Expect-Rejected 'package-swapped-in-loader-rejected' (& $v $p) 'Package allowlist mismatch'
    $p = Join-Path $inputs 'swap-game.zip'; Edit-Zip $candidateZip $p { param($a) $a.GetEntry("$modFolder/README.md").Delete(); Set-ZipEntryFile $a "$modFolder/Assembly-CSharp-firstpass.dll" (Join-Path $config.ManagedDir 'Assembly-CSharp-firstpass.dll') }
    Expect-Rejected 'package-swapped-in-game-assembly-rejected' (& $v $p) 'Package allowlist mismatch'
    $p = Join-Path $inputs 'directory-with-data.zip'; Edit-Zip $candidateZip $p { param($a) $w = [IO.StreamWriter]::new($a.CreateEntry("$modFolder/extra/").Open()); try { $w.Write('inert marker') } finally { $w.Dispose() } }
    Expect-Rejected 'package-data-bearing-directory-record-rejected' (& $v $p) 'data-bearing package directory record'
    $p = Join-Path $inputs 'own-directory-with-data.zip'; Edit-Zip $candidateZip $p { param($a) $w = [IO.StreamWriter]::new($a.CreateEntry("$modFolder/").Open()); try { $w.Write('inert marker') } finally { $w.Dispose() } }
    Expect-Rejected 'package-own-directory-record-with-data-rejected' (& $v $p) 'data-bearing package directory record'
    $p = Join-Path $inputs 'deflate-level0-directory.zip'
    Copy-Item -LiteralPath $candidateZip -Destination $p
    $python = (Get-Command python -ErrorAction Stop).Source
    $zipInfo = & $python -I -c "import sys,zipfile; z=zipfile.ZipFile(sys.argv[1],'a'); i=zipfile.ZipInfo('KingmakerLastAzlantiPreserver/licenses/'); z.writestr(i,b'',compress_type=zipfile.ZIP_DEFLATED,compresslevel=0); z.close(); z=zipfile.ZipFile(sys.argv[1]); print([(x.filename,x.compress_type,x.compress_size) for x in z.infolist() if x.filename.endswith('/')])" $p
    $r = & $v $p
    Add-Case 'package-level0-deflate-empty-directory-accepted' ($r.ExitCode -eq 0 -and $r.Output -match 'Package validation passed') ("directory records $zipInfo; " + $(if ($r.ExitCode -eq 0) { 'accepted' } else { Get-Reason $r.Output }))
    # The validator hashes and inspects one private copy. The harness (a disposable instrumented copy of the validator)
    # replaces the caller's file right after that copy: the report still describes one consistent snapshot.
    $callerZip = Join-Path $inputs 'caller-path.zip'
    Copy-Item -LiteralPath $candidateZip -Destination $callerZip
    $mixReport = Join-Path $inputs 'mix-report.json'
    $replacingValidator = New-InstrumentedScript 'Validate-Package' '[IO.File]::Copy($PackagePath, $inspected)' ('[IO.File]::Copy(' + (Quote $secondZip) + ', $PackagePath, $true)')
    $mix = Invoke-Isolated @('-File', $replacingValidator, '-PackagePath', $callerZip, '-ReportPath', $mixReport)
    Remove-Item -LiteralPath $replacingValidator
    $mr = if (Test-Path -LiteralPath $mixReport) { Get-Content -LiteralPath $mixReport -Raw | ConvertFrom-Json } else { $null }
    $ok = $mix.ExitCode -eq 0 -and $mr -and $mr.package_sha256 -eq (Get-Sha256 $candidateZip) -and $mr.dll_sha256 -eq $firstDllSha -and (Get-Sha256 $callerZip) -eq (Get-Sha256 $secondZip)
    Add-Case 'validator-report-describes-one-zip-when-caller-file-replaced' $ok ("report ZIP $($mr.package_sha256) with DLL $($mr.dll_sha256); caller path now holds $(Get-Sha256 $callerZip)")
    # Ordinary standalone validation and the installation preview (Install.ps1 -WhatIf against a disposable game folder)
    # leave the supplied ZIP unchanged.
    $suppliedZip = Join-Path $inputs 'supplied preview.zip'
    Copy-Item -LiteralPath $candidateZip -Destination $suppliedZip
    $suppliedSha = Get-Sha256 $suppliedZip
    $r = Invoke-Isolated @('-File', $validator, '-PackagePath', $suppliedZip, '-ReportPath', (Join-Path $inputs 'supplied-report.json'))
    Add-Case 'standalone-validation-preserves-supplied-zip' ($r.ExitCode -eq 0 -and (Get-Sha256 $suppliedZip) -eq $suppliedSha) "exit $($r.ExitCode); supplied ZIP still $suppliedSha"
    $disposableGame = Join-Path $temp 'disposable game'
    New-Item -ItemType Directory -Path $disposableGame -Force | Out-Null
    Write-GamePath $gamePath $baselineProfile -InstallDir $disposableGame
    $r = Invoke-Isolated @('-File', (Join-Path $base 'scripts\Install.ps1'), '-PackagePath', $suppliedZip, '-WhatIf')
    $ok = $r.ExitCode -eq 0 -and $r.Output -match 'WhatIf completed' -and (Get-Sha256 $suppliedZip) -eq $suppliedSha -and -not (Test-Path -LiteralPath (Join-Path $disposableGame 'Mods'))
    Add-Case 'install-preview-preserves-supplied-zip' $ok ("exit $($r.ExitCode); " + $(if ($r.ExitCode -eq 0) { 'WhatIf completed' } else { Get-Reason $r.Output }) + "; supplied ZIP still $(Get-Sha256 $suppliedZip); disposable Mods folder created: $(Test-Path -LiteralPath (Join-Path $disposableGame 'Mods'))")
    [IO.File]::WriteAllText($gamePath, $gamePathOriginal)
    $p = Join-Path $inputs 'harmony-as-readme.zip'; Edit-Zip $candidateZip $p { param($a) Set-ZipEntryFile $a "$modFolder/README.md" $pinnedHarmony }
    Expect-Rejected 'package-harmony-bytes-under-readme-name-rejected' (& $v $p) 'binary content: KingmakerLastAzlantiPreserver/README\.md'
    $p = Join-Path $inputs 'loader-as-licence.zip'; Edit-Zip $candidateZip $p { param($a) Set-ZipEntryFile $a "$modFolder/licenses/FIRST-AZLANTI-MIT.txt" $pinnedUmm }
    Expect-Rejected 'package-loader-bytes-under-licence-name-rejected' (& $v $p) 'binary content'
    foreach ($bad in @(@{ Name = 'array'; Value = '["0.31.1"]' }, @{ Name = 'boolean'; Value = 'true' }, @{ Name = 'number'; Value = '0.31' })) {
        $p = Join-Path $inputs "manager-$($bad.Name).zip"
        $replacement = '"ManagerVersion": ' + $bad.Value
        Edit-Zip $candidateZip $p { param($a) $t = Get-ZipEntryText $a "$modFolder/Info.json"; Set-ZipEntryText $a "$modFolder/Info.json" ($t -replace '"ManagerVersion":\s*"0\.31\.1"', $replacement) }
        Expect-Rejected "package-manager-version-$($bad.Name)-rejected" (& $v $p) 'ManagerVersion must be a JSON string'
    }
    $legacyRef = Invoke-Script "([Reflection.Assembly]::ReflectionOnlyLoad([IO.File]::ReadAllBytes($(Quote $legacyDll))).GetReferencedAssemblies() | Where-Object Name -eq 'UnityModManager').Version.ToString()"
    Add-Case 'legacy-release-references-umm-0.33.0' ($legacyRef.ExitCode -eq 0 -and $legacyRef.Output.Trim() -eq '0.33.0.0') ("genuine v0.1.3 ZIP $legacySha256; its DLL references UnityModManager " + $legacyRef.Output.Trim())
    $lowered = Join-Path $inputs 'legacy-lowered-manifest.zip'
    Edit-Zip $legacyZip $lowered { param($a)
        $t = Get-ZipEntryText $a "$modFolder/Info.json"
        $c = $t -replace '"ManagerVersion":\s*"[0-9.]+"', '"ManagerVersion": "0.31.1"'
        if ($c -eq $t) { throw 'Legacy manifest was not lowered.' }
        Set-ZipEntryText $a "$modFolder/Info.json" $c }
    Expect-Rejected 'package-legacy-0.33.0-dll-with-lowered-manifest-rejected' (& $v $lowered) 'must reference pinned UnityModManager 0\.31\.1\.0'
    foreach ($order in @(@($candidateZip, $lowered), @($lowered, $candidateZip))) {
        $text = "foreach (`$zip in @($(Quote $order[0]), $(Quote $order[1]))) { try { & $(Quote $validator) -PackagePath `$zip | Out-Null; 'ACCEPTED ' + [IO.Path]::GetFileName(`$zip) } catch { 'REJECTED ' + [IO.Path]::GetFileName(`$zip) + ': ' + `$_.Exception.Message } }"
        $r = Invoke-Script $text
        $ok = $r.Output -match 'ACCEPTED candidate\.zip' -and $r.Output -match 'REJECTED legacy-lowered-manifest\.zip: Packaged DLL must reference pinned UnityModManager 0\.31\.1\.0'
        Add-Case "same-host-validation-$([IO.Path]::GetFileNameWithoutExtension($order[0]))-first" $ok ($r.Output.Trim() -replace "`r?`n", ' | ')
    }

    # 8. Install route: Install.ps1 extracts only through Expand-ValidatedPackage (private validated copy).
    $r = Invoke-Script ". $(Quote $common); Expand-ValidatedPackage $(Quote $candidateZip) $(Quote (Join-Path $temp 'expand ok'))"
    Add-Case 'expand-validated-package-candidate' ($r.ExitCode -eq 0 -and $r.Output -match $firstDllSha) ('returned validated DLL SHA-256: ' + ($r.Output.Trim() -split "`r?`n" | Select-Object -Last 1))
    $r = Invoke-Script ". $(Quote $common); Expand-ValidatedPackage $(Quote $lowered) $(Quote (Join-Path $temp 'expand legacy'))"
    $ok = $r.ExitCode -ne 0 -and $r.Output -match 'must reference pinned UnityModManager' -and -not (Test-Path -LiteralPath (Join-Path $temp 'expand legacy\KingmakerLastAzlantiPreserver'))
    Add-Case 'expand-validated-package-legacy-rejected' $ok ('rejected before extraction: ' + (Get-Reason $r.Output))
    $install = [IO.File]::ReadAllText((Join-Path $base 'scripts\Install.ps1'))
    $ok = $install.Contains('Expand-ValidatedPackage $PackagePath $temporary') -and -not $install.Contains('ExtractToDirectory') -and
        $install.IndexOf('Expand-ValidatedPackage') -lt $install.IndexOf('CreateDirectory($configuration.ModsDir)')
    Add-Case 'install-uses-validated-private-copy' $ok 'Install.ps1 extracts only via Expand-ValidatedPackage, before any live Mods path (Install.ps1 itself is not executed)'

    # 10. Qualification credits package and contract records only for the current DLL (Preserver Qualify.ps1).
    $qualify = Join-Path $base 'scripts\Qualify.ps1'
    $summaryPath = Join-Path $base 'artifacts\qualification\qualification-summary.json'
    $q = Invoke-Isolated @('-File', $qualify, '-Package')
    if (-not (Test-Path -LiteralPath $summaryPath)) { throw "Qualify -Package wrote no summary (exit $($q.ExitCode)): $($q.Output)" }
    $qs = Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json
    Add-Case 'qualify-credits-current-package' ($q.ExitCode -eq 0 -and $qs.package_validation -eq 'passed' -and $qs.package_sha256 -eq (Get-Sha256 (Join-Path $base "artifacts\packages\KingmakerLastAzlantiPreserver-0.1.3.zip"))) ("package_validation $($qs.package_validation); package $($qs.package_sha256)")
    Invoke-Isolated @('-File', $validator, '-PackagePath', $secondZip) | Out-Null
    $q = Invoke-Isolated @('-File', $qualify)
    $qs = Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json
    Add-Case 'qualify-ignores-validation-of-another-zip' ($q.ExitCode -eq 0 -and $qs.package_validation -eq 'not run for the current DLL' -and -not $qs.package_sha256) ("after validating the changed-source ZIP: package_validation '$($qs.package_validation)'")
    Copy-Item -LiteralPath $secondZip -Destination (Join-Path $base "artifacts\packages\KingmakerLastAzlantiPreserver-0.1.3.zip") -Force
    Invoke-Isolated @('-File', $qualify, '-Package') | Out-Null
    Copy-Item -LiteralPath $secondZip -Destination (Join-Path $base "artifacts\packages\KingmakerLastAzlantiPreserver-0.1.3.zip") -Force
    $q = Invoke-Isolated @('-File', $qualify)
    $qs = Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json
    Add-Case 'qualify-ignores-replaced-zip-on-disk' ($q.ExitCode -eq 0 -and $qs.package_validation -eq 'not run for the current DLL') ("ZIP replaced after packaging: package_validation '$($qs.package_validation)'")

    # 11. Contract checks run on the selected configuration's DLL (Debug here) while a Release build also exists.
    $releaseSha = Get-Sha256 $dll
    $debugDll = Join-Path $base 'artifacts\bin\Debug\KingmakerLastAzlantiPreserver\KingmakerLastAzlantiPreserver.dll'
    $d = Invoke-Isolated @('-File', $qualify, '-Build', '-VerifyContracts', '-Configuration', 'Debug')
    $qs = Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json
    $debugSha = if (Test-Path -LiteralPath $debugDll) { Get-Sha256 $debugDll } else { 'missing' }
    $ok = $d.ExitCode -eq 0 -and $debugSha -ne $releaseSha -and $qs.contracts_verified_dll_sha256 -eq $debugSha -and $qs.dll_sha256 -eq $debugSha -and (Test-Path -LiteralPath $dll)
    Add-Case 'contracts-verify-selected-debug-dll' $ok ("Debug DLL $debugSha; contracts verified on $($qs.contracts_verified_dll_sha256); Release DLL $releaseSha still present; loader profile $($qs.loader_profile); Harmony2 $($qs.harmony2_identity)")

    # 12. Qualification freshness: partial runs never credit an old package, older-format or other-profile contract records
    #     are reported as not current, one host cannot verify a second same-identity DLL as the first, and profile
    #     comparisons use one frozen DLL.
    [IO.File]::AppendAllText((Join-Path $base $marker), "`r`n// loader-baseline test edit`r`n")
    Invoke-Isolated @('-File', $qualify, '-Test', '-Configuration', 'Release') | Out-Null
    $qs = Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json
    Add-Case 'qualify-test-after-source-change-credits-nothing-old' (-not $qs.build_record_current -and -not $qs.package_current_for_candidate -and $qs.package_validation -eq 'not run for the current DLL') ("build_record_current $($qs.build_record_current) ($($qs.build_record_problem)); package '$($qs.package_validation)'")
    & git -C $base checkout -q -- ($marker.Replace('\', '/'))
    Invoke-Isolated @('-File', $qualify, '-Build', '-Package') | Out-Null
    $qs = Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json
    Add-Case 'qualify-fresh-package-control-credited' ($qs.build_record_current -and $qs.package_current_for_candidate -and $qs.package_validation -eq 'passed') ("package $($qs.package_sha256) '$($qs.package_validation)'")
    [IO.File]::AppendAllText((Join-Path $base 'README.md'), "`n<!-- loader-baseline test edit -->`n")
    Invoke-Isolated @('-File', $qualify) | Out-Null
    $qs = Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json
    Add-Case 'qualify-after-packaged-readme-change-not-credited' (-not $qs.package_current_for_candidate -and $qs.package_validation -eq 'not run for the current DLL') ("package '$($qs.package_validation)'")
    & git -C $base checkout -q -- README.md
    Invoke-Isolated @('-File', $qualify) | Out-Null
    $qs = Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json
    Add-Case 'qualify-package-control-credited-after-readme-restore' ($qs.package_current_for_candidate -and $qs.package_validation -eq 'passed') ("package '$($qs.package_validation)'")
    # A changed build input that reproduces the same DLL withdraws package credit (the package names its producing inputs).
    [IO.File]::AppendAllText((Join-Path $base '.editorconfig'), "`r`n# loader-baseline test edit`r`n")
    $same = Invoke-Isolated @('-File', (Join-Path $base 'scripts\Build-Local.ps1'))
    Invoke-Isolated @('-File', $qualify) | Out-Null
    $qs = Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json
    Add-Case 'qualify-package-not-credited-after-build-input-change-reproducing-dll' ($same.ExitCode -eq 0 -and (Get-Sha256 $dll) -eq $firstDllSha -and $qs.build_record_current -and -not $qs.package_current_for_candidate) ("rebuilt DLL $(Get-Sha256 $dll) (same as packaged); build record current $($qs.build_record_current); package current $($qs.package_current_for_candidate)")
    & git -C $base checkout -q -- .editorconfig
    Invoke-Isolated @('-File', (Join-Path $base 'scripts\Build-Local.ps1')) | Out-Null
    Invoke-Isolated @('-File', $qualify) | Out-Null
    $qs = Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json
    Add-Case 'qualify-package-credited-again-after-build-inputs-restored' ($qs.package_current_for_candidate) ("package current $($qs.package_current_for_candidate)")
    # A changed packaging rule withdraws credit from a package produced and validated under the old rule.
    [IO.File]::AppendAllText((Join-Path $base 'scripts\Validate-Package.ps1'), "`r`n# loader-baseline test edit`r`n")
    Invoke-Isolated @('-File', $qualify) | Out-Null
    $qs = Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json
    Add-Case 'qualify-package-not-credited-after-packaging-rule-change' (-not $qs.package_current_for_candidate) ("package current $($qs.package_current_for_candidate)")
    & git -C $base checkout -q -- scripts/Validate-Package.ps1
    # A packaged document changed during staging (by a disposable instrumented Package.ps1) is refused before archiving.
    $stagingEdit = New-InstrumentedScript 'Package' '$packageRules = Get-PackageRuleFingerprint' ('[IO.File]::AppendAllText((Join-Path $root ''README.md''), "`r`n<!-- edited during staging -->`r`n")')
    Expect-Rejected 'package-document-changed-during-staging-rejected' (Invoke-Isolated @('-File', $stagingEdit)) 'changed during staging'
    Remove-Item -LiteralPath $stagingEdit
    & git -C $base checkout -q -- README.md
    Invoke-Isolated @('-File', $qualify, '-Package') | Out-Null
    $qs = Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json
    Add-Case 'qualify-package-control-credited-after-staging-refusal' ($qs.package_current_for_candidate -and $qs.package_validation -eq 'passed') ("package $($qs.package_sha256) '$($qs.package_validation)'")

    # Qualification success follows the requested stages' current results.
    $testProject = Join-Path $base 'tests\KingmakerLastAzlantiPreserver.Tests\KingmakerLastAzlantiPreserver.Tests.csproj'
    $testProjectText = [IO.File]::ReadAllText($testProject)
    $probe = '<Target Name="LoaderBaselineProbeReplace" AfterTargets="Build"><Copy SourceFiles="' + [Security.SecurityElement]::Escape($checkedArithmeticDll) + '" DestinationFiles="$(OutDir)KingmakerLastAzlantiPreserver.dll" /></Target></Project>'
    [IO.File]::WriteAllText($testProject, $testProjectText.Substring(0, $testProjectText.LastIndexOf('</Project>')) + $probe)
    $q = Invoke-Isolated @('-File', $qualify, '-Build', '-Test')
    $qs = Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json
    $ok = $q.ExitCode -ne 0 -and ($q.Output -replace '\s+', ' ') -match 'tests did not run against the current DLL' -and [string]$qs.status -match '^failed'
    Add-Case 'qualify-fails-when-tests-ran-against-a-different-dll' $ok ("test project's copy replaced by a valid checked-arithmetic Release DLL: exit $($q.ExitCode); status '$($qs.status)'; " + (Get-Reason $q.Output))
    & git -C $base checkout -q -- 'tests/KingmakerLastAzlantiPreserver.Tests/KingmakerLastAzlantiPreserver.Tests.csproj'
    $q = Invoke-Isolated @('-File', $qualify, '-Build', '-Test')
    $qs = Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json
    Add-Case 'qualify-build-and-test-control-passes' ($q.ExitCode -eq 0 -and $qs.test_result -eq 'passed') ("exit $($q.ExitCode); tests $($qs.test_count) ($($qs.test_result)); status '$($qs.status)'")
    [IO.File]::AppendAllText((Join-Path $base $marker), "`r`nnamespace KingmakerLastAzlantiPreserver { internal static class LoaderBaselineQualifyMarker { } }`r`n")
    $q = Invoke-Isolated @('-File', $qualify, '-Build')
    $qs = Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json
    Add-Case 'qualify-build-only-after-source-change-inherits-no-test-pass' ($q.ExitCode -eq 0 -and $qs.test_result -eq 'not run for the current DLL' -and $qs.test_count -eq 0) ("exit $($q.ExitCode); tests $($qs.test_count) ('$($qs.test_result)')")
    & git -C $base checkout -q -- ($marker.Replace('\', '/'))
    Invoke-Isolated @('-File', (Join-Path $base 'scripts\Build-Local.ps1')) | Out-Null

    # Contract records count only as one fresh, binding-aware verification under the configured loader.
    $verifyContracts = Join-Path $base 'scripts\Verify-KingmakerContracts.ps1'
    $uiPath = Join-Path $base 'artifacts\qualification\game-over-load-contracts.json'
    $kcPath = Join-Path $base 'artifacts\qualification\contracts.json'
    function Get-Summary { return (Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json) }
    # Records in the fd9f30f shape (DLL and loader identities, but no verification run, loaded-module or loader-hash
    # fields) give a usable summary without credit.
    Invoke-Isolated @('-File', $qualify, '-VerifyContracts') | Out-Null
    Edit-Json $kcPath { param($j) foreach ($n in @('mod_dll_loaded_mvid', 'verification_run_id', 'unity_mod_manager_sha256', 'legacy_harmony_sha256', 'harmony2_sha256')) { $j.PSObject.Properties.Remove($n) } }
    Edit-Json $uiPath { param($j) $j.PSObject.Properties.Remove('verification_run_id'); $j.mod_dll.PSObject.Properties.Remove('loaded_mvid'); $j.harmony2.PSObject.Properties.Remove('loaded_location'); $j.harmony2.PSObject.Properties.Remove('loaded_mvid') }
    $q = Invoke-Isolated @('-File', $qualify)
    $qs = Get-Summary
    Add-Case 'qualify-fd9f30f-shape-contract-records-usable-not-credited' ($q.ExitCode -eq 0 -and -not $qs.contracts_current_for_candidate) ("exit $($q.ExitCode); contracts current $($qs.contracts_current_for_candidate)")
    # A mixed pair left by a second, interrupted verification (only its game-over record written) is not current, whether
    # that run used the same profile or the distinct 0.33.4 profile.
    Invoke-Isolated @('-File', $qualify, '-VerifyContracts') | Out-Null
    $firstRunKc = Get-Content -LiteralPath $kcPath -Raw
    Invoke-Isolated @('-File', $verifyContracts, '-DllPath', $dll, '-OutputPath', (Join-Path $inputs 'second-run-contracts.json'), '-GameOverOutputPath', $uiPath) | Out-Null
    $q = Invoke-Isolated @('-File', $qualify)
    $qs = Get-Summary
    Add-Case 'qualify-mixed-pair-same-profile-not-credited' ($q.ExitCode -eq 0 -and -not $qs.contracts_current_for_candidate -and (Get-Content -LiteralPath $kcPath -Raw) -ceq $firstRunKc) ("contracts.json from run A, game-over record from run B; contracts current $($qs.contracts_current_for_candidate)")
    Invoke-Isolated @('-File', $verifyContracts, '-GamePathProps', $newestProps, '-DllPath', $dll, '-OutputPath', (Join-Path $inputs 'third-run-contracts.json'), '-GameOverOutputPath', $uiPath) | Out-Null
    $q = Invoke-Isolated @('-File', $qualify)
    $qs = Get-Summary
    Add-Case 'qualify-mixed-pair-other-profile-not-credited' ($q.ExitCode -eq 0 -and -not $qs.contracts_current_for_candidate) ("game-over record from a 0.33.4 run; contracts current $($qs.contracts_current_for_candidate)")
    Invoke-Isolated @('-File', $qualify, '-VerifyContracts') | Out-Null
    $qs = Get-Summary
    Add-Case 'qualify-fresh-contract-pair-credited' ($qs.contracts_current_for_candidate -and $qs.loader_profile -eq '0.31.1.0' -and $qs.harmony2_sha256 -eq '5f7ad0df1eb08e81f66d4006d3a9e5cb40fc05e381f36d7bd0513f334f6a251f') ("loader profile $($qs.loader_profile); Harmony2 $($qs.harmony2_identity)")
    # Switching the configured loader to the known-distinct 0.33.4 profile withdraws that credit; a byte-identical copy of
    # the verified 0.31.1 profile at another path keeps it.
    Write-GamePath $gamePath $newestProfile
    Invoke-Isolated @('-File', $qualify) | Out-Null
    $qs = Get-Summary
    Add-Case 'qualify-records-not-credited-after-switch-to-distinct-profile' (-not $qs.contracts_current_for_candidate) ("records verified under 0.31.1; configured profile now 0.33.4; contracts current $($qs.contracts_current_for_candidate)")
    Write-GamePath $gamePath $baselineCopy
    Invoke-Isolated @('-File', $qualify) | Out-Null
    $qs = Get-Summary
    Add-Case 'qualify-records-credited-under-byte-identical-profile-copy' ($qs.contracts_current_for_candidate) ("configured profile now a byte-identical copy of 0.31.1 elsewhere; contracts current $($qs.contracts_current_for_candidate)")
    [IO.File]::WriteAllText($gamePath, $gamePathOriginal)
    # The distinct wrong-loader fixture is still refused with the baseline loader configured; a copy of the configured
    # loader (identical to the pin, by measurement) is accepted as expected.
    Expect-Rejected 'cache-umm-0.32.4-fixture-rejected-under-baseline-configuration' (Invoke-Isolated @('-File', $verifier, '-VerifyOnly', '-ReferenceDirectory', $wrongCache)) 'hash mismatch'
    $configuredCopy = Join-Path $temp 'cache configured loader'
    Copy-Pins $references $configuredCopy
    Copy-Item -LiteralPath (Join-Path $baselineProfile 'UnityModManager.dll') -Destination $configuredCopy -Force
    Expect-Accepted 'cache-copy-of-configured-baseline-loader-accepted' (Invoke-Isolated @('-File', $verifier, '-VerifyOnly', '-ReferenceDirectory', $configuredCopy)) ''

    # One PowerShell host, two DLLs with the product identity: the second is refused as a binding mismatch.
    $oneHost = "& $(Quote $verifyContracts) -DllPath $(Quote $dll) -OutputPath $(Quote (Join-Path $inputs 'host-a.json')) -GameOverOutputPath $(Quote (Join-Path $inputs 'host-a-go.json')); 'FIRST VERIFIED'; " +
        "& $(Quote $verifyContracts) -DllPath $(Quote $debugDll) -OutputPath $(Quote (Join-Path $inputs 'host-b.json')) -GameOverOutputPath $(Quote (Join-Path $inputs 'host-b-go.json')); 'SECOND VERIFIED'"
    $h = Invoke-Script $oneHost
    $ok = $h.Output -match 'FIRST VERIFIED' -and $h.Output -notmatch 'SECOND VERIFIED' -and ($h.Output -replace '\s+', ' ') -match 'Loaded assembly binding mismatch'
    Add-Case 'one-host-second-same-identity-dll-refused' $ok ('second run: ' + (Get-Reason $h.Output))
    # One PowerShell host, the same DLL under 0.31.1 then 0.33.4: the first result records the Harmony2 module actually
    # bound; the second is refused because this process is still bound to the first profile's Harmony modules.
    $hostA = Join-Path $inputs 'profiles-host-a-go.json'; $hostB = Join-Path $inputs 'profiles-host-b-go.json'
    $twoProfiles = "& $(Quote $verifyContracts) -GamePathProps $(Quote $baselineProps) -DllPath $(Quote $dll) -OutputPath $(Quote (Join-Path $inputs 'profiles-host-a.json')) -GameOverOutputPath $(Quote $hostA); 'FIRST VERIFIED'; " +
        "& $(Quote $verifyContracts) -GamePathProps $(Quote $newestProps) -DllPath $(Quote $dll) -OutputPath $(Quote (Join-Path $inputs 'profiles-host-b.json')) -GameOverOutputPath $(Quote $hostB); 'SECOND VERIFIED'"
    $h = Invoke-Script $twoProfiles
    $ha = if (Test-Path -LiteralPath $hostA) { Get-Content -LiteralPath $hostA -Raw | ConvertFrom-Json } else { $null }
    $ok = $h.Output -match 'FIRST VERIFIED' -and $h.Output -notmatch 'SECOND VERIFIED' -and ($h.Output -replace '\s+', ' ') -match 'binding mismatch' -and
        $ha -and $ha.harmony2.sha256 -eq '5f7ad0df1eb08e81f66d4006d3a9e5cb40fc05e381f36d7bd0513f334f6a251f' -and $ha.harmony2.loaded_mvid -and -not (Test-Path -LiteralPath $hostB)
    Add-Case 'one-host-successive-loader-profiles-second-refused' $ok ("first: Harmony2 $($ha.harmony2.identity) loaded MVID $($ha.harmony2.loaded_mvid); second: " + (Get-Reason $h.Output))

    # Separate processes per profile verify one frozen DLL against the two distinct profiles, even when the build output
    # changes between profiles (replacement done by a disposable instrumented copy of Test-LoaderProfiles.ps1).
    $frozenReport = Join-Path $inputs 'profiles-frozen.json'
    $profilesReplacing = New-InstrumentedScript 'Test-LoaderProfiles' '        foreach ($identity in $identities) { Write-Host "    $identity" }' ('        if (-not (Get-Variable -Name replacedOnce -Scope Script -ErrorAction SilentlyContinue)) { Copy-Item -LiteralPath ' + (Quote $legacyDll) + ' -Destination $dll -Force; $script:replacedOnce = $true }')
    $fr = Invoke-Isolated @('-File', $profilesReplacing, '-ProfileRoot', $profileRoot, '-ReportPath', $frozenReport)
    Remove-Item -LiteralPath $profilesReplacing
    $frj = if (Test-Path -LiteralPath $frozenReport) { Get-Content -LiteralPath $frozenReport -Raw | ConvertFrom-Json } else { $null }
    $rows = if ($frj) { @($frj.profiles) } else { @() }
    $ok = $fr.ExitCode -eq 0 -and $rows.Count -eq 2 -and @($rows | Where-Object { $_.passed -and $_.detail -match [regex]::Escape($firstDllSha) }).Count -eq 2 -and (Get-Sha256 $dll) -ne $firstDllSha -and
        @($rows | Where-Object { $_.profile -eq '0.31.1' -and $_.detail -match 'Version=2\.3\.1\.1' }).Count -eq 1 -and @($rows | Where-Object { $_.profile -eq '0.33.4' -and $_.detail -match 'Version=2\.4\.3' }).Count -eq 1
    $profileDetail = (@($rows | ForEach-Object { $_.profile + ': ' + $_.detail }) -join ' | ') + "; build output replaced after the first profile (now $(Get-Sha256 $dll))"
    if (-not $ok) { $profileDetail += "; exit $($fr.ExitCode): " + (Get-Reason $fr.Output) }
    Add-Case 'profile-comparison-distinct-profiles-frozen-dll' $ok $profileDetail
    Copy-Item -LiteralPath (Join-Path $inputs 'first-build-dll.dll') -Destination $dll -Force

    # 9. Inputs and this repository's outputs are preserved.
    $legacyOk = (Get-Sha256 $legacyZip) -eq $legacySha256 -and (-not $LegacyReleaseZip -or (Get-Sha256 $LegacyReleaseZip) -eq $legacyOriginalSha)
    Add-Case 'legacy-input-preserved' $legacyOk "private copy and any supplied original still $legacySha256"
    $sourcePackagesAfter = @(Get-ChildItem -LiteralPath (Join-Path $source 'artifacts\packages') -File -ErrorAction SilentlyContinue | ForEach-Object { $_.Name + '=' + (Get-Sha256 $_.FullName) })
    Add-Case 'repository-package-outputs-untouched' (($sourcePackagesBefore -join ';') -eq ($sourcePackagesAfter -join ';')) ('artifacts\packages before = after: ' + ($sourcePackagesBefore -join ', '))

    $failed = @($cases | Where-Object { -not $_.passed })
    $reportFile = Join-Path $inputs 'candidate-validation.json'
    Invoke-Isolated @('-File', $validator, '-PackagePath', $candidateZip, '-ReportPath', $reportFile) | Out-Null
    $candidateReport = Get-Content -LiteralPath $reportFile -Raw | ConvertFrom-Json
    $summary = [ordered]@{
        schema = 'klap.loader-baseline-tests.v3'
        source_commit = $commit
        clone_build_receipt = [ordered]@{ commit = $receipt.source_commit; dirty = $receipt.source_dirty; configuration = $receipt.configuration; dll_sha256 = $receipt.dll_sha256; build_inputs_sha256 = $receipt.build_inputs_sha256; loader_references = $receipt.loader_references }
        candidate_package_sha256 = Get-Sha256 $candidateZip
        candidate_validation = [ordered]@{ dll_sha256 = $candidateReport.dll_sha256; dll_mvid = $candidateReport.dll_mvid; manager_version = $candidateReport.manager_version; dll_loader_references = $candidateReport.dll_loader_references }
        legacy_release_zip_sha256 = $legacySha256
        wrong_loader_fixture = "UnityModManager 0.32.4.0 $wrongLoaderDllSha256 (NuGet package $wrongLoaderPackageSha256)"
        owner_install_measured = $ownerMeasurement
        passed = $cases.Count - $failed.Count
        total = $cases.Count
        cases = @($cases)
    }
    if ($ReportPath) { $summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $ReportPath -Encoding UTF8 }
    $summary.Remove('cases')
    Write-Host ($summary | ConvertTo-Json -Depth 6)
    Write-Host ("RESULT {0}/{1} loader-baseline checks passed" -f ($cases.Count - $failed.Count), $cases.Count)
    if ($failed.Count -gt 0) { throw "$($failed.Count) loader-baseline check(s) failed." }
}
finally {
    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}
