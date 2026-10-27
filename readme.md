![Tux beside a yellow oven baking cookies](./res/oven.png)

# my-anatase

Personal Anatase image for a Lenovo Legion Go: stock `i.anatase.org/anatase:stable` plus what [`Containerfile`](./Containerfile) adds. Made from [anatase-org/template](https://github.com/anatase-org/template) with **Use this template**.

Published at `ghcr.io/realkaishady/my-anatase:stable` (also `:latest`, same image).

## What's in it

| Path in repo | Goes to | Notes |
| --- | --- | --- |
| `Containerfile` `dnf` line | `/usr` | `btop` (the others are already in the base image) |
| [`cachyos/`](./cachyos/) | `/etc` (audio helper in `/usr/lib/udev`) | CachyOS and Legion Go tuning: zram the size of RAM, swappiness 150, kyber on NVMe (SD cards keep Anatase's `bfq`), NMI watchdog off, THP defrag `defer+madvise`, CachyOS's AC/battery audio power rule, `uaccess`-only USB serial rule. Discover's update settings stay at Anatase's defaults, because its unattended updates keep Flatpak apps current |
| [`bin/my-anatase-verify`](./bin/my-anatase-verify) | `/usr/bin` | Host check of the booted image and the tuning above. Run it on the host: `my-anatase-verify` |
| [`space/`](./space/) | **not in the image** | Files for inside the Ubuntu Space, which has its own `/usr` and `/etc` and can't see the host's. See below |

Files must go under `/usr` or `/etc`, not `/usr/local`: on bootc images `/usr/local` points into `/var`, which the build's cleanup step deletes.

Snapshots use `anatase-snap` from the workbench in `_ANATASE_OPS/bin` (v4.3 or later), run by full path. It isn't shipped here.

### Space files (`space/`)

Run these inside the Ubuntu Space, from the shared `Projects` folder (adjust the path to wherever this repo is cloned):

- `anatase-space-bootstrap`: backs up `.bashrc`/`.zshrc` and writes a `fuse-overlayfs` `~/.config/containers/storage.conf` for podman inside the Space (an existing one is backed up first).
- `profile.d/90-anatase-legion-workbench.sh`: build limits and ROCm variables for the Z1 Extreme's `gfx1103` iGPU. Install with `sudo cp space/profile.d/90-anatase-legion-workbench.sh /etc/profile.d/`, open a new login shell, and check with `echo $HSA_OVERRIDE_GFX_VERSION`. If that prints nothing, your shell doesn't read `/etc/profile.d`.

## How it stays up to date

[`build.yml`](./.github/workflows/build.yml) runs:

- **daily** at 19:17 UTC (06:17 Sydney in summer),
- on every push to `main` that changes the image (not README, `res/` or `examples/`),
- by hand: **Actions > Build Custom Image > Run workflow** (tick *force* to rebuild anyway).

Each run checks the upstream `stable` image and only rebuilds if its digest or this repo's commit changed. A host switched to this image then gets updates the normal way: Anatase checks weekly and applies them at shutdown.

GitHub turns scheduled runs off after 60 days with no activity in the repo (it emails first). If that happens, updates stop. Re-enable the workflow in the Actions tab or push any commit.

## What each build checks

1. **Base signature.** [`ci/verify-signature.sh`](./ci/verify-signature.sh) checks the upstream image's sigstore signature against Anatase's root CA ([`ci/anatase-cosign-root.pem`](./ci/anatase-cosign-root.pem), copied from `anatase-org/anatase`), the same rule Anatase hosts apply in `/etc/containers/policy.json`. The build then uses that exact digest. If Anatase ever replaces its CA, the build fails here until the new certificate is copied in.
2. **`bootc container lint`** runs as the last build step.
3. Nothing checks the result's signature: signing is off (below).

## Signing: off

Commit `2bc5b0d` turned signing off: the workflow no longer passes the signing secrets, and the image no longer installs a signature rule. Images are published **unsigned**, and a host on this image accepts any update published under `ghcr.io/realkaishady/my-anatase` without checking it. Anyone who can push to this repo or its package can change what the Legion Go boots.

To turn it back on, restore what `2bc5b0d` removed: the *Check signing setup* and *Verify published signature* workflow steps, the `SIGNING_KEY`/`SIGNING_PASSWORD` env on the push step, the `IMAGE_REF` build arg, and the `install-policy.sh` step in the `Containerfile` (all in commit `3121c20`). Then:

1. On the Legion Go, Host (❯), make the key pair somewhere private (not in `Projects`). It asks for a passphrase twice:
   ```zsh
   mkdir -p /var/home/geigal/.config/my-anatase-signing && cd /var/home/geigal/.config/my-anatase-signing && skopeo generate-sigstore-key --output-prefix my-anatase
   ```
   Check: `ls -l /var/home/geigal/.config/my-anatase-signing` lists `my-anatase.private` and `my-anatase.pub`.
   Keep a copy of the private key and passphrase in your password manager.
2. In this repo on GitHub: **Settings > Secrets and variables > Actions**, add `SIGNING_KEY` (the whole contents of `my-anatase.private`) and `SIGNING_PASSWORD`.
3. Commit `my-anatase.pub` as `signing/my-anatase.pub`. That push starts a signed build.

If the host's `/etc/containers/policy.json` was ever edited by hand, the host keeps its own copy and the image's rule won't apply. Check with `sudo ostree admin config-diff | grep policy` (no output means unmodified), or run `my-anatase-verify`.

## Using it on the Legion Go (Host ❯)

Before switching, look at what's booted now:
```zsh
sudo bootc status
```
Switch (the change applies at the next reboot; the current OS stays as the rollback slot, which covers `/usr` only, never `/var` or your files):
```zsh
sudo bootc switch ghcr.io/realkaishady/my-anatase:stable
```
After rebooting, check: `sudo bootc status` shows the ghcr image as booted, and `my-anatase-verify` runs.

Go back to stock (Anatase's own signature rule still applies to this pull):
```zsh
sudo bootc switch i.anatase.org/anatase:stable
```
Or hold Shift at boot (or cut power during boot three times) to boot the previous OS.

**Handheld Daemon:** its update button works as usual (`bootc update`). Its channel menu switches to `<this repo>:rolling` or `:testing`, which this repo doesn't publish, so don't change channel while on this image. Switch back to stock first.

**`./update.sh`** (from the template) builds on the Legion Go itself and points the OS at local storage (`containers-storage:localhost/my-anatase:latest`). After that the weekly updater has nothing new to find until you run `./update.sh` again, and the GitHub image is no longer followed. Use it only for quick local experiments, from a **host** terminal, never in a Space. `sudo bootc switch ghcr.io/realkaishady/my-anatase:stable` puts you back on the published image.

---

## Upstream template notes

> [!NOTE]
> **Remember:** use `FROM i.anatase.org/base:stable` when you want to use a different Desktop Environment. To extend Anatase, use `FROM i.anatase.org/anatase:stable`

In the [`./examples`](./examples/) folder, you will find Containerfiles for inspiration, such as ones for Gnome and Cosmic.

The base image does not include a "Return to Gamemode" shortcut or autologin
settings in Handheld Daemon as they are KDE specific. You can configure your Desktop Environment to autologin to "Gamemode" instead.

Gnome supports selecting a session only if you have a password set (gear on the bottom right), otherwise it automatically logs in and blocks you from accessing the button. This is a Gnome issue.

Anatase uses kwallet for secret management. When you switch desktop environments you will lose your secrets, such as various logins in browsers and your IDE credentials (VS Code uses it for your Github login). The examples use the new secret manager oo7, but it is not ready for KDE at this time. This means you can switch through them without losing your secrets.

Lightdm (the Greeter used by Cinnamon and XFCE) does not respect the panel rotation reported by the kernel, so the Steam Deck has the login screen rotated 90 degrees (other portrait panels as well). They also do not associate the touchscreen correctly, so rotating the screen breaks the touchscreen. It does not re-initialize properly when exiting gamemode so you will get a black screen (PRs welcome if you fix it). Without a virtual keyboard, you cannot log in on handhelds.

Cosmic's first boot dialog does not scale properly on handhelds, so you will not be able to complete it without an external display.

**You can rebase between desktop environments arbitrarily, without reinstalling, and face minimal issues (other than losing your secrets).**
