# stelmod-debug

**Universal Stellaris Mod Log Analyzer**

A cross-platform tool for Stellaris mod developers to quickly check logs for errors, filter by mod prefix, and validate log freshness.

## Features

- **Cross-Platform** - Works on Windows, Linux, and macOS
- **GUI Setup** - Folder picker for easy configuration
- **Auto-Detection** - Finds Stellaris folder in common locations
- **Error Scanning** - Find script errors for your mod
- **Game Log Filtering** - Filter by your mod's prefix (e.g., `[MYMOD]`)
- **Timestamp Validation** - Check if logs are fresh after mod sync
- **Color-Coded Output** - Errors, warnings, success highlighted

---

## Quick Start

### Windows

1. Download/extract the `stelmod-debug` folder
2. Double-click `stelmod-debug.bat`
3. Run `stelmod-debug.bat setup` to configure
4. Use `stelmod-debug.bat all` to check logs

### Linux / macOS

```bash
# 1. Download/extract the folder
cd stelmod-debug

# 2. Make executable
chmod +x stelmod-debug.sh

# 3. Run setup (GUI folder picker if zenity/kdialog installed)
./stelmod-debug.sh setup

# 4. Check your logs
./stelmod-debug.sh all
```

---

## Commands

| Command | Description |
|---------|-------------|
| `setup` | Interactive configuration with folder picker |
| `errors` | Show error.log entries for your mod |
| `game` | Show game.log entries matching your prefix |
| `all` | Show freshness + errors + game logs |
| `fresh` | Check if logs are newer than your mod files |
| `summary` | Quick stats on log contents |
| `help` | Show help message |

---

## Usage Examples

### Windows (Command Prompt or PowerShell)
```cmd
stelmod-debug.bat setup      # First-time configuration
stelmod-debug.bat all        # Full log check
stelmod-debug.bat errors     # Just errors
stelmod-debug.bat game       # Just game log
```

### Linux / macOS
```bash
./stelmod-debug.sh setup     # First-time configuration
./stelmod-debug.sh all       # Full log check
./stelmod-debug.sh game -n 100   # Last 100 game log entries
```

---

## Auto-Detected Paths

The tool automatically searches these common locations:

### Windows
- `Documents\Paradox Interactive\Stellaris`
- `OneDrive\Documents\Paradox Interactive\Stellaris`
- `D:\Documents\Paradox Interactive\Stellaris`

### Linux
- `~/.local/share/Paradox Interactive/Stellaris` (Steam)
- `~/.paradoxinteractive/Stellaris` (GOG)

### macOS
- `~/Documents/Paradox Interactive/Stellaris`
- `~/Library/Application Support/Paradox Interactive/Stellaris`

If your folder isn't auto-detected, the setup wizard lets you browse or enter the path manually.

---

## Configuration

After running `setup`, configuration is saved:

- **Windows:** `config.json` (JSON format)
- **Linux/macOS:** `config.sh` (Shell format)

### Settings

| Setting | Description |
|---------|-------------|
| `ModPrefix` | Your log prefix (e.g., "MYMOD" for `[MYMOD]`) |
| `StellarisDocs` | Path to Stellaris user data folder |
| `ModFolder` | Your mod's folder name (for freshness check) |
| `TailLines` | Number of log lines to show (default: 50) |
| `ExtraPatterns` | Additional keywords to highlight |

---

## Output Colors

The tool color-codes output for quick scanning:

| Color | Meaning |
|-------|---------|
| 🔴 Red | Errors, failures |
| 🟡 Yellow | Warnings |
| 🟢 Green | Success, completions |
| 🟣 Magenta | Debug messages |
| 🔵 Cyan | Info, headers |
| ⚪ Gray | Context, hints |

---

## Tips for Mod Developers

### 1. Use Consistent Log Prefixes

In your mod scripts, always use the same prefix:

```pdx
# Good - consistent prefix
log = "[MYMOD] Initializing..."
log = "[MYMOD] Spawned 5 ships"
log = "[MYMOD] ERROR: Something failed"

# Bad - inconsistent
log = "MyMod: Starting..."
log = "[MY_MOD] Did something"
```

### 2. Log Important Events

```pdx
# Initialization
log = "[MYMOD] === INITIALIZATION STARTED ==="

# Key decisions
log = "[MYMOD] Selected destination: [solar_system.GetName]"

# Errors with context
log = "[MYMOD] ERROR: Fleet [This.GetName] has no owner!"
```

### 3. Use Extra Patterns

Add important keywords to highlight:
- Windows: Edit `config.json`, add to `ExtraPatterns` array
- Linux: Edit `config.sh`, set `EXTRA_PATTERNS="FALLBACK|DIRECT|ORPHAN"`

---

## Log Freshness

The "fresh" check compares:
1. Your mod folder's newest file timestamp
2. The game.log modification time

If the log is older than your mod files, you're looking at **stale logs** from before your latest changes. Reload the game!

---

## Troubleshooting

### "No Stellaris folder auto-detected"
- Make sure you've run Stellaris at least once
- Use the folder browser or enter path manually
- Check that the folder contains `logs` and `mod` subfolders

### "No entries found matching [MYMOD]"
- Run your mod's initialization event in-game
- Check your log prefix is correct (exact match, case-sensitive)
- Verify logs aren't from a previous session (run `fresh` command)

### Windows: "Execution Policy" error
Run PowerShell as Administrator and execute:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Linux: GUI folder picker not working
Install zenity (GTK) or kdialog (KDE):
```bash
# Ubuntu/Debian
sudo apt install zenity

# Fedora
sudo dnf install zenity

# Arch
sudo pacman -S zenity
```

---

## Files

```
stelmod-debug/
├── stelmod-debug.bat     # Windows launcher (double-click)
├── stelmod-debug.ps1     # Windows PowerShell script
├── stelmod-debug.sh      # Linux/macOS bash script
├── config.json           # Windows config (created by setup)
├── config.sh             # Linux config (created by setup)
├── config.example.sh     # Example config template
├── README.md             # This file
└── .gitignore            # Excludes personal configs
```

---

## License

MIT - Use freely for any Stellaris modding project.

---

**Made for the Stellaris modding community** 🚀
