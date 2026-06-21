# Debian Baseline Deployment

A single, idempotent script that takes a fresh Debian install (GNOME) to the same functional baseline as the EndeavourOS deployment: native toolkit, browser stack, Wayland tuning, and a split-phase update workflow with GNOME launchers.

This is a **sibling project**, not a port. Debian has no AUR equivalent, no `.pacnew` system, and a couple of standard tools (`fastfetch`, `duf`) aren't in Debian's stable repos at all. The mechanics here are genuinely different even though the end result — a fully provisioned machine reachable via `git clone && ./deploy.sh` — is the same.

Companion repo for Arch-based systems: [endeavouros-deploy](https://github.com/GrimDaTrashPanda/endeavouros-deploy)

## Prerequisites

- Debian already installed (GNOME desktop environment)
- Your `/etc/apt/sources.list` includes the `non-free-firmware` component, needed for `intel-microcode`/`amd64-microcode`. Debian's installer includes this by default since Debian 12; if you're on an older release or a minimal netinst, you may need to add it manually.

## Usage

```bash
git clone https://github.com/<your-username>/<your-repo>.git
cd <your-repo>
chmod +x deploy.sh
./deploy.sh
```

Run as your normal user, not root — it calls `sudo` internally where needed.

## What it does

1. Detects CPU vendor and installs the matching microcode package (`intel-microcode` / `amd64-microcode`)
2. Installs the native toolkit: `firefox-esr`, telegram-desktop, shotcut, gimp, glances, flatpak, plus build tooling
3. Fetches `fastfetch` and `duf` directly from their GitHub releases — neither is in Debian's stable repos
4. Adds the Flathub remote
5. Installs Chrome (direct .deb), Brave (official apt repo), and Edge (official apt repo) — each browser uses a different install mechanism since Debian has no unified AUR-style layer
6. Sets `MOZ_ENABLE_WAYLAND=1` for native Firefox Wayland rendering
7. Creates `update-core.sh` / `update-apps.sh` and matching GNOME launchers

## Key differences from the EndeavourOS version

| | EndeavourOS / Arch | Debian |
|---|---|---|
| Foreign packages | AUR, isolated via `pacman -Qmq` | No equivalent — each browser repo is just another apt source |
| fastfetch / duf | Official repos | Not packaged for stable — fetched as standalone `.deb` from GitHub |
| tldr | Official repos | `node-tldr` (pulls in Node.js) or `pip install tldr` — not installed by default, your call |
| Browser install | Single `yay -S` command, all three | Three separate mechanisms: direct `.deb` (Chrome), official apt repo + keyring (Brave, Edge) |
| Update split logic | "Foreign" vs "official" via `pacman -Qmq` | Everything apt-tracked (including Brave/Edge once their repo is added) updates together — only Flatpak is genuinely separate |
| Config drift tracking | `.pacnew` files | No Debian equivalent — apt handles config file conflicts interactively during `apt upgrade` instead |

## After running

- Log out and back in (applies the Wayland env var)
- Set the Wayland flag manually in each Chromium browser — same `chrome://flags/#ozone-platform-hint` pattern as Arch
- Press **Super**, search "Update" — confirm both launchers appear
- If you want `tldr`: `sudo apt install node-tldr` or `pip install tldr`

## Safe to re-run

Every install step checks for an existing binary or repo file before acting. Re-running won't duplicate repo entries or reinstall already-current packages.

## A note on the "split update" naming

Unlike the Arch version, this split is mostly cosmetic — apt doesn't have a clean way to separate "trusted official" from "third-party repo" packages the way `pacman -Qmq` does for AUR. Once Brave or Edge's repo is added, `apt upgrade` updates them right alongside core Debian packages. The "Update Apps" launcher here really only covers Flatpak. It's kept as two launchers for muscle-memory consistency with the Arch machines, not because the underlying separation is as meaningful here.
