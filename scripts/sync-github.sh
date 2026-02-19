#!/bin/bash

# ==========================================
# Modern GitHub Repository Sync Utility
# ==========================================

DEFAULT_DIRS=(
    "$HOME/GitHub"
    "$HOME/Scripts"
)

BASE_DIRS=("${@:-${DEFAULT_DIRS[@]}}")

OS="$(uname -s)"

# ---------- Colors ----------
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
CYAN="\033[1;36m"
RESET="\033[0m"

# ---------- Collect repos ----------
repos=()

for base in "${BASE_DIRS[@]}"; do
    [ -d "$base" ] || continue
    for d in "$base"/*/; do
        [ -d "$d/.git" ] && repos+=("$d")
    done
done

total=${#repos[@]}

# Safety check
if [ "$total" -eq 0 ]; then
    echo -e "${YELLOW}⚠️  No Git repositories found in configured directories.${RESET}"
    exit 0
fi

# ---------- Header ----------
echo -e "${BLUE}🚀  Syncing GitHub Repositories${RESET}"
echo ""

count=1

for repo in "${repos[@]}"; do
    REPO_NAME=$(basename "$repo")
    printf "[%d/%d] %s " "$count" "$total" "$REPO_NAME"

    cd "$repo" || {
        echo -e "${YELLOW}⚠️  Unable to access repository${RESET}"
        ((count++))
        continue
    }

    # Convert HTTPS → SSH if needed
    current_url=$(git remote get-url origin 2>/dev/null)
    if [[ "$current_url" == https://github.com/* ]]; then
        ssh_url=$(echo "$current_url" | sed 's|https://github.com/|git@github.com:|')
        git remote set-url origin "$ssh_url"
    fi

    # Detect uncommitted changes
    modified_files=$(git status --porcelain | wc -l | tr -d ' ')

    if [ "$modified_files" -gt 0 ]; then
        printf "... ${YELLOW}⚠️  %s modified file(s) — sync skipped${RESET}\n" "$modified_files"
        ((count++))
        continue
    fi

    before_commit=$(git rev-parse HEAD 2>/dev/null)

    {
        git pull --rebase >/dev/null 2>&1
    } &
    pid=$!

    DOTS=1
    while kill -0 $pid 2>/dev/null; do
        dots=$(printf "%0.s." $(seq 1 $DOTS))
        printf "\r[%d/%d] %s %s" "$count" "$total" "$REPO_NAME" "$dots"
        DOTS=$((DOTS+1))
        [ $DOTS -gt 3 ] && DOTS=1
        sleep 0.4
    done

    wait $pid
    RESULT=$?

    after_commit=$(git rev-parse HEAD 2>/dev/null)

    if [ $RESULT -ne 0 ]; then
        printf "\r[%d/%d] %s ... ${YELLOW}⚠️  pull failed${RESET}\n" \
        "$count" "$total" "$REPO_NAME"
    elif [ "$before_commit" = "$after_commit" ]; then
        printf "\r[%d/%d] %s ... ${GREEN}✅ already up to date${RESET}\n" \
        "$count" "$total" "$REPO_NAME"
    else
        commit_count=$(git rev-list --count "$before_commit..$after_commit")
        file_count=$(git diff --name-only "$before_commit..$after_commit" | wc -l | tr -d ' ')

        printf "\r[%d/%d] %s ... ${CYAN}⬇ pulled %s commit(s) affecting %s file(s) — now synced${RESET}\n" \
        "$count" "$total" "$REPO_NAME" "$commit_count" "$file_count"
    fi

    ((count++))
done

echo ""
echo -e "${BLUE}🎉  Repository sync complete.${RESET}"

if [[ "$OS" == "Darwin" ]]; then
    osascript -e 'display notification "Repository sync complete." with title "Sync Repos"'
elif [[ "$OS" == "Linux" ]]; then
    if command -v notify-send >/dev/null; then
        notify-send "Sync Repos" "Repository sync complete."
    fi
fi
