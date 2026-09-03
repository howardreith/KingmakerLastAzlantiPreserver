[CmdletBinding()]
param([ValidateSet('Debug','Release')][string] $Configuration = 'Release')

. (Join-Path $PSScriptRoot 'Common.ps1')
$root = Get-RepositoryRoot
Assert-RepositorySafety
$project = Join-Path $root 'src\KingmakerLastAzlantiPreserver\KingmakerLastAzlantiPreserver.csproj'
$arguments = @($project, '/nologo', '/m', '/t:Rebuild', "/p:Configuration=$Configuration", '/p:Platform=AnyCPU')
$output = & dotnet msbuild @arguments 2>&1
$exitCode = $LASTEXITCODE
$output | ForEach-Object { Write-Host $_ }
$warningCount = @($output | Where-Object { $_ -match ': warning [A-Z]+\d+:' }).Count
$errorCount = @($output | Where-Object { $_ -match ': error [A-Z]+\d+:' }).Count
if ($exitCode -ne 0 -or $warningCount -ne 0 -or $errorCount -ne 0) {
    throw "Production build failed or emitted diagnostics (exit=$exitCode warnings=$warningCount errors=$errorCount)."
}
$dll = Join-Path $root "artifacts\bin\$Configuration\KingmakerLastAzlantiPreserver\KingmakerLastAzlantiPreserver.dll"
Assert-FileExists $dll 'Built mod DLL'
$result = [ordered]@{
    status = 'passed'
    configuration = $Configuration
    compiler_warnings = $warningCount
    compiler_errors = $errorCount
    dll_path = $dll
    dll_sha256 = Get-Sha256 $dll
}
Write-JsonFile (Join-Path $root 'artifacts\qualification\build.json') $result
Write-Host "Build passed: $dll"
Write-Host "Compiler warnings/errors: $warningCount/$errorCount"
Write-Host "DLL SHA-256: $($result.dll_sha256)"
