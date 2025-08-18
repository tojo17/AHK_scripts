# Compile AutoHotkey Scripts
# This script uses Ahk2Exe compiler to compile both v1 and v2 scripts
# It automatically selects the appropriate base file based on script version and architecture

param(
    [string]$ConfigFile = "scripts-to-compile.yml",
    [string]$OutputBaseDir = "compiled"
)

# Import required modules
try {
    Import-Module powershell-yaml -ErrorAction Stop
}
catch {
    Write-Error "PowerShell-Yaml module is required. Please run: Install-Module -Name powershell-yaml -Force"
    exit 1
}

# Verify configuration file exists
if (-not (Test-Path $ConfigFile)) {
    Write-Error "Configuration file not found: $ConfigFile"
    exit 1
}

Write-Host "=== AutoHotkey Script Compilation ===" -ForegroundColor Magenta
Write-Host "Reading YAML configuration from: $ConfigFile"

try {
    # Verify compiler environment
    if (-not $env:AHK_COMPILER_PATH) {
        Write-Error "AHK_COMPILER_PATH environment variable not found. Please run install-ahk.ps1 first."
        exit 1
    }
    
    $compilerPath = Join-Path $env:AHK_COMPILER_PATH "Ahk2Exe.exe"
    if (-not (Test-Path $compilerPath)) {
        Write-Error "Compiler not found at: $compilerPath"
        exit 1
    }
    
    Write-Host "Using compiler: $compilerPath" -ForegroundColor Green
    
    # Read and parse YAML configuration
    $yamlContent = Get-Content $ConfigFile -Raw
    $config = ConvertFrom-Yaml $yamlContent
    
    # Extract script arrays
    $v1Scripts = @()
    $v2Scripts = @()
    
    if ($config.ContainsKey("ahk_v1") -and $config.ahk_v1) {
        $v1Scripts = $config.ahk_v1
        Write-Host "Found $($v1Scripts.Count) v1 scripts" -ForegroundColor Green
    }
    
    if ($config.ContainsKey("ahk_v2") -and $config.ahk_v2) {
        $v2Scripts = $config.ahk_v2
        Write-Host "Found $($v2Scripts.Count) v2 scripts" -ForegroundColor Green
    }
    
    Write-Host "Total: $($v1Scripts.Count) v1 scripts and $($v2Scripts.Count) v2 scripts"
    
    # Initialize counters
    $totalSuccess = 0
    $totalFail = 0
    
    # Function to get base file path for compilation
    function Get-BaseFilePath {
        param($version, $arch)
        
        $baseFileName = switch ("$version-$arch") {
            "v1-x86" { "AutoHotkey_v1_Unicode32.bin" }
            "v1-x64" { "AutoHotkey_v1_Unicode64.bin" }
            "v2-x86" { "AutoHotkey_v2_Unicode32.exe" }
            "v2-x64" { "AutoHotkey_v2_Unicode64.exe" }
            default { throw "Unknown version-arch combination: $version-$arch" }
        }
        
        $baseFilePath = Join-Path $env:AHK_COMPILER_PATH $baseFileName
        if (-not (Test-Path $baseFilePath)) {
            $errorMsg = "Base file not found: $baseFilePath"
            
            # For v2 files, provide more helpful error message
            if ($version -eq "v2") {
                $errorMsg += "`nThis likely means AutoHotkey v2 base files were not properly downloaded during installation."
                $errorMsg += "`nv2 script compilation is not available. Only v1 scripts can be compiled."
            }
            
            throw $errorMsg
        }
        
        return $baseFilePath
    }
    
    # Function to compile script  
    function Compile-Script {
        param($scriptPath, $version, $arch)
        
        if (-not (Test-Path $scriptPath)) {
            Write-Host "ERROR: Script not found: $scriptPath" -ForegroundColor Red
            return $false
        }
        
        # Get script info
        $scriptDir = Split-Path $scriptPath -Parent
        $scriptName = Split-Path $scriptPath -LeafBase
        
        # Create output directory structure
        $outputDir = Join-Path $OutputBaseDir $arch
        New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
        
        # Generate output path with version and arch suffix
        $outputPath = Join-Path $outputDir "$scriptName-$version-$arch.exe"
        
        Write-Host "Compiling [$version-$arch]: $scriptPath -> $outputPath" -ForegroundColor Cyan
        
        try {
            # Get appropriate base file
            $baseFilePath = Get-BaseFilePath -version $version -arch $arch
            Write-Host "  Using base file: $(Split-Path $baseFilePath -Leaf)" -ForegroundColor Gray
            
            # Build arguments for Ahk2Exe
            $arguments = @(
                "/in", "`"$scriptPath`""
                "/out", "`"$outputPath`""
                "/base", "`"$baseFilePath`""
            )
            
            # Execute compilation
            $tempOutput = Join-Path $env:TEMP "compile_output_$(Get-Random).txt"
            $tempError = Join-Path $env:TEMP "compile_error_$(Get-Random).txt"
            
            $process = Start-Process -FilePath $compilerPath -ArgumentList $arguments -Wait -PassThru -NoNewWindow -RedirectStandardOutput $tempOutput -RedirectStandardError $tempError
            
            if ($process.ExitCode -eq 0 -and (Test-Path $outputPath)) {
                Write-Host "✓ SUCCESS: Compiled $scriptPath [$version-$arch]" -ForegroundColor Green
                return $true
            } else {
                Write-Host "✗ ERROR: Failed to compile $scriptPath [$version-$arch] (Exit code: $($process.ExitCode))" -ForegroundColor Red
                
                # Display error output if available
                if (Test-Path $tempError) {
                    $errorContent = Get-Content $tempError -Raw -ErrorAction SilentlyContinue
                    if ($errorContent -and $errorContent.Trim()) { 
                        Write-Host "  Error output: $errorContent" -ForegroundColor Yellow
                    }
                }
                
                # Display standard output for additional context
                if (Test-Path $tempOutput) {
                    $outputContent = Get-Content $tempOutput -Raw -ErrorAction SilentlyContinuous
                    if ($outputContent -and $outputContent.Trim()) {
                        Write-Host "  Compiler output: $outputContent" -ForegroundColor Yellow
                    }
                }
                
                return $false
            }
        }
        catch {
            Write-Host "✗ ERROR: Exception while compiling $scriptPath [$version-$arch]: $($_.Exception.Message)" -ForegroundColor Red
            return $false
        }
        finally {
            # Clean up temp files
            Remove-Item $tempOutput -ErrorAction SilentlyContinue
            Remove-Item $tempError -ErrorAction SilentlyContinue
        }
    }
    
    # Compile all scripts
    $allScripts = @()
    
    # Add v1 scripts
    foreach ($script in $v1Scripts) {
        $allScripts += @{ Script = $script; Version = "v1" }
    }
    
    # Add v2 scripts
    foreach ($script in $v2Scripts) {
        $allScripts += @{ Script = $script; Version = "v2" }
    }
    
    if ($allScripts.Count -eq 0) {
        Write-Host "No scripts found to compile." -ForegroundColor Yellow
        exit 0
    }
    
    Write-Host ""
    Write-Host "=== Starting Compilation Process ===" -ForegroundColor Magenta
    Write-Host "Total scripts to compile: $($allScripts.Count)"
    Write-Host "Architectures: x86, x64"
    Write-Host "Total compilation tasks: $($allScripts.Count * 2)"
    Write-Host ""
    
    # Compile each script for both architectures
    foreach ($scriptInfo in $allScripts) {
        $script = $scriptInfo.Script
        $version = $scriptInfo.Version
        
        Write-Host "Processing: $script ($version)" -ForegroundColor White
        
        # Compile for x86
        if (Compile-Script -scriptPath $script -version $version -arch "x86") {
            $totalSuccess++
        } else {
            $totalFail++
        }
        
        # Compile for x64
        if (Compile-Script -scriptPath $script -version $version -arch "x64") {
            $totalSuccess++
        } else {
            $totalFail++
        }
        
        Write-Host ""
    }
    
    # Summary
    Write-Host ""
    Write-Host "=== Compilation Summary ===" -ForegroundColor Magenta
    Write-Host "  Success: $totalSuccess" -ForegroundColor Green
    Write-Host "  Failed: $totalFail" -ForegroundColor Red
    Write-Host "  Total: $($totalSuccess + $totalFail)"
    
    $successRate = if (($totalSuccess + $totalFail) -gt 0) { 
        [math]::Round(($totalSuccess / ($totalSuccess + $totalFail)) * 100, 1) 
    } else { 0 }
    Write-Host "  Success Rate: $successRate%" -ForegroundColor $(if ($successRate -ge 90) { "Green" } elseif ($successRate -ge 70) { "Yellow" } else { "Red" })
    
    if ($totalFail -gt 0) {
        Write-Host "::warning::$totalFail compilation tasks failed"
    }
    
    # Set environment variables for GitHub Actions
    if ($env:GITHUB_ENV) {
        Write-Host "SUCCESS_COUNT=$totalSuccess" | Out-File -FilePath $env:GITHUB_ENV -Encoding utf8 -Append
        Write-Host "FAIL_COUNT=$totalFail" | Out-File -FilePath $env:GITHUB_ENV -Encoding utf8 -Append
        Write-Host "SUCCESS_RATE=$successRate" | Out-File -FilePath $env:GITHUB_ENV -Encoding utf8 -Append
    }
    
    # Exit with appropriate code
    if ($totalFail -gt 0) {
        exit 1
    } else {
        exit 0
    }
}
catch {
    Write-Error "Error during compilation process: $($_.Exception.Message)"
    exit 1
}