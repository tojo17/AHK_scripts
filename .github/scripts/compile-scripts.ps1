# Compile AutoHotkey Scripts
# This script uses Ahk2Exe compiler to compile both v1 and v2 scripts
# It automatically selects the appropriate base file based on script version and architecture
# Supports dependency files (DLLs, etc.) that are automatically copied to output directories

param(
    [string]$ConfigFile = "scripts-to-compile.yml",
    [string]$OutputBaseDir = "compiled"
)

Write-Host "=== AutoHotkey Script Compilation Setup ===" -ForegroundColor Magenta

# Step 1: Create output directory structure
Write-Host "Creating output directory structure..." -ForegroundColor Cyan
$outputDirs = @("$OutputBaseDir/x86", "$OutputBaseDir/x64")
foreach ($dir in $outputDirs) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    Write-Host "  ✓ Created directory: $dir" -ForegroundColor Green
}

# Step 2: Generate build timestamp
Write-Host "Generating build timestamp..." -ForegroundColor Cyan
$timestamp = Get-Date -Format "yyyyMMddHHmmss"
Write-Host "  ✓ Generated timestamp: $timestamp" -ForegroundColor Green

# Set step output for GitHub Actions
if ($env:GITHUB_OUTPUT) {
    # Set as step output for immediate use in workflow
    Add-Content -Path $env:GITHUB_OUTPUT -Value "build-timestamp=$timestamp" -Encoding UTF8
    Write-Host "  ✓ Build timestamp step output set" -ForegroundColor Green
} else {
    Write-Host "  ⚠ Not in GitHub Actions context - build timestamp: $timestamp" -ForegroundColor Yellow
}

# Step 3: Install and import required modules
Write-Host "Setting up PowerShell modules..." -ForegroundColor Cyan
try {
    # Try to import the module first
    Import-Module powershell-yaml -ErrorAction Stop
    Write-Host "  ✓ PowerShell-Yaml module already available" -ForegroundColor Green
}
catch {
    Write-Host "  Installing PowerShell-Yaml module..." -ForegroundColor White
    try {
        Install-Module -Name powershell-yaml -Force -Scope CurrentUser -ErrorAction Stop
        Import-Module powershell-yaml -ErrorAction Stop
        Write-Host "  ✓ PowerShell-Yaml module installed and imported successfully" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to install or import PowerShell-Yaml module: $($_.Exception.Message)"
        Write-Host "Please manually install the module with: Install-Module -Name powershell-yaml -Force" -ForegroundColor Yellow
        exit 1
    }
}

# Step 4: Verify configuration file exists
Write-Host "Verifying configuration..." -ForegroundColor Cyan
if (-not (Test-Path $ConfigFile)) {
    Write-Error "Configuration file not found: $ConfigFile"
    exit 1
}
Write-Host "  ✓ Configuration file found: $ConfigFile" -ForegroundColor Green

Write-Host ""
Write-Host "=== AutoHotkey Script Compilation Process ===" -ForegroundColor Magenta

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
    
    # Extract and parse script arrays (supporting mixed string/object format)
    $v1Scripts = @()
    $v2Scripts = @()
    
    # Function to parse script configuration (string or object format)
    function Parse-ScriptConfig {
        param($scriptConfig)
        
        if ($scriptConfig -is [string]) {
            # Simple string format - no dependencies
            return @{
                Script = $scriptConfig
                Dependencies = @()
            }
        } elseif ($scriptConfig -is [hashtable] -and $scriptConfig.ContainsKey("path")) {
            # Object format with path and optional deps
            $deps = @()
            if ($scriptConfig.ContainsKey("deps")) {
                if ($scriptConfig.deps -is [array]) {
                    $deps = $scriptConfig.deps
                } elseif ($scriptConfig.deps -is [string]) {
                    $deps = @($scriptConfig.deps)
                }
            }
            return @{
                Script = $scriptConfig.path
                Dependencies = $deps
            }
        } else {
            throw "Invalid script configuration format. Expected string or object with 'path' field."
        }
    }
    
    if ($config.ContainsKey("ahk_v1") -and $config.ahk_v1) {
        foreach ($scriptConfig in $config.ahk_v1) {
            $v1Scripts += Parse-ScriptConfig -scriptConfig $scriptConfig
        }
        Write-Host "Found $($v1Scripts.Count) v1 scripts" -ForegroundColor Green
    }
    
    if ($config.ContainsKey("ahk_v2") -and $config.ahk_v2) {
        foreach ($scriptConfig in $config.ahk_v2) {
            $v2Scripts += Parse-ScriptConfig -scriptConfig $scriptConfig
        }
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
    
    # Function to copy dependency files
    function Copy-Dependencies {
        param($dependencies, $outputDir)
        
        foreach ($depPath in $dependencies) {
            if (Test-Path $depPath) {
                $depFileName = Split-Path $depPath -Leaf
                $destPath = Join-Path $outputDir $depFileName
                try {
                    Copy-Item -Path $depPath -Destination $destPath -Force
                    Write-Host "  ✓ Copied dependency: $depFileName" -ForegroundColor Green
                } catch {
                    Write-Host "  ✗ Failed to copy dependency: $depPath - $($_.Exception.Message)" -ForegroundColor Red
                }
            } else {
                Write-Host "  ✗ Dependency not found: $depPath" -ForegroundColor Red
            }
        }
    }
    
    # Function to compile script  
    function Compile-Script {
        param($scriptPath, $version, $arch, $dependencies = @())
        
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
            
            # Execute compilation with timeout protection
            $tempOutput = Join-Path $env:TEMP "compile_output_$(Get-Random).txt"
            $tempError = Join-Path $env:TEMP "compile_error_$(Get-Random).txt"
            
            # Start process without -Wait to enable timeout control
            $process = Start-Process -FilePath $compilerPath -ArgumentList $arguments -PassThru -NoNewWindow -RedirectStandardOutput $tempOutput -RedirectStandardError $tempError
            
            # Wait for process with timeout (5 minutes max per compilation)
            $timeoutSeconds = 300
            $waitResult = $process.WaitForExit($timeoutSeconds * 1000)
            
            if (-not $waitResult) {
                # Process timed out - force kill it
                Write-Host "  ⚠ Compilation timed out after $timeoutSeconds seconds - terminating process" -ForegroundColor Yellow
                try {
                    $process.Kill()
                    $process.WaitForExit(5000)  # Wait up to 5 seconds for cleanup
                }
                catch {
                    Write-Host "  ⚠ Failed to terminate process cleanly: $($_.Exception.Message)" -ForegroundColor Yellow
                }
                
                Write-Host "✗ ERROR: Compilation timed out for $scriptPath [$version-$arch]" -ForegroundColor Red
                return $false
            }
            
            if ($process.ExitCode -eq 0 -and (Test-Path $outputPath)) {
                Write-Host "✓ SUCCESS: Compiled $scriptPath [$version-$arch]" -ForegroundColor Green
                
                # Copy dependencies if any
                if ($dependencies.Count -gt 0) {
                    Write-Host "  Copying dependencies..." -ForegroundColor Cyan
                    Copy-Dependencies -dependencies $dependencies -outputDir $outputDir
                }
                
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
                    $outputContent = Get-Content $tempOutput -Raw -ErrorAction SilentlyContinue
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
            # Clean up temp files and ensure process is terminated
            try {
                if ($process -and -not $process.HasExited) {
                    Write-Host "  ⚠ Forcefully terminating lingering process" -ForegroundColor Yellow
                    $process.Kill()
                    $process.WaitForExit(2000)
                }
            }
            catch {
                Write-Host "  ⚠ Error during process cleanup: $($_.Exception.Message)" -ForegroundColor Yellow
            }
            
            # Clean up temp files
            try {
                if (Test-Path $tempOutput) { Remove-Item $tempOutput -Force -ErrorAction SilentlyContinue }
                if (Test-Path $tempError) { Remove-Item $tempError -Force -ErrorAction SilentlyContinue }
            }
            catch {
                Write-Host "  ⚠ Failed to clean temp files: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }
    }
    
    # Compile all scripts
    $allScripts = @()
    
    # Add v1 scripts
    foreach ($scriptInfo in $v1Scripts) {
        $allScripts += @{ 
            Script = $scriptInfo.Script
            Version = "v1"
            Dependencies = $scriptInfo.Dependencies
        }
    }
    
    # Add v2 scripts
    foreach ($scriptInfo in $v2Scripts) {
        $allScripts += @{ 
            Script = $scriptInfo.Script
            Version = "v2" 
            Dependencies = $scriptInfo.Dependencies
        }
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
        $depCount = $scriptInfo.Dependencies.Count
        
        $depText = if ($depCount -gt 0) { " with $depCount dependencies" } else { "" }
        Write-Host "Processing: $script ($version)$depText" -ForegroundColor White
        
        # Compile for x86
        if (Compile-Script -scriptPath $script -version $version -arch "x86" -dependencies $scriptInfo.Dependencies) {
            $totalSuccess++
        } else {
            $totalFail++
        }
        
        # Compile for x64
        if (Compile-Script -scriptPath $script -version $version -arch "x64" -dependencies $scriptInfo.Dependencies) {
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