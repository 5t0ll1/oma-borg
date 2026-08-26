# omarchy-borg

Omarchy bar widget for [Vorta](https://github.com/borgbase/vorta) / [Borg](https://www.borgbackup.org/).

Shows last-backup freshness on the bar, lists recent archives in a panel, and
can queue a backup or open Vorta. Status is read from Vorta's **local** SQLite
database and `/proc`. The widget never SSHs to a backup server and never
reads Borg passphrases or SSH keys.

## Install

```bash
omarchy plugin add https://github.com/<you>/omarchy-borg.git --enable
```

Place it on the bar if needed:

```bash
omarchy plugin enable stolli.borg --section right
```

## Requirements

- Omarchy (Quickshell bar)
- `vorta` and `borg` on `PATH`
- A Vorta profile already configured

If you have more than one Vorta profile, set **Vorta profile name** in the
widget settings (or in `~/.config/omarchy/shell.json` on the bar entry).
Leave it empty to use the first profile.

## Bar colors

| Appearance | Meaning |
| --- | --- |
| Normal | Last backup within 24 hours |
| Dim | Older than 24 hours, Vorta down, or never backed up |
| Urgent | Last backup failed, or older than 48 hours |
| Pulse | A backup is running |

Thresholds are widget settings (`staleAfterHours`, `failedAfterHours`).

## Clicks and keys

Bar:

- Left click: open the panel
- Right click: start a backup
- Middle click: refresh status

Panel:

- `j` / `k` or arrows: move between actions
- Enter / space: run the selected action
- `b`: backup now
- `v`: open Vorta
- `r`: refresh
- Esc: close

## What this repo does not contain

This project is meant to be public. It must not include:

- SSH private keys, `authorized_keys`, or `known_hosts`
- Borg passphrases or key files
- Vorta `settings.db` (passwords, repo URLs)
- Hostnames, IPs, ports, or remote repo paths

Runtime status (profile name, last archive names) is read on **your**
machine from Vorta. It is not stored in this repository.

## Development

Repo root **is** the plugin folder (`manifest.json` at the top level), which
is what `omarchy plugin add` expects.

```bash
omarchy plugin validate .
```

To run a local checkout on Omarchy without publishing:

```bash
rsync -a --delete --exclude .git --exclude .gitignore \
  ./ ~/.config/omarchy/plugins/stolli.borg/
omarchy-shell shell rescanPlugins
```
