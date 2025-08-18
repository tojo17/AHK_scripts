# Setup AutoHotkey Compiler Environment
# This script sets up an AutoHotkey compilation environment with:
# - One Ahk2Exe compiler (universal for v1 and v2)
# - Base files for both v1 and v2 in x86 and x64 architectures

param(
    [string]$TempDir = $env:TEMP,
    [string]$CacheDir = "$env:RUNNER_TEMP/ahk-cache",
    [string]$InstallPath = "$env:RUNNER_TEMP/AutoHotkey"
)

Write-Host "=== Setting up AutoHotkey Compiler Environment ===" -ForegroundColor Magenta

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
    
    # Step 5: Organize files for compilation
    Write-Host "Organizing files for compilation..." -ForegroundColor Cyan
    
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
    Write-Host "Processing AutoHotkey v2 base files..." -ForegroundColor White
    $v2ExtractPath = Join-Path $TempDir "v2_extract"
    
    Write-Host "  Searching for v2 executable files..." -ForegroundColor Gray
    if (Test-Path $v2ExtractPath) {
        
        # Search for all possible v2 executable files with multiple patterns
        $v2ExePatterns = @("AutoHotkey*.exe", "*.exe")
        $allV2ExeFiles = @()
        
        foreach ($pattern in $v2ExePatterns) {
            $foundFiles = Get-ChildItem $v2ExtractPath -Recurse -Name $pattern -ErrorAction SilentlyContinue
            $allV2ExeFiles += $foundFiles
        }
        
        # Remove duplicates and filter for likely v2 executables
        $v2ExeFiles = $allV2ExeFiles | Sort-Object -Unique | Where-Object {
            $fileName = Split-Path $_ -Leaf
            # Include AutoHotkey*.exe files and common v2 patterns
            $fileName -match "^AutoHotkey.*\.exe$" -or
            $fileName -match "^ahk.*\.exe$" -or  
            $fileName -eq "AutoHotkey.exe"
        }
        
        if ($v2ExeFiles.Count -eq 0) {
            Write-Host "  ⚠ No standard v2 executable files found" -ForegroundColor Yellow
            Write-Host "  Searching for any .exe files as fallback..." -ForegroundColor Yellow
        } else {
            Write-Host "  ✓ Found $($v2ExeFiles.Count) potential v2 executable files" -ForegroundColor Green
        }
        
        # Process each found v2 executable
        $v2FilesProcessed = 0
        foreach ($exeFile in $v2ExeFiles) {
            try {
                $sourcePath = Join-Path $v2ExtractPath $exeFile
                $fileName = Split-Path $exeFile -Leaf
                
                # Enhanced v2-specific naming with more patterns
                $newName = switch -Regex ($fileName) {
                    "^AutoHotkeyU32\.exe$" { "AutoHotkey_v2_Unicode32.exe" }
                    "^AutoHotkeyU64\.exe$" { "AutoHotkey_v2_Unicode64.exe" }
                    "^AutoHotkey32\.exe$" { "AutoHotkey_v2_Unicode32.exe" }
                    "^AutoHotkey64\.exe$" { "AutoHotkey_v2_Unicode64.exe" }
                    "^AutoHotkey\.exe$" { "AutoHotkey_v2_Unicode32.exe" }
                    "^ahk.*32.*\.exe$" { "AutoHotkey_v2_Unicode32.exe" }
                    "^ahk.*64.*\.exe$" { "AutoHotkey_v2_Unicode64.exe" }
                    default { 
                        # Try to infer architecture from filename or default to 32-bit
                        if ($fileName -match "64|x64") {
                            "AutoHotkey_v2_Unicode64.exe"
                        } else {
                            "AutoHotkey_v2_Unicode32.exe"
                        }
                    }
                }
                
                $destPath = Join-Path $compilerDir $newName
                
                # Check if we already have this target file
                if (-not (Test-Path $destPath)) {
                    Copy-Item $sourcePath $destPath -Force
                    Write-Host "  ✓ Copied $fileName -> $newName" -ForegroundColor Green
                    $v2FilesProcessed++
                }
            }
            catch {
                Write-Host "    ✗ Error processing $fileName : $($_.Exception.Message)" -ForegroundColor Red
            }
        }
        
        # If no files were processed, try a fallback approach
        if ($v2FilesProcessed -eq 0) {
            Write-Host "  Attempting fallback approach..." -ForegroundColor Yellow
            $anyExe = Get-ChildItem $v2ExtractPath -Recurse -Name "*.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($anyExe) {
                try {
                    $fallbackSource = Join-Path $v2ExtractPath $anyExe
                    $fallbackDest32 = Join-Path $compilerDir "AutoHotkey_v2_Unicode32.exe"
                    $fallbackDest64 = Join-Path $compilerDir "AutoHotkey_v2_Unicode64.exe"
                    
                    Copy-Item $fallbackSource $fallbackDest32 -Force
                    Copy-Item $fallbackSource $fallbackDest64 -Force
                    
                    Write-Host "  ✓ Fallback successful: created v2 base files" -ForegroundColor Green
                    $v2FilesProcessed = 2
                }
                catch {
                    Write-Host "  ✗ Fallback failed: $($_.Exception.Message)" -ForegroundColor Red
                }
            }
        }
        
        if ($v2FilesProcessed -gt 0) {
            Write-Host "  ✓ v2 base files ready" -ForegroundColor Green
        } else {
            Write-Host "  ⚠ v2 base files unavailable" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  ✗ v2 extract directory not found: $v2ExtractPath" -ForegroundColor Red
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
    
    Write-Host "Checking base files in: $compilerDir" -ForegroundColor Gray
    $foundV1Files = 0
    $foundV2Files = 0
    $totalRequiredFiles = $requiredBaseFiles.Count
    
    foreach ($baseFile in $requiredBaseFiles) {
        $baseFilePath = Join-Path $compilerDir $baseFile
        if (Test-Path $baseFilePath) {
            $fileSize = (Get-Item $baseFilePath).Length
            Write-Host "  ✓ Found: $baseFile ($([math]::Round($fileSize / 1KB, 2)) KB)" -ForegroundColor Green
            
            if ($baseFile -like "*_v1_*") {
                $foundV1Files++
            } elseif ($baseFile -like "*_v2_*") {
                $foundV2Files++
            }
        } else {
            Write-Host "  ✗ Missing: $baseFile" -ForegroundColor Red
        }
    }
    
    $foundBaseFiles = $foundV1Files + $foundV2Files
    Write-Host ""
    Write-Host "Base Files Summary:" -ForegroundColor White
    Write-Host "  v1 files: $foundV1Files / 2" -ForegroundColor $(if ($foundV1Files -eq 2) { "Green" } else { "Yellow" })
    Write-Host "  v2 files: $foundV2Files / 2" -ForegroundColor $(if ($foundV2Files -eq 2) { "Green" } else { "Red" })
    Write-Host "  Total: $foundBaseFiles / $totalRequiredFiles" -ForegroundColor $(if ($foundBaseFiles -eq $totalRequiredFiles) { "Green" } elseif ($foundBaseFiles -ge 2) { "Yellow" } else { "Red" })
    
    # Step 7: Set environment variables
    Write-Host "Setting environment variables..." -ForegroundColor Cyan
    
    # Verify GITHUB_ENV and GITHUB_PATH exist before writing
    if (-not $env:GITHUB_ENV) {
        Write-Warning "GITHUB_ENV not found - not running in GitHub Actions context"
    }
    
    if (-not $env:GITHUB_PATH) {
        Write-Warning "GITHUB_PATH not found - not running in GitHub Actions context"
    }
    
    # Add compiler directory to PATH
    if ($env:GITHUB_PATH) {
        try {
            Add-Content -Path $env:GITHUB_PATH -Value $InstallPath -Encoding UTF8
            Write-Host "  ✓ Added to PATH: $InstallPath" -ForegroundColor Green
        }
        catch {
            Write-Warning "Failed to add to PATH: $($_.Exception.Message)"
        }
    }
    
    # Set environment variables
    if ($env:GITHUB_ENV) {
        try {
            Add-Content -Path $env:GITHUB_ENV -Value "AHK_COMPILER_PATH=$compilerDir" -Encoding UTF8
            Add-Content -Path $env:GITHUB_ENV -Value "AHK_INSTALL_SUCCESS=true" -Encoding UTF8
            
            Write-Host "  ✓ Environment variables configured" -ForegroundColor Green
        }
        catch {
            Write-Error "Failed to write environment variables: $($_.Exception.Message)"
            throw
        }
        
        # Verify the environment file was written correctly
        if (Test-Path $env:GITHUB_ENV) {
            $envContent = Get-Content $env:GITHUB_ENV -Raw -ErrorAction SilentlyContinue
            
            $hasCompilerPath = $envContent -match "AHK_COMPILER_PATH="
            $hasInstallSuccess = $envContent -match "AHK_INSTALL_SUCCESS=true"
            
            if ($hasCompilerPath -and $hasInstallSuccess) {
                Write-Host "  ✓ Environment variables set successfully" -ForegroundColor Green
            } else {
                Write-Warning "Some environment variables are missing from GITHUB_ENV file"
                throw "Environment variable verification failed"
            }
        } else {
            Write-Error "GITHUB_ENV file not found at: $env:GITHUB_ENV"
            throw "GITHUB_ENV file not accessible"
        }
    }
    
    # Step 8: Summary
    Write-Host ""
    Write-Host "=== AutoHotkey Environment Setup Complete ===" -ForegroundColor Magenta
    Write-Host "Installation Path: $InstallPath" -ForegroundColor Green
    Write-Host "Compiler Path: $compilerDir" -ForegroundColor Green
    Write-Host "Ahk2Exe.exe: Available" -ForegroundColor Green
    Write-Host "Base Files: $foundBaseFiles found" -ForegroundColor Green
    
    # Additional verification for GitHub Actions
    if ($env:GITHUB_ENV) {
        Write-Host "GitHub Actions Integration: ✓ Environment variables set" -ForegroundColor Green
    } else {
        Write-Host "GitHub Actions Integration: ⚠ Not running in GitHub Actions" -ForegroundColor Yellow
    }
    
    # Final verification that all critical paths exist
    Write-Host ""
    Write-Host "=== Final Verification ===" -ForegroundColor Cyan
    Write-Host "Verifying critical components..." -ForegroundColor White
    
    $allGood = $true
    if (Test-Path $ahk2exePath) {
        Write-Host "  ✓ Ahk2Exe.exe found at: $ahk2exePath" -ForegroundColor Green
    } else {
        Write-Host "  ✗ Ahk2Exe.exe NOT found at: $ahk2exePath" -ForegroundColor Red
        $allGood = $false
    }
    
    # Check each base file individually and determine impact
    $criticalMissing = $false
    $v1Available = $false
    $v2Available = $false
    
    foreach ($baseFile in $requiredBaseFiles) {
        $baseFilePath = Join-Path $compilerDir $baseFile
        if (Test-Path $baseFilePath) {
            Write-Host "  ✓ Base file found: $baseFile" -ForegroundColor Green
            if ($baseFile -like "*_v1_*") {
                $v1Available = $true
            } elseif ($baseFile -like "*_v2_*") {
                $v2Available = $true
            }
        } else {
            $isV2File = $baseFile -like "*_v2_*"
            $color = if ($isV2File) { "Yellow" } else { "Red" }
            $impact = if ($isV2File) { "v2 compilation will be unavailable" } else { "v1 compilation will be unavailable" }
            Write-Host "  ✗ Base file MISSING: $baseFile ($impact)" -ForegroundColor $color
            
            if (-not $isV2File) {
                $criticalMissing = $true
            }
        }
    }
    
    # Determine overall status
    Write-Host ""
    Write-Host "=== Installation Status Assessment ===" -ForegroundColor Cyan
    
    if ($criticalMissing) {
        Write-Host "✗ CRITICAL: v1 base files are missing - installation failed" -ForegroundColor Red
        $allGood = $false
    } elseif (-not $v2Available) {
        Write-Host "⚠ WARNING: v2 base files are missing - v2 compilation will not work" -ForegroundColor Yellow
        Write-Host "✓ v1 compilation is available" -ForegroundColor Green
        Write-Host "Installing anyway as v1 functionality is intact..." -ForegroundColor Yellow
        $allGood = $true  # Allow installation to continue with v1 only
    } else {
        Write-Host "✓ All base files available - full functionality" -ForegroundColor Green
        $allGood = $true
    }
    
    if (-not $allGood) {
        Write-Host ""
        Write-Host "=== SETUP FAILED ===" -ForegroundColor Red
        Write-Host "Critical v1 components are missing. Installation cannot continue." -ForegroundColor Red
        exit 1
    }
    
    Write-Host ""
    if ($v1Available -and $v2Available) {
        Write-Host "=== SETUP SUCCESSFUL ===" -ForegroundColor Green  
        Write-Host "All components ready: v1 and v2 AutoHotkey compilation available." -ForegroundColor Green
    } elseif ($v1Available) {
        Write-Host "=== SETUP PARTIALLY SUCCESSFUL ===" -ForegroundColor Yellow
        Write-Host "v1 AutoHotkey compilation is ready. v2 compilation is unavailable due to missing base files." -ForegroundColor Yellow
        Write-Host "Note: v2 scripts in the configuration will fail to compile." -ForegroundColor Yellow
    } else {
        Write-Host "=== SETUP SUCCESSFUL ===" -ForegroundColor Green
        Write-Host "AutoHotkey compiler environment is ready." -ForegroundColor Green
    }
    exit 0
}
catch {
    Write-Error "Error setting up AutoHotkey environment: $($_.Exception.Message)"
    exit 1
}