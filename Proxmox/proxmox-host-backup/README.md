# Proxmox Host Backup

The [proxmox backup client](https://pbs.proxmox.com/docs/backup-client.html) is able to backup files and folders on a host system. For example a physical host.

This script collects the mounted devices, creates a archive for each mountpoint and backup the data to given proxmox backup server.

Please note that this script is not using snapshots. Backups can have incontinence state of backup. Always test you backup!!

# Setup

Copy the script __[proxmox-host-backup.sh](proxmox-host-backup.sh)__ to `/usr/bin/proxmox-host-backup` and make it executeable. Create a environment file to place credetials and information where to store the backup.

```bash
vi /usr/bin/proxmox-host-backup
# ... insert the script and safe
chmod +x /usr/bin/proxmox-host-backup

cat <<EOF > /etc/default/proxmox-host-backup
# username or api token which has permission to write data on pbs
PBS_USER=<CHANGE ME>
# password or api token secret
PBS_PASSWORD=<CHANGE ME>
# pbs hostname or ip
PBS_HOST=<CHANGE ME>
# backup storage
PBS_STORAGE=<CHANGE ME>
# leave ot blank or disable, the script will collect mountpoints
#PBS_TARGETS=
# more arguments to pass (default: --skip-lost-and-found)
#PBS_ARGS=
EOF
```

## Install static linked binaries

```bash
# Download Static linked backup client
curl -O http://download.proxmox.com/debian/pbs-client/dists/bookworm/main/binary-amd64/proxmox-backup-client-static_3.4.1-1_amd64.deb
# Extract the deb archive
ar x proxmox-backup-client-static_3.4.1-1_amd64.deb
# Extract usr/bin/ files to /usr/bin/
tar -xvJf data.tar.xz -C / ./usr/bin/
```

Now, proxmox-backup-client should be available in `/usr/bin/proxmox-backup-client`

# Automate the backup

Take it simple, use cron
```cron
12 0  * * *    root     /usr/bin/proxmox-host-backup
```

or use systemd

_/lib/systemd/system/proxmox-host-backup.service_
```systemd
[Unit]
Description=Proxmox Host Backup

[Service]
Type=exec
User=root
ExecStart=/usr/bin/proxmox-host-backup
EnvironmentFile=/etc/default/proxmox-host-backup

[Install]
WantedBy=multi-user.target
```

_/lib/systemd/system/proxmox-host-backup.timer_
```systemd
[Unit]
Description=Proxmox Host Backup - Timer


[Timer]
OnCalendar=daily
RandomizedDelaySec=86400

[Install]
WantedBy=timers.target
```

Enable systemd units and start the timer
```bash
systemctl daemon-reload
systemctl enable proxmox-host-backup.timer proxmox-host-backup.service
systemctl start proxmox-host-backup.timer
```

## Exclude directories from Backup

See ["Excluding Files/Directories from a Backup"](https://pbs.proxmox.com/docs/backup-client.html#excluding-files-directories-from-a-backup) in the official documentation.
In short words: Place a file named `.pxarexclude` to the root of the mounted device eg. `/srv/.pxarexclude` and list all directories there you want to exclude from backup.

For examle:
__/srv/.pxarexclude__ 
```
dockerd/images/
tmp/
```

This will excude the directories `/srv/dockerd/images/` and `/srv/tmp/` from backup!