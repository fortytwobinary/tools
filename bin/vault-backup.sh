#!/bin/bash
# vault-backup.sh
# 
# written by David L. Whitehurst on Mar 13, 2021
#
# This script creates a static filename for the duration of this shell
# and uses it to create a tar.gz archive to be securely copied over
# the network to another machine for safe keeping. The script also 
# removes the archive from the source machine.
#

export TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
cd /home/pi
tar -czf vault-$TIMESTAMP.tar.gz vault

scp vault-$TIMESTAMP.tar.gz david@192.168.1.20:/home/david/backups/ 
rm vault-$TIMESTAMP.tar.gz

