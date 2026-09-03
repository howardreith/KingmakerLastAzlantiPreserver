[CmdletBinding()]
param(
    [ValidateSet('Release')][string] $Configuration = 'Release',
    [string] $ReleaseNotesPath = 'docs\RELEASE-NOTES-0.1.0.md',
    [switch] $PrepareOnly,
    [switch] $Publish,
    [switch] $ConfirmOwnerAuthorizedUnqualifiedRelease
)

. (Join-Path $PSScriptRoot 'Common.ps1')

function Assert-CommandAvailable([string] $Name) {
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "$Name is required but was not found on PATH."
    }
}

function Invoke-Native([string] $FilePath, [string[]] $Arguments = @()) {
    & $FilePath @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$FilePath failed with exit code $LASTEXITCODE." }
}

function Get-NativeOutput([string] $FilePath, [string[]] $Arguments = @()) {
    $output = & $FilePath @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$FilePath failed with exit code $LASTEXITCODE." }
    return (($output | ForEach-Object { [string] $_ }) -join "`n").Trim()
}

function Test-Native([string] $FilePath, [string[]] $Arguments = @()) {
    $priorPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'SilentlyContinue'
        & $FilePath @Arguments *> $null
        return $LASTEXITCODE -eq 0
    }
    finally {
        $ErrorActionPreference = $priorPreference
    }
}

function Read-Qualification([string] $Root) {
    $qualification = Get-Content -LiteralPath (Join-Path $Root 'artifacts\qualification\qualification-summary.json') -Raw | ConvertFrom-Json
    $contracts = Get-Content -LiteralPath (Join-Path $Root 'artifacts\qualification\contracts.json') -Raw | ConvertFrom-Json
    $validation = Get-Content -LiteralPath (Join-Path $Root 'artifacts\qualification\package-validation.json') -Raw | ConvertFrom-Json
    if ($qualification.status -ne 'non-runtime-qualification-passed' -or
        $qualification.test_result -ne 'passed' -or
        [int] $qualification.test_count -ne 26 -or
        [int] $qualification.compiler_warning_count -ne 0 -or
        [int] $qualification.compiler_error_count -ne 0 -or
        $qualification.package_validation -ne 'passed' -or
        $contracts.status -ne 'passed' -or
        $contracts.patch_ownership -ne 'verified-after-application' -or
        $validation.status -ne 'passed') {
        throw 'Release qualification evidence is incomplete or failed.'
    }

    return [pscustomobject]@{
        Commit = [string] $qualification.commit_sha
        Dirty = [bool] $qualification.dirty
        TestCount = [int] $qualification.test_count
        DllPath = [string] $qualification.dll_path
        DllSha256 = [string] $qualification.dll_sha256
        PackagePath = [string] $qualification.package_path
        PackageSha256 = [string] $qualification.package_sha256
        AssemblySha256 = [string] $qualification.assembly_csharp_sha256
        AssemblyMvid = [string] $qualification.assembly_csharp_mvid
        GameOverHook = [string] $qualification.game_over_hook
        DeletionHook = [string] $qualification.deletion_hook
        RuntimeQualification = [string] $qualification.runtime_qualification
    }
}

function Invoke-ReleaseQualification([string] $Root, [string] $BuildConfiguration) {
    $windowsPowerShell = Join-Path $PSHOME 'powershell.exe'
    Assert-FileExists $windowsPowerShell 'Windows PowerShell executable'
    Invoke-Native $windowsPowerShell @(
        '-NoLogo',
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-File', (Join-Path $PSScriptRoot 'Qualify.ps1'),
        '-Build',
        '-Test',
        '-VerifyContracts',
        '-Package',
        '-Configuration', $BuildConfiguration
    ) | Out-Host
    return Read-Qualification $Root
}

if ($PrepareOnly -and $Publish) { throw '-PrepareOnly and -Publish cannot be combined.' }
if ($Publish -and -not $ConfirmOwnerAuthorizedUnqualifiedRelease) {
    throw 'Publishing 0.1.0 before runtime qualification requires -ConfirmOwnerAuthorizedUnqualifiedRelease.'
}

$root = Get-RepositoryRoot
Assert-CommandAvailable 'git'
Assert-CommandAvailable 'gh'

Push-Location $root
try {
    $status = Get-NativeOutput 'git' @('status', '--porcelain')
    if (-not [string]::IsNullOrWhiteSpace($status)) { throw 'Release publishing requires a clean working tree.' }

    Invoke-Native 'gh' @('auth', 'status', '--hostname', 'github.com')
    $repository = Get-NativeOutput 'gh' @(
        'repo', 'view',
        '--json', 'nameWithOwner,defaultBranchRef,isPrivate'
    ) | ConvertFrom-Json
    if ([string] $repository.nameWithOwner -ne 'howardreith/KingmakerLastAzlantiPreserver') {
        throw "Unexpected GitHub repository: $($repository.nameWithOwner)"
    }
    if ([bool] $repository.isPrivate) { throw 'This release workflow expects the public product repository.' }
    $defaultBranch = [string] $repository.defaultBranchRef.name
    if ($defaultBranch -ne 'main') { throw "The GitHub default branch is '$defaultBranch', not 'main'." }

    $branch = Get-NativeOutput 'git' @('branch', '--show-current')
    if ($branch -ne $defaultBranch) { throw "Release publishing must run from clean '$defaultBranch'; current branch is '$branch'." }
    Invoke-Native 'git' @('fetch', '--prune', '--tags', 'origin', $defaultBranch)
    $head = Get-NativeOutput 'git' @('rev-parse', 'HEAD')
    $remoteHead = Get-NativeOutput 'git' @('rev-parse', "origin/$defaultBranch")
    if ($head -ne $remoteHead) { throw "HEAD $head does not match origin/$defaultBranch $remoteHead." }

    $origin = Get-NativeOutput 'git' @('remote', 'get-url', 'origin')
    if ($origin -notmatch 'howardreith/KingmakerLastAzlantiPreserver(?:\.git)?$') {
        throw "Origin does not match the expected repository: $origin"
    }

    $info = Get-Content -LiteralPath (Join-Path $root 'Info.json') -Raw | ConvertFrom-Json
    if ($info.Id -ne 'KingmakerLastAzlantiPreserver' -or
        $info.Version -ne '0.1.0' -or
        $info.AssemblyName -ne 'KingmakerLastAzlantiPreserver.dll') {
        throw 'Info.json does not match the authorized 0.1.0 release identity.'
    }

    $notesPath = if ([IO.Path]::IsPathRooted($ReleaseNotesPath)) {
        [IO.Path]::GetFullPath($ReleaseNotesPath)
    }
    else {
        [IO.Path]::GetFullPath((Join-Path $root $ReleaseNotesPath))
    }
    Assert-FileExists $notesPath 'Release notes'
    $customNotes = (Get-Content -LiteralPath $notesPath -Raw).Trim()
    if ($customNotes -notmatch '(?i)0\.1\.0' -or $customNotes -notmatch '(?i)not runtime-qualified|runtime qualification.*remain') {
        throw 'Release notes must identify version 0.1.0 and disclose pending runtime qualification.'
    }

    $projectState = Get-Content -LiteralPath (Join-Path $root 'PROJECT-STATE.md') -Raw
    if ($projectState -notmatch 'Owner-authorized release disposition:.*v0\.1\.0' -or
        $projectState -notmatch 'Runtime qualification: \*\*not performed\*\*') {
        throw 'PROJECT-STATE.md does not record the owner-authorized release disposition and runtime boundary.'
    }

    $tag = 'v0.1.0'
    $title = 'Last Azlanti Preserver v0.1.0'
    $existingRelease = $null
    if (Test-Native 'gh' @('release', 'view', $tag, '--repo', [string] $repository.nameWithOwner)) {
        $existingRelease = Get-NativeOutput 'gh' @(
            'release', 'view', $tag,
            '--repo', [string] $repository.nameWithOwner,
            '--json', 'isDraft,isImmutable,url'
        ) | ConvertFrom-Json
        if (-not [bool] $existingRelease.isDraft) { throw "Published release '$tag' already exists; it will not be replaced." }
        if ([bool] $existingRelease.isImmutable) { throw "Draft release '$tag' is immutable." }
    }

    $first = Invoke-ReleaseQualification $root $Configuration
    $firstStatus = Get-NativeOutput 'git' @('status', '--porcelain')
    if (-not [string]::IsNullOrWhiteSpace($firstStatus) -or $first.Dirty -or $first.Commit -ne $head) {
        throw 'The first qualification did not preserve the clean release commit.'
    }

    $second = Invoke-ReleaseQualification $root $Configuration
    $secondStatus = Get-NativeOutput 'git' @('status', '--porcelain')
    if (-not [string]::IsNullOrWhiteSpace($secondStatus) -or $second.Dirty -or $second.Commit -ne $head) {
        throw 'The second qualification did not preserve the clean release commit.'
    }
    if ($first.DllSha256 -cne $second.DllSha256 -or
        $first.PackageSha256 -cne $second.PackageSha256 -or
        $first.AssemblySha256 -cne $second.AssemblySha256 -or
        $first.AssemblyMvid -cne $second.AssemblyMvid) {
        throw 'Two clean release qualifications did not produce identical provenance.'
    }

    $releaseDirectory = Join-Path $root 'artifacts\release\0.1.0'
    Assert-PathWithin $releaseDirectory $root 'Release staging directory'
    if (Test-Path -LiteralPath $releaseDirectory) { Remove-Item -LiteralPath $releaseDirectory -Recurse -Force }
    [IO.Directory]::CreateDirectory($releaseDirectory) | Out-Null

    $assetName = 'KingmakerLastAzlantiPreserver-0.1.0.zip'
    $releasePackage = Join-Path $releaseDirectory $assetName
    Copy-Item -LiteralPath $second.PackagePath -Destination $releasePackage
    & (Join-Path $PSScriptRoot 'Validate-Package.ps1') `
        -PackagePath $releasePackage `
        -ReportPath (Join-Path $releaseDirectory 'package-validation.json')
    $packageHash = Get-Sha256 $releasePackage
    if ($packageHash -cne $second.PackageSha256) { throw 'Release-staged package hash changed after qualification.' }

    $checksumsPath = Join-Path $releaseDirectory 'SHA256SUMS.txt'
    "$packageHash  $assetName" | Set-Content -LiteralPath $checksumsPath -Encoding ASCII
    $manifestPath = Join-Path $releaseDirectory 'release-manifest.json'
    $manifest = [ordered]@{
        schema_version = 1
        generator = 'scripts/Publish-Release.ps1'
        product = [string] $info.DisplayName
        version = [string] $info.Version
        tag = $tag
        branch = $defaultBranch
        commit = $head
        package = $assetName
        package_sha256 = $packageHash
        dll_sha256 = $second.DllSha256
        assembly_csharp_sha256 = $second.AssemblySha256
        assembly_csharp_mvid = $second.AssemblyMvid
        test_count = $second.TestCount
        deterministic_qualifications = 2
        package_validated = $true
        runtime_qualified = $false
        owner_authorized_release_before_runtime_test = $true
    }
    Write-JsonFile $manifestPath $manifest

    $generatedNotesPath = Join-Path $releaseDirectory 'release-notes-0.1.0.md'
    $verificationNotes = @(
        '## Installation',
        '',
        "1. Download **$assetName** from **Assets** below.",
        '2. In Unity Mod Manager, select Pathfinder: Kingmaker and drag the ZIP into the **Mods** tab.',
        '3. Confirm **Last Azlanti Preserver 0.1.0** is enabled and protection reports **AVAILABLE**.',
        '',
        "Do not download GitHub's generated **Source code** archives; they are not the installable UMM package.",
        '',
        '## Verification',
        '',
        ('Package SHA-256: `{0}`' -f $packageHash),
        '',
        ('Release commit: `{0}`' -f $head),
        '',
        ('Assembly-CSharp SHA-256: `{0}`' -f $second.AssemblySha256),
        '',
        ('Assembly-CSharp MVID: `{0}`' -f $second.AssemblyMvid),
        '',
        'The release was qualified twice from clean main with 26/26 tests, exact local contract verification, verified Harmony ownership, zero compiler warnings/errors, deterministic DLL/package hashes, and strict package validation.',
        '',
        '**Runtime qualification has not yet been performed.** The owner explicitly authorized this actual release for main-computer testing; this statement is not a runtime compatibility claim.'
    ) -join [Environment]::NewLine
    ($customNotes + [Environment]::NewLine + [Environment]::NewLine + $verificationNotes) |
        Set-Content -LiteralPath $generatedNotesPath -Encoding UTF8

    Write-Host "Prepared release asset: $releasePackage"
    Write-Host "Package SHA-256: $packageHash"
    Write-Host "DLL SHA-256: $($second.DllSha256)"
    if ($PrepareOnly) {
        Write-Host 'Prepare-only qualification passed; no tag or GitHub release was created.'
        return
    }

    if (Test-Native 'git' @('show-ref', '--verify', '--quiet', "refs/tags/$tag")) {
        $tagCommit = Get-NativeOutput 'git' @('rev-list', '-n', '1', $tag)
        if ($tagCommit -ne $head) { throw "Existing local tag '$tag' does not resolve to release commit $head." }
    }
    else {
        Invoke-Native 'git' @('tag', '-a', $tag, '-m', $title, $head)
    }
    if (-not (Test-Native 'git' @('ls-remote', '--exit-code', '--tags', 'origin', "refs/tags/$tag"))) {
        Invoke-Native 'git' @('push', 'origin', "refs/tags/$tag")
    }

    $assets = @($releasePackage, $checksumsPath, $manifestPath)
    if ($null -eq $existingRelease) {
        $arguments = @(
            'release', 'create', $tag
        ) + $assets + @(
            '--repo', [string] $repository.nameWithOwner,
            '--title', $title,
            '--notes-file', $generatedNotesPath,
            '--verify-tag',
            '--target', $head
        )
        if ($Publish) { $arguments += @('--latest') } else { $arguments += '--draft' }
        Invoke-Native 'gh' $arguments
    }
    else {
        Invoke-Native 'gh' (@(
            'release', 'upload', $tag
        ) + $assets + @(
            '--repo', [string] $repository.nameWithOwner,
            '--clobber'
        ))
        $arguments = @(
            'release', 'edit', $tag,
            '--repo', [string] $repository.nameWithOwner,
            '--title', $title,
            '--notes-file', $generatedNotesPath,
            '--verify-tag',
            '--target', $head
        )
        if ($Publish) { $arguments += @('--draft=false', '--prerelease=false', '--latest') } else { $arguments += '--draft' }
        Invoke-Native 'gh' $arguments
    }

    $release = Get-NativeOutput 'gh' @(
        'release', 'view', $tag,
        '--repo', [string] $repository.nameWithOwner,
        '--json', 'url,isDraft,isPrerelease,tagName,targetCommitish'
    ) | ConvertFrom-Json
    if ($Publish -and ([bool] $release.isDraft -or [bool] $release.isPrerelease)) {
        throw 'GitHub did not publish the requested stable release state.'
    }
    Write-Host "Release: $($release.url)"
    Write-Host "State: $(if ($Publish) { 'published stable/latest' } else { 'draft' })"
}
finally {
    Pop-Location
}
