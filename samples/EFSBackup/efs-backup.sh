#!/bin/bash
# Example would be to run this script as follows:
# Every 6 hours; retain last 4 backups
# efs-backup.sh $src $dst hourly 4 efs-12345
# Once a day; retain last 31 days
# efs-backup.sh $src $dst daily 31 efs-12345
# Once a week; retain 4 weeks of backup
# efs-backup.sh $src $dst weekly 7 efs-12345
# Once a month; retain 3 months of backups
# efs-backup.sh $src $dst monthly 3 efs-12345
#
# Snapshots will look like:
# $dst/$efsid/hourly.0-3; daily.0-30; weekly.0-3; monthly.0-2


# Input arguments
source=$1
destination=$2
interval=$3
retain=$4
efsid=$5

# Prepare system for rsync
#echo 'sudo yum -y update'
#sudo yum -y update
#echo 'sudo yum -y install nfs-utils'
#sudo yum -y install nfs-utils

#we need here to separete directories for running things in parallel
BACKUP_SRC="/backup-$efsid"
BACKUP_DST="/mnt/backups-$efsid"

echo "sudo mkdir ${BACKUP_SRC}"
sudo mkdir ${BACKUP_SRC}
echo "sudo mkdir ${BACKUP_DST}"
sudo mkdir ${BACKUP_DST}
echo "sudo mount -t nfs -o nfsvers=4.1 -o rsize=1048576 -o wsize=1048576 -o timeo=600 -o retrans=2 -o hard $source ${BACKUP_SRC}"
sudo mount -t nfs -o nfsvers=4.1 -o rsize=1048576 -o wsize=1048576 -o timeo=600 -o retrans=2 -o hard $source ${BACKUP_SRC}
echo "sudo mount -t nfs -o nfsvers=4.1 -o rsize=1048576 -o wsize=1048576 -o timeo=600 -o retrans=2 -o hard $destination ${BACKUP_DST}"
sudo mount -t nfs -o nfsvers=4.1 -o rsize=1048576 -o wsize=1048576 -o timeo=600 -o retrans=2 -o hard $destination ${BACKUP_DST}

# we need to decrement retain because we start counting with 0 and we need to remove the oldest backup
let "retain=$retain-1"
if sudo test -d ${BACKUP_DST}/$efsid/$interval.$retain; then
  echo "sudo rm -rf ${BACKUP_DST}/$efsid/$interval.$retain"
  sudo rm -rf ${BACKUP_DST}/$efsid/$interval.$retain
fi


# Rotate all previous backups (except the first one), up one level
for x in `seq $retain -1 2`; do
  if sudo test -d ${BACKUP_DST}/$efsid/$interval.$[$x-1]; then
    echo "sudo mv ${BACKUP_DST}/$efsid/$interval.$[$x-1] ${BACKUP_DST}/$efsid/$interval.$x"
    sudo mv ${BACKUP_DST}/$efsid/$interval.$[$x-1] ${BACKUP_DST}/$efsid/$interval.$x
  fi
done

# Copy first backup with hard links, then replace first backup with new backup
if sudo test -d ${BACKUP_DST}/$efsid/$interval.0 ; then
  echo "Copy first backup with hard links, then replace first backup with new backup"
  echo "sudo cp -al ${BACKUP_DST}/$efsid/$interval.0 ${BACKUP_DST}/$efsid/$interval.1"
  sudo cp -al ${BACKUP_DST}/$efsid/$interval.0 ${BACKUP_DST}/$efsid/$interval.1
fi
if [ ! -d ${BACKUP_DST}/$efsid ]; then
  echo "sudo mkdir -p ${BACKUP_DST}/$efsid"
  sudo mkdir -p ${BACKUP_DST}/$efsid
  echo "sudo chmod 700 ${BACKUP_DST}/$efsid"
  sudo chmod 700 ${BACKUP_DST}/$efsid
fi
if [ ! -d ${BACKUP_DST}/efsbackup-logs ]; then
  echo "sudo mkdir -p ${BACKUP_DST}/efsbackup-logs"
  sudo mkdir -p ${BACKUP_DST}/efsbackup-logs
  echo "sudo chmod 700 ${BACKUP_DST}/efsbackup-logs"
  sudo chmod 700 ${BACKUP_DST}/efsbackup-logs
fi
echo "sudo rm /tmp/efs-backup.log"
sudo rm /tmp/efs-backup.log
echo "sudo rsync -ah --progress --stats --delete --numeric-ids --log-file=/tmp/efs-backup.log ${BACKUP_SRC}/ ${BACKUP_DST}/$efsid/$interval.0/"
sudo rsync -ah --progress --stats --delete --numeric-ids --log-file=/tmp/efs-backup.log ${BACKUP_SRC}/ ${BACKUP_DST}/$efsid/$interval.0/
rsyncStatus=$?
echo "sudo cp /tmp/efs-backup.log ${BACKUP_DST}/efsbackup-logs/$efsid-`date +%Y%m%d-%H%M`.log"
sudo cp /tmp/efs-backup.log ${BACKUP_DST}/efsbackup-logs/$efsid-`date +%Y%m%d-%H%M`.log
echo "sudo touch ${BACKUP_DST}/$efsid/$interval.0/"
sudo touch ${BACKUP_DST}/$efsid/$interval.0/
echo "sudo umount ${BACKUP_SRC}"
sudo umount ${BACKUP_SRC}
echo "sudo umount ${BACKUP_DST}"
sudo umount ${BACKUP_DST}
exit $rsyncStatus
