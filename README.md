# Fedora Laptop

Repeatable workstation setup with rolling user tools for **Fedora Silverblue 44 or newer**. GDM
starts the login session, Niri provides the Wayland compositor, and Noctalia
supplies the desktop shell.

## Layer model

```text
Base image (assumed, never layered)
  GNOME/GDM, Firefox, git, openssh, toolbox, podman, flatpak,
  fontconfig, portals, PipeWire, NetworkManager, nautilus.

Host rpm-ostree (one transaction, one reboot)
  niri, noctalia, ghostty, keyd, wtype, gcc, make, wl-clipboard,
  tailscale, openssh-server, podman-compose. Podman is provided by the base.
  Declared in manifests/host-packages.yaml.

User-local Mise (rolling latest, survives rebases)
  herdr, yazi, neovim, tmux, fzf, bat, eza,
  zoxide, gh, jj, opencode, ripgrep, tree-sitter,
  starship, node, lazygit, prettierd, fd, go, uv, ansible, fastfetch.
  Declared in mise.toml (no lockfile by design). Dotfiles via `mise bootstrap dotfiles`.
  Linked as the global Mise config, so tools resolve in every directory.
  Go stays global; other project language runtimes stay per-project.

Toolbx (project runtimes)
  dev container, minimal DNF (gcc, make,
  wl-clipboard for Neovim builds/clipboard, and mpg123). In interactive `dev`
  shells, the `podman` alias forwards to host Podman with
  `flatpak-spawn --host podman`.
  The same rolling Mise CLI tools are available inside the container. Starship
  is global (host and Toolbx) and shows a `⬢ [dev]` marker inside containers
  via its `container` module.

Flatpak (system-wide)
  Flathub is configured system-wide; applications can be declared in
  manifests/flatpaks.yaml, which currently contains no enabled applications.
  Firefox comes from the Silverblue base RPM and backs the Niri shortcut.
```

Neovim's configuration is kept in the independent kickstart.nvim
repository and follows its `master` branch. It is managed natively by
Mise: `[bootstrap.repos]` in `mise.toml` clones it to
`~/.local/share/fedora-laptop/sources/nvim`, and the `[dotfiles]`
`~/.config/nvim` entry links at it. The dotfiles phase runs
`mise bootstrap repos apply/update` (dirty checkouts are skipped, never
discarded) before applying links, so reruns follow the branch tip
without touching local edits.

Third-party host repositories are declared in `manifests/repositories.yaml`:
the Ghostty and keyd COPRs and the official Tailscale vendor repository. COPRs
are package-scoped (`includepkgs`) with package GPG checking enabled. The
playbook manages the COPR definitions and downloads the vendor definition; it
does not independently pin or verify signing-key fingerprints.

## Install

See [Installation steps](installation_steps.md) for the commands and
prerequisites. The setup is intended for a fresh account. Review the playbooks,
manifests, and dotfiles before applying them.

1. The retained Mise bootstrap installs Mise and the tools in `mise.toml`;
   install the Ansible collection requirements afterward.
2. `deployments/pre-deployment-playbook.yaml` configures repositories and layers
   host packages. If it stages an rpm-ostree deployment, reboot manually.
3. `deployments/post-deployment-playbook.yaml` configures the system, dotfiles,
   Toolbx, and declared Flatpaks. It also refuses to continue while an rpm-ostree
   deployment is pending.

The post-deployment playbook is interactive and uses privileged operations.
Mise applies dotfiles with force, replacing conflicting files without backups.
Firewall changes and enabling Tailscale SSH may interrupt remote sessions.
Ansible check mode is only a partial preview: some command-driven phases are
skipped and package installation cannot be fully validated in check mode.

## Dotfiles and machine-specific settings

Mise manages the user dotfiles declared in `mise.toml`. The post-deployment
playbook creates the Niri `local.kdl` and `touchpad.kdl` stubs if absent and
does not overwrite existing versions. `local.kdl` can be edited later for
machine-specific display settings; the touchpad utility manages its own stub.

The playbook prompts for trusted network UUIDs rather than loading them from
`profiles/laptop/profile.env`. It does not link that optional profile or set up
the old RDP shortcut.

## Firewall zones

Firewalld defaults to `public`. During post-deployment, the user can enter
trusted NetworkManager profile UUIDs; those Wi-Fi and Ethernet profiles use
`FedoraWorkstation`. Other saved Wi-Fi, Ethernet, and non-Tailscale tunnel
profiles use `public`. The Tailscale NetworkManager profile is left untouched.
Zone changes apply when a connection activates, so reconnection may be needed.
Trusted choices are prompted for on each run: an empty response means no
profiles are trusted and can change earlier assignments.

`FedoraWorkstation` is intentionally permissive for networks you trust: this
system's zone allows SSH and broad high-numbered TCP/UDP ports. The firewalld
`trusted` zone is not assigned to Tailscale; Tailscale's own network and SSH
policies control tailnet access. The `public` zone does not allow SSH or those
broad port ranges.

Zone assignments attach to NetworkManager profile UUIDs, not to a router's
identity. In particular, trusting the generic `Wired connection 1` profile
trusts it wherever that profile is used. Only list profiles for networks you
own and trust.

The post-deployment playbook forces Mise dotfile application without making
backups. Niri output names are hardware data: inspect them with
`niri msg outputs` in a Niri session and keep machine-specific rules in `local.kdl`.

Global Mise tools are intentionally rolling. Go is installed globally;
other project language runtimes are not installed by this laptop
profile; declare them in each project instead:

```sh
cd /path/to/project
mise use python@3.13
```

## Updates

This setup provides explicit update commands rather than configuring GNOME
Software. The GNOME Software application may still be present in the base image.
Two streams are covered; everything else stays manual:

- OS deployment (`rpm-ostree`, base plus host layers).
- System Flatpaks.

The update-check timer files are included in the dotfiles, but the Ansible
playbook does not enable the timer. `Super+Alt+U` or `fedora-update` stages
an OS deployment (which takes effect on reboot) and updates system Flatpaks.
Deliberately out of scope: Mise tools
(`mise upgrade` when you choose), the toolbox userland (`dnf upgrade`
inside `dev`), firmware (`fwupdmgr`), and Neovim/Mason packages.

## Remote development over Tailscale SSH

SSH sessions land on the host and authenticate through Tailscale identity,
so no SSH keys are needed on clients. Tailscale SSH sessions skip
`pam_systemd`, leaving `XDG_RUNTIME_DIR` unset; without it rootless
Podman/Toolbox fails. The managed `.bashrc` repairs this automatically
(before the non-interactive early return), so
`toolbox enter dev` works from any Tailscale SSH shell.

The Bash functions mirror the desktop workflow: `herdev` runs the default
Herdr session inside the `dev` Toolbx, while `adm` attaches to the separate
named `admin` session on the host.

## Verification and recovery

The playbooks report their individual task results; there is no separate
automated verification phase. Check the desktop, networking, Toolbx, and other
features you rely on after installation. Inspect deployments with
`rpm-ostree status`.

If a deployment fails, select the previous entry at boot or run
`rpm-ostree rollback` and reboot. Rollback reverts `/usr` only; `/etc/keyd`,
repo files, and home symlinks must be reverted separately.

The `keyd` package is included in the host package layer. Post-deployment
configures and enables the remap, prompting for a keyboard ID. An empty answer
applies it to all keyboards. The remap swaps Left Alt/Meta and turns held Left
Control into a Shift+Meta layer (not Control). Keep a second input ready.

keyd recovery drill (an invalid map can break typing):

1. Switch to a TTY (`Ctrl+Alt+F3`) or boot the previous deployment.
2. `sudo systemctl stop keyd`
3. Repair or remove `/etc/keyd/default.conf`.
4. `sudo systemctl restart keyd` (or leave it stopped).
5. Note: `rpm-ostree rollback` does NOT revert `/etc/keyd` — fix it by hand.

The playbook enables `sshd`, `tailscaled`, and the Tailscale SSH preference,
but does not authenticate the machine to a tailnet. Complete authentication
manually and ensure the tailnet policy allows the desired SSH access. Podman
is rootless and daemonless; it is provided by the
Silverblue base and does not need a system service. The host package layer adds
`podman-compose` as Podman's Compose provider. In interactive `dev` shells, the
`podman` alias uses `flatpak-spawn --host podman`, so commands run as your host
user against host Podman's storage and networking. No Docker daemon, Docker
group, or socket forwarding is configured.

Dockerfiles and common Compose projects generally work with Podman; validate
projects using Docker-specific behavior or advanced BuildKit features. Docker
container/image/volume state is not migrated into Podman's separate storage.
Setup only installs the packages declared by this repository; it does not
remove Docker packages, data, or repository files that may already exist.

The playbook checks that firewalld is active before configuring its zones. It
does not manage the NetworkManager, firewalld, fstrim, or power-profile service
states. It manages keyd, SSH/Tailscale services, the network-zone policy, and
the Wi-Fi powersave configuration.

WiFi power save is unconditionally disabled via
`system/NetworkManager/wifi-powersave.conf` (`wifi.powersave = 2`): the
Fedora default parks the radio and adds wake-up latency spikes that power
profiles (Noctalia/tuned) do not govern. Battery cost is negligible. The
setting takes effect on NetworkManager restart or reboot.

## Optional battery charge thresholds (75/80)

The post-deployment playbook offers an opt-in configuration designed for the
ThinkPad E14 Gen 5. It may affect other supported batteries; skip it unless it
is appropriate for the machine. The reference laptop uses `BAT0` and applies
the cap through UPower and Noctalia. The hardware database rule is broad, while
the service specifically checks for a `BAT0` threshold interface; opting in does
not guarantee that another machine supports the cap:

- Source: `system/udev/61-battery-local.hwdb` (`CHARGE_LIMIT=75,80`,
  Lenovo conservation behavior: resume below 75%, stop at 80%).
- Installed to `/etc/udev/hwdb.d/61-battery-local.hwdb` by the playbook,
  followed by `systemd-hwdb update`,
  a `power_supply` trigger, and a `upower` restart.
- Re-applied at boot by `battery-thresholds.service`
  (`system/systemd/battery-thresholds.service` +
  `/usr/local/bin/battery-thresholds-apply`): the EC resets sysfs to
  95/100 on every boot and UPower does not rewrite the start threshold
  on its own, so without the unit the cap silently stops working after
  a reboot. The helper only writes when the UPower toggle is on, so
  travel mode is respected; it refreshes UPower afterwards so the
  Noctalia Power tab stops showing the stale start value.
- Effective only when Noctalia `Control Center > Power > Use charge
  thresholds` is ON (UPower `EnableChargeThreshold`). The toggle persists
  across reboot; the hwdb file makes reinstalls deterministic.
- On the supported reference hardware, inspect the `BAT0` charge-control
  thresholds and UPower state to confirm the cap. Travel mode can legitimately
  leave different values.
- Above 80% after enabling will not drain on its own: unplug to ~75%
  once, replug, and it holds at 80% from then on.
- On the supported reference hardware, a one-time seed (stuck at `95/100`
  with the toggle ON) is only needed if
  the toggle was enabled before the hwdb pin existed, leaving UPower
  with a stale `95/80` that the EC rejects (`start > end`). The boot
  service heals this automatically on next boot; for immediate effect:
  `sudo systemctl start battery-thresholds.service`, or manually:
  `echo 75 | sudo tee /sys/class/power_supply/BAT0/charge_control_start_threshold`
  `echo 80 | sudo tee /sys/class/power_supply/BAT0/charge_control_end_threshold`
  `sudo systemctl restart upower`
  Fresh installs with the hwdb file present before first enable do not
  need this.

Travel day (charge to 100%): turn the Noctalia toggle OFF the night
before, charge on AC to full, travel, then turn it back ON when docked.
UPower remembers OFF across reboot, so re-enabling is a deliberate step.

## Security boundaries

The playbooks use privilege escalation for system configuration. Review
commands, systemd units, and `/etc` changes before execution. The setup does
not reboot automatically or store Tailscale credentials.
