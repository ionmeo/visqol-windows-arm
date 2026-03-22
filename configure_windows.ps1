function Find-Bash {
    $commonPaths = @(
        "$env:ProgramFiles\Git\bin\bash.exe",
        "${env:ProgramFiles(x86)}\Git\bin\bash.exe",
        "C:\msys64\usr\bin\bash.exe",
        "C:\cygwin64\bin\bash.exe"
    )
    foreach ($path in $commonPaths) {
        if (Test-Path $path) { return $path }
    }

    # Fallback to PATH lookup (but skip WSL bash)
    $bashPath = (Get-Command bash -ErrorAction SilentlyContinue).Source
    if ($bashPath -and $bashPath -notmatch "system32") { return $bashPath }

    return $null
}

function Find-Python {
    $pythonPath = (Get-Command python -ErrorAction SilentlyContinue).Source
    if ($pythonPath) { return $pythonPath }

    try {
        $pyOutput = & py -c "import sys; print(sys.executable)" 2>$null
        if ($pyOutput -and (Test-Path $pyOutput)) { return $pyOutput }
    } catch {}

    return $null
}

Write-Host "Looking for bash and python..." -ForegroundColor Cyan

$bashPath = Find-Bash
$pythonPath = Find-Python

$missing = 0

if ($bashPath) {
    Write-Host "  Found bash: $bashPath" -ForegroundColor Green
} else {
    Write-Host "  bash.exe not found" -ForegroundColor Red
    $missing++
}

if ($pythonPath) {
    Write-Host "  Found python: $pythonPath" -ForegroundColor Green
} else {
    Write-Host "  python.exe not found" -ForegroundColor Red
    $missing++
}

if ($missing -gt 0) { exit 1 }

# Convert to forward slashes for Bazel
$bashPath = $bashPath -replace '\\', '/'
$pythonPath = $pythonPath -replace '\\', '/'

$bazelrcContent = @"
# Fixes "Configuration Error: --define PYTHON_BIN_PATH='C:/path/python.exe' is not executable. Is it the python binary?"
build:windows --action_env=BAZEL_SH="$bashPath"
build:windows --repo_env=PYTHON_BIN_PATH="$pythonPath"

# Fixes "<3>WSL (11) ERROR: CreateProcessCommon:559: execvpe(/bin/bash) failed: No such file or directory"
# Error caused by WSL bash (C:\Windows\system32\bash.exe) being used instead of Git bash
build:windows --shell_executable="$bashPath"
"@

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$bazelrcPath = Join-Path $scriptDir ".bazelrc.user"

Set-Content -Path $bazelrcPath -Value $bazelrcContent -Encoding UTF8

Write-Host "`nCreated $bazelrcPath" -ForegroundColor Green
