# Debian Baseline Deployment

A single, idempotent script that takes a fresh Debian install (GNOME) to a fully provisioned baseline: native toolkit, browser stack, Wayland tuning, and a split-phase update workflow with GNOME launchers.

Full background and rationale: [Debian-Deployment-Guide.md](./Debian-Deployment-Guide.md)

Debian has no unified "foreign package" layer, no automatic config-drift tracking, and a couple of standard tools (`fastfetch`, `duf`) aren't in Debian's stable repos at all. This script handles each of those gaps explicitly.

## Prerequisites

- Debian already installed (GNOME desktop environment)
- Your `/etc/apt/sources.list` includes the `non-free-firmware` component, needed for `intel-microcode`/`amd64-microcode`. Debian's installer includes this by default since Debian 12; if you're on an older release or a minimal netinst, you may need to add it manually.

## Usage

```bash
git clone https://github.com/GrimDaTrashPanda/debian-deploy.git
cd debian-deploy
chmod +x deploy.sh
./deploy.sh
```

Run as your normal user, not root — it calls `sudo` internally where needed.

## What it does

1. Detects CPU vendor and installs the matching microcode package (`intel-microcode` / `amd64-microcode`)
2. Installs the native toolkit: `firefox-esr`, telegram-desktop, shotcut, gimp, glances, flatpak, vlc, p7zip-full, plus build tooling
3. Fetches `fastfetch` and `duf` directly from their GitHub releases — neither is in Debian's stable repos
4. Adds the Flathub remote
5. Installs Chrome (direct .deb), Brave (official apt repo), and Edge (official apt repo) — each browser uses a different install mechanism since Debian has no single package source that covers all three
6. Sets `MOZ_ENABLE_WAYLAND=1` for native Firefox Wayland rendering
7. Creates `update-core.sh` / `update-apps.sh` and matching GNOME launchers

## How package sources break down on Debian

| | Detail |
|---|---|
| Official apt packages | Everything from Debian's own repos — the vast majority of the toolkit |
| Third-party apt repos | Brave and Edge each add their own signed repo; once added, apt treats them exactly like official packages |
| Direct `.deb` installs | Chrome ships no apt repo by default, so it's installed from a downloaded `.deb` |
| GitHub-release binaries | `fastfetch` and `duf` aren't packaged for Debian stable at all, so they're fetched directly from their GitHub releases |
| Flatpak | Sandboxed, distribution-agnostic apps via Flathub — kept fully separate from apt |
| Config file conflicts | No separate tracking step needed — `apt upgrade` stops and asks interactively any time an update would overwrite a config file you've modified |

## After running

- Log out and back in (applies the Wayland env var)
- Set the Wayland flag manually in each Chromium browser via `chrome://flags/#ozone-platform-hint`
- Press **Super**, search "Update" — confirm both launchers appear
- If you want `tldr`: `sudo apt install node-tldr` or `pip install tldr`

## Safe to re-run

Every install step checks for an existing binary or repo file before acting. Re-running won't duplicate repo entries or reinstall already-current packages.

## A note on the "split update" naming

The split between "Update Core" and "Update Apps" is mostly cosmetic on Debian — apt doesn't have a clean way to separate "trusted official" from "third-party repo" packages. Once Brave or Edge's repo is added, `apt upgrade` updates them right alongside core Debian packages. The "Update Apps" launcher here really only covers Flatpak. It's kept as two separate launchers for a consistent update habit across machines, not because the underlying separation is deeply meaningful on Debian itself.
