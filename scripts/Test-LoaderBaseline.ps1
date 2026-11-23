[CmdletBinding()]
param(
    # Optional local copies of the two downloaded fixtures; otherwise they are downloaded. Both are hash-checked and
    # only ever read: the suite works on private copies.
    [string] $LegacyReleaseZip,
    [string] $WrongLoaderPackage,
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

    # Temporary clone of the committed HEAD under a path with a space; seed its ignored cache and local game paths.
    & git clone -q --no-hardlinks $source $base
    if ($LASTEXITCODE -ne 0) { throw 'git clone failed.' }
    & git -C $base checkout -q --detach $commit
    Copy-Item -LiteralPath (Join-Path $source 'GamePath.props') -Destination $base
    $references = Join-Path $base 'artifacts\references'
    Copy-Pins (Get-PinnedReferenceDirectory) $references
    $project = Join-Path $base 'src\KingmakerLastAzlantiPreserver\KingmakerLastAzlantiPreserver.csproj'
    $dll = Join-Path $base "artifacts\bin\$Configuration\KingmakerLastAzlantiPreserver\KingmakerLastAzlantiPreserver.dll"
    $receiptPath = Join-Path $base 'artifacts\qualification\build.json'
    $build = Invoke-Isolated @('-File', (Join-Path $base 'scripts\Build-Local.ps1'))
    if ($build.ExitCode -ne 0) { throw "Clone build failed: $($build.Output)" }
    $firstDllSha = Get-Sha256 $dll
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
    Expect-Accepted 'resolved-input-pinned-accepted' (Invoke-MSBuildIsolated @((New-ProbeProject 'pinned' $pinnedUmm), '/t:ResolveAssemblyReferences')) ''
    Expect-Rejected 'resolved-input-identical-copy-elsewhere-rejected' (Invoke-MSBuildIsolated @((New-ProbeProject 'stray' (Join-Path $stray 'UnityModManager.dll')), '/t:ResolveAssemblyReferences')) 'must be the verified files'
    Expect-Rejected 'resolved-input-same-stem-file-in-pinned-dir-rejected' (Invoke-MSBuildIsolated @((New-ProbeProject 'samestem' (Join-Path $references 'UnityModManager.exe')), '/t:ResolveAssemblyReferences')) 'must be the verified files'
    Expect-Rejected 'resolved-input-renamed-loader-in-pinned-dir-rejected' (Invoke-MSBuildIsolated @((New-ProbeProject 'alias' (Join-Path $references 'umm-alias.dll')), '/t:ResolveAssemblyReferences')) 'must be the verified files'
    Expect-Rejected 'resolved-input-umm-0.32.4-fixture-rejected' (Invoke-MSBuildIsolated @((New-ProbeProject 'wrong' $wrongUmm), '/t:ResolveAssemblyReferences')) 'must be the verified files'
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
        schema = 'klap.loader-baseline-tests.v2'
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
