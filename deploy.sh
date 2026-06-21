#!/usr/bin/env bash
#
# Debian Baseline Deployment Script
# https://github.com/<your-username>/<your-repo>
#
# Run this AFTER first boot into a fresh Debian install (GNOME desktop).
# Equivalent in outcome to the EndeavourOS deployment script, but the
# mechanics are genuinely different — Debian has no AUR equivalent, so
# each non-repo browser gets its own official apt source added manually.
#
# Usage:
#   chmod +x deploy.sh
#   ./deploy.sh
#
# Safe to re-run. Existing repo sources and installed packages are
# detected and skipped rather than re-added/reinstalled.

set -euo pipefail

# ── Colour output helpers ────────────────────────────────────────────────
BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
RESET='\033[0m'

info()  { echo -e "${BOLD}${GREEN}==>${RESET} $1"; }
warn()  { echo -e "${BOLD}${YELLOW}==>${RESET} $1"; }
error() { echo -e "${BOLD}${RED}==>${RESET} $1" >&2; }

# ── Sanity checks ─────────────────────────────────────────────────────────
if [ "$(id -u)" -eq 0 ]; then
  error "Don't run this as root. Run as your normal user — it calls sudo where needed."
  exit 1
fi

if ! command -v apt &> /dev/null; then
  error "apt not found. This script is for Debian-based systems."
  exit 1
fi

echo ""
echo -e "${BOLD}Debian Baseline Deployment${RESET}"
echo "──────────────────────────────────────────"
echo ""

# ── Phase 1: CPU vendor detection ─────────────────────────────────────────
info "Detecting CPU vendor..."

CPU_VENDOR=$(grep -m1 'vendor_id' /proc/cpuinfo | awk '{print $3}')
UCODE_PKG=""

case "$CPU_VENDOR" in
  GenuineIntel)
    UCODE_PKG="intel-microcode"
    info "Detected: Intel CPU → will install intel-microcode"
    ;;
  AuthenticAMD)
    UCODE_PKG="amd64-microcode"
    info "Detected: AMD CPU → will install amd64-microcode"
    ;;
  *)
    warn "Could not determine CPU vendor (got: '${CPU_VENDOR:-unknown}'). Skipping microcode package."
    ;;
esac

echo ""
warn "intel-microcode / amd64-microcode live in Debian's 'non-free-firmware' component."
warn "If your /etc/apt/sources.list doesn't already include it, this step will fail to find the package."
warn "Fix: add 'non-free-firmware' alongside 'main' in your sources.list, then re-run 'sudo apt update'."

echo ""

# ── Phase 2: Update package index ─────────────────────────────────────────
info "Refreshing package index..."
sudo apt update

echo ""

# ── Phase 3: Native toolkit (official repos only) ────────────────────────
info "Installing native toolkit (official Debian repos)..."

PACKAGES=(
  build-essential
  git
  curl
  wget
  gnupg
  firefox-esr
  telegram-desktop
  shotcut
  gimp
  glances
  flatpak
)

if [ -n "$UCODE_PKG" ]; then
  PACKAGES+=("$UCODE_PKG")
fi

sudo apt install -y "${PACKAGES[@]}"

echo ""
info "Note: this installs firefox-esr (Debian's standard Firefox package), not the"
info "vanilla 'firefox' package — that's expected and matches Debian convention."

echo ""

# ── Phase 4: Tools not in Debian stable — fetched directly ───────────────
# fastfetch and duf are not packaged in Debian 12 (Bookworm) stable repos.
# Both are fetched as standalone .deb releases from their GitHub pages
# rather than added as a third-party apt repo, since neither publishes one.

info "Installing fastfetch (not in Debian stable — fetching .deb directly)..."

if command -v fastfetch &> /dev/null; then
  info "fastfetch already installed, skipping."
else
  FASTFETCH_DEB=$(mktemp --suffix=.deb)
  FASTFETCH_URL=$(curl -fsSL https://api.github.com/repos/fastfetch-cli/fastfetch/releases/latest \
    | grep -oP '"browser_download_url":\s*"\K[^"]*linux-amd64\.deb')
  if [ -z "$FASTFETCH_URL" ]; then
    warn "Could not auto-detect the latest fastfetch .deb URL. Skipping — install manually from:"
    warn "https://github.com/fastfetch-cli/fastfetch/releases"
  else
    curl -fsSL -o "$FASTFETCH_DEB" "$FASTFETCH_URL"
    sudo apt install -y "$FASTFETCH_DEB"
    rm -f "$FASTFETCH_DEB"
  fi
fi

echo ""
info "Installing duf (not in Debian stable — fetching .deb directly)..."

if command -v duf &> /dev/null; then
  info "duf already installed, skipping."
else
  DUF_DEB=$(mktemp --suffix=.deb)
  DUF_URL=$(curl -fsSL https://api.github.com/repos/muesli/duf/releases/latest \
    | grep -oP '"browser_download_url":\s*"\K[^"]*linux_amd64\.deb')
  if [ -z "$DUF_URL" ]; then
    warn "Could not auto-detect the latest duf .deb URL. Skipping — install manually from:"
    warn "https://github.com/muesli/duf/releases"
  else
    curl -fsSL -o "$DUF_DEB" "$DUF_URL"
    sudo apt install -y "$DUF_DEB"
    rm -f "$DUF_DEB"
  fi
fi

echo ""
info "Skipping tldr — Debian's apt package is named 'node-tldr' and pulls in Node.js as"
info "a dependency. If you want it, run: sudo apt install node-tldr"
info "Alternative with no Node dependency: pip install tldr (or pipx install tldr)"

echo ""

# ── Phase 5: Flathub remote ────────────────────────────────────────────────
info "Setting up Flathub remote..."

flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

echo ""

# ── Phase 6: Browser stack ─────────────────────────────────────────────────
# Debian has no AUR equivalent. Each browser is added as its own official
# apt repository with its own signing key, then installed normally.

info "Installing browser stack (Chrome, Brave, Edge)..."

# --- Google Chrome ---
if command -v google-chrome &> /dev/null; then
  info "Google Chrome already installed, skipping."
else
  info "Installing Google Chrome (direct .deb, no repo — matches Google's own instructions)..."
  CHROME_DEB=$(mktemp --suffix=.deb)
  curl -fsSL -o "$CHROME_DEB" "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb"
  sudo apt install -y "$CHROME_DEB"
  rm -f "$CHROME_DEB"
fi

# --- Brave ---
if command -v brave-browser &> /dev/null; then
  info "Brave already installed, skipping."
else
  info "Adding Brave's official apt repository..."
  sudo curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg \
    https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
  echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg arch=amd64] https://brave-browser-apt-release.s3.brave.com/ stable main" \
    | sudo tee /etc/apt/sources.list.d/brave-browser-release.list > /dev/null
  sudo apt update
  sudo apt install -y brave-browser
fi

# --- Microsoft Edge ---
if command -v microsoft-edge-stable &> /dev/null; then
  info "Microsoft Edge already installed, skipping."
else
  info "Adding Microsoft's official apt repository..."
  curl -fsSL https://packages.microsoft.com/keys/microsoft.asc \
    | sudo gpg --dearmor -o /usr/share/keyrings/microsoft-edge-keyring.gpg
  echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft-edge-keyring.gpg] https://packages.microsoft.com/repos/edge stable main" \
    | sudo tee /etc/apt/sources.list.d/microsoft-edge.list > /dev/null
  sudo apt update
  sudo apt install -y microsoft-edge-stable
fi

echo ""

# ── Phase 7: Wayland environment variable (Firefox/Mozilla engine) ───────
info "Configuring Wayland for Mozilla-engine browsers..."

if grep -q "MOZ_ENABLE_WAYLAND" /etc/environment 2>/dev/null; then
  info "MOZ_ENABLE_WAYLAND already set in /etc/environment, skipping."
else
  echo "MOZ_ENABLE_WAYLAND=1" | sudo tee -a /etc/environment > /dev/null
  info "Added MOZ_ENABLE_WAYLAND=1 to /etc/environment (takes effect next login)."
fi

warn "Chromium browsers (Chrome/Brave/Edge) need their Wayland flag set manually per-browser."
warn "chrome://flags/#ozone-platform-hint  →  switch to Wayland  →  Relaunch."
warn "Same flag URL pattern for brave:// and edge:// — one-time per browser."

echo ""

# ── Phase 8: Split-update workflow scripts + GNOME launchers ─────────────
info "Setting up split-update workflow..."

mkdir -p "$HOME/.local/bin" "$HOME/.local/share/applications"

# --- Core system updater (apt-managed packages only) ---
cat << 'SCRIPT_EOF' > "$HOME/.local/bin/update-core.sh"
#!/usr/bin/env bash
clear
echo "========================================="
echo "  UPGRADING APT-MANAGED PACKAGES"
echo "========================================="
echo "==> Refreshing package index..."
sudo apt update
echo ""
echo "==> Upgrading installed packages..."
sudo apt upgrade -y
echo ""
echo "==> Checking for orphaned dependencies..."
sudo apt autoremove --dry-run
echo ""
echo "(Run 'sudo apt autoremove' manually if the above list looks safe to clear.)"
echo ""
echo "Press Enter to close..."
read -r
SCRIPT_EOF

# --- Application layer updater (Flatpak only — no AUR equivalent exists) ---
cat << 'SCRIPT_EOF' > "$HOME/.local/bin/update-apps.sh"
#!/usr/bin/env bash
clear
echo "========================================="
echo "  UPGRADING FLATPAKS"
echo "========================================="
echo "==> Updating Flatpaks..."
if command -v flatpak &> /dev/null; then
    flatpak update -y
fi
echo ""
echo "Note: there is no AUR equivalent on Debian. Browsers installed via"
echo "third-party apt repos (Brave, Edge) are updated automatically by"
echo "'Update System' above, since they're tracked by apt once their repo"
echo "is added. Chrome's direct .deb install also self-updates via its own"
echo "added apt source after first install."
echo ""
echo "Press Enter to close..."
read -r
SCRIPT_EOF

chmod +x "$HOME/.local/bin/update-core.sh" "$HOME/.local/bin/update-apps.sh"

# --- Detect terminal emulator for the .desktop Exec= line ---
if command -v gnome-terminal &> /dev/null; then
    TERM_EXEC="gnome-terminal --"
elif command -v kgx &> /dev/null; then
    TERM_EXEC="kgx -e"
else
    TERM_EXEC="bash -c"
fi

# --- Core updater launcher ---
# Unquoted heredoc (EOF, not 'EOF') is intentional — $TERM_EXEC and $HOME
# need to expand to real values now, since .desktop files are static text.
cat << EOF > "$HOME/.local/share/applications/update-system.desktop"
[Desktop Entry]
Version=1.0
Type=Application
Name=Update System (APT)
Comment=Updates all apt-managed packages, including third-party browser repos
Exec=$TERM_EXEC "$HOME/.local/bin/update-core.sh"
Terminal=false
Icon=system-software-update
Categories=System;Settings;
Keywords=update;upgrade;apt;system;
EOF

# --- App layer updater launcher ---
cat << EOF > "$HOME/.local/share/applications/update-apps.desktop"
[Desktop Entry]
Version=1.0
Type=Application
Name=Update Apps (Flatpak)
Comment=Updates sandboxed Flatpak applications
Exec=$TERM_EXEC "$HOME/.local/bin/update-apps.sh"
Terminal=false
Icon=software-update-available
Categories=System;Settings;
Keywords=update;upgrade;flatpak;apps;
EOF

update-desktop-database "$HOME/.local/share/applications/" 2>/dev/null || true

echo ""
info "Deployment complete."
echo ""
echo "Next steps:"
echo "  1. Log out and back in (applies MOZ_ENABLE_WAYLAND)."
echo "  2. Set the Wayland flag in each Chromium browser (chrome/brave/edge://flags/#ozone-platform-hint)."
echo "  3. Press Super, search 'Update', confirm both launchers appear."
echo "  4. If you want tldr: 'sudo apt install node-tldr' or 'pip install tldr'."
echo ""
