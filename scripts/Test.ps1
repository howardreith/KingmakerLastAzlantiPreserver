[CmdletBinding()]
param(
    [ValidateSet('Debug','Release')][string] $Configuration = 'Release',
    # Also write this invocation's result here (Qualify reads its own run's result from this path, never the shared record).
    [string] $ResultPath
)

. (Join-Path $PSScriptRoot 'Common.ps1')
$root = Get-RepositoryRoot
$project = Join-Path $root 'tests\KingmakerLastAzlantiPreserver.Tests\KingmakerLastAzlantiPreserver.Tests.csproj'
Invoke-MSBuild @($project, '/nologo', '/m', '/t:Rebuild', "/p:Configuration=$Configuration", '/p:Platform=AnyCPU')
$builtRunner = Join-Path $root "artifacts\tests\$Configuration\KingmakerLastAzlantiPreserver.Tests.exe"
Assert-FileExists $builtRunner 'Deterministic test runner'
# The runner executes from a private copy of its output folder: the product DLL it loads cannot be replaced between the
# run and the record, and the recorded identity is that copy's.
$privateRun = Join-Path ([IO.Path]::GetTempPath()) ('klap-test-run-' + [Guid]::NewGuid().ToString('N'))
try {
# The private copy is made inside the cleanup scope: a partial copy is removed too.
Copy-Item -LiteralPath (Split-Path -Parent $builtRunner) -Destination $privateRun -Recurse
$runner = Join-Path $privateRun 'KingmakerLastAzlantiPreserver.Tests.exe'
$testedDll = Join-Path $privateRun 'KingmakerLastAzlantiPreserver.dll'
$testedDllSha = Get-Sha256 $testedDll
$testedMvid = [Reflection.AssemblyName]::GetAssemblyName($testedDll).FullName
$configurationPaths = Get-KingmakerConfiguration
$priorReferenceDirs = $env:KMLAP_TEST_REFERENCE_DIRS
try {
    $env:KMLAP_TEST_REFERENCE_DIRS = @(
        $configurationPaths.UnityModManagerDir
        $configurationPaths.ManagedDir
    ) -join [IO.Path]::PathSeparator
    $output = & $runner 2>&1
    $exitCode = $LASTEXITCODE
}
finally {
    $env:KMLAP_TEST_REFERENCE_DIRS = $priorReferenceDirs
}
$output | ForEach-Object { Write-Host $_ }
$summary = @($output | Where-Object { $_ -match '^RESULT total=(\d+) passed=(\d+) failed=(\d+)$' }) | Select-Object -Last 1
if (-not $summary) { throw 'Test runner did not emit its deterministic RESULT line.' }
$match = [regex]::Match([string] $summary, '^RESULT total=(\d+) passed=(\d+) failed=(\d+)$')
$result = [ordered]@{
    status = if ($exitCode -eq 0) { 'passed' } else { 'failed' }
    total = [int] $match.Groups[1].Value
    passed = [int] $match.Groups[2].Value
    failed = [int] $match.Groups[3].Value
    runner = $runner
    # The product DLL the runner loaded, from the private run copy (hashed before and after the run).
    dll_sha256 = $testedDllSha
    dll_identity = $testedMvid
}
if ((Get-Sha256 $testedDll) -cne $testedDllSha) { throw 'The tested product DLL changed during the test run.' }
Write-JsonFile (Join-Path $root 'artifacts\qualification\tests.json') $result
if ($ResultPath) { Write-JsonFile $ResultPath $result }
if ($exitCode -ne 0 -or $result.failed -ne 0) { throw "Tests failed (exit=$exitCode failed=$($result.failed))." }
Write-Host "Tests passed: $($result.passed)/$($result.total)"
}
finally { if ([IO.Directory]::Exists($privateRun)) { [IO.Directory]::Delete($privateRun, $true) } }
