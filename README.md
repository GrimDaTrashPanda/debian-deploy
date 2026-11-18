# debian-deploy

App loadout for a fresh Debian 13 (Trixie) desktop. Works on any desktop environment.

## Usage

Run as your normal user, not root:

    sudo apt install -y curl && bash <(curl -fsSL https://raw.githubusercontent.com/GrimDaTrashPanda/debian-deploy/main/deploy.sh)

Safe to re-run.

## What it installs

- **apt:** chromium, libreoffice, meld, vlc, kdenlive, obs-studio, ffmpeg, vainfo, fastfetch, duf, git, curl, wget, flatpak
- **Brave's official apt repo:** brave-browser (native, no Flatpak sandbox shim)
- **Flatpak (Flathub):** Discord, LibreWolf, LocalSend, Telegram

## Not included

Drivers (Nvidia, firmware) and dotfiles. Those are per-machine.
