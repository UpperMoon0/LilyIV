<# :
@echo off
setlocal
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -Command "Invoke-Expression ($(Get-Content '%~f0' | Out-String))"
exit /b
#>

# PowerShell logic starts here
$configPath = 'repo_config.json'

if (-not (Test-Path $configPath)) {
    Write-Host "Error: repo_config.json not found." -ForegroundColor Red
    exit 1
}

try {
    $jsonContent = Get-Content -Raw -Path $configPath
    $repos = ConvertFrom-Json $jsonContent
} catch {
    Write-Host "Error reading or parsing repo_config.json" -ForegroundColor Red
    exit 1
}

$rootDir = Get-Location

foreach ($repo in $repos) {
    $path = $repo.path
    $enabled = $repo.enabled

    if (-not $enabled) {
        Write-Host "Skipping $path (disabled)" -ForegroundColor DarkGray
        continue
    }

    $fullPath = Join-Path $rootDir $path

    if (-not (Test-Path $fullPath -PathType Container)) {
        Write-Host "Warning: Directory $path does not exist. Skipping." -ForegroundColor Yellow
        continue
    }

    Write-Host "`nProcessing $path..." -ForegroundColor Cyan
    
    # Store current location
    Push-Location $fullPath

    try {
        # 1. Get current branch name
        $currentBranch = git rev-parse --abbrev-ref HEAD
        if ($LASTEXITCODE -ne 0) { throw "Git error getting branch name" }
        
        Write-Host "  Current branch: $currentBranch"

        if ($currentBranch -eq 'main') {
            Write-Host "  Already on main branch. Nothing to merge into main." -ForegroundColor Yellow
        } else {
            # 2. Checkout main
            Write-Host "  Checking out main..."
            git checkout main | Out-Null
            if ($LASTEXITCODE -ne 0) { throw "Git checkout main failed" }

            # 3. Merge saved branch into main
            Write-Host "  Merging $currentBranch into main..."
            git merge $currentBranch
            if ($LASTEXITCODE -ne 0) { throw "Git merge failed" }
            
            Write-Host "  Successfully merged $currentBranch into main in $path." -ForegroundColor Green
        }
    } catch {
        Write-Host "  Failed to process $path. Error: $_" -ForegroundColor Red
    } finally {
        Pop-Location
    }
}

Write-Host "`nProcess complete." -ForegroundColor Green
# Pause to let user see output if double-clicked
Start-Sleep -Seconds 3
