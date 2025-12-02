# Vector Studio - Automated Setup Script (Windows PowerShell)
# Run with: .\setup.ps1
# Requires: Python 3.10-3.13 (for ONNX Runtime compatibility)
# Auto-installs Python 3.12, CMake, Ninja, VS Build Tools via winget if needed

Write-Host ""
Write-Host "========================================" -ForegroundColor Yellow
Write-Host "   Vector Studio - Automated Setup" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow
Write-Host ""

# ============================================================================
# Helper Functions
# ============================================================================

function Test-Winget {
    try {
        $null = Get-Command winget -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

function Refresh-Path {
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
}

function Install-Python312 {
    Write-Host "      Installing Python 3.12 via winget..." -ForegroundColor Cyan
    try {
        winget install Python.Python.3.12 --accept-package-agreements --accept-source-agreements
        if ($LASTEXITCODE -eq 0) {
            Write-Host "      Python 3.12 installed successfully." -ForegroundColor Green
            Write-Host "      NOTE: You may need to restart your terminal for PATH changes." -ForegroundColor Yellow
            Refresh-Path
            return $true
        } else {
            Write-Host "      WARNING: winget install returned non-zero exit code." -ForegroundColor Yellow
            return $false
        }
    } catch {
        Write-Host "      ERROR: Failed to install Python via winget." -ForegroundColor Red
        return $false
    }
}

function Install-CMake {
    Write-Host "      Installing CMake via winget..." -ForegroundColor Cyan
    try {
        winget install Kitware.CMake --accept-package-agreements --accept-source-agreements
        if ($LASTEXITCODE -eq 0) {
            Write-Host "      CMake installed successfully." -ForegroundColor Green
            Refresh-Path
            return $true
        }
    } catch {}
    Write-Host "      WARNING: Failed to install CMake." -ForegroundColor Yellow
    return $false
}

function Install-Ninja {
    Write-Host "      Installing Ninja via winget..." -ForegroundColor Cyan
    try {
        winget install Ninja-build.Ninja --accept-package-agreements --accept-source-agreements
        if ($LASTEXITCODE -eq 0) {
            Write-Host "      Ninja installed successfully." -ForegroundColor Green
            Refresh-Path
            return $true
        }
    } catch {}
    Write-Host "      WARNING: Failed to install Ninja (optional)." -ForegroundColor Yellow
    return $false
}

function Install-VSBuildTools {
    Write-Host "      Installing Visual Studio Build Tools 2022..." -ForegroundColor Cyan
    try {
        winget install Microsoft.VisualStudio.2022.BuildTools --accept-package-agreements --accept-source-agreements
        if ($LASTEXITCODE -eq 0) {
            Write-Host "      VS Build Tools installed." -ForegroundColor Green
            Write-Host "      NOTE: Run Visual Studio Installer to add C++ workload if needed." -ForegroundColor Yellow
            return $true
        }
    } catch {}
    Write-Host "      WARNING: Failed to install VS Build Tools." -ForegroundColor Yellow
    return $false
}

function Get-PythonCommand {
    # Priority: py launcher with 3.12 > 3.11 > 3.10 > 3.13 > generic python
    foreach ($ver in @("3.12", "3.11", "3.10", "3.13")) {
        try {
            $result = py "-$ver" --version 2>&1
            if ($result -match "Python $ver") {
                return "py -$ver"
            }
        } catch {}
    }
    
    # Try generic python
    try {
        $result = python --version 2>&1
        if ($result -match "Python 3\.1[0-3]") {
            return "python"
        }
    } catch {}
    
    return $null
}

function Test-VisualStudio {
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (Test-Path $vswhere) {
        $vsPath = & $vswhere -latest -property installationPath 2>$null
        if ($vsPath) { return $true }
    }
    $btPath = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\BuildTools"
    if (Test-Path $btPath) { return $true }
    return $false
}

# ============================================================================
# Main Setup Process
# ============================================================================

$totalSteps = 8

# Step 1: Check Python
Write-Host "[1/$totalSteps] Checking Python installation..." -ForegroundColor Cyan

$pythonCmd = Get-PythonCommand

if ($null -eq $pythonCmd) {
    Write-Host "      No compatible Python (3.10-3.13) found." -ForegroundColor Yellow
    
    if (Test-Winget) {
        Write-Host "      Attempting automatic installation..." -ForegroundColor Cyan
        if (Install-Python312) {
            Start-Sleep -Seconds 2
            $pythonCmd = Get-PythonCommand
            if ($null -eq $pythonCmd) {
                Write-Host "      Please restart your terminal and run this script again." -ForegroundColor Yellow
                exit 0
            }
        } else {
            Write-Host "      ERROR: Automatic installation failed." -ForegroundColor Red
            Write-Host "      Please install Python 3.12 manually:" -ForegroundColor Yellow
            Write-Host "        winget install Python.Python.3.12" -ForegroundColor Gray
            exit 1
        }
    } else {
        Write-Host "      ERROR: winget not available for automatic install." -ForegroundColor Red
        Write-Host "      Please install Python 3.12 manually from https://www.python.org/downloads/" -ForegroundColor Yellow
        exit 1
    }
}

$pythonVersion = Invoke-Expression "$pythonCmd --version" 2>&1
Write-Host "      Using: $pythonVersion ($pythonCmd)" -ForegroundColor Green

# Step 2: Check/Install CMake
Write-Host "[2/$totalSteps] Checking CMake..." -ForegroundColor Cyan

$cmake = Get-Command cmake -ErrorAction SilentlyContinue
if ($cmake) {
    $cmakeVer = (& cmake --version | Select-Object -First 1)
    Write-Host "      $cmakeVer" -ForegroundColor Green
} else {
    if (Test-Winget) {
        Install-CMake
    } else {
        Write-Host "      WARNING: CMake not found. Install from https://cmake.org/download/" -ForegroundColor Yellow
    }
}

# Step 3: Check/Install Ninja
Write-Host "[3/$totalSteps] Checking Ninja build system..." -ForegroundColor Cyan

$ninja = Get-Command ninja -ErrorAction SilentlyContinue
if ($ninja) {
    $ninjaVer = (& ninja --version)
    Write-Host "      Ninja $ninjaVer" -ForegroundColor Green
} else {
    if (Test-Winget) {
        Install-Ninja
    } else {
        Write-Host "      Ninja not found (optional, will use default generator)" -ForegroundColor Yellow
    }
}

# Step 4: Check Visual Studio / Build Tools
Write-Host "[4/$totalSteps] Checking C++ build tools..." -ForegroundColor Cyan

if (Test-VisualStudio) {
    Write-Host "      Visual Studio / Build Tools found" -ForegroundColor Green
} else {
    Write-Host "      No C++ build tools found." -ForegroundColor Yellow
    if (Test-Winget) {
        Install-VSBuildTools
    } else {
        Write-Host "      Install Visual Studio 2022 or Build Tools manually." -ForegroundColor Yellow
    }
}

# Step 5: Create/Activate Virtual Environment
Write-Host "[5/$totalSteps] Setting up Python virtual environment..." -ForegroundColor Cyan

$venvDir = "venv"
if (Test-Path $venvDir) {
    Write-Host "      Virtual environment '$venvDir' already exists." -ForegroundColor Yellow
} else {
    Invoke-Expression "$pythonCmd -m venv $venvDir"
    if ($LASTEXITCODE -eq 0) {
        Write-Host "      Created $venvDir successfully." -ForegroundColor Green
    } else {
        Write-Host "      ERROR: Failed to create virtual environment." -ForegroundColor Red
        exit 1
    }
}

# Activate virtual environment
Write-Host "      Activating virtual environment..." -ForegroundColor Cyan
try {
    & ".\$venvDir\Scripts\Activate.ps1"
    Write-Host "      Activated $venvDir" -ForegroundColor Green
} catch {
    Write-Host "      ERROR: Failed to activate virtual environment." -ForegroundColor Red
    Write-Host "      Try running: Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser" -ForegroundColor Yellow
    exit 1
}

# Step 6: Upgrade pip and install pip-tools
Write-Host "[6/$totalSteps] Upgrading pip and installing tools..." -ForegroundColor Cyan

python -m pip install --upgrade pip --quiet
pip install --upgrade setuptools wheel --quiet
Write-Host "      pip and setuptools upgraded" -ForegroundColor Green

# Step 7: Install Python dependencies
Write-Host "[7/$totalSteps] Installing Python dependencies..." -ForegroundColor Cyan

if (Test-Path "requirements.txt") {
    pip install -r requirements.txt --quiet
    if ($LASTEXITCODE -eq 0) {
        Write-Host "      Installed requirements.txt" -ForegroundColor Green
    } else {
        Write-Host "      WARNING: Some packages may have failed to install." -ForegroundColor Yellow
    }
}

if (Test-Path "requirements-dev.txt") {
    pip install -r requirements-dev.txt --quiet
    if ($LASTEXITCODE -eq 0) {
        Write-Host "      Installed requirements-dev.txt" -ForegroundColor Green
    } else {
        Write-Host "      WARNING: Some dev packages may have failed." -ForegroundColor Yellow
    }
} else {
    Write-Host "      Skipped dev dependencies (requirements-dev.txt not found)" -ForegroundColor Yellow
}

# Step 8: Download ONNX models
Write-Host "[8/$totalSteps] Downloading ONNX models..." -ForegroundColor Cyan

$modelsScript = "scripts\download_models.py"
if (Test-Path $modelsScript) {
    python $modelsScript
    if ($LASTEXITCODE -eq 0) {
        Write-Host "      Models downloaded successfully" -ForegroundColor Green
    } else {
        Write-Host "      WARNING: Model download may have failed. Run manually later:" -ForegroundColor Yellow
        Write-Host "        python scripts\download_models.py" -ForegroundColor Gray
    }
} else {
    Write-Host "      Skipped (download_models.py not found)" -ForegroundColor Yellow
}

# Create directories
Write-Host ""
Write-Host "----------------------------------------" -ForegroundColor Gray

if (-not (Test-Path "build")) {
    New-Item -ItemType Directory -Path "build" | Out-Null
    Write-Host "Created build directory." -ForegroundColor Green
}

if (-not (Test-Path "models")) {
    New-Item -ItemType Directory -Path "models" | Out-Null
    Write-Host "Created models directory." -ForegroundColor Green
}

# Summary
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "   Setup Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Build the project:"
Write-Host "       .\scripts\build.ps1 -Release" -ForegroundColor Gray
Write-Host ""
Write-Host "  2. Run tests:"
Write-Host "       cd build && ctest --output-on-failure" -ForegroundColor Gray
Write-Host ""
Write-Host "  3. Use Python bindings:"
Write-Host "       import pyvdb" -ForegroundColor Gray
Write-Host ""
Write-Host "Virtual environment '$venvDir' is now active." -ForegroundColor Green
Write-Host "To deactivate later, run: deactivate" -ForegroundColor Gray
Write-Host ""
