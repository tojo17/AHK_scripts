# Install AutoHotkey v2.0
# This script downloads and installs AutoHotkey v2.0 for GitHub Actions

param(
    [string]$TempDir = $env:TEMP
)

Write-Host "Installing AutoHotkey v2.0..."

try {
    # Get latest v2.x release from GitHub API
    Write-Host "Fetching latest AutoHotkey v2.x release from GitHub..."
    $apiUrl = "https://api.github.com/repos/AutoHotkey/AutoHotkey/releases"
    $releases = Invoke-RestMethod -Uri $apiUrl -Headers @{ "User-Agent" = "PowerShell" }
    
    # Find the latest v2.x release (excluding pre-releases)
    $v2Release = $releases | Where-Object { $_.tag_name -match "^v2\." -and -not $_.prerelease } | Select-Object -First 1
    
    if (-not $v2Release) {
        Write-Error "Could not find any stable v2.x releases"
        exit 1
    }
    
    $version = $v2Release.tag_name -replace "^v", ""  # Remove 'v' prefix
    Write-Host "Found latest v2.x version: v$version"
    
    # Look for setup installer asset
    $setupAsset = $v2Release.assets | Where-Object { $_.name -match ".*_setup\.exe$" } | Select-Object -First 1
    
    if (-not $setupAsset) {
        Write-Error "Could not find setup installer in release assets"
        exit 1
    }
    
    $url = $setupAsset.browser_download_url
    $output = Join-Path $TempDir "ahk2-install.exe"
    
    Write-Host "Downloading from: $url"
    Write-Host "Saving to: $output"
    
    try {
        Invoke-WebRequest -Uri $url -OutFile $output -ErrorAction Stop
    }
    catch {
        Write-Host "Failed to download from direct URL, trying latest download link..."
        # Fallback to latest download link
        $fallbackUrl = "https://github.com/AutoHotkey/AutoHotkey/releases/latest/download/AutoHotkey_${version}_setup.exe"
        Write-Host "Fallback URL: $fallbackUrl"
        Invoke-WebRequest -Uri $fallbackUrl -OutFile $output
    }
    
    # Install AutoHotkey v2.0 silently
    Write-Host "Installing AutoHotkey v2.0 silently..."
    Start-Process -FilePath $output -ArgumentList "/S" -Wait
    
    # Find AutoHotkey v2 installation path
    $possiblePaths = @(
        "${env:ProgramFiles}\AutoHotkey\v2",
        "${env:ProgramFiles}\AutoHotkey v2",
        "${env:LOCALAPPDATA}\Programs\AutoHotkey\v2"
    )
    
    $ahkV2Path = $null
    Write-Host "Searching for AutoHotkey v2 installation..."
    
    foreach ($path in $possiblePaths) {
        Write-Host "Checking: $path"
        if (Test-Path (Join-Path $path "AutoHotkey.exe")) {
            $ahkV2Path = $path
            Write-Host "✓ Found AutoHotkey v2 at: $path"
            break
        }
    }
    
    if ($ahkV2Path) {
        # Add to PATH for subsequent steps
        Write-Host "$ahkV2Path" | Out-File -FilePath $env:GITHUB_PATH -Encoding utf8 -Append
        Write-Host "✓ AutoHotkey v2.0 installed successfully at: $ahkV2Path"
        Write-Host "AHK_V2_PATH=$ahkV2Path" | Out-File -FilePath $env:GITHUB_ENV -Encoding utf8 -Append
        exit 0
    } else {
        Write-Error "AutoHotkey v2.0 installation failed - could not find AutoHotkey.exe"
        
        # Debug: List what was actually installed
        Write-Host "Debug - Listing Program Files AutoHotkey directories:"
        $ahkBaseDir = "${env:ProgramFiles}\AutoHotkey"
        if (Test-Path $ahkBaseDir) {
            Get-ChildItem $ahkBaseDir -Recurse | Where-Object { $_.Name -eq "AutoHotkey.exe" } | ForEach-Object {
                Write-Host "Found AutoHotkey.exe at: $($_.FullName)"
            }
        }
        
        exit 1
    }
}
catch {
    Write-Error "Error installing AutoHotkey v2.0: $($_.Exception.Message)"
    exit 1
}