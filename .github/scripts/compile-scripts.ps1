# Compile AutoHotkey Scripts
# This script parses YAML configuration and compiles AutoHotkey scripts for both v1 and v2

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

Write-Host "Reading YAML configuration from: $ConfigFile"

try {
    # Read and parse YAML configuration
    $yamlContent = Get-Content $ConfigFile -Raw
    $config = ConvertFrom-Yaml $yamlContent
    
    # Extract script arrays
    $v1Scripts = @()
    $v2Scripts = @()
    
    if ($config.ContainsKey("ahk_v1") -and $config.ahk_v1) {
        $v1Scripts = $config.ahk_v1
        Write-Host "Found $($v1Scripts.Count) v1 scripts"
    }
    
    if ($config.ContainsKey("ahk_v2") -and $config.ahk_v2) {
        $v2Scripts = $config.ahk_v2
        Write-Host "Found $($v2Scripts.Count) v2 scripts"
    }
    
    Write-Host "Total: $($v1Scripts.Count) v1 scripts and $($v2Scripts.Count) v2 scripts"
    
    # Initialize counters
    $totalSuccess = 0
    $totalFail = 0
    
    # Function to compile script with specific version and architecture
    function Compile-Script {
        param($scriptPath, $version, $arch, $compilerPath)
        
        if (-not (Test-Path $scriptPath)) {
            Write-Host "ERROR: Script not found: $scriptPath" -ForegroundColor Red
            return $false
        }
        
        # Get script info
        $scriptDir = Split-Path $scriptPath -Parent
        $scriptName = Split-Path $scriptPath -LeafBase
        
        # Create output directory structure
        $outputDir = Join-Path $OutputBaseDir "$version/$arch"
        if ($scriptDir) {
            $outputDir = Join-Path $outputDir $scriptDir
            New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
        }
        
        # Generate output path with arch suffix
        $archSuffix = if ($arch -eq "x64") { "_x64" } else { "_x86" }
        $outputPath = Join-Path $outputDir "$scriptName$archSuffix.exe"
        
        Write-Host "Compiling [$version-$arch]: $scriptPath -> $outputPath" -ForegroundColor Cyan
        
        try {
            $arguments = @(
                "/in", "`"$scriptPath`""
                "/out", "`"$outputPath`""
            )
            
            # Add architecture-specific arguments for v1
            if ($version -eq "v1") {
                if ($arch -eq "x64") {
                    $binPath = Join-Path $env:AHK_V1_PATH "Compiler\Unicode 64-bit.bin"
                    $arguments += "/bin", "`"$binPath`""
                } else {
                    $binPath = Join-Path $env:AHK_V1_PATH "Compiler\Unicode 32-bit.bin"
                    $arguments += "/bin", "`"$binPath`""
                }
            }
            
            # Execute compilation
            $tempOutput = Join-Path $env:TEMP "compile_output.txt"
            $tempError = Join-Path $env:TEMP "compile_error.txt"
            
            $process = Start-Process -FilePath $compilerPath -ArgumentList $arguments -Wait -PassThru -NoNewWindow -RedirectStandardOutput $tempOutput -RedirectStandardError $tempError
            
            if ($process.ExitCode -eq 0 -and (Test-Path $outputPath)) {
                Write-Host "✓ SUCCESS: Compiled $scriptPath [$version-$arch]" -ForegroundColor Green
                return $true
            } else {
                Write-Host "✗ ERROR: Failed to compile $scriptPath [$version-$arch] (Exit code: $($process.ExitCode))" -ForegroundColor Red
                
                # Display error output if available
                if (Test-Path $tempError) {
                    $errorContent = Get-Content $tempError -Raw
                    if ($errorContent -and $errorContent.Trim()) { 
                        Write-Host "Error output: $errorContent" -ForegroundColor Yellow
                    }
                }
                return $false
            }
        }
        catch {
            Write-Host "✗ ERROR: Exception while compiling $scriptPath [$version-$arch]: $($_.Exception.Message)" -ForegroundColor Red
            return $false
        }
    }
    
    # Compile v1 scripts
    if ($v1Scripts.Count -gt 0) {
        Write-Host ""
        Write-Host "=== Compiling AutoHotkey v1 Scripts ===" -ForegroundColor Magenta
        
        $ahk2exe = Join-Path $env:AHK_V1_PATH "Ahk2Exe.exe"
        if (-not (Test-Path $ahk2exe)) {
            Write-Error "Ahk2Exe.exe not found at: $ahk2exe"
            $totalFail += ($v1Scripts.Count * 2)
        } else {
            Write-Host "Using compiler: $ahk2exe"
            
            foreach ($script in $v1Scripts) {
                # Compile both 32-bit and 64-bit versions
                if (Compile-Script -scriptPath $script -version "v1" -arch "x86" -compilerPath $ahk2exe) {
                    $totalSuccess++
                } else {
                    $totalFail++
                }
                
                if (Compile-Script -scriptPath $script -version "v1" -arch "x64" -compilerPath $ahk2exe) {
                    $totalSuccess++
                } else {
                    $totalFail++
                }
            }
        }
    }
    
    # Compile v2 scripts
    if ($v2Scripts.Count -gt 0) {
        Write-Host ""
        Write-Host "=== Compiling AutoHotkey v2 Scripts ===" -ForegroundColor Magenta
        
        # For v2, find suitable compiler
        $ahk2exeV2 = $null
        $possibleCompilers = @(
            (Join-Path $env:AHK_V2_PATH "Ahk2Exe.exe"),
            (Join-Path $env:AHK_V1_PATH "Ahk2Exe.exe")  # v1 compiler can compile v2 scripts too
        )
        
        foreach ($compiler in $possibleCompilers) {
            if (Test-Path $compiler) {
                $ahk2exeV2 = $compiler
                Write-Host "Using compiler: $ahk2exeV2"
                break
            }
        }
        
        if (-not $ahk2exeV2) {
            Write-Error "No suitable compiler found for v2 scripts"
            $totalFail += ($v2Scripts.Count * 2)
        } else {
            foreach ($script in $v2Scripts) {
                # Compile both architectures for v2
                if (Compile-Script -scriptPath $script -version "v2" -arch "x86" -compilerPath $ahk2exeV2) {
                    $totalSuccess++
                } else {
                    $totalFail++
                }
                
                if (Compile-Script -scriptPath $script -version "v2" -arch "x64" -compilerPath $ahk2exeV2) {
                    $totalSuccess++
                } else {
                    $totalFail++
                }
            }
        }
    }
    
    # Summary
    Write-Host ""
    Write-Host "=== Compilation Summary ===" -ForegroundColor Magenta
    Write-Host "  Success: $totalSuccess" -ForegroundColor Green
    Write-Host "  Failed: $totalFail" -ForegroundColor Red
    Write-Host "  Total: $($totalSuccess + $totalFail)"
    
    if ($totalFail -gt 0) {
        Write-Host "::warning::Some scripts failed to compile"
    }
    
    # Set environment variables for GitHub Actions
    if ($env:GITHUB_ENV) {
        Write-Host "SUCCESS_COUNT=$totalSuccess" | Out-File -FilePath $env:GITHUB_ENV -Encoding utf8 -Append
        Write-Host "FAIL_COUNT=$totalFail" | Out-File -FilePath $env:GITHUB_ENV -Encoding utf8 -Append
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