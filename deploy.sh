#!/usr/bin/env bash
# debian-deploy: app loadout for a fresh Debian 13 desktop. DE-agnostic, safe to re-run.
set -euo pipefail

[ "$(id -u)" -ne 0 ] || { echo "Run as your normal user, not root." >&2; exit 1; }
. /etc/os-release
[ "${ID:-}" = "debian" ] || { echo "This script is for Debian." >&2; exit 1; }

APT_PKGS=(
  git curl wget flatpak
  chromium
  libreoffice meld vlc kdenlive obs-studio
  ffmpeg vainfo
  fastfetch duf
)

FLATPAKS=(
  com.discordapp.Discord
  io.gitlab.librewolf-community
  org.localsend.localsend_app
  org.telegram.desktop
)

echo "==> Adding Brave's apt repo..."
sudo apt-get update
sudo apt-get install -y curl ca-certificates
sudo curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg \
  https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg arch=amd64] https://brave-browser-apt-release.s3.brave.com/ stable main" \
  | sudo tee /etc/apt/sources.list.d/brave-browser-release.list >/dev/null

echo "==> Installing apt packages..."
sudo apt-get update
sudo apt-get install -y brave-browser "${APT_PKGS[@]}"

echo "==> Installing Flatpaks..."
sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
FAILED=()
for app in "${FLATPAKS[@]}"; do
  flatpak info "$app" &>/dev/null && continue
  sudo flatpak install -y --noninteractive flathub "$app" </dev/null || FAILED+=("$app")
done

echo
if [ ${#FAILED[@]} -gt 0 ]; then
  echo "Done, but these Flatpaks failed: ${FAILED[*]}"
else
  echo "Done. Log out and back in so Flatpak apps show up in your menu."
fi
