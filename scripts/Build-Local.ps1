[CmdletBinding()]
param([ValidateSet('Debug','Release')][string] $Configuration = 'Release')

. (Join-Path $PSScriptRoot 'Common.ps1')
$root = Get-RepositoryRoot
Initialize-PinnedReferences | Out-Null
$loaderReferences = @(Get-PinnedReferenceIdentities)
# Fingerprint the material inputs before building: a change during or after the build invalidates the receipt.
$compilerReferences = @(Get-CompilerReferenceIdentities $Configuration)
$buildInputs = Get-BuildInputFingerprint $Configuration $compilerReferences
Assert-RepositorySafety
$git = Get-GitMetadata
$project = Join-Path $root 'src\KingmakerLastAzlantiPreserver\KingmakerLastAzlantiPreserver.csproj'
# The production compile writes its own compiler inventory; it must equal the inventory evaluated before building,
# which the receipt records and the fingerprint covers.
$productionInventory = Join-Path ([IO.Path]::GetTempPath()) ('klap-production-inputs-' + [Guid]::NewGuid().ToString('N') + '.txt')
$arguments = @($project, '/nologo', '/m', '/t:Rebuild', "/p:Configuration=$Configuration", '/p:Platform=AnyCPU', "/p:CompilerReferenceListPath=$productionInventory")
$output = & dotnet msbuild @arguments 2>&1
$exitCode = $LASTEXITCODE
$produced = if (Test-Path -LiteralPath $productionInventory) { @(ConvertFrom-CompilerInputList $productionInventory) } else { @() }
Remove-Item -LiteralPath $productionInventory -Force -ErrorAction SilentlyContinue
$output | ForEach-Object { Write-Host $_ }
$warningCount = @($output | Where-Object { $_ -match ': warning [A-Z]+\d+:' }).Count
$errorCount = @($output | Where-Object { $_ -match ': error [A-Z]+\d+:' }).Count
if ($exitCode -ne 0 -or $warningCount -ne 0 -or $errorCount -ne 0) {
    throw "Production build failed or emitted diagnostics (exit=$exitCode warnings=$warningCount errors=$errorCount)."
}
$difference = Get-CompilerInventoryDifference $produced $compilerReferences
if ($difference) {
    throw "The production compile used different compiler inputs from the evaluated inventory ($difference); the build is not recorded."
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
    loader_references = $loaderReferences
    build_inputs_sha256 = $buildInputs
    compiler_references = $compilerReferences
    source_commit = $git.Commit
    source_dirty = $git.Dirty
}
Write-JsonFile (Join-Path $root 'artifacts\qualification\build.json') $result
Write-Host "Build passed: $dll"
Write-Host "Compiler warnings/errors: $warningCount/$errorCount"
Write-Host "DLL SHA-256: $($result.dll_sha256)"
