#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# stelmod-debug - Universal Stellaris Mod Log Analyzer (Linux/macOS)
# ═══════════════════════════════════════════════════════════════════════════════
# A tool for Stellaris mod developers to quickly check logs for errors,
# filter by mod prefix, and validate log freshness.
#
# Usage: ./stelmod-debug.sh [command] [options]
#
# Commands:
#   setup     - Configure (with GUI folder picker if available)
#   errors    - Show error log entries for your mod
#   game      - Show game log entries matching your prefix
#   all       - Show freshness + errors + game logs
#   fresh     - Check if logs are fresh
#   summary   - Quick stats
#   help      - Show help
#
# Version: 1.0.0
# ═══════════════════════════════════════════════════════════════════════════════

set -e

# ─────────────────────────────────────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.sh"

# Default values
MOD_PREFIX="YOUR_MOD"
MOD_FOLDER=""
STELLARIS_DOCS=""
ERROR_LOG=""
GAME_LOG=""
TAIL_LINES=50
EXTRA_PATTERNS=""

# Popular paths to check (Linux/macOS/WSL)
POPULAR_PATHS=(
    # Linux native (Steam)
    "$HOME/.local/share/Paradox Interactive/Stellaris"
    # Linux native (GOG/other)
    "$HOME/.paradoxinteractive/Stellaris"
    # macOS
    "$HOME/Documents/Paradox Interactive/Stellaris"
    "$HOME/Library/Application Support/Paradox Interactive/Stellaris"
    # WSL paths (Windows user folders mounted)
    "/mnt/c/Users/$USER/Documents/Paradox Interactive/Stellaris"
    "/mnt/c/Users/$USER/OneDrive/Documents/Paradox Interactive/Stellaris"
)

# Load user config if exists
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
fi

# Set log paths from docs path
if [[ -n "$STELLARIS_DOCS" ]]; then
    ERROR_LOG="${ERROR_LOG:-$STELLARIS_DOCS/logs/error.log}"
    GAME_LOG="${GAME_LOG:-$STELLARIS_DOCS/logs/game.log}"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Color Definitions
# ─────────────────────────────────────────────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
NC='\033[0m'
BOLD='\033[1m'

# ─────────────────────────────────────────────────────────────────────────────
# Helper Functions
# ─────────────────────────────────────────────────────────────────────────────

print_header() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${WHITE}  🔍 stelmod-debug - Stellaris Mod Log Analyzer${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
}

print_section() {
    echo -e "${YELLOW}───────────────────────────────────────────────────────────────${NC}"
    echo -e "${BOLD}${WHITE}  $1${NC}"
    echo -e "${YELLOW}───────────────────────────────────────────────────────────────${NC}"
}

check_config() {
    if [[ "$MOD_PREFIX" == "YOUR_MOD" ]]; then
        echo -e "${RED}❌ MOD_PREFIX not configured${NC}"
        echo -e "${YELLOW}   Run: ./stelmod-debug.sh setup${NC}"
        return 1
    fi

    if [[ -z "$STELLARIS_DOCS" ]] || [[ ! -d "$STELLARIS_DOCS" ]]; then
        echo -e "${RED}❌ Stellaris folder not found: $STELLARIS_DOCS${NC}"
        echo -e "${YELLOW}   Run: ./stelmod-debug.sh setup${NC}"
        return 1
    fi

    return 0
}

# Check if GUI tools are available
has_gui() {
    command -v zenity &>/dev/null || command -v kdialog &>/dev/null
}

show_folder_picker() {
    local title="$1"
    local start_dir="$2"

    if command -v zenity &>/dev/null; then
        zenity --file-selection --directory --title="$title" --filename="$start_dir/" 2>/dev/null
    elif command -v kdialog &>/dev/null; then
        kdialog --getexistingdirectory "$start_dir" --title "$title" 2>/dev/null
    else
        return 1
    fi
}

find_stellaris_folders() {
    local found=()

    for path in "${POPULAR_PATHS[@]}"; do
        # Expand ~ and variables
        expanded_path=$(eval echo "$path")
        if [[ -d "$expanded_path" ]] && [[ -d "$expanded_path/logs" ]]; then
            found+=("$expanded_path")
        fi
    done

    # Also check for any WSL user folders
    if [[ -d "/mnt/c/Users" ]]; then
        for user_dir in /mnt/c/Users/*/; do
            if [[ -d "${user_dir}Documents/Paradox Interactive/Stellaris/logs" ]]; then
                found+=("${user_dir}Documents/Paradox Interactive/Stellaris")
            fi
            if [[ -d "${user_dir}OneDrive/Documents/Paradox Interactive/Stellaris/logs" ]]; then
                found+=("${user_dir}OneDrive/Documents/Paradox Interactive/Stellaris")
            fi
        done
    fi

    printf '%s\n' "${found[@]}" | sort -u
}

# ─────────────────────────────────────────────────────────────────────────────
# Command: Setup
# ─────────────────────────────────────────────────────────────────────────────

cmd_setup() {
    print_header
    print_section "⚙️  Configuration Setup"
    echo ""

    # Step 1: Find Stellaris folder
    echo -e "${CYAN}Step 1: Locate Stellaris User Data${NC}"
    echo ""
    echo -e "${WHITE}🔍 Searching for Stellaris folder...${NC}"

    mapfile -t detected_paths < <(find_stellaris_folders)

    local selected_path=""

    if [[ ${#detected_paths[@]} -gt 0 ]]; then
        echo ""
        echo -e "${GREEN}Found ${#detected_paths[@]} potential location(s):${NC}"
        for i in "${!detected_paths[@]}"; do
            echo -e "${CYAN}  [$((i+1))] ${detected_paths[$i]}${NC}"
        done

        if has_gui; then
            echo -e "${YELLOW}  [B] Browse for different folder (GUI)...${NC}"
        fi
        echo -e "${YELLOW}  [M] Enter path manually...${NC}"
        echo ""

        read -p "Select option: " choice

        if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le ${#detected_paths[@]} ]]; then
            selected_path="${detected_paths[$((choice-1))]}"
        elif [[ "$choice" == "B" ]] || [[ "$choice" == "b" ]]; then
            if has_gui; then
                selected_path=$(show_folder_picker "Select Stellaris User Data Folder" "$HOME")
            else
                echo -e "${RED}No GUI tools available (install zenity or kdialog)${NC}"
                read -p "Enter path manually: " selected_path
            fi
        elif [[ "$choice" == "M" ]] || [[ "$choice" == "m" ]]; then
            read -p "Enter path: " selected_path
        fi
    else
        echo -e "${YELLOW}No Stellaris folder auto-detected.${NC}"
        echo ""

        if has_gui; then
            echo -e "${CYAN}Opening folder browser...${NC}"
            selected_path=$(show_folder_picker "Select Stellaris User Data Folder" "$HOME")
        else
            echo -e "${GRAY}Tip: Install 'zenity' for GUI folder picker${NC}"
            read -p "Enter path to Stellaris folder: " selected_path
        fi
    fi

    if [[ -z "$selected_path" ]]; then
        echo -e "${RED}❌ No folder selected. Setup cancelled.${NC}"
        return 1
    fi

    # Validate
    if [[ ! -d "$selected_path/logs" ]]; then
        echo -e "${YELLOW}⚠️  Warning: No 'logs' folder found in $selected_path${NC}"
        echo -e "${GRAY}   This may not be correct, or Stellaris hasn't been run yet.${NC}"
    fi

    STELLARIS_DOCS="$selected_path"
    echo -e "${GREEN}✅ Selected: $selected_path${NC}"
    echo ""

    # Step 2: Get mod prefix
    echo -e "${CYAN}Step 2: Set Your Mod Prefix${NC}"
    echo ""
    echo -e "${WHITE}What prefix do you use in log statements?${NC}"
    echo -e "${GRAY}Example: If you write log = \"[MYMOD] message\", enter: MYMOD${NC}"
    echo ""

    read -p "> " input_prefix
    MOD_PREFIX="${input_prefix:-YOUR_MOD}"
    MOD_PREFIX="${MOD_PREFIX^^}"  # Uppercase
    echo -e "${GREEN}✅ Prefix set: [$MOD_PREFIX]${NC}"
    echo ""

    # Step 3: Get mod folder (optional)
    echo -e "${CYAN}Step 3: Your Mod Folder Name (optional)${NC}"
    echo ""
    echo -e "${WHITE}For freshness checking, enter your mod's folder name.${NC}"
    echo -e "${GRAY}This is the folder in: $selected_path/mod/${NC}"
    echo ""

    # List available mod folders
    if [[ -d "$selected_path/mod" ]]; then
        local mod_folders
        mod_folders=$(ls -1 "$selected_path/mod" 2>/dev/null | head -10)
        if [[ -n "$mod_folders" ]]; then
            echo -e "${CYAN}Available mod folders:${NC}"
            echo "$mod_folders" | while read -r folder; do
                echo -e "${GRAY}  - $folder${NC}"
            done
            echo ""
        fi
    fi

    read -p "Mod folder name (or Enter to skip): " MOD_FOLDER
    if [[ -n "$MOD_FOLDER" ]]; then
        echo -e "${GREEN}✅ Mod folder: $MOD_FOLDER${NC}"
    else
        echo -e "${YELLOW}⏭️  Skipped (freshness check will be limited)${NC}"
    fi

    # Step 4: Extra patterns (optional)
    echo ""
    echo -e "${CYAN}Step 4: Extra Search Patterns (optional)${NC}"
    echo ""
    echo -e "${WHITE}Additional keywords to highlight (pipe-separated)${NC}"
    echo -e "${GRAY}Example: FALLBACK|DIRECT|ORPHAN${NC}"
    echo ""

    read -p "Extra patterns (or Enter to skip): " EXTRA_PATTERNS

    # Save config
    cat > "$CONFIG_FILE" << EOF
# stelmod-debug Configuration
# Generated: $(date)

# Your mod's log prefix (without brackets)
MOD_PREFIX="$MOD_PREFIX"

# Path to Stellaris user data folder
STELLARIS_DOCS="$STELLARIS_DOCS"

# Your mod folder name (for freshness checks)
MOD_FOLDER="$MOD_FOLDER"

# Log file paths
ERROR_LOG="\$STELLARIS_DOCS/logs/error.log"
GAME_LOG="\$STELLARIS_DOCS/logs/game.log"

# Number of lines to show by default
TAIL_LINES=50

# Additional patterns to search for (pipe-separated)
EXTRA_PATTERNS="$EXTRA_PATTERNS"
EOF

    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  ✅ Configuration Saved!${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${CYAN}Test your setup:${NC}"
    echo -e "  ./stelmod-debug.sh all      # Full log check"
    echo -e "  ./stelmod-debug.sh errors   # Just errors"
    echo -e "  ./stelmod-debug.sh game     # Just game log"
    echo ""
}

# ─────────────────────────────────────────────────────────────────────────────
# Command: Errors
# ─────────────────────────────────────────────────────────────────────────────

cmd_errors() {
    check_config || return 1

    print_header
    print_section "🔴 Error Log - Mod-Related Entries"
    echo -e "${GRAY}File: $ERROR_LOG${NC}"
    echo -e "${GRAY}Filter: $MOD_PREFIX (case-insensitive)${NC}"
    echo ""

    if [[ ! -f "$ERROR_LOG" ]]; then
        echo -e "${YELLOW}No error log found. Game may not have been run yet.${NC}"
        return 0
    fi

    local pattern="${MOD_PREFIX,,}"
    local count
    count=$(grep -ic "$pattern" "$ERROR_LOG" 2>/dev/null) || count=0

    if [[ "$count" -eq 0 ]]; then
        echo -e "${GREEN}✅ No errors found matching '$MOD_PREFIX'${NC}"
    else
        echo -e "${RED}Found $count error(s) matching '$MOD_PREFIX':${NC}"
        echo ""
        grep -i "$pattern" "$ERROR_LOG" 2>/dev/null | tail -n "$TAIL_LINES" | while read -r line; do
            if [[ "$line" =~ "Error" ]] || [[ "$line" =~ "ERROR" ]]; then
                echo -e "${RED}$line${NC}"
            elif [[ "$line" =~ "Warning" ]] || [[ "$line" =~ "WARNING" ]]; then
                echo -e "${YELLOW}$line${NC}"
            else
                echo -e "${WHITE}$line${NC}"
            fi
        done
    fi
    echo ""
}

# ─────────────────────────────────────────────────────────────────────────────
# Command: Game
# ─────────────────────────────────────────────────────────────────────────────

cmd_game() {
    check_config || return 1

    print_header
    print_section "🔵 Game Log - Mod Entries"
    echo -e "${GRAY}File: $GAME_LOG${NC}"
    echo -e "${GRAY}Filter: [$MOD_PREFIX]${NC}"
    echo ""

    if [[ ! -f "$GAME_LOG" ]]; then
        echo -e "${YELLOW}No game log found. Game may not have been run yet.${NC}"
        return 0
    fi

    local pattern="\[$MOD_PREFIX\]"
    local count
    count=$(grep -Ec "$pattern" "$GAME_LOG" 2>/dev/null) || count=0

    if [[ "$count" -eq 0 ]]; then
        echo -e "${YELLOW}No entries found matching '[$MOD_PREFIX]'${NC}"
        echo -e "${GRAY}Tip: Run your mod's init event in-game to generate logs${NC}"
    else
        echo -e "${CYAN}Found $count entries matching '[$MOD_PREFIX]':${NC}"
        echo ""
        grep -E "$pattern" "$GAME_LOG" 2>/dev/null | tail -n "$TAIL_LINES" | while read -r line; do
            if [[ "$line" =~ "ERROR" ]] || [[ "$line" =~ "FAIL" ]]; then
                echo -e "${RED}$line${NC}"
            elif [[ "$line" =~ "WARNING" ]] || [[ "$line" =~ "WARN" ]]; then
                echo -e "${YELLOW}$line${NC}"
            elif [[ "$line" =~ "SUCCESS" ]] || [[ "$line" =~ "COMPLETE" ]]; then
                echo -e "${GREEN}$line${NC}"
            elif [[ "$line" =~ "DEBUG" ]]; then
                echo -e "${MAGENTA}$line${NC}"
            else
                echo -e "${WHITE}$line${NC}"
            fi
        done
    fi

    # Check extra patterns
    if [[ -n "$EXTRA_PATTERNS" ]]; then
        echo ""
        print_section "⚠️  Extra Pattern Matches"
        local extra_results
        extra_results=$(grep -E "$EXTRA_PATTERNS" "$GAME_LOG" 2>/dev/null | tail -n 20)
        if [[ -n "$extra_results" ]]; then
            echo -e "${YELLOW}$extra_results${NC}"
        else
            echo -e "${GREEN}No matches for extra patterns${NC}"
        fi
    fi

    echo ""
}

# ─────────────────────────────────────────────────────────────────────────────
# Command: Fresh
# ─────────────────────────────────────────────────────────────────────────────

cmd_fresh() {
    check_config || return 1

    print_header
    print_section "🕐 Log Freshness Check"
    echo ""

    if [[ -f "$GAME_LOG" ]]; then
        local log_time log_date
        if [[ "$(uname)" == "Darwin" ]]; then
            # macOS
            log_time=$(stat -f %m "$GAME_LOG")
            log_date=$(date -r "$log_time" "+%Y-%m-%d %H:%M:%S")
        else
            # Linux
            log_time=$(stat -c %Y "$GAME_LOG")
            log_date=$(date -d "@$log_time" "+%Y-%m-%d %H:%M:%S")
        fi
        echo -e "${CYAN}Game Log:  $log_date${NC}"
    else
        echo -e "${RED}Game log not found${NC}"
        return
    fi

    if [[ -n "$MOD_FOLDER" ]]; then
        local mod_path="$STELLARIS_DOCS/mod/$MOD_FOLDER"
        if [[ -d "$mod_path" ]]; then
            local newest_file mod_time mod_date mod_file

            if [[ "$(uname)" == "Darwin" ]]; then
                # macOS - different find syntax
                newest_file=$(find "$mod_path" -type f -name "*.txt" -exec stat -f "%m %N" {} \; 2>/dev/null | sort -rn | head -1)
                mod_time=$(echo "$newest_file" | awk '{print $1}')
                mod_file=$(echo "$newest_file" | cut -d' ' -f2-)
                mod_date=$(date -r "$mod_time" "+%Y-%m-%d %H:%M:%S" 2>/dev/null)
            else
                # Linux
                newest_file=$(find "$mod_path" -type f -name "*.txt" -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1)
                mod_time=$(echo "$newest_file" | cut -d' ' -f1 | cut -d'.' -f1)
                mod_file=$(echo "$newest_file" | cut -d' ' -f2-)
                mod_date=$(date -d "@$mod_time" "+%Y-%m-%d %H:%M:%S" 2>/dev/null)
            fi

            if [[ -n "$mod_time" ]]; then
                echo -e "${CYAN}Mod Sync:  $mod_date${NC}"
                echo -e "${GRAY}  Latest: $(basename "$mod_file")${NC}"
                echo ""

                if (( log_time > mod_time )); then
                    echo -e "${GREEN}✅ FRESH - Logs are AFTER mod sync${NC}"
                else
                    echo -e "${RED}⚠️  STALE - Logs are BEFORE mod sync${NC}"
                    echo -e "${YELLOW}   Reload game to get fresh logs${NC}"
                fi
            fi
        else
            echo -e "${YELLOW}Mod folder not found: $mod_path${NC}"
        fi
    else
        echo -e "${GRAY}Configure MOD_FOLDER for freshness comparison${NC}"
    fi

    echo ""
}

# ─────────────────────────────────────────────────────────────────────────────
# Command: All
# ─────────────────────────────────────────────────────────────────────────────

cmd_all() {
    cmd_fresh
    echo ""
    cmd_errors
    cmd_game
}

# ─────────────────────────────────────────────────────────────────────────────
# Command: Summary
# ─────────────────────────────────────────────────────────────────────────────

cmd_summary() {
    check_config || return 1

    print_header
    print_section "📊 Log Summary"
    echo ""

    # Count errors
    if [[ -f "$ERROR_LOG" ]]; then
        local error_count
        error_count=$(grep -ic "${MOD_PREFIX,,}" "$ERROR_LOG" 2>/dev/null) || error_count=0
        if [[ "$error_count" -gt 0 ]]; then
            echo -e "${RED}🔴 Errors:      $error_count${NC}"
        else
            echo -e "${GREEN}🟢 Errors:      0${NC}"
        fi
    fi

    # Count game log entries
    if [[ -f "$GAME_LOG" ]]; then
        local game_count
        game_count=$(grep -Ec "\[$MOD_PREFIX\]" "$GAME_LOG" 2>/dev/null) || game_count=0
        echo -e "${CYAN}📝 Log entries: $game_count${NC}"

        if [[ "$game_count" -gt 0 ]]; then
            local warn_count fail_count success_count
            warn_count=$(grep -E "\[$MOD_PREFIX\]" "$GAME_LOG" 2>/dev/null | grep -ic "warning\|warn") || warn_count=0
            fail_count=$(grep -E "\[$MOD_PREFIX\]" "$GAME_LOG" 2>/dev/null | grep -ic "fail\|error") || fail_count=0
            success_count=$(grep -E "\[$MOD_PREFIX\]" "$GAME_LOG" 2>/dev/null | grep -ic "success\|complete") || success_count=0

            echo -e "${YELLOW}⚠️  Warnings:   $warn_count${NC}"
            echo -e "${RED}❌ Failures:   $fail_count${NC}"
            echo -e "${GREEN}✅ Success:    $success_count${NC}"
        fi
    fi

    echo ""
}

# ─────────────────────────────────────────────────────────────────────────────
# Command: Help
# ─────────────────────────────────────────────────────────────────────────────

cmd_help() {
    print_header
    echo -e "${BOLD}USAGE:${NC}"
    echo "  ./stelmod-debug.sh [command] [options]"
    echo ""
    echo -e "${BOLD}COMMANDS:${NC}"
    echo -e "  ${CYAN}setup${NC}     Configure (with GUI folder picker if available)"
    echo -e "  ${CYAN}errors${NC}    Show error log entries for your mod"
    echo -e "  ${CYAN}game${NC}      Show game log entries matching mod prefix"
    echo -e "  ${CYAN}all${NC}       Show freshness + errors + game logs"
    echo -e "  ${CYAN}fresh${NC}     Check if logs are fresh vs mod sync time"
    echo -e "  ${CYAN}summary${NC}   Quick stats on log contents"
    echo -e "  ${CYAN}help${NC}      Show this help message"
    echo ""
    echo -e "${BOLD}OPTIONS:${NC}"
    echo "  -n NUM    Number of lines to show (default: 50)"
    echo ""
    echo -e "${BOLD}EXAMPLES:${NC}"
    echo "  ./stelmod-debug.sh setup         # First-time configuration"
    echo "  ./stelmod-debug.sh all           # Full log check"
    echo "  ./stelmod-debug.sh game -n 100   # Last 100 game log entries"
    echo ""
    echo -e "${BOLD}FIRST TIME?${NC}"
    echo "  Run: ./stelmod-debug.sh setup"
    echo ""
    echo -e "${GRAY}Tip: Install 'zenity' for GUI folder picker on Linux${NC}"
    echo ""
}

# ─────────────────────────────────────────────────────────────────────────────
# Argument Parsing
# ─────────────────────────────────────────────────────────────────────────────

while getopts "n:" opt; do
    case $opt in
        n) TAIL_LINES="$OPTARG" ;;
        *) ;;
    esac
done
shift $((OPTIND-1))

COMMAND="${1:-help}"

case "$COMMAND" in
    setup)   cmd_setup ;;
    errors)  cmd_errors ;;
    game)    cmd_game ;;
    all)     cmd_all ;;
    fresh)   cmd_fresh ;;
    summary) cmd_summary ;;
    help|--help|-h) cmd_help ;;
    *)
        echo -e "${RED}Unknown command: $COMMAND${NC}"
        echo "Run './stelmod-debug.sh help' for usage"
        exit 1
        ;;
esac
