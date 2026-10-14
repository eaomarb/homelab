# Homelab backups

My Debian + Docker server backs itself up every night at 04:00. Backups are encrypted, incremental, and verified afterwards.

## What gets backed up

| Source | Backup location | How it is backed up |
|---|---|---|
| `/docker` | `/backups/docker` | Incremental tar piped through encryption and split into 3.5 GB chunks. |
| `/data/gocryptfs` | `/data2/backups/gocryptfs` | Already encrypted, so it is packed as-is into 3.5 GB slices without compressing it again. |

## How it works

A systemd timer starts it every night, one service per step: Docker backup, then encrypted backup, then cloud upload. Each step has a lock so two runs never overlap. Before the backup, the containers on a list are stopped and their names are saved, so the next run can restart them even if the script was killed.

Marker files record the last successful run and the last full backup, which decides whether the next one is full or incremental. If a source folder is empty, the run aborts, because that almost always means a mount died.

## Off-site copy

For off-site storage I use my ISP's cloud, which has no official API. Files are uploaded one at a time through a community gateway. The cloud keeps the latest backup separate from the monthly history.

Every step of the pipeline is checked: sizes every night, a re-read of the stored data on Sundays, and real checksums weekly.

## Restore
Each script asks for a date and a folder. Restoring the full chain is the normal choice.

To restore from the cloud, I download the latest folder first and then follow the same steps. If the whole machine is lost, I reinstall with the same folder layout: Docker first, then the encrypted files.