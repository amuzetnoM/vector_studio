#!/bin/bash
# Vector Studio - Automated Setup Script (Unix/macOS/Linux)
# Run with: chmod +x scripts/setup.sh && ./scripts/setup.sh
# Auto-installs Python 3.12, CMake, Ninja via brew (macOS) or apt/dnf (Linux) if needed

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo ""
echo "========================================"
echo "   Vector Studio - Automated Setup"
echo "========================================"
echo ""

# ============================================================================
# Helper Functions
# ============================================================================

detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ -f /etc/debian_version ]]; then
        echo "debian"
    elif [[ -f /etc/redhat-release ]]; then
        echo "redhat"
    elif [[ -f /etc/arch-release ]]; then
        echo "arch"
    else
        echo "unknown"
    fi
}

OS_TYPE=$(detect_os)
echo -e "      Detected OS: ${CYAN}$OS_TYPE${NC}"

check_python_version() {
    local python_cmd=$1
    if command -v $python_cmd &> /dev/null; then
        local version=$($python_cmd --version 2>&1 | grep -oP '\d+\.\d+' | head -1)
        local major=$(echo $version | cut -d. -f1)
        local minor=$(echo $version | cut -d. -f2)
        if [[ $major -eq 3 && $minor -ge 10 && $minor -le 13 ]]; then
            echo $python_cmd
            return 0
        fi
    fi
    return 1
}

find_python() {
    for ver in python3.12 python3.11 python3.10 python3.13; do
        if result=$(check_python_version $ver); then
            echo $result
            return 0
        fi
    done
    
    if result=$(check_python_version python3); then
        echo $result
        return 0
    fi
    
    return 1
}

install_python() {
    echo -e "      ${CYAN}Attempting automatic Python 3.12 installation...${NC}"
    
    case $OS_TYPE in
        macos)
            if command -v brew &> /dev/null; then
                echo -e "      ${CYAN}Installing via Homebrew...${NC}"
                brew install python@3.12
                export PATH="/opt/homebrew/opt/python@3.12/bin:/usr/local/opt/python@3.12/bin:$PATH"
                return 0
            else
                echo -e "      ${YELLOW}Installing Homebrew first...${NC}"
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
                if [[ -f "/opt/homebrew/bin/brew" ]]; then
                    eval "$(/opt/homebrew/bin/brew shellenv)"
                elif [[ -f "/usr/local/bin/brew" ]]; then
                    eval "$(/usr/local/bin/brew shellenv)"
                fi
                brew install python@3.12
                export PATH="/opt/homebrew/opt/python@3.12/bin:/usr/local/opt/python@3.12/bin:$PATH"
                return 0
            fi
            ;;
        debian)
            echo -e "      ${CYAN}Installing via apt...${NC}"
            sudo apt update
            sudo apt install -y python3.12 python3.12-venv python3.12-dev python3-pip
            return 0
            ;;
        redhat)
            echo -e "      ${CYAN}Installing via dnf...${NC}"
            sudo dnf install -y python3.12 python3.12-devel python3-pip
            return 0
            ;;
        arch)
            echo -e "      ${CYAN}Installing via pacman...${NC}"
            sudo pacman -Sy --noconfirm python python-pip
            return 0
            ;;
        *)
            echo -e "      ${RED}Unsupported OS for automatic installation.${NC}"
            return 1
            ;;
    esac
}

install_cmake() {
    echo -e "      ${CYAN}Installing CMake...${NC}"
    
    case $OS_TYPE in
        macos)
            brew install cmake
            ;;
        debian)
            sudo apt install -y cmake
            ;;
        redhat)
            sudo dnf install -y cmake
            ;;
        arch)
            sudo pacman -Sy --noconfirm cmake
            ;;
    esac
}

install_ninja() {
    echo -e "      ${CYAN}Installing Ninja...${NC}"
    
    case $OS_TYPE in
        macos)
            brew install ninja
            ;;
        debian)
            sudo apt install -y ninja-build
            ;;
        redhat)
            sudo dnf install -y ninja-build
            ;;
        arch)
            sudo pacman -Sy --noconfirm ninja
            ;;
    esac
}

install_build_essentials() {
    echo -e "      ${CYAN}Installing build tools...${NC}"
    
    case $OS_TYPE in
        macos)
            xcode-select --install 2>/dev/null || true
            ;;
        debian)
            sudo apt install -y build-essential
            ;;
        redhat)
            sudo dnf groupinstall -y "Development Tools"
            ;;
        arch)
            sudo pacman -Sy --noconfirm base-devel
            ;;
    esac
}

# ============================================================================
# Main Setup Process
# ============================================================================

TOTAL_STEPS=8

# Step 1: Check Python
echo -e "[1/$TOTAL_STEPS] Checking Python installation..."

PYTHON_CMD=$(find_python) || PYTHON_CMD=""

if [[ -z "$PYTHON_CMD" ]]; then
    echo -e "      ${YELLOW}No compatible Python (3.10-3.13) found.${NC}"
    
    if install_python; then
        sleep 2
        PYTHON_CMD=$(find_python) || PYTHON_CMD=""
        if [[ -z "$PYTHON_CMD" ]]; then
            echo -e "      ${YELLOW}Please restart your terminal and run this script again.${NC}"
            exit 0
        fi
    else
        echo -e "      ${RED}ERROR: Automatic installation failed.${NC}"
        echo -e "      ${YELLOW}Please install Python 3.12 manually.${NC}"
        exit 1
    fi
fi

PYTHON_VERSION=$($PYTHON_CMD --version 2>&1)
echo -e "      ${GREEN}Using: $PYTHON_VERSION ($PYTHON_CMD)${NC}"

# Step 2: Check/Install CMake
echo -e "[2/$TOTAL_STEPS] Checking CMake..."

if command -v cmake &> /dev/null; then
    CMAKE_VER=$(cmake --version | head -n1)
    echo -e "      ${GREEN}$CMAKE_VER${NC}"
else
    install_cmake
fi

# Step 3: Check/Install Ninja
echo -e "[3/$TOTAL_STEPS] Checking Ninja..."

if command -v ninja &> /dev/null; then
    NINJA_VER=$(ninja --version)
    echo -e "      ${GREEN}Ninja $NINJA_VER${NC}"
else
    install_ninja
fi

# Step 4: Check build tools
echo -e "[4/$TOTAL_STEPS] Checking C++ build tools..."

if command -v g++ &> /dev/null || command -v clang++ &> /dev/null; then
    if command -v g++ &> /dev/null; then
        GCC_VER=$(g++ --version | head -n1)
        echo -e "      ${GREEN}$GCC_VER${NC}"
    else
        CLANG_VER=$(clang++ --version | head -n1)
        echo -e "      ${GREEN}$CLANG_VER${NC}"
    fi
else
    install_build_essentials
fi

# Step 5: Create/Activate Virtual Environment
echo -e "[5/$TOTAL_STEPS] Setting up Python virtual environment..."

VENV_DIR="venv"
if [ -d "$VENV_DIR" ]; then
    echo -e "      ${YELLOW}Virtual environment '$VENV_DIR' already exists.${NC}"
else
    $PYTHON_CMD -m venv $VENV_DIR
    echo -e "      ${GREEN}Created $VENV_DIR successfully.${NC}"
fi

echo -e "      Activating virtual environment..."
source $VENV_DIR/bin/activate
echo -e "      ${GREEN}Activated $VENV_DIR${NC}"

# Step 6: Upgrade pip
echo -e "[6/$TOTAL_STEPS] Upgrading pip and installing tools..."

python -m pip install --upgrade pip --quiet
pip install --upgrade setuptools wheel --quiet
echo -e "      ${GREEN}pip and setuptools upgraded${NC}"

# Step 7: Install Python dependencies
echo -e "[7/$TOTAL_STEPS] Installing Python dependencies..."

if [ -f "requirements.txt" ]; then
    pip install -r requirements.txt --quiet
    echo -e "      ${GREEN}Installed requirements.txt${NC}"
fi

if [ -f "requirements-dev.txt" ]; then
    pip install -r requirements-dev.txt --quiet
    echo -e "      ${GREEN}Installed requirements-dev.txt${NC}"
else
    echo -e "      ${YELLOW}Skipped dev dependencies (requirements-dev.txt not found)${NC}"
fi

# Step 8: Download ONNX models
echo -e "[8/$TOTAL_STEPS] Downloading ONNX models..."

MODELS_SCRIPT="scripts/download_models.py"
if [ -f "$MODELS_SCRIPT" ]; then
    python $MODELS_SCRIPT
    if [ $? -eq 0 ]; then
        echo -e "      ${GREEN}Models downloaded successfully${NC}"
    else
        echo -e "      ${YELLOW}WARNING: Model download may have failed. Run manually later:${NC}"
        echo "        python scripts/download_models.py"
    fi
else
    echo -e "      ${YELLOW}Skipped (download_models.py not found)${NC}"
fi

# Create directories
echo ""
echo "----------------------------------------"

if [ ! -d "build" ]; then
    mkdir -p build
    echo -e "${GREEN}Created build directory.${NC}"
fi

if [ ! -d "models" ]; then
    mkdir -p models
    echo -e "${GREEN}Created models directory.${NC}"
fi

# Summary
echo ""
echo "========================================"
echo -e "${GREEN}   Setup Complete!${NC}"
echo "========================================"
echo ""
echo "Next steps:"
echo "  1. Build the project:"
echo "       mkdir build && cd build"
echo "       cmake .. -G Ninja -DCMAKE_BUILD_TYPE=Release"
echo "       ninja"
echo ""
echo "  2. Run tests:"
echo "       cd build && ctest --output-on-failure"
echo ""
echo "  3. Use Python bindings:"
echo "       import pyvdb"
echo ""
echo -e "${GREEN}Virtual environment '$VENV_DIR' is now active.${NC}"
echo "To deactivate later, run: deactivate"
echo ""
