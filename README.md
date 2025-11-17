-------
I created this script to help others get benefit from the free tier offered by Github

I appreciate all the support I got for making this, but would now suggest people look
at TheLolos' excellent fork at https://github.com/TheLoloS/Copilot-CLI-Unlocker
which significantly expands the capabilities
-------

# Copilot Model Patcher

A tool to add custom models to GitHub Copilot CLI's allowed models list.

## Requirements

- **Bash shell** (macOS, Linux, WSL)
- **Perl** (pre-installed on macOS/Linux)
- **GitHub Copilot CLI** installed

**Platform Support:**
- ✅ macOS
- ✅ Linux
- ✅ Windows (via WSL/Git Bash)

## Quick Start

```bash
cd ~/copilot-patch
chmod +x patch-models.sh
./patch-models.sh --dry-run    # Preview changes
./patch-models.sh              # Apply patch
```

After patching, update your config at `~/.copilot/config.json`:
```json
{
  "model": "gpt-5-mini"
}
```

## Problem Statement

The GitHub Copilot CLI has a hardcoded array of allowed models in its minified `index.js` file. If you configure a model in `~/.copilot/config.json` that isn't in this list, the CLI silently falls back to another model.

**Example:** Setting `"model": "gpt-5-mini"` in your config won't work if "gpt-5-mini" isn't in the allowed list.

## Solution Overview

This patcher:
1. Locates the models array variable in the minified code
2. Adds your desired models to the array
3. Creates timestamped backups before making changes
4. Validates the patch was successful

## Usage

### Basic Usage
```bash
./patch-models.sh                  # Add gpt-5-mini (default)
./patch-models.sh --dry-run        # Preview without making changes
```

The script will automatically:
1. Detect your Copilot installation location
2. Add the specified models to the allowed list
3. Create a timestamped backup
4. Remind you to update `~/.copilot/config.json`

### Add Specific Models
```bash
./patch-models.sh --models gpt-5-mini,o1
./patch-models.sh --models claude-opus-4
```

### Patch Custom Location
```bash
./patch-models.sh --file /path/to/custom/index.js
```

## Installation Location Detection

The script automatically searches these locations (in order):
1. `$HOME/node_modules/@github/copilot/index.js`
2. Global npm modules (from `npm root -g`)
3. `/usr/local/lib/node_modules/@github/copilot/index.js`
4. `/opt/homebrew/lib/node_modules/@github/copilot/index.js` (Homebrew on Apple Silicon)

You can override with `--file` if your installation is elsewhere.

## When to Run

You need to re-run this patcher:
- After updating the `@github/copilot` npm package
- When the CLI is reinstalled
- If you encounter "model not available" errors

## How It Works

### 1. The Minified Structure

The Copilot CLI's `index.js` is a ~13.5 MB minified file. Inside, there's a variable (currently `Yv`) that contains the allowed models:

```javascript
Yv=["claude-sonnet-4.5","claude-sonnet-4","claude-haiku-4.5","gpt-5"]
```

*Note: The variable name changes between versions (`Ef`, `Yv`, etc.) but the patcher auto-detects it.*

### 2. Detection Strategy

The patcher finds this array by searching for a recognizable pattern:
- Looks for variable assignments containing known model names (like "claude-sonnet")
- Extracts the variable name dynamically (works even if `Yv` changes to `Zv`, `Aa`, etc.)
- Parses the current models from the array

### 3. Patching Process

```bash
# Original
Yv=["claude-sonnet-4.5","claude-sonnet-4","claude-haiku-4.5","gpt-5"]

# Patched
Yv=["claude-sonnet-4.5","claude-sonnet-4","claude-haiku-4.5","gpt-5","gpt-5-mini"]
```

The patcher:
1. Creates a backup: `index.js.bak.YYYYMMDD-HHMMSS`
2. Uses Perl with environment variables to safely handle special characters
3. Performs the replacement in-place
4. Verifies the new array exists in the file
5. Restores backup if verification fails
6. Reminds you to update `~/.copilot/config.json`

## Adapting for Future Updates

If GitHub updates the Copilot CLI and this patcher stops working, here's how to adapt it:

### Step 1: Locate the New Models Array

```bash
# Search for known model patterns
grep -o 'gpt-5.*gpt-4.*claude' ~/node_modules/@github/copilot/index.js

# Or search for array-like structures
grep -o '\["gpt-[^]]*\]' ~/node_modules/@github/copilot/index.js
grep -o '\["claude-[^]]*\]' ~/node_modules/@github/copilot/index.js
```

### Step 2: Find the Variable Name

Once you find the array, look for what variable it's assigned to:

```bash
# Extract variable name and full assignment
grep -o '[A-Za-z_$][A-Za-z0-9_$]*=\["claude-sonnet-[^]]*\]' ~/node_modules/@github/copilot/index.js
```

Example output:
```
Yv=["claude-sonnet-4.5","claude-sonnet-4","claude-haiku-4.5","gpt-5"]
```

The variable name is `Yv` (the part before `=`).

### Step 3: Update the Search Pattern

If the patcher can't auto-detect the array, you can update the script's search pattern:

Edit `patch-models.sh` around line 85:

```bash
# Old pattern (searches for claude-sonnet models)
ARRAY_PATTERN=$(grep -o '[A-Za-z_$][A-Za-z0-9_$]*=\["claude-sonnet-[^]]*\]' "$TARGET_FILE" | head -n 1 || true)

# If models change, update the search term:
# For GPT-focused arrays:
ARRAY_PATTERN=$(grep -o '[A-Za-z_$][A-Za-z0-9_$]*=\["gpt-[^]]*\]' "$TARGET_FILE" | head -n 1 || true)

# For any model array with known model name:
ARRAY_PATTERN=$(grep -o '[A-Za-z_$][A-Za-z0-9_$]*=\["known-model-name[^]]*\]' "$TARGET_FILE" | head -n 1 || true)
```

### Step 4: Verify Your Changes

Always test with `--dry-run` first:

```bash
./patch-models.sh --dry-run
```

Look for:
- ✓ Variable name detected correctly
- ✓ Current models list makes sense
- ✓ New array includes your additions

## Technical Details

### File Locations (Auto-detected)
```
$HOME/node_modules/@github/copilot/index.js           # Local install
$(npm root -g)/@github/copilot/index.js               # Global npm
/usr/local/lib/node_modules/@github/copilot/index.js  # Standard global
/opt/homebrew/lib/node_modules/@github/copilot/index.js # Homebrew (Apple Silicon)
```

### Config File Location
```
$HOME/.copilot/config.json
```

### Backup Pattern
```
index.js.bak.YYYYMMDD-HHMMSS
```
Example: `index.js.bak.20251109-101507`

### Key Variables (as of Nov 2025)
- **Models Array Variable:** `Yv` (auto-detected, was `Ef` in earlier versions)
- **Default Models:** claude-sonnet-4.5, claude-sonnet-4, claude-haiku-4.5, gpt-5
- **File Size:** ~13.5 MB (minified)

### Why Perl Instead of Sed?

```bash
# sed has issues with special characters in minified code
sed 's/old/new/' file.js  # ❌ Can break on [], (), etc.

# perl with environment variables and \Q...\E is safe
export SEARCH="old" REPLACE="new"
perl -pe 's/\Q$ENV{SEARCH}\E/$ENV{REPLACE}/' file.js  # ✅ Safe for minified code
```

## Troubleshooting

### Error: "Could not find models array"

The file structure changed. Follow "Adapting for Future Updates" above.

### Error: "Replacement failed"

1. Check if the file is already patched:
   ```bash
   grep "gpt-5-mini" ~/node_modules/@github/copilot/index.js
   ```

2. Try restoring from a backup:
   ```bash
   ls -lt ~/node_modules/@github/copilot/index.js.bak.*
   cp ~/node_modules/@github/copilot/index.js.bak.YYYYMMDD-HHMMSS \
      ~/node_modules/@github/copilot/index.js
   ```

### Model Still Not Working

1. Verify the patch was applied:
   ```bash
   grep -o '[A-Za-z_$][A-Za-z0-9_$]*=\[.*gpt-5-mini.*\]' ~/node_modules/@github/copilot/index.js
   ```

2. Check your config file:
   ```bash
   cat ~/.copilot/config.json | grep model
   ```

   Should show:
   ```json
   "model": "gpt-5-mini"
   ```

3. Ensure exact spelling:
   - ✅ `gpt-5-mini`
   - ❌ `gpt5-mini` (missing hyphen)
   - ❌ `GPT-5-mini` (wrong case)

## Files in This Directory

```
copilot-patch/
├── patch-models.sh          # Main patcher script
├── README.md               # This file
└── CHANGELOG.md            # Version history (if tracking updates)
```

## Contributing / Maintenance

When updating this patcher for future Copilot versions:

1. Document the changes in `CHANGELOG.md`
2. Note the Copilot version number
3. Update the "Key Variables" section above
4. Test thoroughly with `--dry-run`

## Example Session

```bash
$ cd ~/copilot-patch

$ ./patch-models.sh --dry-run
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Copilot Model Patcher
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Requirements:
  • Bash shell (macOS, Linux, WSL)
  • Perl (pre-installed on macOS/Linux)
  • GitHub Copilot CLI installed

Platform Support:
  ✅ macOS    ✅ Linux    ✅ Windows (WSL/Git Bash)

✓ Target file: /Users/username/node_modules/@github/copilot/index.js

Step 1: Locating models array...
✓ Found variable: Yv
✓ Current array: ["claude-sonnet-4.5","claude-sonnet-4","claude-haiku-4.5","gpt-5"]

Step 2: Parsing current models...
✓ Current models:
    - claude-sonnet-4.5
    - claude-sonnet-4
    - claude-haiku-4.5
    - gpt-5

Step 3: Building new models array...
+  Adding model: gpt-5-mini
✓ New array: ["claude-sonnet-4.5","claude-sonnet-4","claude-haiku-4.5","gpt-5","gpt-5-mini"]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  DRY RUN MODE - No changes will be made
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Would replace:
  FROM: Yv=["claude-sonnet-4.5","claude-sonnet-4","claude-haiku-4.5","gpt-5"]
  TO:   Yv=["claude-sonnet-4.5","claude-sonnet-4","claude-haiku-4.5","gpt-5","gpt-5-mini"]

To apply changes, run without --dry-run flag

$ ./patch-models.sh
[... applies patch ...]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ✅ Successfully patched!
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📋 Backup saved to: index.js.bak.20251109-143022

Models now available:
  - claude-sonnet-4.5
  - claude-sonnet-4
  - claude-haiku-4.5
  - gpt-5
  - gpt-5-mini (newly added)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ⚠️  Next Step: Update Your Config
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Edit your Copilot config: ~/.copilot/config.json

Change the "model" field to use a free model, for example:
  "model": "gpt-5-mini"

Available free models you just added:
  - gpt-5-mini
```

## License

This is a utility script for personal use. The GitHub Copilot CLI itself is proprietary software from GitHub.

## Support

For issues with:
- **This patcher:** Check the troubleshooting section above
- **Copilot CLI itself:** Contact GitHub Support
- **Model availability:** Check with your GitHub organization's settings
