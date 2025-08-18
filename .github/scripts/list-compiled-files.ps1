# List Compiled Files
# This script lists all compiled executable files and provides a summary

param(
    [string]$CompiledDir = "compiled"
)

Write-Host "=== Compiled Executable Files ===" -ForegroundColor Magenta

if (-not (Test-Path $CompiledDir)) {
    Write-Host "  No compiled directory found at: $CompiledDir" -ForegroundColor Yellow
    exit 0
}

try {
    $archs = @("x86", "x64")
    $totalFileCount = 0
    $totalSizeKB = 0
    
    foreach ($arch in $archs) {
        $archPath = Join-Path $CompiledDir $arch
        
        if (Test-Path $archPath) {
            $files = Get-ChildItem -Recurse $archPath -Include "*.exe"
            
            if ($files.Count -gt 0) {
                Write-Host ""
                Write-Host "[$arch] ($($files.Count) files):" -ForegroundColor Cyan
                
                $sectionSizeKB = 0
                $files | Sort-Object Name | ForEach-Object {
                    $sizeKB = [math]::Round($_.Length / 1KB, 2)
                    $sectionSizeKB += $sizeKB
                    
                    # Get relative path from current directory
                    $relativePath = $_.FullName.Replace((Get-Location).Path + "\", "")
                    Write-Host "  $relativePath ($sizeKB KB)" -ForegroundColor White
                }
                
                Write-Host "  Section total: $([math]::Round($sectionSizeKB, 2)) KB" -ForegroundColor Gray
                $totalSizeKB += $sectionSizeKB
                $totalFileCount += $files.Count
            }
        }
    }
    
    Write-Host ""
    Write-Host "=== Summary ===" -ForegroundColor Magenta
    Write-Host "  Total compiled executables: $totalFileCount" -ForegroundColor Green
    Write-Host "  Total size: $([math]::Round($totalSizeKB, 2)) KB ($([math]::Round($totalSizeKB / 1024, 2)) MB)" -ForegroundColor Green
    
    if ($totalFileCount -eq 0) {
        Write-Host "  No executable files found in compiled directory" -ForegroundColor Yellow
        exit 1
    }
    
    # Set environment variable for GitHub Actions if available
    if ($env:GITHUB_ENV) {
        Write-Host "COMPILED_FILE_COUNT=$totalFileCount" | Out-File -FilePath $env:GITHUB_ENV -Encoding utf8 -Append
        Write-Host "COMPILED_TOTAL_SIZE_KB=$([math]::Round($totalSizeKB, 2))" | Out-File -FilePath $env:GITHUB_ENV -Encoding utf8 -Append
    }
    
    exit 0
}
catch {
    Write-Error "Error listing compiled files: $($_.Exception.Message)"
    exit 1
}