[CmdletBinding()]
param(
    [ValidateSet('Debug','Release')][string] $Configuration = 'Release',
    # Optional local copy of the genuine v0.1.3 release ZIP; otherwise it is downloaded and hash-checked.
    [string] $LegacyReleaseZip,
    [string] $ReportPath
)
# Failure-boundary tests for the pinned UMM 0.31.1 compile baseline. They use real files, archives,
# MSBuild and this repository's own scripts, each check in its own PowerShell process (as Install.ps1
# runs the validator), and write only to a temporary directory and the normal artifacts\packages output.
# Prerequisite: scripts\Build-Local.ps1 for the same configuration (pinned cache, DLL, build receipt).
. (Join-Path $PSScriptRoot 'Common.ps1')
$root = Get-RepositoryRoot
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

# Genuine published release, compiled against UnityModManager 0.33.0.0 (its manifest says 0.33.0).
$legacyUrl = 'https://github.com/howardreith/KingmakerLastAzlantiPreserver/releases/download/v0.1.3/KingmakerLastAzlantiPreserver-0.1.3.zip'
$legacySha256 = '8b59d76d4583ed0108f1eb740c1669dbac4ea05dacb1003f728b612887d2fbed'
$modFolder = 'KingmakerLastAzlantiPreserver'
$project = Join-Path $root 'src\KingmakerLastAzlantiPreserver\KingmakerLastAzlantiPreserver.csproj'
$references = Get-PinnedReferenceDirectory
$dll = Join-Path $root "artifacts\bin\$Configuration\KingmakerLastAzlantiPreserver\KingmakerLastAzlantiPreserver.dll"
$receiptPath = Join-Path $root 'artifacts\qualification\build.json'
foreach ($required in @($dll, $receiptPath, (Join-Path $references 'UnityModManager.dll'), (Join-Path $references '0Harmony12.dll'))) {
    Assert-FileExists $required 'Build output (run scripts\Build-Local.ps1 first)'
}
# The repository builds with `dotnet msbuild` (scripts\Build-Local.ps1, Invoke-MSBuild); use the same engine.
$dotnet = (Get-Command dotnet -ErrorAction Stop).Source
$config = Get-KingmakerConfiguration
$temp = Join-Path ([IO.Path]::GetTempPath()) ('klap-loader-baseline-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temp | Out-Null
$cases = [Collections.Generic.List[object]]::new()

function Invoke-Isolated([string[]] $Arguments) {
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { $output = & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass @Arguments 2>&1 | Out-String }
    finally { $ErrorActionPreference = $previous }
    return [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = $output }
}
function Invoke-MSBuildIsolated([string[]] $Arguments) {
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { $output = & $dotnet msbuild /nologo /v:m @Arguments 2>&1 | Out-String }
    finally { $ErrorActionPreference = $previous }
    return [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = $output }
}
function Add-Case([string] $Name, [bool] $Passed, [string] $Detail) {
    $cases.Add([ordered]@{ name = $Name; passed = $Passed; detail = $Detail })
    if ($Passed) { Write-Host "PASS $Name" } else { Write-Host "FAIL $Name :: $Detail" }
}
function Expect-Rejected([string] $Name, $Result, [string] $Pattern) {
    $ok = $Result.ExitCode -ne 0 -and $Result.Output -match $Pattern
    Add-Case $Name $ok ("exit {0}; expected /{1}/; output: {2}" -f $Result.ExitCode, $Pattern, $Result.Output.Trim())
}
function Expect-Accepted([string] $Name, $Result, [string] $Pattern) {
    $ok = $Result.ExitCode -eq 0 -and (-not $Pattern -or $Result.Output -match $Pattern)
    Add-Case $Name $ok ("exit {0}; output: {1}" -f $Result.ExitCode, $Result.Output.Trim())
}
function Copy-Directory([string] $Source, [string] $Destination) {
    New-Item -ItemType Directory -Force -Path $Destination | Out-Null
    Get-ChildItem -LiteralPath $Source -File -Filter *.dll | ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $Destination }
}
function Edit-Zip([string] $Source, [string] $Destination, [scriptblock] $Edit) {
    Copy-Item -LiteralPath $Source -Destination $Destination
    $archive = [IO.Compression.ZipFile]::Open($Destination, [IO.Compression.ZipArchiveMode]::Update)
    try { & $Edit $archive } finally { $archive.Dispose() }
}
function Set-ZipEntryText($Archive, [string] $Name, [string] $Text) {
    $entry = $Archive.GetEntry($Name)
    if ($null -eq $entry) { throw "Archive entry not found: $Name" }
    $entry.Delete()
    $writer = [IO.StreamWriter]::new($Archive.CreateEntry($Name).Open(), [Text.UTF8Encoding]::new($false))
    try { $writer.Write($Text) } finally { $writer.Dispose() }
}
function Get-ZipEntryText($Archive, [string] $Name) {
    $reader = [IO.StreamReader]::new($Archive.GetEntry($Name).Open(), [Text.Encoding]::UTF8, $true)
    try { return $reader.ReadToEnd() } finally { $reader.Dispose() }
}
function Add-ZipFile($Archive, [string] $Name, [string] $Path) {
    [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($Archive, $Path, $Name) | Out-Null
}
function Quote([string] $Value) { return "'" + $Value.Replace("'", "''") + "'" }

try {
    $verifier = Join-Path $root 'scripts\Get-PinnedLoaderReferences.ps1'

    # 1. Reference cache: genuine bytes pass; corrupt, missing and installed-newer bytes fail clearly.
    Expect-Accepted 'cache-genuine-verified' (Invoke-Isolated @('-File', $verifier, '-VerifyOnly', '-ReferenceDirectory', $references)) ''
    $corrupt = Join-Path $temp 'cache-corrupt'
    Copy-Directory $references $corrupt
    $bytes = [IO.File]::ReadAllBytes((Join-Path $corrupt 'UnityModManager.dll'))
    $bytes[$bytes.Length - 1] = $bytes[$bytes.Length - 1] -bxor 0xFF
    [IO.File]::WriteAllBytes((Join-Path $corrupt 'UnityModManager.dll'), $bytes)
    Expect-Rejected 'cache-corrupt-rejected' (Invoke-Isolated @('-File', $verifier, '-VerifyOnly', '-ReferenceDirectory', $corrupt)) 'hash mismatch'
    $missing = Join-Path $temp 'cache-missing'
    New-Item -ItemType Directory -Path $missing | Out-Null
    Copy-Item -LiteralPath (Join-Path $references '0Harmony12.dll') -Destination $missing
    Expect-Rejected 'cache-missing-rejected' (Invoke-Isolated @('-File', $verifier, '-VerifyOnly', '-ReferenceDirectory', $missing)) 'reference missing'
    $installed = Join-Path $temp 'cache-installed-loader'
    Copy-Directory $references $installed
    Copy-Item -LiteralPath (Join-Path $config.UnityModManagerDir 'UnityModManager.dll') -Destination $installed -Force
    $installedVersion = [Reflection.AssemblyName]::GetAssemblyName((Join-Path $installed 'UnityModManager.dll')).Version.ToString()
    Expect-Rejected "cache-installed-loader-$installedVersion-rejected" (Invoke-Isolated @('-File', $verifier, '-VerifyOnly', '-ReferenceDirectory', $installed)) 'hash mismatch'

    # 2. Direct MSBuild (IDE path) of the production project: a corrupt cache stops before compilation;
    #    the genuine cache compiles and csc receives exactly the pinned loader files.
    $obj = Join-Path $temp 'msbuild-obj\'
    $out = Join-Path $temp 'msbuild-bin\'
    Expect-Rejected 'msbuild-corrupt-cache-rejected' (Invoke-MSBuildIsolated @($project, '/t:Build', "/p:Configuration=$Configuration",
        "/p:PinnedLoaderReferenceDir=$corrupt", "/p:IntermediateOutputPath=$obj", "/p:OutputPath=$out")) 'hash mismatch'
    $direct = Invoke-MSBuildIsolated @($project, '/t:Rebuild', '/v:n', "/p:Configuration=$Configuration",
        "/p:IntermediateOutputPath=$obj", "/p:OutputPath=$out")
    $cscLine = @($direct.Output -split "`r?`n" | Where-Object { $_ -match 'csc\.(exe|dll)[" ]' }) -join "`n"
    $ummInputs = @([regex]::Matches($cscLine, '/reference:"?([^" ]*UnityModManager\.dll)') | ForEach-Object { $_.Groups[1].Value })
    $harmonyInputs = @([regex]::Matches($cscLine, '/reference:"?([^" ]*0Harmony[^" ]*\.dll)') | ForEach-Object { $_.Groups[1].Value })
    $pinnedUmm = [IO.Path]::GetFullPath((Join-Path $references 'UnityModManager.dll'))
    $pinnedHarmony = [IO.Path]::GetFullPath((Join-Path $references '0Harmony12.dll'))
    $ok = $direct.ExitCode -eq 0 -and $ummInputs.Count -eq 1 -and $ummInputs[0] -ieq $pinnedUmm -and
        $harmonyInputs.Count -eq 1 -and $harmonyInputs[0] -ieq $pinnedHarmony
    Add-Case 'msbuild-direct-compiles-against-pinned-inputs' $ok ("exit {0}; UnityModManager inputs: {1}; Harmony inputs: {2}" -f $direct.ExitCode, ($ummInputs -join ', '), ($harmonyInputs -join ', '))

    # 3. Resolved-input guard: a reference that resolves outside the pinned directory is refused even
    #    when its bytes are identical to the pin, and when it is the installed newer loader.
    $stray = Join-Path $temp 'stray-copy'
    Copy-Directory $references $stray
    $targets = Join-Path $root 'LoaderReferences.targets'
    function New-ProbeProject([string] $Name, [string] $UmmPath) {
        $path = Join-Path $temp "$Name.csproj"
        $text = @"
<Project ToolsVersion="15.0" DefaultTargets="Build" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
  <Import Project="`$(MSBuildExtensionsPath)\`$(MSBuildToolsVersion)\Microsoft.Common.props" Condition="Exists('`$(MSBuildExtensionsPath)\`$(MSBuildToolsVersion)\Microsoft.Common.props')" />
  <PropertyGroup>
    <TargetFrameworkVersion>v4.7.2</TargetFrameworkVersion>
    <OutputType>Library</OutputType>
    <OutputPath>$temp\probe-bin\$Name\</OutputPath>
    <IntermediateOutputPath>$temp\probe-obj\$Name\</IntermediateOutputPath>
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
    Expect-Rejected 'resolved-input-identical-copy-elsewhere-rejected' (Invoke-MSBuildIsolated @((New-ProbeProject 'stray' (Join-Path $stray 'UnityModManager.dll')), '/t:ResolveAssemblyReferences')) 'must resolve inside the pinned directory'
    Expect-Rejected 'resolved-input-installed-loader-rejected' (Invoke-MSBuildIsolated @((New-ProbeProject 'installed' (Join-Path $config.UnityModManagerDir 'UnityModManager.dll')), '/t:ResolveAssemblyReferences')) 'must resolve inside the pinned directory'

    # 4. Manifest / compiler-reference agreement, on a copy of the real scripts and manifest.
    function New-ManifestFixture([string] $Name, [scriptblock] $Edit) {
        $fixture = Join-Path $temp $Name
        New-Item -ItemType Directory -Force -Path (Join-Path $fixture 'scripts') | Out-Null
        Copy-Item -LiteralPath $verifier -Destination (Join-Path $fixture 'scripts')
        Copy-Item -LiteralPath (Join-Path $root 'scripts\loader-reference-pins.json') -Destination (Join-Path $fixture 'scripts')
        Copy-Item -LiteralPath (Join-Path $root 'Info.json') -Destination $fixture
        & $Edit $fixture
        return (Join-Path $fixture 'scripts\Get-PinnedLoaderReferences.ps1')
    }
    $control = New-ManifestFixture 'manifest-control' { param($f) }
    Expect-Accepted 'manifest-control-accepted' (Invoke-Isolated @('-File', $control, '-VerifyOnly', '-ReferenceDirectory', $references)) ''
    $raised = New-ManifestFixture 'manifest-raised' { param($f)
        $p = Join-Path $f 'Info.json'; $t = [IO.File]::ReadAllText($p)
        [IO.File]::WriteAllText($p, ($t -replace '"ManagerVersion":\s*"0\.31\.1"', '"ManagerVersion": "0.33.0"')) }
    Expect-Rejected 'manifest-above-compiler-reference-rejected' (Invoke-Isolated @('-File', $raised, '-VerifyOnly', '-ReferenceDirectory', $references)) 'ManagerVersion must equal'
    $repinned = New-ManifestFixture 'pin-raised' { param($f)
        $p = Join-Path $f 'scripts\loader-reference-pins.json'; $t = [IO.File]::ReadAllText($p)
        [IO.File]::WriteAllText($p, $t.Replace('"Version": "0.31.1.0"', '"Version": "0.33.0.0"')) }
    Expect-Rejected 'compiler-pin-above-minimum-rejected' (Invoke-Isolated @('-File', $repinned, '-VerifyOnly', '-ReferenceDirectory', $references)) 'must equal the declared minimum'

    # 5. Build receipts bind the exact DLL bytes and the pinned reference identities.
    $common = Join-Path $root 'scripts\Common.ps1'
    $legacyZip = $LegacyReleaseZip
    if (-not $legacyZip) {
        $legacyZip = Join-Path $temp 'KingmakerLastAzlantiPreserver-0.1.3.zip'
        Invoke-WebRequest -Uri $legacyUrl -OutFile $legacyZip -UseBasicParsing
    }
    if ((Get-Sha256 $legacyZip) -ne $legacySha256) { throw "Legacy release ZIP hash mismatch: $legacyZip" }
    $legacyDll = Join-Path $temp 'legacy-KingmakerLastAzlantiPreserver.dll'
    $archive = [IO.Compression.ZipFile]::OpenRead($legacyZip)
    try { [IO.Compression.ZipFileExtensions]::ExtractToFile($archive.GetEntry("$modFolder/KingmakerLastAzlantiPreserver.dll"), $legacyDll) }
    finally { $archive.Dispose() }
    $legacyRef = Invoke-Isolated @('-Command', "([Reflection.Assembly]::ReflectionOnlyLoad([IO.File]::ReadAllBytes($(Quote $legacyDll))).GetReferencedAssemblies() | Where-Object Name -eq 'UnityModManager').Version.ToString()")
    Add-Case 'legacy-release-references-umm-0.33.0' ($legacyRef.ExitCode -eq 0 -and $legacyRef.Output.Trim() -eq '0.33.0.0') ("observed: " + $legacyRef.Output.Trim())

    function Test-Receipt([string] $ReceiptFile, [string] $DllFile) {
        return Invoke-Isolated @('-Command', ". $(Quote $common); Assert-PinnedBuildReceipt (Get-Content -LiteralPath $(Quote $ReceiptFile) -Raw | ConvertFrom-Json) $(Quote $DllFile)")
    }
    Expect-Accepted 'receipt-matching-build-accepted' (Test-Receipt $receiptPath $dll) ''
    Expect-Rejected 'receipt-other-dll-bytes-rejected' (Test-Receipt $receiptPath $legacyDll) 'does not match the mod DLL'
    $receipt = Get-Content -LiteralPath $receiptPath -Raw | ConvertFrom-Json
    $noRefs = Join-Path $temp 'receipt-no-refs.json'
    $receipt | Select-Object -Property * -ExcludeProperty loader_references | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $noRefs -Encoding UTF8
    Expect-Rejected 'receipt-without-loader-references-rejected' (Test-Receipt $noRefs $dll) 'no pinned loader references'
    $otherPin = Join-Path $temp 'receipt-other-pin.json'
    $edited = Get-Content -LiteralPath $receiptPath -Raw | ConvertFrom-Json
    @($edited.loader_references | Where-Object { $_.file -eq 'UnityModManager.dll' })[0].sha256 = (Get-Sha256 (Join-Path $config.UnityModManagerDir 'UnityModManager.dll'))
    $edited | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $otherPin -Encoding UTF8
    Expect-Rejected 'receipt-recording-other-loader-rejected' (Test-Receipt $otherPin $dll) 'does not match pinned reference'

    # 6. Packages: the real candidate passes the standalone validator; smuggled loader files and the
    #    genuine 0.33.0-compiled release with only its manifest lowered are refused before installation.
    #    Every validation writes its report to the temporary directory, never over the qualification record.
    $package = Invoke-Isolated @('-File', (Join-Path $root 'scripts\Package.ps1'), '-Configuration', $Configuration)
    $zipMatch = [regex]::Match($package.Output, 'Package: (.+\.zip)')
    if ($package.ExitCode -ne 0 -or -not $zipMatch.Success) { throw "Package.ps1 failed: $($package.Output)" }
    $candidateZip = $zipMatch.Groups[1].Value.Trim()
    $validator = Join-Path $root 'scripts\Validate-Package.ps1'
    $validationReport = Join-Path $temp 'package-validation.json'
    Expect-Accepted 'package-candidate-accepted' (Invoke-Isolated @('-File', $validator, '-PackagePath', $candidateZip, '-ReportPath', $validationReport)) 'UnityModManager 0\.31\.1\.0'
    $smuggledExtra = Join-Path $temp 'smuggled-extra.zip'
    Edit-Zip $candidateZip $smuggledExtra { param($a) Add-ZipFile $a "$modFolder/0Harmony12.dll" $pinnedHarmony }
    Expect-Rejected 'package-extra-harmony-rejected' (Invoke-Isolated @('-File', $validator, '-PackagePath', $smuggledExtra, '-ReportPath', $validationReport)) 'Expected exactly \d+ package files'
    $smuggledSwap = Join-Path $temp 'smuggled-swap.zip'
    Edit-Zip $candidateZip $smuggledSwap { param($a) $a.GetEntry("$modFolder/README.md").Delete(); Add-ZipFile $a "$modFolder/UnityModManager.dll" $pinnedUmm }
    Expect-Rejected 'package-swapped-in-loader-rejected' (Invoke-Isolated @('-File', $validator, '-PackagePath', $smuggledSwap, '-ReportPath', $validationReport)) 'Package allowlist mismatch'
    $smuggledGame = Join-Path $temp 'smuggled-game.zip'
    Edit-Zip $candidateZip $smuggledGame { param($a) $a.GetEntry("$modFolder/README.md").Delete(); Add-ZipFile $a "$modFolder/Assembly-CSharp-firstpass.dll" (Join-Path $config.ManagedDir 'Assembly-CSharp-firstpass.dll') }
    Expect-Rejected 'package-swapped-in-game-assembly-rejected' (Invoke-Isolated @('-File', $validator, '-PackagePath', $smuggledGame, '-ReportPath', $validationReport)) 'Package allowlist mismatch'
    $lowered = Join-Path $temp 'legacy-lowered-manifest.zip'
    Edit-Zip $legacyZip $lowered { param($a)
        $text = Get-ZipEntryText $a "$modFolder/Info.json"
        $changed = $text -replace '"ManagerVersion":\s*"[0-9.]+"', '"ManagerVersion": "0.31.1"'
        if ($changed -eq $text) { throw 'Legacy manifest was not lowered.' }
        Set-ZipEntryText $a "$modFolder/Info.json" $changed }
    Expect-Rejected 'package-legacy-0.33.0-dll-with-lowered-manifest-rejected' (Invoke-Isolated @('-File', $validator, '-PackagePath', $lowered, '-ReportPath', $validationReport)) 'must reference pinned UnityModManager 0\.31\.1\.0'

    # Install.ps1 is the supported route for a supplied ZIP; it must run this validator before extracting.
    $install = [IO.File]::ReadAllText((Join-Path $root 'scripts\Install.ps1'))
    $validateAt = $install.IndexOf('Validate-Package.ps1')
    $extractAt = $install.IndexOf('ExtractToDirectory')
    Add-Case 'install-validates-before-extracting' ($validateAt -ge 0 -and $extractAt -gt $validateAt) "validate at $validateAt, extract at $extractAt"

    $failed = @($cases | Where-Object { -not $_.passed })
    $summary = [ordered]@{
        schema = 'klap.loader-baseline-tests.v1'
        source_commit = (Get-GitMetadata).Commit
        source_dirty = (Get-GitMetadata).Dirty
        build_receipt_commit = $receipt.source_commit
        build_receipt_dirty = $receipt.source_dirty
        dll_sha256 = Get-Sha256 $dll
        candidate_package = $candidateZip
        candidate_package_sha256 = Get-Sha256 $candidateZip
        legacy_release_zip_sha256 = $legacySha256
        installed_loader_version = $installedVersion
        cases = @($cases)
        passed = $cases.Count - $failed.Count
        total = $cases.Count
    }
    if ($receipt.source_commit -ne $summary.source_commit -or $receipt.source_dirty -or $summary.source_dirty) {
        Write-Host "WARNING: the tested build was not produced from the current clean commit (receipt $($receipt.source_commit), dirty $($receipt.source_dirty)); rebuild for candidate evidence."
    }
    if ($ReportPath) { $summary | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $ReportPath -Encoding UTF8 }
    Write-Host ("RESULT {0}/{1} loader-baseline checks passed" -f $summary.passed, $summary.total)
    if ($failed.Count -gt 0) { throw "$($failed.Count) loader-baseline check(s) failed." }
}
finally {
    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}
