#!/bin/bash
# Wrapper script to backup proxmox host
#
# Author: Martin Weber (martin.weber@claranet.com)
# Version: 1.0.0

# is script is not started by systemd timer 
if [ -z "${SYSTEMD_EXEC_PID}" ] && [ -f /etc/default/proxmox-host-backup ]; then
	set -a # also export loaded variables
	. /etc/default/proxmox-host-backup
	set +a
fi

: ${PBS_CLIENT_BIN:="/usr/bin/proxmox-backup-client"}
: ${PBS_ARGS:="--skip-lost-and-found"}
: ${PBS_REPOSITORY:="${PBS_USER}@${PBS_HOST}:${PBS_STORAGE}"}
: ${PBS_BACKUP_ID:="$(hostname -f)"}

export PBS_REPOSITORY

if [ -z "${PBS_TARGETS}" ]; then
	PBS_TARGETS="root.pxar:/"
	# sed - Remove first slash
	MOUNT_POINTS=( $( findmnt -t nosquashfs,notmpfs,nodevtmpfs -D -n -o TARGET | sed 's/^\///' ) )
	for mount in ${MOUNT_POINTS[@]}; do
		NAME=$( echo $mount | sed 's/\-/--/' | sed 's/\//-/g' )
		PBS_TARGETS="${PBS_TARGETS} ${NAME}.pxar:/${mount}"
	done
fi

PBS_ARGS="${PBS_TARGETS} --backup-id ${PBS_BACKUP_ID} ${PBS_ARGS}"
${PBS_CLIENT_BIN} backup $PBS_ARGS
