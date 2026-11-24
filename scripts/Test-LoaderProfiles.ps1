[CmdletBinding()]
param(
    # A folder whose subfolders are loader profiles, each holding UnityModManager.dll, 0Harmony.dll and 0Harmony12.dll.
    [Parameter(Mandatory = $true)][string] $ProfileRoot,
    [ValidateSet('Debug','Release')][string] $Configuration = 'Release',
    [string] $ReportPath
)
# Managed (out-of-game) contract checks of one candidate DLL against several loader profiles. For each profile the
# repository's contract verifiers load Assembly-CSharp from the configured game installation and apply, verify and
# remove this product's Harmony patches in-process through that profile's 0Harmony12 -> 0Harmony stack, after checking
# the profile's exact UnityModManager and Harmony2 identities. Every profile runs in its own PowerShell process with a
# temporary GamePath.props; the installed loader, mods and saves are not touched. This is not an in-game run.
. (Join-Path $PSScriptRoot 'Common.ps1')
$root = Get-RepositoryRoot
$gameConfig = Get-KingmakerConfiguration -AllowMissingLoader
$dll = Join-Path $root "artifacts\bin\$Configuration\KingmakerLastAzlantiPreserver\KingmakerLastAzlantiPreserver.dll"
Assert-FileExists $dll 'Candidate DLL (build first)'
$dllSha = Get-Sha256 $dll
$temp = Join-Path ([IO.Path]::GetTempPath()) ('klap-loader-profiles-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temp | Out-Null
# Every profile verifies the same private frozen copy, and each row is credited only if it reports that digest.
$frozenDirectory = Join-Path $temp 'frozen'
New-Item -ItemType Directory -Path $frozenDirectory | Out-Null
$frozen = Join-Path $frozenDirectory 'KingmakerLastAzlantiPreserver.dll'
[IO.File]::Copy($dll, $frozen)
if ((Get-Sha256 $frozen) -ne $dllSha) { throw 'The build output changed while it was being frozen.' }
$results = @()
try {
    foreach ($profile in @(Get-ChildItem -LiteralPath $ProfileRoot -Directory | Sort-Object Name)) {
        $work = Join-Path $temp $profile.Name
        New-Item -ItemType Directory -Path $work | Out-Null
        $props = Join-Path $work 'GamePath.props'
        $xml = "<Project xmlns=`"http://schemas.microsoft.com/developer/msbuild/2003`"><PropertyGroup>" +
            "<KingmakerInstallDir>$([Security.SecurityElement]::Escape($gameConfig.InstallDir))</KingmakerInstallDir>" +
            "<KingmakerManagedDir>$([Security.SecurityElement]::Escape($gameConfig.ManagedDir))</KingmakerManagedDir>" +
            "<UnityModManagerDir>$([Security.SecurityElement]::Escape($profile.FullName))</UnityModManagerDir>" +
            "</PropertyGroup></Project>"
        [IO.File]::WriteAllText($props, $xml)
        $identities = @(foreach ($file in @('UnityModManager.dll', '0Harmony.dll', '0Harmony12.dll')) {
            $path = Join-Path $profile.FullName $file
            if (Test-Path -LiteralPath $path) { "$file $([Reflection.AssemblyName]::GetAssemblyName($path).Version) $(Get-Sha256 $path)" } else { "$file missing" }
        })
        $gameOver = Join-Path $work 'game-over-load-contracts.json'
        $previous = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            $records = $null | & powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'Verify-KingmakerContracts.ps1') `
                -GamePathProps $props -OutputPath (Join-Path $work 'contracts.json') -GameOverOutputPath $gameOver -DllPath $frozen 2>&1
        }
        finally { $ErrorActionPreference = $previous }
        $exit = $LASTEXITCODE
        $text = @($records | ForEach-Object { "$_" })
        $passed = $exit -eq 0 -and (Test-Path -LiteralPath $gameOver)
        if ($passed -and [string](Get-Content -LiteralPath $gameOver -Raw | ConvertFrom-Json).mod_dll.sha256 -ne $dllSha) {
            $passed = $false
            $text = @('refused: verified DLL digest does not match the frozen candidate')
        }
        $detail = if ($passed) {
            $report = Get-Content -LiteralPath $gameOver -Raw | ConvertFrom-Json
            "loader profile $($report.loader_profile); Harmony2 $($report.harmony2.identity); core/optional patch ownership " +
                "$($report.harmony_ownership.core_owned_after_application)/$($report.harmony_ownership.optional_owned_after_application); " +
                "core kept after optional unpatch $($report.harmony_ownership.core_owned_after_optional_unpatch); verified DLL $($report.mod_dll.sha256)"
        }
        else {
            $reason = @($text | Where-Object { $_ -match 'does not match|must|missing|refus|failed|Exception' -and $_ -notmatch '^\s*(At |\+|CategoryInfo|FullyQualifiedErrorId)' } | Select-Object -First 1)
            if (-not $reason) { $reason = @($text | Where-Object { $_ -match '\S' } | Select-Object -Last 1) }
            'refused: ' + ($reason -join ' ').Trim()
        }
        $results += [ordered]@{ profile = $profile.Name; files = $identities; passed = $passed; detail = $detail }
        Write-Host ("{0} {1} :: {2}" -f $(if ($passed) { 'PASSED ' } else { 'REFUSED' }), $profile.Name, $detail)
        foreach ($identity in $identities) { Write-Host "    $identity" }
    }
    $summary = [ordered]@{ schema = 'klap.loader-profile-contracts.v2'; configuration = $Configuration; dll_sha256 = $dllSha; frozen_copy_verified = $true; profiles = $results }
    if ($ReportPath) { $summary | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $ReportPath -Encoding UTF8 }
    Write-Host "Candidate DLL ($Configuration): $dllSha"
}
finally { Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue }
