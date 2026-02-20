#!/bin/bash

# ==========================================
# GitHub Sync - Installer
# ==========================================

clear
set -e

# Detect OS
OS="$(uname -s)"

# Define Paths
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_PATH="$REPO_DIR/scripts/github-sync.sh"

echo ""
echo -e "\033[1;36mStarting installation for github-sync...\033[0m"
echo ""

# ---------- Configuration Prompt ----------
CONFIG_DIR="$HOME/.config/github-sync"
CONFIG_FILE="$CONFIG_DIR/config"

mkdir -p "$CONFIG_DIR"

echo -e "\033[1;36mConfigure Repository Paths\033[0m"
echo "By default, GitHub Sync looks in ~/GitHub, ~/Projects, ~/Scripts, and ~/Repositories."
echo "You can specify exactly where your repositories are located."
echo ""

USER_PATHS=""

if [[ "$OS" == "Darwin" ]]; then
    # macOS native AppleScript stateful menu loop
    USER_PATHS=$(osascript -e '
        set userPaths to {}
        repeat
            set pathString to ""
            repeat with p in userPaths
                set pathString to pathString & "• " & p & return
            end repeat
            if pathString is "" then set pathString to "(None selected, will use defaults: ~/GitHub, ~/Projects, ~/Scripts, ~/Repositories)"
            
            try
                set theResult to display dialog "Current Repositories:" & return & return & pathString buttons {"Done", "Clear All", "Add Folder..."} default button "Add Folder..." with title "GitHub Sync Configuration"
                
                if button returned of theResult is "Add Folder..." then
                    set newFolder to choose folder with prompt "Select a repository folder:" default location (path to home folder)
                    set end of userPaths to POSIX path of newFolder
                else if button returned of theResult is "Clear All" then
                    set userPaths to {}
                else if button returned of theResult is "Done" then
                    exit repeat
                end if
            on error
                -- User clicked Cancel or pressed Escape
                exit repeat
            end try
        end repeat
        
        set outString to ""
        repeat with p in userPaths
            set outString to outString & p & ","
        end repeat
        if (length of outString) > 0 then
            return text 1 thru -2 of outString
        else
            return ""
        end if
    ' 2>/dev/null || echo "")
elif [[ "$OS" == "Linux" ]]; then
    # Linux GUI native stateful menu loop
    user_paths_array=()
    if command -v zenity >/dev/null; then
        while true; do
            path_string=""
            for p in "${user_paths_array[@]}"; do
                path_string+="• $p\n"
            done
            if [ -z "$path_string" ]; then
                path_string="(None selected, will use defaults)"
            fi
            
            action=$(zenity --question --title="GitHub Sync Configuration" --text="<b>Current Repositories:</b>\n\n$path_string" --ok-label="Done" --cancel-label="Add Folder..." --extra-button="Clear All" 2>/dev/null)
            ret=$?
            
            if [ "$action" = "Clear All" ]; then
                user_paths_array=()
            elif [ $ret -eq 0 ]; then
                break # Done
            elif [ $ret -eq 1 ]; then
                selected=$(zenity --file-selection --directory --title="Select a repo folder" 2>/dev/null)
                if [ -n "$selected" ]; then
                    user_paths_array+=("$selected")
                fi
            else
                break # Window closed
            fi
        done
    elif command -v kdialog >/dev/null; then
        while true; do
            path_string=""
            for p in "${user_paths_array[@]}"; do
                path_string+="• $p\n"
            done
            if [ -z "$path_string" ]; then
                path_string="(None selected, will use defaults)"
            fi
            
            # Kdialog yesnocancel: 0=Yes(Done), 1=No(Add Folder), 2=Cancel(Clear All), other=closed
            kdialog --yesnocancel "Current Repositories:\n\n$path_string" --yes-label "Done" --no-label "Add Folder..." --cancel-label "Clear All" --title "GitHub Sync Configuration" 2>/dev/null
            ret=$?
            
            if [ $ret -eq 0 ]; then
                break
            elif [ $ret -eq 1 ]; then
                selected=$(kdialog --getexistingdirectory "$HOME" --title "Select a repo folder" 2>/dev/null)
                if [ -n "$selected" ]; then
                    user_paths_array+=("$selected")
                fi
            elif [ $ret -eq 2 ]; then
                user_paths_array=()
            else
                break
            fi
        done
    else
        read -p "Enter custom repository paths (comma separated) or press Enter for defaults: " USER_PATHS
    fi
    
    # Rebuild USER_PATHS from array for Linux
    if [ ${#user_paths_array[@]} -gt 0 ]; then
        USER_PATHS=$(IFS=,; echo "${user_paths_array[*]}")
    fi
fi

if [ -n "$USER_PATHS" ]; then
    > "$CONFIG_FILE"
    IFS=',' read -ra PATH_ARRAY <<< "$USER_PATHS"
    for p in "${PATH_ARRAY[@]}"; do
        # Trim whitespace
        p=$(echo "$p" | xargs)
        if [ -n "$p" ]; then
            echo "$p" >> "$CONFIG_FILE"
        fi
    done
    echo "* Saved custom paths to $CONFIG_FILE"
    echo ""
else
    echo "* Using default paths."
    echo ""
fi

# 1. Make script executable
chmod +x "$SCRIPT_PATH"
echo "* Made script executable"

# 2. Setup CLI symlink
# We prefer ~/.local/bin to avoid sudo requirements, falling back to /usr/local/bin if necessary.
LOCAL_BIN="$HOME/.local/bin"
if [ ! -d "$LOCAL_BIN" ]; then
    mkdir -p "$LOCAL_BIN"
    echo "* Created $LOCAL_BIN"
    # Note: user might need to add ~/.local/bin to their PATH.
fi

ln -sf "$SCRIPT_PATH" "$LOCAL_BIN/github-sync"
echo "* Linked 'github-sync' into $LOCAL_BIN/"

# Check if ~/.local/bin is in PATH, if not recommend adding it
if [[ ":$PATH:" != *":$LOCAL_BIN:"* ]]; then
    echo -e "\033[1;33m⚠️  Warning: $LOCAL_BIN is not in your PATH.\033[0m"
    if [[ "$OS" == "Darwin" ]]; then
        echo -e "Add this to your ~/.zshrc or ~/.bash_profile: \033[1;32mexport PATH=\"\$HOME/.local/bin:\$PATH\"\033[0m"
    else
        echo -e "Add this to your ~/.bashrc or ~/.profile: \033[1;32mexport PATH=\"\$HOME/.local/bin:\$PATH\"\033[0m"
    fi
fi

# 3. Handle OS-specific App Wrappers
if [[ "$OS" == "Darwin" ]]; then
    # Generate macOS Application Wrapper
    APP_NAME="GitHub Sync.app"
    echo "* Detected macOS. Generating $APP_NAME..."
    
    # We create a simple AppleScript application that binds to our script.
    APP_DIR="$REPO_DIR/$APP_NAME"
    osacompile -o "$APP_DIR" -e "tell application \"Terminal\"" -e "activate" -e "do script \"'$SCRIPT_PATH'\"" -e "end tell"
    
    # Replace default AppleScript icon with native Terminal icon
    if [ -f "/System/Applications/Utilities/Terminal.app/Contents/Resources/Terminal.icns" ]; then
        cp "/System/Applications/Utilities/Terminal.app/Contents/Resources/Terminal.icns" "$APP_DIR/Contents/Resources/applet.icns"
        touch "$APP_DIR"
    fi
    
    echo "* Created macOS application at $APP_DIR"
    echo "* You can drag this into your /Applications folder or run via Spotlight."

elif [[ "$OS" == "Linux" ]]; then
    # Generate Linux .desktop Entry
    echo "* Detected Linux. Generating .desktop entry..."
    DESKTOP_ENTRY_DIR="$HOME/.local/share/applications"
    mkdir -p "$DESKTOP_ENTRY_DIR"
    
    DESKTOP_FILE="$DESKTOP_ENTRY_DIR/github-sync.desktop"
    
    cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=GitHub Sync
Comment=Synchronize all local GitHub repositories
Exec=$SCRIPT_PATH
Icon=utilities-terminal
Terminal=true
Categories=Utility;Development;
Keywords=git;github;sync;repository;
EOF

    chmod +x "$DESKTOP_FILE"
    echo "* Created application shortcut at $DESKTOP_FILE"
fi

echo ""
echo -e "\033[1;32m✅ Installation Complete!\033[0m"
echo "You can now run 'github-sync' from anywhere."
echo ""
