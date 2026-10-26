$ErrorActionPreference = "Stop"

function Set-JsonProperty {
    param(
        [Parameter(Mandatory = $true)] $Object,
        [Parameter(Mandatory = $true)] [string] $Name,
        $Value
    )

    $property = $Object.PSObject.Properties[$Name]

    if ($null -eq $property) {
        $Object | Add-Member -MemberType NoteProperty -Name $Name -Value $Value
    }
    else {
        $property.Value = $Value
    }
}

function Read-JsonFile {
    param(
        [Parameter(Mandatory = $true)] [string] $Path
    )

    $text = [System.IO.File]::ReadAllText(
        $Path,
        [System.Text.Encoding]::UTF8
    )

    return ($text | ConvertFrom-Json)
}

function Write-JsonFile {
    param(
        [Parameter(Mandatory = $true)] $Object,
        [Parameter(Mandatory = $true)] [string] $Path
    )

    $json = $Object | ConvertTo-Json -Depth 100 -Compress
    $utf8 = New-Object System.Text.UTF8Encoding($false)

    [System.IO.File]::WriteAllText(
        $Path,
        $json,
        $utf8
    )
}

try {

    # ------------------------------------------------------------
    # Chrome paths
    # ------------------------------------------------------------

    $userData = Join-Path $env:LOCALAPPDATA "Google\Chrome\User Data"
    $localStatePath = Join-Path $userData "Local State"

    if (-not (Test-Path -LiteralPath $localStatePath)) {
        throw "Chrome Local State was not found: $localStatePath"
    }

    # ------------------------------------------------------------
    # Read Chrome profile list
    # ------------------------------------------------------------

    $localState = Read-JsonFile -Path $localStatePath

    if (
        $null -eq $localState.profile -or
        $null -eq $localState.profile.info_cache
    ) {
        throw "Chrome profile information was not found."
    }

    $profiles = @()

    foreach ($property in $localState.profile.info_cache.PSObject.Properties) {

        $directory = $property.Name
        $info = $property.Value

        $profilePath = Join-Path $userData $directory
        $preferencesPath = Join-Path $profilePath "Preferences"

        if (-not (Test-Path -LiteralPath $preferencesPath)) {
            continue
        }

        $displayName = $info.name

        if ([string]::IsNullOrWhiteSpace($displayName)) {
            $displayName = "(no name)"
        }

        $account = ""

        if (
            $info.PSObject.Properties["user_name"] -and
            -not [string]::IsNullOrWhiteSpace($info.user_name)
        ) {
            $account = $info.user_name
        }

        $gaiaId = ""

        if (
            $info.PSObject.Properties["gaia_id"] -and
            -not [string]::IsNullOrWhiteSpace($info.gaia_id)
        ) {
            $gaiaId = $info.gaia_id
        }

        $profiles += [PSCustomObject]@{
            Directory       = $directory
            Name            = $displayName
            Account         = $account
            GaiaId          = $gaiaId
            ProfilePath     = $profilePath
            PreferencesPath = $preferencesPath
        }
    }

    if ($profiles.Count -eq 0) {
        throw "No Chrome profiles were found."
    }

    # ------------------------------------------------------------
    # Profile selection
    # ------------------------------------------------------------

    Write-Host ""
    Write-Host "================================================"
    Write-Host " Chrome Profile Avatar Repair"
    Write-Host "================================================"
    Write-Host ""
    Write-Host "Select the Chrome profile to repair."
    Write-Host ""

    for ($i = 0; $i -lt $profiles.Count; $i++) {

        $p = $profiles[$i]
        $number = $i + 1

        Write-Host ("{0}. {1}" -f $number, $p.Directory)
        Write-Host ("   Name    : {0}" -f $p.Name)

        if (-not [string]::IsNullOrWhiteSpace($p.Account)) {
            Write-Host ("   Account : {0}" -f $p.Account)
        }

        Write-Host ""
    }

    Write-Host "0. Cancel"
    Write-Host ""

    while ($true) {

        $answer = Read-Host "Profile number"
        $choice = 0

        if ([int]::TryParse($answer, [ref]$choice)) {

            if ($choice -eq 0) {
                exit 2
            }

            if (
                $choice -ge 1 -and
                $choice -le $profiles.Count
            ) {
                break
            }
        }

        Write-Host "Invalid profile number." -ForegroundColor Yellow
    }

    $selected = $profiles[$choice - 1]

    $profileDir = $selected.Directory
    $profilePath = $selected.ProfilePath
    $preferencesPath = $selected.PreferencesPath

    Write-Host ""
    Write-Host "Selected profile"
    Write-Host "----------------"
    Write-Host ("Directory : {0}" -f $profileDir)
    Write-Host ("Name      : {0}" -f $selected.Name)

    if (-not [string]::IsNullOrWhiteSpace($selected.Account)) {
        Write-Host ("Account   : {0}" -f $selected.Account)
    }

    Write-Host ""

    $confirm = Read-Host "Continue? (Y/N)"

    if ($confirm -notmatch '^[Yy]$') {
        exit 2
    }

    # ------------------------------------------------------------
    # Wait until Chrome is closed
    # Chrome is NEVER killed automatically
    # ------------------------------------------------------------

    $warningShown = $false

    while ($true) {

        $chrome = Get-Process chrome -ErrorAction SilentlyContinue

        if (-not $chrome) {
            break
        }

        if (-not $warningShown) {

            Write-Host ""
            Write-Host "================================================" -ForegroundColor Yellow
            Write-Host " WARNING: Google Chrome is running" -ForegroundColor Yellow
            Write-Host "================================================" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "Chrome will NOT be terminated automatically."
            Write-Host "Close all Chrome windows normally."
            Write-Host "Save any unfinished work before closing Chrome."
            Write-Host ""

            $warningShown = $true
        }

        $waitAnswer = Read-Host "Close Chrome, then press ENTER. Type C to cancel"

        if ($waitAnswer -match '^[Cc]$') {
            exit 2
        }

        Start-Sleep -Seconds 1

        $chrome = Get-Process chrome -ErrorAction SilentlyContinue

        if ($chrome) {
            Write-Host ""
            Write-Host "chrome.exe is still running." -ForegroundColor Yellow
            Write-Host "Close Chrome completely and try again."
            Write-Host ""
        }
    }

    Write-Host ""
    Write-Host "Chrome is closed." -ForegroundColor Green

    # ------------------------------------------------------------
    # Backup
    # ------------------------------------------------------------

    Write-Host ""
    Write-Host "[1/5] Creating backup..."

    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $safeProfileName = $profileDir -replace '[\\/:*?"<>| ]', '_'

    $backupDir = Join-Path `
        $userData `
        ("AvatarRepairBackup_{0}_{1}" -f $safeProfileName, $timestamp)

    New-Item `
        -ItemType Directory `
        -Path $backupDir `
        -Force | Out-Null

    Copy-Item `
        -LiteralPath $preferencesPath `
        -Destination (Join-Path $backupDir "Preferences") `
        -Force

    Copy-Item `
        -LiteralPath $localStatePath `
        -Destination (Join-Path $backupDir "Local State") `
        -Force

    Write-Host ("Backup: {0}" -f $backupDir)

    # ------------------------------------------------------------
    # Repair Preferences
    # ------------------------------------------------------------

    Write-Host ""
    Write-Host "[2/5] Resetting Chrome avatar preferences..."

    $prefs = Read-JsonFile -Path $preferencesPath

    if ($null -eq $prefs.profile) {
        Set-JsonProperty `
            -Object $prefs `
            -Name "profile" `
            -Value ([PSCustomObject]@{})
    }

    Set-JsonProperty `
        -Object $prefs.profile `
        -Name "avatar_index" `
        -Value (-1)

    Set-JsonProperty `
        -Object $prefs.profile `
        -Name "using_default_avatar" `
        -Value $true

    Set-JsonProperty `
        -Object $prefs.profile `
        -Name "using_gaia_avatar" `
        -Value $false

    # ------------------------------------------------------------
    # Clear account avatar download cache marker
    # picture_url is deliberately preserved
    # ------------------------------------------------------------

    $accountUpdated = $false

    if ($null -ne $prefs.account_info) {

        foreach ($accountInfo in @($prefs.account_info)) {

            $emailMatch = $false
            $gaiaMatch = $false

            if (
                -not [string]::IsNullOrWhiteSpace($selected.Account) -and
                $accountInfo.PSObject.Properties["email"]
            ) {
                $emailMatch = (
                    $accountInfo.email -eq $selected.Account
                )
            }

            if (
                -not [string]::IsNullOrWhiteSpace($selected.GaiaId)
            ) {

                if ($accountInfo.PSObject.Properties["account_id"]) {

                    if (
                        $accountInfo.account_id -eq $selected.GaiaId
                    ) {
                        $gaiaMatch = $true
                    }
                }

                if ($accountInfo.PSObject.Properties["gaia"]) {

                    if (
                        $accountInfo.gaia -eq $selected.GaiaId
                    ) {
                        $gaiaMatch = $true
                    }
                }
            }

            if ($emailMatch -or $gaiaMatch) {

                Set-JsonProperty `
                    -Object $accountInfo `
                    -Name "last_downloaded_image_url_with_size" `
                    -Value ""

                $accountUpdated = $true
            }
        }

        if (
            -not $accountUpdated -and
            @($prefs.account_info).Count -eq 1
        ) {

            Set-JsonProperty `
                -Object @($prefs.account_info)[0] `
                -Name "last_downloaded_image_url_with_size" `
                -Value ""

            $accountUpdated = $true
        }
    }

    Write-JsonFile `
        -Object $prefs `
        -Path $preferencesPath

    # ------------------------------------------------------------
    # Repair Local State
    # ------------------------------------------------------------

    Write-Host ""
    Write-Host "[3/5] Resetting Chrome profile cache..."

    $localState = Read-JsonFile -Path $localStatePath

    $profileProperty = `
        $localState.profile.info_cache.PSObject.Properties[$profileDir]

    if ($null -eq $profileProperty) {
        throw "Selected profile was not found in Local State."
    }

    $profileInfo = $profileProperty.Value

    Set-JsonProperty `
        -Object $profileInfo `
        -Name "avatar_icon" `
        -Value "chrome://theme/IDR_PROFILE_AVATAR_26"

    Set-JsonProperty `
        -Object $profileInfo `
        -Name "is_using_default_avatar" `
        -Value $true

    Set-JsonProperty `
        -Object $profileInfo `
        -Name "use_gaia_picture" `
        -Value $false

    Set-JsonProperty `
        -Object $profileInfo `
        -Name "gaia_picture_file_name" `
        -Value ""

    Set-JsonProperty `
        -Object $profileInfo `
        -Name "last_downloaded_gaia_picture_url_with_size" `
        -Value ""

    Write-JsonFile `
        -Object $localState `
        -Path $localStatePath

    # ------------------------------------------------------------
    # Remove cached profile image
    # ------------------------------------------------------------

    Write-Host ""
    Write-Host "[4/5] Removing stale avatar cache..."

    $googleProfilePicture = `
        Join-Path $profilePath "Google Profile Picture.png"

    if (Test-Path -LiteralPath $googleProfilePicture) {

        Copy-Item `
            -LiteralPath $googleProfilePicture `
            -Destination (Join-Path $backupDir "Google Profile Picture.png") `
            -Force

        Remove-Item `
            -LiteralPath $googleProfilePicture `
            -Force

        Write-Host "Removed: Google Profile Picture.png"
    }
    else {
        Write-Host "Not found: Google Profile Picture.png"
    }

    $avatarImages = `
        Join-Path $profilePath "Accounts\Avatar Images"

    if (Test-Path -LiteralPath $avatarImages) {

        $avatarBackup = `
            Join-Path $backupDir "Avatar Images"

        Copy-Item `
            -LiteralPath $avatarImages `
            -Destination $avatarBackup `
            -Recurse `
            -Force

        Remove-Item `
            -LiteralPath $avatarImages `
            -Recurse `
            -Force

        Write-Host "Removed: Accounts\Avatar Images"
    }
    else {
        Write-Host "Not found: Accounts\Avatar Images"
    }

    # ------------------------------------------------------------
    # Log
    # ------------------------------------------------------------

    $logPath = Join-Path $backupDir "RepairLog.txt"

    $log = @"
Chrome Profile Avatar Repair

Date:
$(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

Profile:
$profileDir

Name:
$($selected.Name)

Account:
$($selected.Account)

Preferences:
avatar_index = -1
using_default_avatar = true
using_gaia_avatar = false

Local State:
avatar_icon = chrome://theme/IDR_PROFILE_AVATAR_26
is_using_default_avatar = true
use_gaia_picture = false
gaia_picture_file_name = ""
last_downloaded_gaia_picture_url_with_size = ""

Cache:
Google Profile Picture.png
Accounts\Avatar Images

Backup:
$backupDir
"@

    $logEncoding = `
        New-Object System.Text.UTF8Encoding($true)

    [System.IO.File]::WriteAllText(
        $logPath,
        $log,
        $logEncoding
    )

    # ------------------------------------------------------------
    # Start Chrome
    # ------------------------------------------------------------

    Write-Host ""
    Write-Host "[5/5] Starting Chrome..."

    $chromeCandidates = @(
        "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
        "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
        "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"
    )

    $chromeExe = $null

    foreach ($candidate in $chromeCandidates) {

        if (
            -not [string]::IsNullOrWhiteSpace($candidate) -and
            (Test-Path -LiteralPath $candidate)
        ) {
            $chromeExe = $candidate
            break
        }
    }

    if ($null -ne $chromeExe) {

        $profileArgument = `
            '--profile-directory="{0}"' -f $profileDir

        Start-Process `
            -FilePath $chromeExe `
            -ArgumentList $profileArgument

        Write-Host ""
        Write-Host "Chrome started." -ForegroundColor Green
    }
    else {

        Write-Host ""
        Write-Host "Chrome executable was not found." `
            -ForegroundColor Yellow

        Write-Host "Start Chrome manually."
    }

    # ------------------------------------------------------------
    # Completed
    # ------------------------------------------------------------

    Write-Host ""
    Write-Host "================================================" `
        -ForegroundColor Green

    Write-Host " Repair completed" `
        -ForegroundColor Green

    Write-Host "================================================" `
        -ForegroundColor Green

    Write-Host ""
    Write-Host ("Profile : {0}" -f $profileDir)
    Write-Host ("Backup  : {0}" -f $backupDir)
    Write-Host ""

    exit 0
}
catch {

    Write-Host ""
    Write-Host "================================================" `
        -ForegroundColor Red

    Write-Host " ERROR" `
        -ForegroundColor Red

    Write-Host "================================================" `
        -ForegroundColor Red

    Write-Host ""
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ""

    exit 1
}
