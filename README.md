# Sync GitHub

A highly polished, reliable, and OS-aware shell utility to aggressively synchronize multiple local GitHub repositories at once.

## Features
- **Parallel Fetching:** Iterates and pulls repositories concurrently.
- **Dynamic Configuration:** Automatically rewrites HTTPS remotes to SSH to circumvent authentication limits and bypass hardcoded user parameters.
- **Fail-safes:** Detects and skips synchronization for repositories with uncommitted changes to prevent overwriting your work.
- **Native Notifications:** Displays OS-level graphical notifications upon completion (macOS and Linux).
- **Universal Installer:** Ships with an automated, one-step installer.

## Requirements
- `git`
- `bash`

## Installation
Ensure you are in the root directory of this repository and simply run the `install.sh` script:

```bash
./install.sh
```

**The installer will automatically:**
1. Make the core script executable.
2. Link the CLI utility to your path (`~/.local/bin/sync-github`), allowing you to invoke it from anywhere.
3. Generate a Spotlight-searchable macOS wrapper (`Sync GitHub.app`) or a launcher `.desktop` shortcut on Linux.

## Usage
By default, running `sync-github` expects repositories in `~/GitHub` or `~/Scripts`.

```bash
sync-github
```

**Custom Paths:**
You can override the default paths on the fly by passing the parent directories as arguments:

```bash
sync-github ~/Projects ~/Work
```
