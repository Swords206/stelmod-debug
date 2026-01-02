# stelmod-debug Configuration Example
# Copy this to config.sh and edit for your setup
#
# Run: cp config.example.sh config.sh

# ═══════════════════════════════════════════════════════════════════════════════
# REQUIRED SETTINGS
# ═══════════════════════════════════════════════════════════════════════════════

# Your mod's log prefix (without brackets)
# This is what appears in your log statements: log = "[MYMOD] message"
# Example: "LN" matches "[LN]" in logs
MOD_PREFIX="MYMOD"

# Path to Stellaris user data folder
# This folder contains: logs/, mod/, save games/
#
# Common paths:
#   WSL:        /mnt/c/Users/YourName/Documents/Paradox Interactive/Stellaris
#   WSL+OneDrive: /mnt/c/Users/YourName/OneDrive/Documents/Paradox Interactive/Stellaris
#   Linux:      ~/.local/share/Paradox Interactive/Stellaris
#   macOS:      ~/Documents/Paradox Interactive/Stellaris
STELLARIS_DOCS="/mnt/c/Users/YourName/Documents/Paradox Interactive/Stellaris"

# ═══════════════════════════════════════════════════════════════════════════════
# OPTIONAL SETTINGS
# ═══════════════════════════════════════════════════════════════════════════════

# Your mod folder name (for freshness checks)
# This is the folder in STELLARIS_DOCS/mod/
# Leave empty "" to skip freshness validation
MOD_FOLDER="my_awesome_mod"

# Log file paths (usually auto-set from STELLARIS_DOCS)
# Only override if your logs are in a non-standard location
ERROR_LOG="$STELLARIS_DOCS/logs/error.log"
GAME_LOG="$STELLARIS_DOCS/logs/game.log"

# Number of lines to show by default
# Override with -n flag: ./stelmod-debug.sh game -n 100
TAIL_LINES=50

# Additional patterns to search for (pipe-separated regex)
# These are highlighted in addition to your MOD_PREFIX
# Example: "FALLBACK|DIRECT|ERROR|ORPHAN"
EXTRA_PATTERNS=""

# ═══════════════════════════════════════════════════════════════════════════════
# EXAMPLES FOR DIFFERENT SETUPS
# ═══════════════════════════════════════════════════════════════════════════════

# --- Living Network Mod (WSL + OneDrive) ---
# MOD_PREFIX="LN"
# STELLARIS_DOCS="/mnt/c/Users/fswa9/OneDrive/Documents/Paradox Interactive/Stellaris"
# MOD_FOLDER="the_living_network"
# EXTRA_PATTERNS="FALLBACK|DIRECT|ORPHAN"

# --- Generic Mod (Native Linux) ---
# MOD_PREFIX="MYMOD"
# STELLARIS_DOCS="$HOME/.local/share/Paradox Interactive/Stellaris"
# MOD_FOLDER="my_mod_folder"

# --- Generic Mod (macOS) ---
# MOD_PREFIX="MYMOD"
# STELLARIS_DOCS="$HOME/Documents/Paradox Interactive/Stellaris"
# MOD_FOLDER="my_mod_folder"
