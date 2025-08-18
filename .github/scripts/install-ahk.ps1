# Install AutoHotkey (v1.1 or v2.0)
# This script downloads and installs AutoHotkey for GitHub Actions

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("v1", "v2")]
    [string]$Version,
    
    [string]$TempDir = $env:TEMP,
    [string]$CacheDir = "$env:RUNNER_TEMP/ahk-installers/$Version"
)

Write-Host "Installing AutoHotkey $Version..."

# Version-specific configuration
switch ($Version) {
    "v1" {
        $versionPattern = "^v1\.1\."
        $preReleaseFilter = $false  # v1 doesn't filter pre-releases
        $installerPattern = ".*setup.*\.exe$|.*install.*\.exe$"
        $fallbackUrl = "https://www.autohotkey.com/download/ahk-install.exe"
        $executableName = "Ahk2Exe.exe"
        $installPaths = @("${env:ProgramFiles}\AutoHotkey")
        $envVarName = "AHK_V1_PATH"
        $cacheFileName = "ahk-install.exe"
        $displayName = "v1.1"
    }
    "v2" {
        $versionPattern = "^v2\."
        $preReleaseFilter = $true   # v2 filters out pre-releases
        $installerPattern = ".*_setup\.exe$"
        $fallbackUrl = $null  # v2 doesn't have official website fallback
        $executableName = "Ahk2Exe.exe"
        $installPaths = @(
            "${env:ProgramFiles}\AutoHotkey\v2",
            "${env:ProgramFiles}\AutoHotkey v2",
            "${env:LOCALAPPDATA}\Programs\AutoHotkey\v2"
        )
        $envVarName = "AHK_V2_PATH"
        $cacheFileName = "ahk2-install.exe"
        $displayName = "v2.0"
    }
}

try {
    # Get latest release from GitHub API
    Write-Host "Fetching latest AutoHotkey $displayName release from GitHub..."
    $apiUrl = "https://api.github.com/repos/AutoHotkey/AutoHotkey/releases"
    $releases = Invoke-RestMethod -Uri $apiUrl -Headers @{ "User-Agent" = "PowerShell" }
    
    # Find the appropriate release
    if ($preReleaseFilter) {
        $targetRelease = $releases | Where-Object { $_.tag_name -match $versionPattern -and -not $_.prerelease } | Select-Object -First 1
    } else {
        $targetRelease = $releases | Where-Object { $_.tag_name -match $versionPattern } | Select-Object -First 1
    }
    
    if (-not $targetRelease) {
        Write-Error "Could not find any $displayName releases"
        exit 1
    }
    
    $releaseVersion = $targetRelease.tag_name
    Write-Host "Found latest $displayName version: $releaseVersion"
    
    # Check cache first
    $cachedInstaller = Join-Path $CacheDir $cacheFileName
    $output = Join-Path $TempDir $cacheFileName
    
    if (Test-Path $cachedInstaller) {
        Write-Host "✓ Using cached installer from: $cachedInstaller"
        Copy-Item $cachedInstaller $output
    } else {
        Write-Host "Cache miss - downloading installer..."
        
        # Look for installer asset in the release
        $installerAsset = $targetRelease.assets | Where-Object { $_.name -match $installerPattern } | Select-Object -First 1
        
        if ($installerAsset) {
            # Use GitHub release asset
            $url = $installerAsset.browser_download_url
            Write-Host "Using GitHub release installer: $($installerAsset.name)"
        } elseif ($fallbackUrl) {
            # Fall back to official website (v1 only)
            Write-Host "No installer asset found in GitHub release, falling back to official website"
            $url = $fallbackUrl
        } else {
            Write-Error "Could not find installer asset in release"
            exit 1
        }
        
        Write-Host "Downloading from: $url"
        Write-Host "Saving to: $output"
        
        try {
            Invoke-WebRequest -Uri $url -OutFile $output -ErrorAction Stop
        }
        catch {
            if ($Version -eq "v2" -and $installerAsset) {
                # v2 fallback logic
                Write-Host "Failed to download from direct URL, trying latest download link..."
                $cleanVersion = $releaseVersion -replace "^v", ""  # Remove 'v' prefix
                $fallbackUrl = "https://github.com/AutoHotkey/AutoHotkey/releases/latest/download/AutoHotkey_${cleanVersion}_setup.exe"
                Write-Host "Fallback URL: $fallbackUrl"
                Invoke-WebRequest -Uri $fallbackUrl -OutFile $output
            } else {
                throw
            }
        }
        
        # Cache the downloaded installer
        Write-Host "Caching installer to: $cachedInstaller"
        New-Item -ItemType Directory -Force -Path $CacheDir | Out-Null
        Copy-Item $output $cachedInstaller
    }
    
    # Install AutoHotkey silently
    Write-Host "Installing AutoHotkey $displayName silently..."
    Start-Process -FilePath $output -ArgumentList "/S" -Wait
    
    # Find installation path
    $ahkPath = $null
    Write-Host "Searching for AutoHotkey $displayName installation..."
    
    foreach ($path in $installPaths) {
        Write-Host "Checking: $path"
        if (Test-Path (Join-Path $path $executableName)) {
            $ahkPath = $path
            Write-Host "✓ Found AutoHotkey $displayName at: $path"
            break
        }
    }
    
    if ($ahkPath) {
        # Add to PATH for subsequent steps
        Write-Host "$ahkPath" | Out-File -FilePath $env:GITHUB_PATH -Encoding utf8 -Append
        Write-Host "✓ AutoHotkey $displayName installed successfully at: $ahkPath"
        Write-Host "$envVarName=$ahkPath" | Out-File -FilePath $env:GITHUB_ENV -Encoding utf8 -Append
        exit 0
    } else {
        Write-Error "AutoHotkey $displayName installation failed - $executableName not found"
        
        # Debug output for v2
        if ($Version -eq "v2") {
            Write-Host "Debug - Listing Program Files AutoHotkey directories:"
            $ahkBaseDir = "${env:ProgramFiles}\AutoHotkey"
            if (Test-Path $ahkBaseDir) {
                Get-ChildItem $ahkBaseDir -Recurse | Where-Object { $_.Name -eq $executableName } | ForEach-Object {
                    Write-Host "Found $executableName at: $($_.FullName)"
                }
            }
        }
        
        exit 1
    }
}
catch {
    Write-Error "Error installing AutoHotkey $displayName: $($_.Exception.Message)"
    exit 1
}