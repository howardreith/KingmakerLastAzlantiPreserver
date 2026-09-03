[CmdletBinding(SupportsShouldProcess=$true)]
param()

. (Join-Path $PSScriptRoot 'Common.ps1')
$configuration = Get-KingmakerConfiguration
$target = [IO.Path]::GetFullPath((Join-Path $configuration.ModsDir 'KingmakerLastAzlantiPreserver'))
if (-not [string]::Equals((Split-Path -Parent $target).TrimEnd('\'), $configuration.ModsDir.TrimEnd('\'), [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Uninstall target validation failed.'
}
if (-not (Test-Path -LiteralPath $target -PathType Container)) { Write-Host 'Last Azlanti Preserver is not installed.'; return }
if (Get-Process -Name 'Kingmaker' -ErrorAction SilentlyContinue) { throw 'Exit Pathfinder: Kingmaker before uninstalling.' }
if ($PSCmdlet.ShouldProcess($target, 'Remove only Last Azlanti Preserver')) {
    Remove-Item -LiteralPath $target -Recurse -Force
    Write-Host "Removed only: $target"
}
