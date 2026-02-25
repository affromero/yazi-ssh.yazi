# yazi-ssh

Browse remote filesystems in [yazi](https://github.com/sxyazi/yazi) over SSH — like VS Code Remote, but in your terminal.

Right-click any file or folder to open, download, or copy its path.

## Features

- **SSH browsing** — mount remote filesystems via `sshfs` and browse them natively in yazi
- **Right-click context menu** — the first context menu plugin for any terminal file manager
- **Download** — copy remote files/folders to your local `~/Downloads` (or any configured directory)
- **Copy paths** — absolute, relative, or filename to clipboard
- **Works locally too** — the context menu works on local files without SSH

## Context menu

Right-click a file or folder (or press `m`) to open the menu:

| Key | Action | Description |
|-----|--------|-------------|
| `o` | Open | Open with default program |
| `O` | Open with... | Choose which program to open with |
| `c` | Copy path | Absolute path (or remote path in SSH mode) |
| `r` | Copy relative path | Relative to current directory |
| `n` | Copy filename | Just the filename |
| `d` | Download | Copy to `~/Downloads` |

In SSH mode, "Copy path" returns the real remote path (e.g., `user@host:~/Code/file.py`), not the local mount path.

## Requirements

- [yazi](https://yazi-rs.github.io/docs/installation/) >= 25.2
- [sshfs](https://github.com/libfuse/sshfs) (only needed for remote browsing)

### Installing sshfs

**macOS:**
```bash
brew install macfuse sshfs
```

**Ubuntu/Debian:**
```bash
sudo apt install sshfs
```

**Arch Linux:**
```bash
sudo pacman -S sshfs
```

## Installation

### Full install (SSH + context menu)

```bash
git clone https://github.com/afromero/yazi-ssh.git /tmp/yazi-ssh
bash /tmp/yazi-ssh/install.sh
```

This installs:
1. The context menu plugin (via `ya pkg`)
2. The `yazi-ssh` wrapper script to `~/.local/bin/`
3. Right-click handler in `~/.config/yazi/init.lua`

### Plugin only (context menu without SSH)

If you just want the right-click context menu for local files:

```bash
ya pkg add afromero/yazi-ssh
```

Then add the right-click handler to `~/.config/yazi/init.lua`:

```lua
-- Right-click context menu (yazi-ssh)
local original_entity_click = Entity.click
function Entity:click(event, up)
	if up or event.is_middle then
		return
	end
	ya.emit("reveal", { self._file.url })
	if event.is_right then
		ya.emit("plugin", { "yazi-ssh" })
	else
		original_entity_click(self, event, up)
	end
end
```

And optionally add a keyboard shortcut in `~/.config/yazi/keymap.toml`:

```toml
[[mgr.prepend_keymap]]
on   = "m"
run  = "plugin yazi-ssh"
desc = "Context menu"
```

## Usage

### Remote browsing

```bash
# Basic
yazi-ssh user@myserver

# With SSH key and remote path
yazi-ssh -i ~/.ssh/key.pem ubuntu@ec2-host:~/Code

# Custom port
yazi-ssh -p 2222 user@host:/var/www

# Download to a custom directory
yazi-ssh -d ~/Desktop user@host:~/projects
```

### Local context menu

Just right-click any file or folder in yazi, or press `m`.

## Configuration

### Download directory

Default: `~/Downloads`

Set via environment variable:

```bash
export YAZI_SSH_DOWNLOAD_DIR="$HOME/Desktop"
```

Or pass `-d` to the wrapper:

```bash
yazi-ssh -d ~/Desktop user@host:~/Code
```

### sshfs options

Pass extra sshfs/SSH options with `-o`:

```bash
yazi-ssh -o "Compression=yes" -o "Ciphers=aes128-ctr" user@host:~/Code
```

## How it works

### SSH browsing

`yazi-ssh` is a thin wrapper that:

1. Mounts the remote filesystem locally via `sshfs` (FUSE)
2. Sets environment variables so the plugin knows we're in SSH mode
3. Launches yazi pointed at the mount
4. Unmounts and cleans up on exit

Since the remote filesystem is mounted locally, all yazi features work natively — image previews, file search, bulk operations, etc. "Download" is just a local `cp` from the mount to your downloads folder.

### Context menu

The plugin uses `ya.which()` to show a key-based selection menu. Right-click is intercepted by overriding `Entity:click()` in `init.lua` to dispatch to the plugin instead of the default "open" action.

### Environment variables

These are set automatically by the `yazi-ssh` wrapper. The plugin reads them to detect SSH mode:

| Variable | Description |
|----------|-------------|
| `YAZI_SSH_REMOTE` | Remote host (e.g., `user@host`) |
| `YAZI_SSH_REMOTE_PATH` | Remote base path (e.g., `~/Code`) |
| `YAZI_SSH_MOUNT` | Local mount point |
| `YAZI_SSH_DOWNLOAD_DIR` | Download destination |

## License

MIT
