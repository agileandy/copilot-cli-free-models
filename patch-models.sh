#!/bin/bash

# Copilot Model Patcher
# Adds additional models to the GitHub Copilot CLI's allowed models array
#
# Usage:
#   ./patch-models.sh [--file /path/to/index.js] [--dry-run] [--models model1,model2]
#
# Examples:
#   ./patch-models.sh                           # Patch default location, add gpt-5-mini
#   ./patch-models.sh --dry-run                 # Preview changes without modifying
#   ./patch-models.sh --models gpt-5-mini,o1    # Add multiple models
#   ./patch-models.sh --file /custom/path       # Patch specific file

set -euo pipefail

# Default configuration
# Auto-detect Copilot installation location
COPILOT_PATH=""

# Check common locations in order of preference
SEARCH_PATHS=(
    "$HOME/node_modules/@github/copilot/index.js"
    "$(npm root -g 2>/dev/null)/@github/copilot/index.js"
    "/usr/local/lib/node_modules/@github/copilot/index.js"
    "/opt/homebrew/lib/node_modules/@github/copilot/index.js"
)

for path in "${SEARCH_PATHS[@]}"; do
    if [[ -f "$path" ]]; then
        COPILOT_PATH="$path"
        break
    fi
done

TARGET_FILE="${COPILOT_PATH}"
BACKUP_SUFFIX=".bak.$(date +%Y%m%d-%H%M%S)"
DRY_RUN=false
MODELS_TO_ADD=("gpt-5-mini")

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --file)
            TARGET_FILE="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --models)
            IFS=',' read -ra MODELS_TO_ADD <<< "$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --file PATH       Path to index.js (default: node_modules/@github/copilot/index.js)"
            echo "  --dry-run         Preview changes without modifying files"
            echo "  --models M1,M2    Comma-separated list of models to add (default: gpt-5-mini)"
            echo "  -h, --help        Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0 --dry-run"
            echo "  $0 --models gpt-5-mini,o1"
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Unknown option: $1${NC}"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Copilot Model Patcher${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${BLUE}Requirements:${NC}"
echo "  • Bash shell (macOS, Linux, WSL)"
echo "  • Perl (pre-installed on macOS/Linux)"
echo "  • GitHub Copilot CLI installed"
echo ""
echo -e "${BLUE}Platform Support:${NC}"
echo "  ✅ macOS    ✅ Linux    ✅ Windows (WSL/Git Bash)"
echo ""

# Verify file exists
if [[ ! -f "$TARGET_FILE" ]]; then
    echo -e "${RED}❌ Error: File not found: $TARGET_FILE${NC}"
    exit 1
fi

echo -e "${GREEN}✓${NC} Target file: $TARGET_FILE"

# Step 1: Find the models array variable and current models
echo ""
echo -e "${YELLOW}Step 1: Locating models array...${NC}"

# Extract the current array - looking for pattern like: Ef=["model1","model2",...]
ARRAY_PATTERN=$(grep -o '[A-Za-z_$][A-Za-z0-9_$]*=\["claude-sonnet-[^]]*\]' "$TARGET_FILE" | head -n 1 || true)

if [[ -z "$ARRAY_PATTERN" ]]; then
    echo -e "${RED}❌ Error: Could not find models array in file${NC}"
    echo "The file structure may have changed in a newer version."
    echo "Please check README.md for instructions on finding the new pattern."
    exit 1
fi

# Extract variable name (e.g., "Ef" from "Ef=[...]")
VAR_NAME=$(echo "$ARRAY_PATTERN" | cut -d'=' -f1)
CURRENT_ARRAY=$(echo "$ARRAY_PATTERN" | cut -d'=' -f2)

echo -e "${GREEN}✓${NC} Found variable: ${BLUE}$VAR_NAME${NC}"
echo -e "${GREEN}✓${NC} Current array: ${BLUE}$CURRENT_ARRAY${NC}"

# Step 2: Parse current models
echo ""
echo -e "${YELLOW}Step 2: Parsing current models...${NC}"

# Extract models from array (remove brackets and split by comma)
CURRENT_MODELS_STR=$(echo "$CURRENT_ARRAY" | sed 's/\[//g' | sed 's/\]//g' | sed 's/"//g')
IFS=',' read -ra CURRENT_MODELS <<< "$CURRENT_MODELS_STR"

echo -e "${GREEN}✓${NC} Current models:"
for model in "${CURRENT_MODELS[@]}"; do
    echo "    - $model"
done

# Step 3: Build new array with additional models
echo ""
echo -e "${YELLOW}Step 3: Building new models array...${NC}"

NEW_MODELS=("${CURRENT_MODELS[@]}")
MODELS_ADDED=()

for model in "${MODELS_TO_ADD[@]}"; do
    # Check if model already exists
    if [[ " ${CURRENT_MODELS[*]} " == *" $model "* ]]; then
        echo -e "${YELLOW}⚠${NC}  Model '$model' already exists, skipping"
    else
        NEW_MODELS+=("$model")
        MODELS_ADDED+=("$model")
        echo -e "${GREEN}+${NC}  Adding model: $model"
    fi
done

if [[ ${#MODELS_ADDED[@]} -eq 0 ]]; then
    echo -e "${YELLOW}⚠${NC}  No new models to add - file already up to date"
    exit 0
fi

# Build new array string
NEW_ARRAY="["
for i in "${!NEW_MODELS[@]}"; do
    if [[ $i -gt 0 ]]; then
        NEW_ARRAY+=","
    fi
    NEW_ARRAY+="\"${NEW_MODELS[$i]}\""
done
NEW_ARRAY+="]"

echo -e "${GREEN}✓${NC} New array: ${BLUE}$NEW_ARRAY${NC}"

# Define search and replacement patterns
SEARCH_PATTERN="${VAR_NAME}=${CURRENT_ARRAY}"
REPLACEMENT="${VAR_NAME}=${NEW_ARRAY}"

# Step 4: Show dry-run or apply patch
echo ""
if [[ "$DRY_RUN" == "true" ]]; then
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}  DRY RUN MODE - No changes will be made${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "Would replace:"
    echo -e "  ${RED}FROM:${NC} $SEARCH_PATTERN"
    echo -e "  ${GREEN}TO:${NC}   $REPLACEMENT"
    echo ""
    echo "To apply changes, run without --dry-run flag"
    exit 0
fi

echo -e "${YELLOW}Step 4: Applying patch...${NC}"

# Create backup
BACKUP_FILE="${TARGET_FILE}${BACKUP_SUFFIX}"
echo -e "${BLUE}📦${NC} Creating backup: $BACKUP_FILE"
cp "$TARGET_FILE" "$BACKUP_FILE"

# Perform replacement using perl with literal string replacement
# Pass patterns via environment variables to avoid shell escaping issues
export SEARCH_PATTERN REPLACEMENT
perl -i -pe 'BEGIN{undef $/;} s/\Q$ENV{SEARCH_PATTERN}\E/$ENV{REPLACEMENT}/g' "$TARGET_FILE"

# Verify replacement was successful
if grep -qF "$REPLACEMENT" "$TARGET_FILE"; then
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}  ✅ Successfully patched!${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${BLUE}📋${NC} Backup saved to: $BACKUP_FILE"
    echo ""
    echo "Models now available:"
    for model in "${NEW_MODELS[@]}"; do
        if [[ " ${MODELS_ADDED[*]} " == *" $model "* ]]; then
            echo -e "  - $model ${GREEN}(newly added)${NC}"
        else
            echo "  - $model"
        fi
    done
    echo ""

    # Remind user to update config
    COPILOT_CONFIG="$HOME/.copilot/config.json"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}  ⚠️  Next Step: Update Your Config${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    if [[ -f "$COPILOT_CONFIG" ]]; then
        echo -e "Edit your Copilot config: ${BLUE}$COPILOT_CONFIG${NC}"
    else
        echo -e "Edit your Copilot config: ${BLUE}\$HOME/.copilot/config.json${NC}"
    fi
    echo ""
    echo "Change the \"model\" field to use a free model, for example:"
    echo -e "  ${GREEN}\"model\": \"gpt-5-mini\"${NC}"
    echo ""
    echo "Available free models you just added:"
    for model in "${MODELS_ADDED[@]}"; do
        echo -e "  - ${GREEN}$model${NC}"
    done
    echo ""
else
    echo ""
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}  ❌ Error: Replacement failed!${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "Restoring from backup..."
    mv "$BACKUP_FILE" "$TARGET_FILE"
    exit 1
fi
