Debian Baseline Deployment

A single, idempotent script that takes a fresh Debian install (GNOME) to a fully provisioned baseline: native toolkit, browser stack, Wayland tuning, and a split-phase update workflow with GNOME launchers.

The end result is a fully provisioned machine reachable via git clone && ./deploy.sh.
Prerequisites

    Debian already installed (GNOME desktop environment)

    Your /etc/apt/sources.list includes the non-free-firmware component, needed for CPU microcode. (Debian's installer includes this by default since Debian 12).

Usage
Bash

git clone https://github.com/GrimDaTrashPanda/debian-deploy.git
cd debian-deploy
chmod +x deploy.sh
./deploy.sh

Run as your normal user, not root — it calls sudo internally where needed.
What it does

    Detects CPU vendor and installs the matching microcode package (intel-microcode / amd64-microcode)

    Installs the native toolkit: firefox-esr, telegram-desktop, shotcut, gimp, glances, flatpak, plus build tooling

    Fetches fastfetch and duf directly from their GitHub releases (since they are absent from Debian's stable repositories)

    Adds the Flathub remote

    Installs Chrome (direct .deb), Brave (official apt repo), and Edge (official apt repo)

    Sets MOZ_ENABLE_WAYLAND=1 for native Firefox Wayland rendering

    Creates update-core.sh / update-apps.sh and matching GNOME launchers

After running

    Log out and back in (applies the Wayland env var)

    Set the Wayland flag manually in each Chromium browser — chrome://flags/#ozone-platform-hint, brave://flags/#ozone-platform-hint, edge://flags/#ozone-platform-hint — switch to Wayland, relaunch. One-time per browser.

    Press Super, search "Update" — confirm both launchers appear

    If you want tldr: sudo apt install node-tldr or pip install tldr

Safe to re-run

Every install step checks for an existing binary or repo file before acting. Re-running won't duplicate repo entries or reinstall already-current packages.
The Split Update Workflow

The deployment creates two separate update paths to mirror your workflow across machines:

    Update Core: Handles native system packages via standard apt updates.

    Update Apps: Handles sandboxed user applications via flatpak.
