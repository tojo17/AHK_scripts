# Setup Unified AutoHotkey Compiler Environment
# This script sets up a unified AutoHotkey compilation environment with:
# - One Ahk2Exe compiler (universal for v1 and v2)
# - Base files for both v1 and v2 in x86 and x64 architectures

param(
    [string]$TempDir = $env:TEMP,
    [string]$CacheDir = "$env:RUNNER_TEMP/ahk-unified-cache",
    [string]$InstallPath = "$env:RUNNER_TEMP/AutoHotkey_Unified"
)

Write-Host "=== Setting up Unified AutoHotkey Compiler Environment ===" -ForegroundColor Magenta

try {
    # Step 1: Get latest release information
    Write-Host "Fetching release information..." -ForegroundColor Cyan
    
    $headers = @{ "User-Agent" = "PowerShell" }
    
    # Get AutoHotkey v1.1 latest release
    $ahkApiUrl = "https://api.github.com/repos/AutoHotkey/AutoHotkey/releases"
    $ahkReleases = Invoke-RestMethod -Uri $ahkApiUrl -Headers $headers
    $v1Release = $ahkReleases | Where-Object { $_.tag_name -match "^v1\.1\." } | Select-Object -First 1
    $v2Release = $ahkReleases | Where-Object { $_.tag_name -match "^v2\." -and -not $_.prerelease } | Select-Object -First 1
    
    # Get Ahk2Exe latest release  
    $ahk2exeApiUrl = "https://api.github.com/repos/AutoHotkey/Ahk2Exe/releases/latest"
    $ahk2exeRelease = Invoke-RestMethod -Uri $ahk2exeApiUrl -Headers $headers
    
    Write-Host "AutoHotkey v1.1: $($v1Release.tag_name)" -ForegroundColor Green
    Write-Host "AutoHotkey v2.0: $($v2Release.tag_name)" -ForegroundColor Green  
    Write-Host "Ahk2Exe: $($ahk2exeRelease.tag_name)" -ForegroundColor Green
    
    # Step 2: Prepare download information
    Write-Host "Preparing downloads..." -ForegroundColor Cyan
    
    # Find download assets
    $v1ZipAsset = $v1Release.assets | Where-Object { $_.name -match ".*\.zip$" -and $_.name -notmatch "ansi|x64" } | Select-Object -First 1
    $v2ZipAsset = $v2Release.assets | Where-Object { $_.name -match ".*\.zip$" } | Select-Object -First 1  
    $ahk2exeZipAsset = $ahk2exeRelease.assets | Where-Object { $_.name -match ".*\.zip$" } | Select-Object -First 1
    
    if (-not $v1ZipAsset) { throw "Could not find AutoHotkey v1.1 ZIP asset" }
    if (-not $v2ZipAsset) { throw "Could not find AutoHotkey v2.0 ZIP asset" }
    if (-not $ahk2exeZipAsset) { throw "Could not find Ahk2Exe ZIP asset" }
    
    $downloads = @(
        @{ Name = "AutoHotkey v1.1"; Url = $v1ZipAsset.browser_download_url; File = "ahk-v1.zip"; ExtractDir = "v1_extract" }
        @{ Name = "AutoHotkey v2.0"; Url = $v2ZipAsset.browser_download_url; File = "ahk-v2.zip"; ExtractDir = "v2_extract" }
        @{ Name = "Ahk2Exe"; Url = $ahk2exeZipAsset.browser_download_url; File = "ahk2exe.zip"; ExtractDir = "ahk2exe_extract" }
    )
    
    # Step 3: Create directories
    Write-Host "Creating directory structure..." -ForegroundColor Cyan
    $compilerDir = Join-Path $InstallPath "Compiler"
    New-Item -ItemType Directory -Force -Path $compilerDir | Out-Null
    New-Item -ItemType Directory -Force -Path $CacheDir | Out-Null
    
    foreach ($download in $downloads) {
        New-Item -ItemType Directory -Force -Path (Join-Path $TempDir $download.ExtractDir) | Out-Null
    }
    
    # Step 4: Download and extract files
    Write-Host "Downloading and extracting files..." -ForegroundColor Cyan
    
    foreach ($download in $downloads) {
        $zipPath = Join-Path $TempDir $download.File
        $extractPath = Join-Path $TempDir $download.ExtractDir
        
        Write-Host "  Downloading $($download.Name)..." -ForegroundColor White
        Write-Host "    From: $($download.Url)" -ForegroundColor Gray
        Write-Host "    To: $zipPath" -ForegroundColor Gray
        
        Invoke-WebRequest -Uri $download.Url -OutFile $zipPath -ErrorAction Stop
        
        Write-Host "  Extracting $($download.Name)..." -ForegroundColor White
        Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
        
        Write-Host "  ✓ Completed $($download.Name)" -ForegroundColor Green
    }
    
    # Step 5: Organize files in unified structure
    Write-Host "Organizing files in unified structure..." -ForegroundColor Cyan
    
    # Copy Ahk2Exe.exe
    $ahk2exeExtractPath = Join-Path $TempDir "ahk2exe_extract"
    $ahk2exeFile = Get-ChildItem $ahk2exeExtractPath -Recurse -Name "Ahk2Exe.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
    
    if (-not $ahk2exeFile) { throw "Could not find Ahk2Exe.exe in extracted files" }
    
    $ahk2exeSourcePath = Join-Path $ahk2exeExtractPath $ahk2exeFile
    $ahk2exeDestPath = Join-Path $compilerDir "Ahk2Exe.exe"
    Copy-Item $ahk2exeSourcePath $ahk2exeDestPath -Force
    Write-Host "  ✓ Copied Ahk2Exe.exe" -ForegroundColor Green
    
    # Copy v1 base files
    $v1ExtractPath = Join-Path $TempDir "v1_extract"
    $v1BinFiles = Get-ChildItem $v1ExtractPath -Recurse -Name "*.bin" -ErrorAction SilentlyContinue
    
    foreach ($binFile in $v1BinFiles) {
        $sourcePath = Join-Path $v1ExtractPath $binFile
        $fileName = Split-Path $binFile -Leaf
        
        # Rename to v1-specific naming
        $newName = switch ($fileName) {
            "Unicode 32-bit.bin" { "AutoHotkey_v1_Unicode32.bin" }
            "Unicode 64-bit.bin" { "AutoHotkey_v1_Unicode64.bin" }  
            "ANSI 32-bit.bin" { "AutoHotkey_v1_ANSI32.bin" }
            default { "AutoHotkey_v1_$fileName" }
        }
        
        $destPath = Join-Path $compilerDir $newName
        Copy-Item $sourcePath $destPath -Force
        Write-Host "  ✓ Copied $fileName -> $newName" -ForegroundColor Green
    }
    
    # Copy v2 base files (v2 uses .exe files as base, not .bin files)
    $v2ExtractPath = Join-Path $TempDir "v2_extract"
    $v2ExeFiles = Get-ChildItem $v2ExtractPath -Recurse -Name "AutoHotkey*.exe" -ErrorAction SilentlyContinue
    
    foreach ($exeFile in $v2ExeFiles) {
        $sourcePath = Join-Path $v2ExtractPath $exeFile
        $fileName = Split-Path $exeFile -Leaf
        
        # Rename to v2-specific naming (v2 uses .exe as base files)
        $newName = switch ($fileName) {
            "AutoHotkeyU32.exe" { "AutoHotkey_v2_Unicode32.exe" }
            "AutoHotkeyU64.exe" { "AutoHotkey_v2_Unicode64.exe" }
            "AutoHotkey.exe" { "AutoHotkey_v2_Unicode32.exe" }  # Fallback naming
            default { "AutoHotkey_v2_$fileName" }
        }
        
        $destPath = Join-Path $compilerDir $newName
        Copy-Item $sourcePath $destPath -Force
        Write-Host "  ✓ Copied $fileName -> $newName" -ForegroundColor Green
    }
    
    # Step 6: Verify installation
    Write-Host "Verifying installation..." -ForegroundColor Cyan
    
    $ahk2exePath = Join-Path $compilerDir "Ahk2Exe.exe"
    if (-not (Test-Path $ahk2exePath)) { throw "Ahk2Exe.exe not found at expected location" }
    
    $requiredBaseFiles = @(
        "AutoHotkey_v1_Unicode32.bin",
        "AutoHotkey_v1_Unicode64.bin", 
        "AutoHotkey_v2_Unicode32.exe",
        "AutoHotkey_v2_Unicode64.exe"
    )
    
    $foundBaseFiles = 0
    foreach ($baseFile in $requiredBaseFiles) {
        $baseFilePath = Join-Path $compilerDir $baseFile
        if (Test-Path $baseFilePath) {
            Write-Host "  ✓ Found: $baseFile" -ForegroundColor Green
            $foundBaseFiles++
        } else {
            Write-Host "  ⚠ Missing: $baseFile" -ForegroundColor Yellow
        }
    }
    
    Write-Host "Found $foundBaseFiles out of $($requiredBaseFiles.Count) expected base files" -ForegroundColor White
    
    # Step 7: Set environment variables
    Write-Host "Setting environment variables..." -ForegroundColor Cyan
    
    # Add compiler directory to PATH
    Write-Host "$InstallPath" | Out-File -FilePath $env:GITHUB_PATH -Encoding utf8 -Append
    Write-Host "AHK_UNIFIED_PATH=$InstallPath" | Out-File -FilePath $env:GITHUB_ENV -Encoding utf8 -Append
    Write-Host "AHK_COMPILER_PATH=$compilerDir" | Out-File -FilePath $env:GITHUB_ENV -Encoding utf8 -Append
    
    # Step 8: Summary
    Write-Host ""
    Write-Host "=== Unified AutoHotkey Environment Setup Complete ===" -ForegroundColor Magenta
    Write-Host "Installation Path: $InstallPath" -ForegroundColor Green
    Write-Host "Compiler Path: $compilerDir" -ForegroundColor Green
    Write-Host "Ahk2Exe.exe: Available" -ForegroundColor Green
    Write-Host "Base Files: $foundBaseFiles found" -ForegroundColor Green
    
    if ($foundBaseFiles -lt 2) {
        Write-Warning "Some base files are missing. Compilation may fail for some script types."
        exit 1
    }
    
    exit 0
}
catch {
    Write-Error "Error setting up AutoHotkey environment: $($_.Exception.Message)"
    exit 1
}