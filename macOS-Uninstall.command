#!/bin/bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$DIR/scripts/uninstall.sh"

echo ""
read -p "   Press [Enter] to exit..."
WIN_ID=$(osascript -e 'tell application "Terminal" to get id of front window' 2>/dev/null)
DISABLE_BASH=0
DISABLE_ZSH=0
[ ! -e ~/.bash_sessions_disable ] && touch ~/.bash_sessions_disable && DISABLE_BASH=1
[ ! -e ~/.zsh_sessions_disable ] && touch ~/.zsh_sessions_disable && DISABLE_ZSH=1

if [ -n "$WIN_ID" ]; then
    nohup bash -c "sleep 0.5; [ $DISABLE_BASH -eq 1 ] && rm -f ~/.bash_sessions_disable; [ $DISABLE_ZSH -eq 1 ] && rm -f ~/.zsh_sessions_disable; osascript -e 'tell application \"Terminal\" to close (every window whose id is $WIN_ID)'" >/dev/null 2>&1 </dev/null &
fi
exit 0
