# Debian Baseline Deployment Guide

> Universal setup reference for any hardware — from fresh install to fully configured system  
> Debian · GNOME · Wayland · Multi-browser · Split-update workflow

---

## Table of Contents

1. [Overview](#1-overview)
2. [Phase 1: Installation](#2-phase-1-installation)
3. [Phase 2: Wayland Input Configuration](#3-phase-2-wayland-input-configuration)
4. [Phase 3: Software Provisioning](#4-phase-3-software-provisioning)
5. [Phase 4: Split-Phase Update Workflow](#5-phase-4-split-phase-update-workflow)
6. [Phase 5: Ongoing Maintenance Reference](#6-phase-5-ongoing-maintenance-reference)
7. [Quick Reference Card](#7-quick-reference-card)
8. [Appendix: Troubleshooting](#8-appendix-troubleshooting)

---

## 1. Overview

This document is the companion reference to [`deploy.sh`](./deploy.sh) — it explains *why* each step exists, not just what command to run. If you just want to run the script, see the [README](./README.md). This guide is for understanding what's happening under the hood, or for doing any of it manually.

This is the Debian sibling to the [EndeavourOS deployment guide](https://github.com/GrimDaTrashPanda/endeavouros-deploy) — same end goal, genuinely different mechanics. Debian has no AUR, no `.pacnew` system, and its stable repos lag behind Arch's rolling model, so a few tools need to be fetched directly rather than installed through the package manager.

**This guide covers:**

| ✅ In scope | ❌ Out of scope |
|---|---|
| Debian installation (GNOME, stable branch) | Dual-boot or multi-partition layouts |
| Wayland input optimisation for all browser engines | NVIDIA proprietary driver setup |
| Multi-method browser provisioning (no AUR equivalent) | Gaming / Steam configuration |
| Tools missing from Debian stable, fetched directly | Server / headless deployments |
| Split-phase update workflow | Debian Testing/Sid (this guide assumes stable) |

> 📌 **Why Debian Stable specifically?** This guide targets the **stable** branch (currently Bookworm/12) — the one most people mean when they say "Debian." Testing and Sid have different package availability and update cadence; some of the "fetch directly" workarounds below (`fastfetch`, `duf`) may not be necessary on Sid, where packages land faster.

---

## 2. Phase 1: Installation

Unlike EndeavourOS, Debian's installer (`debian-installer` or the graphical Calamares-based live image, depending on which ISO you choose) doesn't have a known mirror-stall bug at a specific percentage. Mirror selection still matters for download speed, but it doesn't have the same failure mode worth specifically engineering around.

### 1.1 Choosing an Installer Image

Debian offers multiple ISO types. For a desktop GNOME machine, the **live image with GNOME** is the simplest path — it lets you test the desktop environment before committing to install, similar in spirit to how Arch live media works, though Debian's live environment is less commonly used for system administration tasks before installing.

### 1.2 Running the Installer

1. Boot from the live media.
2. If using the live-GNOME image: test the desktop, then launch the installer from the desktop. If using the standard netinst image: the installer runs directly, text-based.
3. Select your language, location, and keyboard layout.
4. **Partitioning:** Debian's installer supports LVM with encryption (LUKS) through the guided partitioning options — select **Guided - use entire disk and set up encrypted LVM** if you want the same disk-encryption posture as the EndeavourOS deployment.
5. Set up your user account and password.
6. **Software selection:** when prompted for desktop environment, select **GNOME**. Deselect other desktop environments if presented as a list, to avoid installing multiple DEs you won't use.
7. Confirm and let the installer run. This will take noticeably longer than an Arch-based install — Debian's installer pulls a more complete base system by default.

> 📌 **Why LUKS + LVM here, not just LUKS?** Debian's guided partitioner bundles encryption with LVM (Logical Volume Manager) rather than offering plain LUKS-on-partition the way Calamares does. Functionally the security outcome is the same — full disk encryption — but the underlying disk layout is more flexible to resize later. No action needed beyond selecting the right guided option.

### 1.3 First Boot

After install and reboot, you'll see a passphrase prompt (if you encrypted) before GDM loads. Log in normally afterward.

> ⚠️ **Check your sources.list before doing anything else.** Debian's default `/etc/apt/sources.list` (or the newer `/etc/apt/sources.list.d/debian.sources` format on Bookworm+) needs the `non-free-firmware` component for CPU microcode packages. Recent Debian installers include this automatically — but if you're on an older release, a minimal netinst, or you edited sources during install, verify it's present:

```bash
cat /etc/apt/sources.list
```

You should see `main`, `contrib`, `non-free-firmware` (or just `main contrib non-free-firmware` on one line) — not just `main` alone. If `non-free-firmware` is missing, add it manually before continuing, then run `sudo apt update`.

---

## 3. Phase 2: Wayland Input Configuration

This phase is functionally identical to the EndeavourOS guide — Wayland is Wayland regardless of distro, and Firefox/Chromium handle it the same way on Debian as on Arch.

### 2.1 Mozilla Engine — Firefox

Debian's repo package is `firefox-esr` (Extended Support Release), not the bleeding-edge `firefox` package you'd get on Arch. This is intentional on Debian's part — ESR tracks a more conservative release cadence that matches Debian's overall stability philosophy. Functionally, for Wayland purposes, it behaves the same:

```bash
echo "MOZ_ENABLE_WAYLAND=1" | sudo tee -a /etc/environment
```

**What this does:** Identical mechanism to Arch — appends one line to `/etc/environment`, applied at next login.

### 2.2 Chromium Engine — Chrome, Brave, Edge

Identical flag-based configuration to the Arch guide. The browsers themselves are installed differently on Debian (see Phase 3.5), but once installed, the Wayland tuning step is the same:

| Browser | Address to paste |
|---|---|
| Google Chrome | `chrome://flags/#ozone-platform-hint` |
| Brave | `brave://flags/#ozone-platform-hint` |
| Microsoft Edge | `edge://flags/#ozone-platform-hint` |

Set each to **Wayland**, click **Relaunch**. One-time per browser, same as Arch.

---

## 4. Phase 3: Software Provisioning

This is where Debian and Arch diverge the most. There's no AUR, no unified helper like `yay`, and Debian's stable repos move slowly enough that a couple of common tools simply aren't packaged there at all.

### 3.1 Understanding the Debian Package Landscape

| Source | What it is |
|---|---|
| **Debian Stable repos** (`apt`) | Curated, heavily-tested packages. Very stable, but can lag months to years behind upstream releases. |
| **Third-party apt repos** | Vendor-maintained sources added manually (e.g. Brave, Microsoft Edge) — each comes with its own signing key and `sources.list.d` entry. |
| **Direct `.deb` downloads** | Some software (Chrome, and tools like `fastfetch`/`duf` that don't maintain a repo) is installed by downloading a `.deb` file directly and installing it with `apt install ./package.deb`. |
| **Flatpak** | Same as Arch — sandboxed, distribution-agnostic. |

> ⚠️ **There is no AUR equivalent.** This is the single biggest structural difference from the Arch guide. On Arch, "foreign software" is cleanly separated into one bucket (AUR) that a single helper manages. On Debian, "foreign software" is scattered: direct `.deb` files, vendor apt repos, and Flatpak are all distinct mechanisms with no unifying layer. The deploy script handles each one explicitly because there's no shortcut around this.

### 3.2 Native Toolkit — Standard Loadout

Install the core toolkit plus build essentials:

```bash
sudo apt update
sudo apt install -y \
  build-essential \
  git \
  curl \
  wget \
  gnupg \
  firefox-esr \
  telegram-desktop \
  shotcut \
  gimp \
  glances \
  flatpak
```

| Package | What it's for |
|---|---|
| `build-essential` | Compiler toolchain — Debian's equivalent of Arch's `base-devel`. |
| `git` | Version control, needed for some later steps. |
| `curl` / `wget` / `gnupg` | Needed to fetch and verify the direct-download tools and third-party repo keys in the next sections. |
| `firefox-esr` | Debian's standard Firefox package — see note in 2.1. |
| `telegram-desktop` | Messaging. |
| `shotcut` | Video editing. |
| `gimp` | Raster image editing. |
| `glances` | Terminal system monitor. |
| `flatpak` | Sandboxed app runtime. |

> 📌 **Notice what's missing here.** `fastfetch`, `duf`, and `tldr` from the Arch loadout aren't in this list — see 3.3 and 3.4 for why, and what to do about each.

### 3.3 Tools Missing From Debian Stable — Fetched Directly

`fastfetch` and `duf` are not in Debian 12's repositories at all — not even in `contrib` or `non-free`. Both publish only GitHub releases, not an apt repo, so the standard install method is downloading a `.deb` and installing it locally:

```bash
# fastfetch
FASTFETCH_URL=$(curl -fsSL https://api.github.com/repos/fastfetch-cli/fastfetch/releases/latest \
  | grep -oP '"browser_download_url":\s*"\K[^"]*linux-amd64\.deb')
curl -fsSL -o /tmp/fastfetch.deb "$FASTFETCH_URL"
sudo apt install -y /tmp/fastfetch.deb

# duf
DUF_URL=$(curl -fsSL https://api.github.com/repos/muesli/duf/releases/latest \
  | grep -oP '"browser_download_url":\s*"\K[^"]*linux_amd64\.deb')
curl -fsSL -o /tmp/duf.deb "$DUF_URL"
sudo apt install -y /tmp/duf.deb
```

**What this does:** Queries each project's GitHub API for the latest release, extracts the download URL for the Linux amd64 `.deb` asset specifically (filtering out ARM/Windows/macOS builds), downloads it, and installs it via `apt install` pointed at a local file rather than a repo.

> ⚠️ **This is the one part of the deployment that doesn't self-update through normal channels.** Since these aren't apt-tracked, `apt upgrade` will never update them. Re-running the full deploy script will fetch whatever the current latest release is, but there's no lightweight "just update these two tools" command the way there is for everything else.

### 3.4 tldr — Optional, Your Call

Debian's apt package for `tldr` is named `node-tldr`, and it pulls in Node.js as a dependency just to run a small command-line tool — a meaningfully heavier dependency footprint than the same tool on Arch. Two options, neither installed by default:

```bash
# Option A: apt, accepts the Node.js dependency
sudo apt install node-tldr

# Option B: pip, no Node dependency
pip install --user tldr
```

This guide doesn't pick one for you — it's left out of the default loadout specifically because the "right" choice depends on whether you're already running Node.js for something else on that machine.

### 3.5 Browser Stack

Three browsers, three different install mechanisms — this is the most concrete illustration of "no unified AUR-style layer."

**Google Chrome — direct `.deb`, no repo:**

```bash
curl -fsSL -o /tmp/chrome.deb "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb"
sudo apt install -y /tmp/chrome.deb
```

Chrome's installer actually adds its own apt repo as a side effect of this install, so subsequent updates come through normal `apt upgrade` afterward — the manual step is just for the first install.

**Brave — official apt repo + keyring:**

```bash
sudo curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg \
  https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg arch=amd64] https://brave-browser-apt-release.s3.brave.com/ stable main" \
  | sudo tee /etc/apt/sources.list.d/brave-browser-release.list
sudo apt update
sudo apt install -y brave-browser
```

**Microsoft Edge — official apt repo + keyring:**

```bash
curl -fsSL https://packages.microsoft.com/keys/microsoft.asc \
  | sudo gpg --dearmor -o /usr/share/keyrings/microsoft-edge-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft-edge-keyring.gpg] https://packages.microsoft.com/repos/edge stable main" \
  | sudo tee /etc/apt/sources.list.d/microsoft-edge.list
sudo apt update
sudo apt install -y microsoft-edge-stable
```

> 📌 **Why the keyring dance for Brave/Edge but not Chrome?** Brave and Edge are following the modern, more secure apt convention: a dedicated keyring file referenced explicitly in the repo definition (`signed-by=`), rather than adding a key to the system-wide trusted keyring. Chrome's installer uses an older pattern baked into its own postinst script. Both are valid; the keyring approach is generally considered the better practice and is what Debian itself recommends for third-party repos going forward.

---

## 5. Phase 4: Split-Phase Update Workflow

The Arch version splits "official repos" from "AUR/Flatpak" cleanly, because `pacman -Qmq` can tell you exactly which packages came from outside the official repos. Debian has no equivalent query — once a third-party repo (Brave, Edge) is added via `sources.list.d`, apt treats it exactly like any other trusted repo. There's no "show me only the third-party stuff" command.

### 4.1 What the Split Actually Means Here

| | EndeavourOS / Arch | Debian (this guide) |
|---|---|---|
| What "Update Core" does | Official repos only, explicitly excludes AUR | All apt-tracked packages — official Debian + Brave + Edge, since apt can't distinguish them |
| What "Update Apps" does | Flatpak + AUR | Flatpak only |
| Is the split meaningful? | Yes — genuinely isolates two different trust/stability tiers | Mostly cosmetic — kept for muscle-memory consistency across your fleet, not because it does real isolation |

If you want true isolation between "Debian's own packages" and "third-party repos I added," that would require pinning or apt preferences configuration — meaningfully more complex than this guide's scope, and probably not worth the overhead for a handful of browser packages.

### 4.2 The Update Scripts

```bash
mkdir -p ~/.local/bin ~/.local/share/applications

# Core updater — covers all apt-tracked packages, official + third-party repos alike
cat << 'EOF' > ~/.local/bin/update-core.sh
#!/usr/bin/env bash
clear
echo "========================================="
echo "  UPGRADING APT-MANAGED PACKAGES"
echo "========================================="
sudo apt update
sudo apt upgrade -y
echo ""
echo "==> Checking for orphaned dependencies..."
sudo apt autoremove --dry-run
echo ""
echo "(Run 'sudo apt autoremove' manually if the above list looks safe.)"
echo "Press Enter to close..."
read -r
EOF

# App updater — Flatpak only
cat << 'EOF' > ~/.local/bin/update-apps.sh
#!/usr/bin/env bash
clear
echo "========================================="
echo "  UPGRADING FLATPAKS"
echo "========================================="
flatpak update -y
echo "Press Enter to close..."
read -r
EOF

chmod +x ~/.local/bin/update-core.sh ~/.local/bin/update-apps.sh
```

GNOME launcher creation follows the same pattern as the Arch guide — terminal-emulator detection, then `.desktop` file generation. See `deploy.sh` for the exact implementation; it's mechanically identical to the Arch version, just pointed at these two scripts.

### 4.3 Why `apt autoremove` Is a Dry-Run, Not Automatic

Unlike the Arch script, which runs `pacman -Rns` somewhat freely on confirmed orphans, the Debian update-core script deliberately stops at `--dry-run` for `autoremove` and asks you to run it manually. Apt's dependency graph on Debian sometimes flags packages as removable that you'd actually want to keep — false positives are more common here than with `pacman -Qdtq`. Worth eyeballing the list before clearing it, every time.

---

## 6. Phase 5: Ongoing Maintenance Reference

### 5.1 No `.pacnew` Equivalent — How Debian Handles Config Conflicts Instead

Arch's `.pacnew` system saves a new config file alongside your modified one and lets you merge later, on your own schedule. Debian's `apt` takes a different approach entirely: when a package update would overwrite a config file you've modified, **apt stops and asks you interactively, during the upgrade itself** — usually presenting a menu like "keep your version / install the package's version / show a diff."

This means config conflicts on Debian surface immediately during `sudo apt upgrade`, not as a follow-up list to review later. There's nothing to "check for" after the fact the way you'd `find /etc -name "*.pacnew"` on Arch — if nothing prompted you during the upgrade, nothing conflicted.

### 5.2 Updating the Directly-Fetched Tools

Since `fastfetch` and `duf` aren't apt-tracked, check their installed version against the latest release periodically:

```bash
fastfetch --version
duf --version
```

Compare against the latest releases on their GitHub pages, and re-run the relevant block from Phase 3.3 if you want to update either one. There's no automatic path for this — it's a manual, occasional check.

### 5.3 Checking What's Actually Installed From Third-Party Sources

There's no single command equivalent to Arch's `pacman -Qm`, but you can list configured non-Debian apt sources directly:

```bash
ls /etc/apt/sources.list.d/
```

On a standard deployment from this guide, you should see `brave-browser-release.list` and `microsoft-edge.list` — Chrome's repo, if you check, typically installs as `/etc/apt/sources.list.d/google-chrome.list` automatically as part of its `.deb` postinst script.

### 5.4 Removing a Package Cleanly

```bash
sudo apt remove --purge <package>
sudo apt autoremove
```

`--purge` also removes config files, which `apt remove` alone leaves behind — closer in spirit to Arch's `pacman -Rns`.

---

## 7. Quick Reference Card

| Task | Command |
|---|---|
| Update everything apt-tracked | `sudo apt update && sudo apt upgrade -y` |
| Update Flatpaks only | `flatpak update -y` |
| Install official package | `sudo apt install <package>` |
| Remove package + config files | `sudo apt remove --purge <package>` |
| List orphaned dependencies | `apt autoremove --dry-run` |
| List third-party apt sources | `ls /etc/apt/sources.list.d/` |
| Check installed package info | `apt show <package>` |
| Search repos for a package | `apt search <term>` |
| Install a local .deb file | `sudo apt install ./file.deb` |

---

## 8. Appendix: Troubleshooting

### A.1 `apt install <package>` Says "Unable to Locate Package"

Either the package isn't in Debian stable at all (check 3.3 — you may need a direct `.deb` instead), or you haven't run `sudo apt update` recently and your local package index is stale.

### A.2 Microcode Package Not Found

Your `sources.list` is missing the `non-free-firmware` component. See Phase 1.3 — add it, then `sudo apt update` and retry.

### A.3 Brave or Edge Won't Install — GPG / Signature Errors

The keyring file may not have downloaded correctly. Re-run the `curl` step from Phase 3.5 for whichever browser is failing, and confirm the file actually exists and isn't empty:

```bash
ls -la /usr/share/keyrings/
```

### A.4 Browser Scrolling Still Feels Wrong After Phase 2

Same fix as the Arch guide: verify the flag was saved, log out and back in, and as a last resort add `--ozone-platform=wayland` directly to the browser's `.desktop` file `Exec=` line.

### A.5 fastfetch or duf GitHub Fetch Returns Nothing

GitHub's API occasionally changes its asset naming convention, or you've hit a rate limit on unauthenticated API requests (60/hour per IP). Check manually at the project's releases page and download the right `.deb` by hand if the automated fetch comes up empty:

- fastfetch: https://github.com/fastfetch-cli/fastfetch/releases
- duf: https://github.com/muesli/duf/releases

---

*Debian Baseline Deployment Guide · Debian Stable · GNOME · Wayland*
