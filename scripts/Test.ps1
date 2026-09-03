[CmdletBinding()]
param([ValidateSet('Debug','Release')][string] $Configuration = 'Release')

. (Join-Path $PSScriptRoot 'Common.ps1')
$root = Get-RepositoryRoot
$project = Join-Path $root 'tests\KingmakerLastAzlantiPreserver.Tests\KingmakerLastAzlantiPreserver.Tests.csproj'
Invoke-MSBuild @($project, '/nologo', '/m', '/t:Rebuild', "/p:Configuration=$Configuration", '/p:Platform=AnyCPU')
$runner = Join-Path $root "artifacts\tests\$Configuration\KingmakerLastAzlantiPreserver.Tests.exe"
Assert-FileExists $runner 'Deterministic test runner'
$output = & $runner 2>&1
$exitCode = $LASTEXITCODE
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
}
Write-JsonFile (Join-Path $root 'artifacts\qualification\tests.json') $result
if ($exitCode -ne 0 -or $result.failed -ne 0) { throw "Tests failed (exit=$exitCode failed=$($result.failed))." }
Write-Host "Tests passed: $($result.passed)/$($result.total)"
