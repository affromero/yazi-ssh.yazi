#!/usr/bin/env bash
# install.sh — install yazi-ssh (plugin + wrapper + right-click handler)
set -euo pipefail

REPO="affromero/yazi-ssh"
BIN_DIR="${HOME}/.local/bin"
INIT_LUA="${HOME}/.config/yazi/init.lua"

echo "Installing yazi-ssh..."
echo ""

# ------------------------------------------------------------------
# 1. Plugin (context menu)
# ------------------------------------------------------------------
if command -v ya &>/dev/null; then
    echo "[1/4] Installing context menu plugin..."
    ya pkg add "$REPO" 2>/dev/null && echo "  Installed via ya pkg" \
        || { ya pkg upgrade "$REPO" 2>/dev/null && echo "  Upgraded via ya pkg"; }
else
    echo "[1/4] 'ya' not found — install yazi first, then re-run."
    echo "  https://yazi-rs.github.io/docs/installation/"
    exit 1
fi

# ------------------------------------------------------------------
# 2. Wrapper script
# ------------------------------------------------------------------
echo "[2/4] Installing yazi-ssh wrapper..."
mkdir -p "$BIN_DIR"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cp "$SCRIPT_DIR/bin/yazi-ssh" "$BIN_DIR/yazi-ssh"
chmod +x "$BIN_DIR/yazi-ssh"
echo "  Installed to $BIN_DIR/yazi-ssh"

# Ensure ~/.local/bin is in PATH
if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    echo ""
    echo "  Add to your shell rc:"
    echo "    export PATH=\"\$HOME/.local/bin:\$PATH\""
    echo ""
fi

# ------------------------------------------------------------------
# 3. Right-click handler in init.lua
# ------------------------------------------------------------------
echo "[3/4] Configuring right-click handler..."
mkdir -p "$(dirname "$INIT_LUA")"
touch "$INIT_LUA"

if grep -q "yazi-ssh" "$INIT_LUA" 2>/dev/null; then
    echo "  Already configured in $INIT_LUA"
else
    cat >> "$INIT_LUA" << 'EOF'

-- Right-click context menu (yazi-ssh)
-- https://github.com/afromero/yazi-ssh
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
EOF
    echo "  Added right-click handler to $INIT_LUA"
fi

# ------------------------------------------------------------------
# 4. Check sshfs
# ------------------------------------------------------------------
echo "[4/4] Checking sshfs..."
if command -v sshfs &>/dev/null; then
    echo "  sshfs: $(sshfs -V 2>&1 | head -1)"
else
    echo ""
    echo "  sshfs not found. Install it for remote browsing:"
    echo "    macOS:  brew install macfuse sshfs"
    echo "    Ubuntu: sudo apt install sshfs"
    echo "    Arch:   sudo pacman -S sshfs"
    echo ""
    echo "  The context menu plugin works without sshfs (local files only)."
fi

# ------------------------------------------------------------------
# Done
# ------------------------------------------------------------------
echo ""
echo "Done! Restart yazi to activate."
echo ""
echo "Usage:"
echo "  Right-click any file/folder in yazi for the context menu"
echo "  yazi-ssh user@host:~/path    # browse remote filesystem"
echo "  yazi-ssh -i key.pem user@host:~/Code"
