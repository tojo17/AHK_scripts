# Get AutoHotkey Version Information for Cache Key Generation
# This script fetches the latest version information for AutoHotkey v1, v2, and Ahk2Exe
# and sets environment variables for GitHub Actions workflow caching

Write-Host "=== Fetching AutoHotkey Version Information ===" -ForegroundColor Magenta

try {
    # Set up HTTP headers for API requests
    $headers = @{ "User-Agent" = "PowerShell" }
    
    Write-Host "Fetching release information from GitHub APIs..." -ForegroundColor Cyan
    
    # Get AutoHotkey latest release information
    Write-Host "  Fetching AutoHotkey releases..." -ForegroundColor White
    $ahkApiUrl = "https://api.github.com/repos/AutoHotkey/AutoHotkey/releases"
    $ahkReleases = Invoke-RestMethod -Uri $ahkApiUrl -Headers $headers
    
    # Find latest stable v1.1.x release
    $v1Release = $ahkReleases | Where-Object { $_.tag_name -match "^v1\.1\." } | Select-Object -First 1
    if (-not $v1Release) {
        throw "Could not find AutoHotkey v1.1.x release"
    }
    
    # Find latest stable v2.x release (non-prerelease)
    $v2Release = $ahkReleases | Where-Object { $_.tag_name -match "^v2\." -and -not $_.prerelease } | Select-Object -First 1
    if (-not $v2Release) {
        throw "Could not find AutoHotkey v2.x stable release"
    }
    
    # Get Ahk2Exe latest release
    Write-Host "  Fetching Ahk2Exe release..." -ForegroundColor White
    $ahk2exeApiUrl = "https://api.github.com/repos/AutoHotkey/Ahk2Exe/releases/latest"
    $ahk2exeRelease = Invoke-RestMethod -Uri $ahk2exeApiUrl -Headers $headers
    
    if (-not $ahk2exeRelease) {
        throw "Could not find Ahk2Exe latest release"
    }
    
    # Extract version tags
    $v1Version = $v1Release.tag_name
    $v2Version = $v2Release.tag_name
    $ahk2exeVersion = $ahk2exeRelease.tag_name
    
    Write-Host ""
    Write-Host "=== Version Information ===" -ForegroundColor Green
    Write-Host "AutoHotkey v1.1: $v1Version" -ForegroundColor Green
    Write-Host "AutoHotkey v2.0: $v2Version" -ForegroundColor Green
    Write-Host "Ahk2Exe: $ahk2exeVersion" -ForegroundColor Green
    
    # Generate cache key from versions
    $cacheKey = "ahk-binaries-$v1Version-$v2Version-$ahk2exeVersion"
    Write-Host ""
    Write-Host "Generated cache key: $cacheKey" -ForegroundColor Cyan
    
    # Set environment variables and step outputs for GitHub Actions
    Write-Host ""
    Write-Host "Setting GitHub Actions environment variables and outputs..." -ForegroundColor Cyan
    
    if ($env:GITHUB_ENV -and $env:GITHUB_OUTPUT) {
        # Write to GitHub Environment file for later steps
        Add-Content -Path $env:GITHUB_ENV -Value "AHK_V1_VERSION=$v1Version" -Encoding UTF8
        Add-Content -Path $env:GITHUB_ENV -Value "AHK_V2_VERSION=$v2Version" -Encoding UTF8
        Add-Content -Path $env:GITHUB_ENV -Value "AHK2EXE_VERSION=$ahk2exeVersion" -Encoding UTF8
        
        # Write to GitHub Output file for immediate use in next steps
        Add-Content -Path $env:GITHUB_OUTPUT -Value "cache-key=$cacheKey" -Encoding UTF8
        Add-Content -Path $env:GITHUB_OUTPUT -Value "v1-version=$v1Version" -Encoding UTF8
        Add-Content -Path $env:GITHUB_OUTPUT -Value "v2-version=$v2Version" -Encoding UTF8
        Add-Content -Path $env:GITHUB_OUTPUT -Value "ahk2exe-version=$ahk2exeVersion" -Encoding UTF8
        
        Write-Host "  ✓ Environment variables and outputs set successfully" -ForegroundColor Green
        Write-Host "    Environment variables:" -ForegroundColor Gray
        Write-Host "      AHK_V1_VERSION = $v1Version" -ForegroundColor Gray
        Write-Host "      AHK_V2_VERSION = $v2Version" -ForegroundColor Gray
        Write-Host "      AHK2EXE_VERSION = $ahk2exeVersion" -ForegroundColor Gray
        Write-Host "    Step outputs:" -ForegroundColor Gray
        Write-Host "      cache-key = $cacheKey" -ForegroundColor Gray
        Write-Host "      v1-version = $v1Version" -ForegroundColor Gray
        Write-Host "      v2-version = $v2Version" -ForegroundColor Gray
        Write-Host "      ahk2exe-version = $ahk2exeVersion" -ForegroundColor Gray
    } else {
        Write-Host "  ⚠ GITHUB_ENV or GITHUB_OUTPUT not found - not running in GitHub Actions context" -ForegroundColor Yellow
        Write-Host "  Values for local testing:" -ForegroundColor Yellow
        Write-Host "    CACHE_KEY = $cacheKey" -ForegroundColor Gray
        Write-Host "    AHK_V1_VERSION = $v1Version" -ForegroundColor Gray
        Write-Host "    AHK_V2_VERSION = $v2Version" -ForegroundColor Gray  
        Write-Host "    AHK2EXE_VERSION = $ahk2exeVersion" -ForegroundColor Gray
    }
    
    Write-Host ""
    Write-Host "=== Version Information Retrieval Complete ===" -ForegroundColor Magenta
    exit 0
}
catch {
    Write-Host ""
    Write-Host "=== ERROR ===" -ForegroundColor Red
    Write-Error "Failed to fetch AutoHotkey version information: $($_.Exception.Message)"
    Write-Host "This may be due to:" -ForegroundColor Yellow
    Write-Host "  - Network connectivity issues" -ForegroundColor Yellow
    Write-Host "  - GitHub API rate limiting" -ForegroundColor Yellow
    Write-Host "  - Changes in GitHub repository structure" -ForegroundColor Yellow
    exit 1
}