# Install AutoHotkey v1.1
# This script downloads and installs AutoHotkey v1.1 for GitHub Actions

param(
    [string]$TempDir = $env:TEMP,
    [string]$CacheDir = "$env:RUNNER_TEMP/ahk-installers/v1"
)

Write-Host "Installing AutoHotkey v1.1..."

try {
    # Get latest v1.1.x release from GitHub API
    Write-Host "Fetching latest AutoHotkey v1.1.x release from GitHub..."
    $apiUrl = "https://api.github.com/repos/AutoHotkey/AutoHotkey/releases"
    $releases = Invoke-RestMethod -Uri $apiUrl -Headers @{ "User-Agent" = "PowerShell" }
    
    # Find the latest v1.1.x release
    $v1Release = $releases | Where-Object { $_.tag_name -match "^v1\.1\." } | Select-Object -First 1
    
    if (-not $v1Release) {
        Write-Error "Could not find any v1.1.x releases"
        exit 1
    }
    
    $version = $v1Release.tag_name
    Write-Host "Found latest v1.1.x version: $version"
    
    # Check cache first
    $cachedInstaller = Join-Path $CacheDir "ahk-install.exe"
    $output = Join-Path $TempDir "ahk-install.exe"
    
    if (Test-Path $cachedInstaller) {
        Write-Host "✓ Using cached installer from: $cachedInstaller"
        Copy-Item $cachedInstaller $output
    } else {
        Write-Host "Cache miss - downloading installer..."
        
        # Look for installer asset in the release
        $installerAsset = $v1Release.assets | Where-Object { $_.name -match ".*setup.*\.exe$|.*install.*\.exe$" } | Select-Object -First 1
        
        if ($installerAsset) {
            # Use GitHub release asset
            $url = $installerAsset.browser_download_url
            Write-Host "Using GitHub release installer: $($installerAsset.name)"
        } else {
            # Fall back to official website if no installer asset found
            Write-Host "No installer asset found in GitHub release, falling back to official website"
            $url = "https://www.autohotkey.com/download/ahk-install.exe"
        }
        
        Write-Host "Downloading from: $url"
        Write-Host "Saving to: $output"
        
        Invoke-WebRequest -Uri $url -OutFile $output
        
        # Cache the downloaded installer
        Write-Host "Caching installer to: $cachedInstaller"
        New-Item -ItemType Directory -Force -Path $CacheDir | Out-Null
        Copy-Item $output $cachedInstaller
    }
    
    # Install AutoHotkey v1.1 silently
    Write-Host "Installing AutoHotkey v1.1 silently..."
    Start-Process -FilePath $output -ArgumentList "/S" -Wait
    
    # Set paths
    $ahkV1Path = "${env:ProgramFiles}\AutoHotkey"
    Write-Host "AutoHotkey v1.1 path: $ahkV1Path"
    
    # Add to PATH for subsequent steps
    Write-Host "$ahkV1Path" | Out-File -FilePath $env:GITHUB_PATH -Encoding utf8 -Append
    
    # Verify installation
    $ahk2exePath = Join-Path $ahkV1Path "Ahk2Exe.exe"
    if (Test-Path $ahk2exePath) {
        Write-Host "✓ AutoHotkey v1.1 installed successfully"
        Write-Host "AHK_V1_PATH=$ahkV1Path" | Out-File -FilePath $env:GITHUB_ENV -Encoding utf8 -Append
        exit 0
    } else {
        Write-Error "AutoHotkey v1.1 installation failed - Ahk2Exe.exe not found"
        exit 1
    }
}
catch {
    Write-Error "Error installing AutoHotkey v1.1: $($_.Exception.Message)"
    exit 1
}