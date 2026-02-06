@echo off
setlocal

REM Check if repo_config.json exists
if not exist "repo_config.json" (
    echo Error: repo_config.json not found.
    pause
    exit /b 1
)

echo Starting auto-merge process...
echo.

REM Delegate logic to PowerShell to handle JSON parsing natively
powershell -NoProfile -ExecutionPolicy Bypass -Command "& {
    $configPath = 'repo_config.json';
    try {
        $jsonContent = Get-Content -Raw -Path $configPath;
        $repos = ConvertFrom-Json $jsonContent;
    } catch {
        Write-Host 'Error reading or parsing repo_config.json' -ForegroundColor Red;
        exit 1;
    }

    $rootDir = Get-Location;

    foreach ($repo in $repos) {
        $path = $repo.path;
        $enabled = $repo.enabled;

        if (-not $enabled) {
            Write-Host 'Skipping' $path '(disabled)' -ForegroundColor DarkGray;
            continue;
        }

        $fullPath = Join-Path $rootDir $path;

        if (-not (Test-Path $fullPath -PathType Container)) {
            Write-Host 'Warning: Directory' $path 'does not exist. Skipping.' -ForegroundColor Yellow;
            continue;
        }

        Write-Host \"`nProcessing $path...\" -ForegroundColor Cyan;
        
        # Store current location so we can easily return (though Push-Location implies it)
        Push-Location $fullPath;

        try {
            # 1. Get current branch name
            $currentBranch = git rev-parse --abbrev-ref HEAD;
            if ($LASTEXITCODE -ne 0) { throw 'Git error getting branch name'; }
            
            Write-Host \"  Current branch: $currentBranch\";

            if ($currentBranch -eq 'main') {
                Write-Host '  Already on main branch. Nothing to merge into main.' -ForegroundColor Yellow;
            } else {
                # 2. Checkout main
                Write-Host '  Checking out main...';
                git checkout main | Out-Null;
                if ($LASTEXITCODE -ne 0) { throw 'Git checkout main failed'; }

                # 3. Merge saved branch into main
                Write-Host \"  Merging $currentBranch into main...\";
                git merge $currentBranch;
                if ($LASTEXITCODE -ne 0) { throw 'Git merge failed'; }
                
                Write-Host \"  Successfully merged $currentBranch into main in $path.\" -ForegroundColor Green;
            }
        } catch {
            Write-Host \"  Failed to process $path. Error: $_\" -ForegroundColor Red;
        } finally {
            Pop-Location;
        }
    }
}"

echo.
echo Process complete.
pause
