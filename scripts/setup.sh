#!/usr/bin/env bash
# ==============================================================================
# TCGA-HNSC Prognostic Signature - Environment Setup
# ==============================================================================
# Usage: ./scripts/setup.sh
# 
# This script:
#   1. Checks for R installation
#   2. Fixes macOS C++ toolchain issues (if needed)
#   3. Initializes renv and installs all dependencies
# ==============================================================================

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# ------------------------------------------------------------------------------
# Check R installation
# ------------------------------------------------------------------------------
if ! command -v R &> /dev/null; then
    log_error "R is not installed. Please install R >= 4.3 from https://cran.r-project.org/"
    exit 1
fi

R_VERSION=$(R --version | head -n1 | grep -oE '[0-9]+\.[0-9]+')
log_info "Found R version: $R_VERSION"

# ------------------------------------------------------------------------------
# macOS: Fix C++ toolchain for source compilation
# ------------------------------------------------------------------------------
if [[ "$OSTYPE" == "darwin"* ]]; then
    log_info "Detected macOS - checking C++ toolchain configuration..."
    
    MAKEVARS_DIR="$HOME/.R"
    MAKEVARS_FILE="$MAKEVARS_DIR/Makevars"
    SDK_PATH="/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk"
    
    if [[ -d "$SDK_PATH" ]]; then
        mkdir -p "$MAKEVARS_DIR"
        
        # Check if fix already applied
        if [[ -f "$MAKEVARS_FILE" ]] && grep -q "tcga-hnsc-prognostic-signature" "$MAKEVARS_FILE"; then
            log_info "Makevars already configured"
        else
            log_info "Configuring Makevars for Command Line Tools SDK..."
            cat >> "$MAKEVARS_FILE" << EOF

# Added by tcga-hnsc-prognostic-signature setup script
SDK_PATH = $SDK_PATH
CPPFLAGS += -isysroot \$(SDK_PATH)
CXXFLAGS += -isysroot \$(SDK_PATH) -I\$(SDK_PATH)/usr/include/c++/v1
LDFLAGS += -isysroot \$(SDK_PATH)
EOF
            log_info "Makevars configured at $MAKEVARS_FILE"
        fi
    else
        log_warn "macOS SDK not found at expected path. If compilation fails, run:"
        log_warn "  xcode-select --install"
    fi
fi

# ------------------------------------------------------------------------------
# Install R packages via renv
# ------------------------------------------------------------------------------
log_info "Installing R packages (this may take 10-15 minutes on first run)..."

cd "$(dirname "$0")/.."  # Navigate to project root

R --quiet --no-save << 'RSCRIPT'
options(repos = c(CRAN = "https://cloud.r-project.org"))

# Initialize renv if not already done
if (!file.exists("renv.lock")) {
    renv::init(bare = TRUE)
}

cat("\n[1/3] Installing CRAN packages...\n")
cran_pkgs <- c(
    # Data wrangling
    "tidyverse",
    "data.table",
    "janitor",
    # Survival analysis
    "survival",
    "glmnet",
    "survminer",
    "timeROC",
    "Hmisc",
    # Utilities
    "jsonlite",
    "ggplot2",
    "patchwork",
    "knitr",
    "rmarkdown"
)
renv::install(cran_pkgs)

cat("\n[2/3] Installing Bioconductor packages...\n")
if (!requireNamespace("BiocManager", quietly = TRUE)) {
    install.packages("BiocManager")
}

bioc_pkgs <- c(
    "bioc::UCSCXenaTools",
    "bioc::clusterProfiler",
    "bioc::org.Hs.eg.db",
    "bioc::enrichplot",
    "bioc::DOSE"
)
renv::install(bioc_pkgs)

cat("\n[3/3] Creating lockfile snapshot...\n")
renv::snapshot(prompt = FALSE)

cat("\n✓ All packages installed successfully!\n")
RSCRIPT

log_info "Setup complete! You can now run the analysis."
